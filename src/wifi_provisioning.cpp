#include "wifi_provisioning.h"

// Static variables
static Preferences prefs;
static DNSServer dnsServer;
static WiFiState currentState = AP_ONLY;
static unsigned long staConnectStart = 0;
static String savedSSID;
static String savedPassword;
static bool staConnecting = false;

// Constant definitions
const char* AP_SSID = "ESP32_Config";
const char* AP_PASSWORD = nullptr;
const int AP_CHANNEL = 6;
const int MAX_AP_CLIENTS = 4;
const IPAddress AP_IP(192, 168, 4, 1);
const IPAddress AP_GATEWAY(192, 168, 4, 1);
const IPAddress AP_SUBNET(255, 255, 255, 0);
const uint32_t STA_CONNECT_TIMEOUT = 15000;
const byte DNS_PORT = 53;

void wifi_start_ap() {
  WiFi.softAPConfig(AP_IP, AP_GATEWAY, AP_SUBNET);
  WiFi.softAP(AP_SSID, AP_PASSWORD, AP_CHANNEL, 0, MAX_AP_CLIENTS);
  Serial.printf("AP started: SSID=%s, IP=%s\n", AP_SSID, AP_IP.toString().c_str());
}

void wifi_start_sta(const char* ssid, const char* password) {
  if (staConnecting) return;
  Serial.printf("Connecting to STA SSID: %s\n", ssid);
  WiFi.begin(ssid, password);
  staConnectStart = millis();
  currentState = CONNECTING;
  staConnecting = true;
}

bool wifi_save_credentials(const char* ssid, const char* password) {
  prefs.begin("wifi_creds", false);
  prefs.putString("ssid", ssid);
  prefs.putString("password", password ? password : "");
  prefs.end();
  Serial.printf("Saved WiFi credentials: SSID=%s\n", ssid);
  return true;
}

bool wifi_load_credentials(String &ssid, String &password) {
  prefs.begin("wifi_creds", true);
  bool hasSSID = prefs.isKey("ssid");
  if (hasSSID) {
    ssid = prefs.getString("ssid");
    password = prefs.getString("password", "");
  }
  prefs.end();
  return hasSSID;
}

void wifi_init() {
  WiFi.mode(WIFI_MODE_APSTA);
  wifi_start_ap();

  String ssid, pass;
  if (wifi_load_credentials(ssid, pass)) {
    savedSSID = ssid;
    savedPassword = pass;
    wifi_start_sta(ssid.c_str(), pass.c_str());
  } else {
    currentState = AP_ONLY;
    Serial.println("No saved WiFi credentials, running in AP-only mode");
  }
  
  wifi_start_captive_portal();
}

WiFiState wifi_get_state() {
  if (WiFi.status() == WL_CONNECTED) {
    currentState = CONNECTED;
    staConnecting = false;
  } else if (currentState == CONNECTING) {
    if (millis() - staConnectStart > STA_CONNECT_TIMEOUT) {
      currentState = FAILED;
      staConnecting = false;
      WiFi.disconnect();
      Serial.println("STA connection timed out");
    }
  }
  return currentState;
}

String wifi_get_sta_ip() {
  if (WiFi.status() == WL_CONNECTED) {
    return WiFi.localIP().toString();
  }
  return "";
}

void wifi_loop() {
  wifi_get_state();
  dnsServer.processNextRequest();
}

void wifi_start_captive_portal() {
  dnsServer.start(DNS_PORT, "*", AP_IP);
  Serial.println("Captive portal DNS server started");
}

void wifi_stop_captive_portal() {
  dnsServer.stop();
  Serial.println("Captive portal DNS server stopped");
}
