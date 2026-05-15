#include "sd_card.h"
#include "HWCDC.h"

#ifndef SD_MOSI_PIN
#define SD_MOSI_PIN 1
#endif
#ifndef SD_MISO_PIN
#define SD_MISO_PIN 2
#endif
#ifndef SD_SCK_PIN
#define SD_SCK_PIN 3
#endif
#ifndef SD_CS_PIN
#define SD_CS_PIN 10
#endif

SDCardManager sdCard;

bool SDCardManager::begin() {
  spi.begin(SD_SCK_PIN, SD_MISO_PIN, SD_MOSI_PIN, SD_CS_PIN);

  if (!SD.begin(SD_CS_PIN, spi, 1000000)) {
    Serial.println("SD card mount failed");
    initialized = false;
    return false;
  }

  uint8_t cardType = SD.cardType();
  if (cardType == CARD_NONE) {
    Serial.println("No SD card detected");
    initialized = false;
    return false;
  }

  Serial.printf("SD card initialized. Type: %u\n", cardType);

  if (!createNewFile()) {
    initialized = false;
    return false;
  }

  initialized = true;
  Serial.printf("SD logging to: %s\n", currentFilename.c_str());
  return true;
}

bool SDCardManager::createNewFile() {
  currentFilename = generateFilename();

  File file = SD.open(currentFilename.c_str(), FILE_WRITE);
  if (!file) {
    Serial.printf("Failed to create file: %s\n", currentFilename.c_str());
    return false;
  }

  file.println("timestamp,current,voltage,power,frequency,power_usage");
  file.close();

  Serial.printf("Created log file: %s\n", currentFilename.c_str());
  return true;
}

String SDCardManager::generateFilename() {
  for (uint16_t i = 1; i <= 999; i++) {
    char filename[MAX_FILENAME_LEN];
    snprintf(filename, MAX_FILENAME_LEN, "/measurement_%03u.csv", i);
    if (!SD.exists(filename)) {
      return String(filename);
    }
  }
  return String("/measurement_999.csv");
}

bool SDCardManager::hasSpace() {
  size_t freeKB = SD.totalBytes() / 1024 - SD.usedBytes() / 1024;
  return freeKB >= MIN_FREE_SPACE_KB;
}

void SDCardManager::logEntry(uint32_t timestamp, const MeasureData &data) {
  if (!initialized) {
    return;
  }

  if (!hasSpace()) {
    Serial.println("SD card low on space, skipping log");
    return;
  }

  File file = SD.open(currentFilename.c_str(), FILE_APPEND);
  if (!file) {
    Serial.println("Failed to open log file for append");
    return;
  }

  char line[128];
  snprintf(line, sizeof(line), "%u,%.4f,%.4f,%.4f,%.4f,%.4f", timestamp,
           data.current, data.voltage, data.power, data.frequency,
           data.power_usage);

  file.println(line);
  file.close();
}

std::vector<String> SDCardManager::listFiles() {
  std::vector<String> files;
  if (!initialized) {
    return files;
  }

  File root = SD.open("/");
  if (!root || !root.isDirectory()) {
    return files;
  }

  String name;
  while ((name = root.getNextFileName()) != "") {
    File f = SD.open(name.c_str());
    if (f && !f.isDirectory()) {
      files.push_back(name);
    }
    f.close();
  }
  root.close();

  return files;
}
