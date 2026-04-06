#pragma once

#include <Arduino.h>
#include <WiFi.h>
#include <Preferences.h>
#include <PsychicHttp.h>

class WiFiProvisioning {
public:
    enum State {
        AP_MODE,
        CONNECTING,
        STATION_MODE
    };

    static constexpr const char* AP_SSID = "ESP32-Config";
    static constexpr const char* AP_PASS = "";
    static constexpr uint8_t AP_CHANNEL = 1;
    static constexpr size_t MAX_WIFI_SSID_LEN = 32;
    static constexpr size_t MAX_WIFI_PASS_LEN = 64;
    static constexpr unsigned long CONNECT_TIMEOUT_MS = 10000;
    static constexpr uint8_t MAX_RETRIES = 3;

private:
    State state = AP_MODE;
    Preferences prefs;
    uint8_t retryCount = 0;
    unsigned long connectStartTime = 0;
    PsychicHttpServer* server = nullptr;
    PsychicEndpoint* rootEndpoint = nullptr;
    PsychicEndpoint* configEndpoint = nullptr;
    PsychicEndpoint* statusEndpoint = nullptr;

public:
    void begin();
    void loop();
    void setServer(PsychicHttpServer* srv);
    State getState() const { return state; }
    String getCurrentSSID() const;
    bool hasStoredCredentials();
    bool clearCredentials();
    bool connect(const char* ssid, const char* pass);
    void handleConnectTimeout();
    void handleDisconnection();
    IPAddress getLocalIP() const;

private:
    void createAccessPoint();
    void registerProvisioningEndpoints();
    void unregisterProvisioningEndpoints();
    esp_err_t handleRoot(PsychicRequest* request, PsychicResponse* response);
    esp_err_t handleConfigure(PsychicRequest* request, PsychicResponse* response);
    esp_err_t handleStatus(PsychicRequest* request, PsychicResponse* response);
    static esp_err_t staticHandleRoot(PsychicRequest* request, PsychicResponse* response) { return instance->handleRoot(request, response); }
    static esp_err_t staticHandleConfigure(PsychicRequest* request, PsychicResponse* response) { return instance->handleConfigure(request, response); }
    static esp_err_t staticHandleStatus(PsychicRequest* request, PsychicResponse* response) { return instance->handleStatus(request, response); }
    static WiFiProvisioning* instance;
};
