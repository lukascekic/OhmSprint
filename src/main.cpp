#include "PsychicHandler.h"
#include "PsychicResponse.h"
#include "simple.pb.h"
#include "wifi_provisioning.h"
#include <Arduino.h>
#include <FS.h>
#include <LittleFS.h>
#include <PsychicHttp.h>
#include <WiFi.h>
#include <pb_decode.h>
#include <pb_encode.h>

static WiFiProvisioning wifiProv;
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
  if (filePath == "/") {
    filePath = "/index.html";
  }

  File file = LittleFS.open(filePath, "r");
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

static SensorData dummy_sensor_data() {
  SensorData data = SensorData_init_zero;
  data.temperature = 23.5f;
  data.humidity = 65.0f;
  data.timestamp = millis();
  strcpy(data.sensor_id, "ESP32C3-001");
  return data;
}

esp_err_t handleProtobuf(PsychicRequest *request, PsychicResponse *response) {
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
  return response->send(200, "application/x-protobuf", buffer,
                        stream.bytes_written);
}

esp_err_t handleJson(PsychicRequest *request, PsychicResponse *response) {
  SensorData data = dummy_sensor_data();
  response->setContentType("application/json");

  char json[256];
  snprintf(json, sizeof(json),
           "{\"temperature\":%.1f,\"humidity\":%.1f,\"timestamp\":%lu,\"sensor_"
           "id\":\"%s\"}",
           data.temperature, data.humidity, data.timestamp, data.sensor_id);

  return response->send(json);
}

esp_err_t handleRoot(PsychicRequest *request, PsychicResponse *response) {
  return serveStaticFile(request->url().c_str(), response);
}

esp_err_t handleStatus(PsychicRequest *request, PsychicResponse *response) {
  char json[256];
  snprintf(json, sizeof(json), "{\"ssid\":\"%s\",\"ip\":\"%s\",\"rssi\":%d}",
           wifiProv.getCurrentSSID().c_str(),
           wifiProv.getLocalIP().toString().c_str(), WiFi.RSSI());
  return response->send(json);
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("\n\n=== ESP32-C3 Sensor Server ===");

  mountLittleFS();

  wifiProv.setServer(&server);
  wifiProv.begin();

  if (wifiProv.getState() == WiFiProvisioning::STATION_MODE) {
    Serial.println("WiFi connected, starting main server...");
  } else {
    Serial.println(
        "Access Point mode. Provisioning endpoints available at 192.168.4.1");
  }

  server.on("/", HTTP_GET, handleRoot);
  server.on("/status", HTTP_GET, handleStatus);
  server.on("/data/json", HTTP_GET, handleJson);
  server.on("/data/proto", HTTP_GET, handleProtobuf);
  server.on("/*", HTTP_GET, handleRoot);

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
