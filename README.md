# OhmSprint

Projekat razvijen za **OhmSprint hakaton** — sistem za merenje potrošnje
električne energije zasnovan na ATM90E26 mernom čipu, sa STM32 firmverom,
ESP32 mrežnim slojem i Flutter mobilnom aplikacijom.

## Struktura repozitorijuma

Sav kod se nalazi u tri foldera unutar `Code/`:

| Folder | Opis | README |
|---|---|---|
| [`Code/STM32`](Code/STM32) | STM32F103 firmver: merenje preko ATM90E26, lokalni OLED prikaz, USART1 dijagnostika, protobuf telemetrija ka ESP32 | [README](Code/STM32/README.md) |
| [`Code/ESP32`](Code/ESP32) | ESP32 mrežni sloj: WiFi provisioning, WebSocket/HTTP servis, SD logovanje, Astro web UI | [README](Code/ESP32/README.md) |
| [`Code/Mobile`](Code/Mobile/ohmsprint) | Flutter mobilna aplikacija: prikaz merenja, grafici, lokalna istorija, mDNS discovery | [README](Code/Mobile/ohmsprint/README.md) |

## Dokumentacija

Detaljna softverska dokumentacija — arhitektura sistema, projektne odluke,
kompromisi i validacija — nalazi se u
[`softver-dokumentacija.md`](softver-dokumentacija.md).
