#include "wifi_provisioning.h"

WiFiProvisioning* WiFiProvisioning::instance = nullptr;

void WiFiProvisioning::setServer(PsychicHttpServer* srv) {
    server = srv;
}

void WiFiProvisioning::begin() {
    WiFiProvisioning::instance = this;
    prefs.begin("wifi-creds", false);
    
    if (prefs.isKey("ssid")) {
        String storedSSID = prefs.getString("ssid");
        String storedPass = prefs.getString("pass", "");
        
        Serial.println("Found stored credentials, attempting to connect...");
        if (connect(storedSSID.c_str(), storedPass.c_str())) {
            return;
        }
    }
    
    createAccessPoint();
}

void WiFiProvisioning::createAccessPoint() {
    WiFi.mode(WIFI_AP_STA);
    WiFi.softAP(AP_SSID, AP_PASS, AP_CHANNEL);
    
    IPAddress IP = WiFi.softAPIP();
    Serial.print("Access Point started. IP: ");
    Serial.println(IP);
    
    registerProvisioningEndpoints();
    
    state = AP_MODE;
}

void WiFiProvisioning::registerProvisioningEndpoints() {
    if (!server) return;
    
    rootEndpoint = server->on("/", HTTP_GET, [this](PsychicRequest* request, PsychicResponse* response) {
        return handleRoot(request, response);
    });
    configEndpoint = server->on("/configure", HTTP_POST, [this](PsychicRequest* request, PsychicResponse* response) {
        return handleConfigure(request, response);
    });
    statusEndpoint = server->on("/status", HTTP_GET, [this](PsychicRequest* request, PsychicResponse* response) {
        return handleStatus(request, response);
    });
}

void WiFiProvisioning::unregisterProvisioningEndpoints() {
    if (server) {
        server->removeEndpoint(rootEndpoint);
        server->removeEndpoint(configEndpoint);
        server->removeEndpoint(statusEndpoint);
    }
    rootEndpoint = nullptr;
    configEndpoint = nullptr;
    statusEndpoint = nullptr;
}

esp_err_t WiFiProvisioning::handleRoot(PsychicRequest* request, PsychicResponse* response) {
    const char* html = R"(
<!DOCTYPE html>
<html>
<head>
    <title>WiFi Configuration</title>
    <meta name='viewport' content='width=device-width, initial-scale=1'>
    <style>
        * { box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 400px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { text-align: center; color: #333; margin-bottom: 30px; }
        .status { padding: 15px; border-radius: 5px; margin-bottom: 20px; text-align: center; }
        .status.connecting { background: #fff3cd; color: #856404; }
        .status.success { background: #d4edda; color: #155724; }
        .status.error { background: #f8d7da; color: #721c24; }
        .status.idle { background: #e2e3e5; color: #383d41; }
        label { display: block; margin-bottom: 5px; color: #555; font-weight: 500; }
        input[type='text'], input[type='password'] { width: 100%; padding: 12px; margin-bottom: 20px; border: 1px solid #ddd; border-radius: 5px; font-size: 16px; }
        button { width: 100%; padding: 15px; background: #007bff; color: white; border: none; border-radius: 5px; font-size: 16px; cursor: pointer; }
        button:hover { background: #0056b3; }
        button:disabled { background: #ccc; cursor: not-allowed; }
        .hidden { display: none; }
        .info { text-align: center; color: #666; font-size: 14px; margin-top: 20px; }
        .spinner { display: inline-block; width: 20px; height: 20px; border: 3px solid rgba(0,0,0,0.1); border-radius: 50%; border-top-color: #856404; animation: spin 1s ease-in-out infinite; margin-right: 10px; }
        @keyframes spin { to { transform: rotate(360deg); } }
    </style>
</head>
<body>
    <div class='container'>
        <h1>WiFi Configuration</h1>
        <div id='status' class='status idle'>Access Point Active</div>
        <form id='wifiForm'>
            <label for='ssid'>Network Name (SSID)</label>
            <input type='text' id='ssid' name='ssid' maxlength='32' required placeholder='Enter WiFi network name'>
            <label for='password'>Password</label>
            <input type='password' id='password' name='password' maxlength='64' placeholder='Enter WiFi password'>
            <button type='submit' id='submitBtn'>Connect</button>
        </form>
        <div id='message' class='hidden'></div>
        <p class='info'>Connect your device to the <strong>ESP32-Config</strong> network to configure WiFi.</p>
    </div>
    <script>
        const form = document.getElementById('wifiForm');
        const statusEl = document.getElementById('status');
        const message = document.getElementById('message');
        const submitBtn = document.getElementById('submitBtn');

        let pollingInterval = null;
        let isConnecting = false;

        async function checkStatus() {
            try {
                const resp = await fetch('/status');
                const data = await resp.json();
                
                if (data.state === 'connecting') {
                    statusEl.className = 'status connecting';
                    statusEl.innerHTML = '<span class="spinner"></span>Connecting...';
                } else if (data.state === 'connected') {
                    statusEl.className = 'status success';
                    statusEl.textContent = 'Connected! IP: ' + data.ip;
                    message.classList.remove('hidden');
                    message.style.background = '#d4edda';
                    message.style.color = '#155724';
                    message.style.padding = '15px';
                    message.style.borderRadius = '5px';
                    message.style.marginTop = '20px';
                    message.textContent = 'WiFi configured successfully. Redirecting...';
                    clearInterval(pollingInterval);
                    setTimeout(() => { window.location.href = '/'; }, 2000);
                } else if (data.state === 'failed') {
                    statusEl.className = 'status error';
                    statusEl.textContent = 'Connection Failed';
                    message.classList.remove('hidden');
                    message.style.background = '#f8d7da';
                    message.style.color = '#721c24';
                    message.style.padding = '15px';
                    message.style.borderRadius = '5px';
                    message.style.marginTop = '20px';
                    message.textContent = data.message || 'Could not connect to the specified network.';
                    submitBtn.disabled = false;
                    form.style.display = 'block';
                    clearInterval(pollingInterval);
                    isConnecting = false;
                }
            } catch (err) {
                console.error('Status check failed:', err);
            }
        }

        form.addEventListener('submit', async (e) => {
            e.preventDefault();
            if (isConnecting) return;

            const ssid = document.getElementById('ssid').value;
            const password = document.getElementById('password').value;

            if (!ssid || ssid.length > 31) {
                alert('Invalid SSID');
                return;
            }

            isConnecting = true;
            submitBtn.disabled = true;
            form.style.display = 'none';
            statusEl.className = 'status connecting';
            statusEl.innerHTML = '<span class="spinner"></span>Connecting...';
            message.classList.add('hidden');

            try {
                const formData = new URLSearchParams();
                formData.append('ssid', ssid);
                formData.append('password', password);

                const response = await fetch('/configure', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                    body: formData.toString()
                });

                const result = await response.json();

                if (result.success) {
                    pollingInterval = setInterval(checkStatus, 1000);
                    checkStatus();
                } else {
                    statusEl.className = 'status error';
                    statusEl.textContent = 'Error: ' + (result.message || 'Unknown error');
                    submitBtn.disabled = false;
                    form.style.display = 'block';
                    isConnecting = false;
                }
            } catch (err) {
                statusEl.className = 'status error';
                statusEl.textContent = 'Request failed';
                submitBtn.disabled = false;
                form.style.display = 'block';
                isConnecting = false;
            }
        });
    </script>
</body>
</html>
)";
    response->setContentType("text/html");
    return response->send(html);
}

esp_err_t WiFiProvisioning::handleConfigure(PsychicRequest* request, PsychicResponse* response) {
    if (request->method() != HTTP_POST) {
        return response->error(HTTPD_405_METHOD_NOT_ALLOWED, "Method not allowed");
    }

    String ssid = request->getParam("ssid") ? request->getParam("ssid")->value() : "";
    String password = request->getParam("password") ? request->getParam("password")->value() : "";

    if (ssid.length() == 0 || ssid.length() > 31) {
        response->setContentType("application/json");
        char error[128];
        snprintf(error, sizeof(error), "{\"success\":false,\"message\":\"Invalid SSID length (1-31 chars required)\"}");
        return response->send(error);
    }

    if (password.length() > 63) {
        response->setContentType("application/json");
        return response->send("{\"success\":false,\"message\":\"Password too long (max 63 chars)\"}");
    }

    Serial.printf("Received credentials for SSID: %s\n", ssid.c_str());

    prefs.putString("ssid", ssid);
    prefs.putString("pass", password);
    prefs.end();

    connect(ssid.c_str(), password.c_str());

    response->setContentType("application/json");
    return response->send("{\"success\":true,\"state\":\"connecting\"}");
}

esp_err_t WiFiProvisioning::handleStatus(PsychicRequest* request, PsychicResponse* response) {
    response->setContentType("application/json");
    
    char json[256];
    
    if (state == CONNECTING) {
        snprintf(json, sizeof(json),
            "{\"state\":\"connecting\",\"ip\":\"\",\"ssid\":\"\"}");
    } else if (state == STATION_MODE) {
        snprintf(json, sizeof(json),
            "{\"state\":\"connected\",\"ip\":\"%s\",\"ssid\":\"%s\"}",
            WiFi.localIP().toString().c_str(),
            WiFi.SSID().c_str());
    } else {
        snprintf(json, sizeof(json),
            "{\"state\":\"idle\",\"ip\":\"%s\",\"ssid\":\"\"}",
            WiFi.softAPIP().toString().c_str());
    }
    
    return response->send(json);
}

void WiFiProvisioning::loop() {
    if (state == CONNECTING) {
        handleConnectTimeout();
    }
}

bool WiFiProvisioning::connect(const char* ssid, const char* pass) {
    WiFi.mode(WIFI_AP_STA);
    WiFi.begin(ssid, pass);
    
    state = CONNECTING;
    connectStartTime = millis();
    retryCount = 0;
    
    Serial.printf("Connecting to %s...\n", ssid);
    
    return true;
}

void WiFiProvisioning::handleConnectTimeout() {
    wl_status_t status = WiFi.status();
    
    if (status == WL_CONNECTED) {
        state = STATION_MODE;
        Serial.print("Connected! IP: ");
        Serial.println(WiFi.localIP());
        return;
    }
    
    if (millis() - connectStartTime > CONNECT_TIMEOUT_MS) {
        retryCount++;
        Serial.printf("Connection timeout. Retry %d/%d\n", retryCount, MAX_RETRIES);
        
        if (retryCount >= MAX_RETRIES) {
            Serial.println("Max retries reached. Returning to AP mode.");
            WiFi.disconnect(true);
            prefs.begin("wifi-creds", false);
            prefs.remove("ssid");
            prefs.remove("pass");
            prefs.end();
            createAccessPoint();
        } else {
            WiFi.disconnect(false);
            delay(100);
            String ssid = prefs.getString("ssid");
            String pass = prefs.getString("pass", "");
            WiFi.begin(ssid.c_str(), pass.c_str());
            connectStartTime = millis();
        }
    }
}

void WiFiProvisioning::handleDisconnection() {
    if (state == STATION_MODE) {
        Serial.println("WiFi disconnected. Returning to AP mode.");
        createAccessPoint();
    }
}

bool WiFiProvisioning::hasStoredCredentials() {
    return prefs.isKey("ssid");
}

bool WiFiProvisioning::clearCredentials() {
    return prefs.clear();
}

String WiFiProvisioning::getCurrentSSID() const {
    if (state == STATION_MODE) {
        return WiFi.SSID();
    }
    return "";
}

IPAddress WiFiProvisioning::getLocalIP() const {
    if (state == STATION_MODE) {
        return WiFi.localIP();
    } else if (state == AP_MODE) {
        return WiFi.softAPIP();
    }
    return IPAddress(0, 0, 0, 0);
}
