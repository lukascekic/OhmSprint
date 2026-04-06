#include <Arduino.h>
#include <WiFi.h>
#include <PsychicHttp.h>
#include <pb_encode.h>
#include <pb_decode.h>
#include "wifi_provisioning.h"
#include "simple.pb.h"

static WiFiProvisioning wifiProv;
static PsychicHttpServer server;

static SensorData dummy_sensor_data() {
    SensorData data = SensorData_init_zero;
    data.temperature = 23.5f;
    data.humidity = 65.0f;
    data.timestamp = millis();
    strcpy(data.sensor_id, "ESP32C3-001");
    return data;
}

esp_err_t handleProtobuf(PsychicRequest* request, PsychicResponse* response) {
    SensorResponse resp = SensorResponse_init_zero;
    resp.success = true;
    strncpy(resp.message, "OK", sizeof(resp.message) - 1);
    resp.data.temperature = 23.5f;
    resp.data.humidity = 65.0f;
    resp.data.timestamp = millis();
    strncpy(resp.data.sensor_id, "ESP32C3-001", sizeof(resp.data.sensor_id) - 1);
    resp.has_data = true;

    uint8_t buffer[256];
    pb_ostream_t stream = pb_ostream_from_buffer(buffer, sizeof(buffer));
    
    if (!pb_encode(&stream, SensorResponse_fields, &resp)) {
        response->setContentType("text/plain");
        return response->send("Encoding failed");
    }

    response->setContentType("application/x-protobuf");
    return response->send(200, "application/x-protobuf", buffer, stream.bytes_written);
}

esp_err_t handleJson(PsychicRequest* request, PsychicResponse* response) {
    SensorData data = dummy_sensor_data();
    
    char json[256];
    snprintf(json, sizeof(json),
        "{\"temperature\":%.1f,\"humidity\":%.1f,\"timestamp\":%lu,\"sensor_id\":\"%s\"}",
        data.temperature, data.humidity, data.timestamp, data.sensor_id);

    return response->send(json);
}

esp_err_t handleRoot(PsychicRequest* request, PsychicResponse* response) {
    const char* html = R"(
        <!DOCTYPE html>
        <html>
        <head>
            <title>ESP32-C3 Sensor</title>
            <meta name='viewport' content='width=device-width, initial-scale=1'>
            <style>
                body { font-family: -apple-system, sans-serif; margin: 0; padding: 20px; background: #f0f0f0; }
                .container { max-width: 600px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; }
                h1 { color: #333; }
                .data { background: #f8f9fa; padding: 20px; border-radius: 5px; margin: 20px 0; }
                .data p { margin: 10px 0; }
                a { display: inline-block; padding: 10px 20px; background: #007bff; color: white; text-decoration: none; border-radius: 5px; margin: 5px; }
                .status { color: #666; font-size: 14px; }
            </style>
        </head>
        <body>
            <div class='container'>
                <h1>ESP32-C3 Sensor Server</h1>
                <div class='status'>WiFi: <span id='ssid'></span> | IP: <span id='ip'></span></div>
                <div class='data'>
                    <p><strong>Temperature:</strong> <span id='temp'>--</span> C</p>
                    <p><strong>Humidity:</strong> <span id='hum'>--</span> %</p>
                    <p><strong>Timestamp:</strong> <span id='time'>--</span></p>
                    <p><strong>Sensor ID:</strong> <span id='id'>--</span></p>
                </div>
                <div>
                    <a href='/data/proto'>Get Protobuf</a>
                    <a href='/data/json'>Get JSON</a>
                </div>
            </div>
            <script>
                async function loadData() {
                    try {
                        const resp = await fetch('/data/json');
                        const data = await resp.json();
                        document.getElementById('temp').textContent = data.temperature;
                        document.getElementById('hum').textContent = data.humidity;
                        document.getElementById('time').textContent = data.timestamp;
                        document.getElementById('id').textContent = data.sensor_id;
                    } catch (e) {}
                }
                async function loadStatus() {
                    try {
                        const resp = await fetch('/status');
                        const data = await resp.json();
                        document.getElementById('ssid').textContent = data.ssid || 'Not connected';
                        document.getElementById('ip').textContent = data.ip || '--';
                    } catch (e) {}
                }
                loadData();
                loadStatus();
                setInterval(loadData, 5000);
            </script>
        </body>
        </html>
    )";
    response->setContentType("text/html");
    return response->send(html);
}

esp_err_t handleStatus(PsychicRequest* request, PsychicResponse* response) {
    char json[256];
    snprintf(json, sizeof(json),
        "{\"ssid\":\"%s\",\"ip\":\"%s\",\"rssi\":%d}",
        wifiProv.getCurrentSSID().c_str(),
        wifiProv.getLocalIP().toString().c_str(),
        WiFi.RSSI());
    return response->send(json);
}

void setup() {
    Serial.begin(115200);
    delay(500);
    
    Serial.println("\n\n=== ESP32-C3 Sensor Server ===");
    
    wifiProv.setServer(&server);
    wifiProv.begin();
    
    if (wifiProv.getState() == WiFiProvisioning::STATION_MODE) {
        Serial.println("WiFi connected, starting main server...");
    } else {
        Serial.println("Access Point mode. Provisioning endpoints available at 192.168.4.1");
    }

    server.on("/", HTTP_GET, handleRoot);
        server.on("/status", HTTP_GET, handleStatus);
        server.on("/data/json", HTTP_GET, handleJson);
        server.on("/data/proto", HTTP_GET, handleProtobuf);

    server.begin();
}

void loop() {
    wifiProv.loop();
    
    if (wifiProv.getState() == WiFiProvisioning::STATION_MODE) {
        if (WiFi.status() != WL_CONNECTED) {
            wifiProv.handleDisconnection();
        }
    }
}
