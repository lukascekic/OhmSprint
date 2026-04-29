#include "PsychicHandler.h"
#include "PsychicResponse.h"
#include "wifi_provisioning.h"
#include <Arduino.h>
#include <ArduinoJson.h>
#include <DNSServer.h>
#include <FS.h>
#include <LittleFS.h>
#include <PsychicHttp.h>
#include <PsychicRequest.h>
#include <WiFi.h>
#include <pb_decode.h>
#include <pb_encode.h>

static PsychicHttpServer server;

bool lfsMounted = false;

bool mountLittleFS() {
  if (!LittleFS.begin()) {
    Serial.println("LittleFS mount failed");
    return false;
  }
  Serial.println("LittleFS mounted");
  lfsMounted = true;
  return true;
}

esp_err_t serveStaticFile(const char *path, PsychicResponse *response) {
  if (!lfsMounted) {
    return response->send(500, "text/plain", "LittleFS not mounted");
  }

  String filePath = path;

  // Normalize: remove trailing slash (except for root)
  if (filePath != "/" && filePath.endsWith("/")) {
    filePath.remove(filePath.length() - 1);
  }

  if (filePath == "/") {
    filePath = "/index.html";
  }

  File file = LittleFS.open(filePath, "r");

  if (file.isDirectory()) {
    String indexFilePath = filePath + "/index.html";
    file = LittleFS.open(indexFilePath, "r");
    if (file) {
      filePath = indexFilePath;
    }
  }

  if (!file) {
    return response->send(404, "text/plain", "File not found");
  }

  String contentType = "text/plain";
  if (filePath.endsWith(".html"))
    contentType = "text/html";
  else if (filePath.endsWith(".css"))
    contentType = "text/css";
  else if (filePath.endsWith(".js"))
    contentType = "application/javascript";
  else if (filePath.endsWith(".svg"))
    contentType = "image/svg+xml";
  else if (filePath.endsWith(".png"))
    contentType = "image/png";
  else if (filePath.endsWith(".ico"))
    contentType = "image/x-icon";

  size_t size = file.size();
  uint8_t *buffer = (uint8_t *)malloc(size);
  if (!buffer) {
    file.close();
    return response->send(500, "text/plain", "Memory allocation failed");
  }

  file.read(buffer, size);
  file.close();

  response->setContentType(contentType.c_str());
  esp_err_t err = response->send(200, contentType.c_str(), buffer, size);
  free(buffer);
  return err;
}

esp_err_t handleRoot(PsychicRequest *request, PsychicResponse *response) {
  return serveStaticFile(request->url().c_str(), response);
}

esp_err_t handleCaptiveRedirect(PsychicRequest *request,
                                PsychicResponse *response) {
  String redirectURL = "http://" + AP_IP.toString() + "/configure/index.html";
  return response->redirect(redirectURL.c_str());
}

esp_err_t handleCaptiveOK(PsychicRequest *request, PsychicResponse *response) {
  return response->send(200, "text/plain", "");
}

esp_err_t handle404(PsychicRequest *request, PsychicResponse *response) {
  return response->send(404, "text/plain", "Not Found");
}

esp_err_t handleConfigure(PsychicRequest *request, PsychicResponse *response) {
  String body = request->body();
  String ssid, password;

  int ssidStart = body.indexOf("ssid=");
  int passStart = body.indexOf("&password=");

  if (ssidStart >= 0) {
    ssidStart += 5;
    if (passStart > ssidStart) {
      ssid = body.substring(ssidStart, passStart);
      password = body.substring(passStart + 10);
      ssid.replace("+", " ");
      password.replace("+", " ");
    } else {
      ssid = body.substring(ssidStart);
      ssid.replace("+", " ");
    }
  }

  JsonDocument doc;
  if (ssid.length() == 0 || ssid.length() > 31) {
    doc["success"] = false;
    doc["message"] = "Invalid SSID";
  } else {
    wifi_save_credentials(ssid.c_str(), password.c_str());
    wifi_start_sta(ssid.c_str(), password.c_str());
    doc["success"] = true;
  }

  String json;
  serializeJson(doc, json);
  return response->send(200, "application/json", json.c_str());
}

esp_err_t handleStatus(PsychicRequest *request, PsychicResponse *response) {
  JsonDocument doc;
  WiFiState state = wifi_get_state();

  switch (state) {
  case AP_ONLY:
    doc["state"] = "idle";
    break;
  case CONNECTING:
    doc["state"] = "connecting";
    break;
  case CONNECTED:
    doc["state"] = "connected";
    doc["ip"] = wifi_get_sta_ip();
    break;
  case FAILED:
    doc["state"] = "failed";
    doc["message"] = "Connection failed";
    break;
  }

  String json;
  serializeJson(doc, json);
  return response->send(200, "application/json", json.c_str());
}

esp_err_t handleCatchAll(PsychicRequest *request, PsychicResponse *response) {
  String redirectURL = "http://" + AP_IP.toString() + "/configure";
  return response->redirect(redirectURL.c_str());
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  if (!Serial)
    delay(2000); // Wait for USB CDC on ESP32-C3

  Serial.println("\n\n=== ESP32-C3 Sensor Server ===");

  mountLittleFS();

  // WiFi provisioning
  wifi_init();

  // Captive portal detection endpoints
  server.on("/generate_204", HTTP_GET, handleCaptiveRedirect);
  server.on("/hotspot-detect.html", HTTP_GET, handleCaptiveRedirect);
  server.on("/canonical.html", HTTP_GET, handleCaptiveRedirect);
  server.on("/ncsi.txt", HTTP_GET, handleCaptiveRedirect);
  server.on("/connecttest.txt", HTTP_GET, handleCaptiveRedirect);
  server.on("/success.txt", HTTP_GET, handleCaptiveOK);
  server.on("/wpad.dat", HTTP_GET, handle404);

  // Configuration endpoints
  server.on("/configure", HTTP_POST, handleConfigure);
  server.on("/status", HTTP_GET, handleStatus);

  // Static file serving
  server.on("/", HTTP_GET, handleRoot);
  server.on("/*", HTTP_GET, handleRoot);

  // Catch-all redirect for captive portal
  server.onNotFound(handleCatchAll);

  server.begin();
}

void loop() { wifi_loop(); }
