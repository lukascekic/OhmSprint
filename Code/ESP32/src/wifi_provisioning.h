#ifndef WIFI_PROVISIONING_H
#define WIFI_PROVISIONING_H

#include <Arduino.h>
#include <WiFi.h>
#include <DNSServer.h>
#include <Preferences.h>

enum WiFiState {
  AP_ONLY,
  CONNECTING,
  CONNECTED,
  FAILED
};

// Constants
extern const char* AP_SSID;
extern const char* AP_PASSWORD;
extern const int AP_CHANNEL;
extern const int MAX_AP_CLIENTS;
extern const IPAddress AP_IP;
extern const IPAddress AP_GATEWAY;
extern const IPAddress AP_SUBNET;
extern const uint32_t STA_CONNECT_TIMEOUT;
extern const byte DNS_PORT;

// Functions
void wifi_init();
bool wifi_save_credentials(const char* ssid, const char* password);
bool wifi_load_credentials(String &ssid, String &password);
void wifi_start_ap();
void wifi_start_sta(const char* ssid, const char* password);
WiFiState wifi_get_state();
String wifi_get_sta_ip();
void wifi_loop();
void wifi_start_captive_portal();
void wifi_stop_captive_portal();

#endif
