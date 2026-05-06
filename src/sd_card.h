#ifndef SD_CARD_H
#define SD_CARD_H

#include "esp32-hal-spi.h"
#include <Arduino.h>
#include <SD.h>
#include <SPI.h>
#include <simple.pb.h>
#include <vector>

class SDCardManager {
public:
  bool begin();
  void logEntry(uint32_t timestamp, const MeasureData &data);
  bool isInitialized() const { return initialized; }
  std::vector<String> listFiles();

private:
  bool initialized = false;
  String currentFilename;
  SPIClass spi{FSPI};
  static constexpr uint32_t MIN_FREE_SPACE_KB = 100;
  static constexpr size_t MAX_FILENAME_LEN = 64;

  bool createNewFile();
  bool hasSpace();
  String generateFilename();
};

extern SDCardManager sdCard;

#endif
