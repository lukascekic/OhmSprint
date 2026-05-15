# Softverska dokumentacija

## 1. Arhitektura sistema

Softver je organizovan u tri sloja: STM32 firmware, ESP32 mrežni servis i Flutter mobilna aplikacija. STM32 firmware je zadužen za merenje: inicijalizaciju merne elektronike, komunikaciju sa ATM90E26 mernim čipom, lokalni prikaz, dijagnostički log i slanje merenja prema ESP32. ESP32 firmware je zaseban sloj u predatom repozitorijumu i služi kao veza između STM32 i mobilne aplikacije.

Osnovni tok podataka je:

```text
ATM90E26
   │  SPI1 register read/write
   ▼
STM32F103C8T6 firmware
   │  USART2: [4-byte big-endian length][nanopb MeasureData]
   ▼
ESP32 firmware
   │  WiFi: JSON preko WebSocket-a ili HTTP polling-a
   ▼
Flutter mobilna aplikacija
```

Ovakva podela odgovornosti smanjuje mešanje različitih problema. STM32 ostaje fokusiran na merenje, pin-control i lokalnu dijagnostiku, ESP32 prima protobuf poruke, izlaže mrežni servis, servira lokalnu web aplikaciju i vodi SD log, a mobilna aplikacija prikazuje podatke i čuva istoriju.

## 2. STM32 firmware

### 2.1 Uloga i periferije

STM32 firmware se nalazi u `Code/STM32`. Glavni aplikacioni tok je u `Core/Src/main.c`, dok su pojedinačne odgovornosti izdvojene u posebne module. Firmware koristi sledeće periferije:

| Periferija | Namena |
|---|---|
| SPI1 | Komunikacija sa ATM90E26 mernim čipom |
| I2C1 | Komunikacija sa SSD1306 OLED displejem |
| USART1 | Dijagnostički log prema računaru |
| USART2 | Binarna telemetrija prema ESP32 |
| TIM2 | PWM izlaz za buzzer i input capture za CF1/CF2 impulse |
| EXTI | Brojanje ZX, IRQ i WARN_OUT događaja |
| GPIO | Reset merne elektronike, chip select, ulazi za stanje napajanja, ESP enable/boot/mux kontrola |

Pregled glavnih modula:

| Modul | Odgovornost |
|---|---|
| `main.c` | Orkestracija boot sekvence, periodičnog merenja i callback logike |
| `atm90e26.c/h` | SPI driver za ATM90E26, kalibracija, checksum provera i čitanje registara |
| `board_control.c/h` | Bezbedni početni nivoi pinova, reset merne elektronike, snapshot stanja ploče i detekcija izvora napajanja |
| `esp_control.c/h` | Kontrola ESP32 enable/boot/mux pinova, snapshot ESP stanja i USB DTR/RTS passthrough logika |
| `debug_console.c/h` | Strukturisani USART1 dijagnostički log |
| `display.c/h` | Aplikacioni sloj za OLED prikaz merenja i grešaka |
| `ssd1306.c/h` | SSD1306 I2C driver i framebuffer |
| `uart_protocol.c/h` | Kodiranje `MeasureData` poruke i slanje prema ESP32 preko USART2 |
| `measure.proto`, `measure.pb.c/h` | Protobuf šema i nanopb opis poruke, ugovor za STM32-ESP32 payload |

OLED inicijalizacija ne zaustavlja sistem. Ako displej ne odgovori na I2C, firmware to evidentira u USART1 logu i nastavlja merenje i slanje podataka. U slučaju HardFault prekida, `HardFault_Handler` emituje `HF` preko USART1 pre ulaska u beskonačnu petlju (`stm32f1xx_it.c:85-98`), što olakšava dijagnostiku kada se problem desi bez priključenog debuggera.

### 2.2 Boot sekvenca i periodično merenje

Boot sekvenca je linearna: prvo se inicijalizuju HAL i periferije, zatim početna stanja pinova, dijagnostika, displej, napredni I/O i merni čip. Ovaj redosled olakšava hardversku validaciju, jer USART1 log postaje dostupan pre inicijalizacije mernog čipa.

```text
HAL_Init
  -> SystemClock_Config
  -> MX_GPIO/I2C/SPI/USART/TIM init
  -> DWT_Init
  -> BoardControl_ApplyBringupDefaults
  -> BoardControl_ResetSensing
  -> DebugConsole_Init + BOOT/BOARD/ESP log
  -> Display_Init
  -> AdvancedIo_Init
  -> ATM90E26_Init, do 3 pokušaja
  -> UART_Proto_Init
  -> 1 Hz measurement loop
```

U kodu se period merenja definiše kao `MEASUREMENT_PERIOD_MS = 1000U` u `main.c:48`. Glavna petlja proverava proteklo vreme preko `HAL_GetTick()` i na svakih 1000 ms pokreće merni ciklus (`main.c:288-314`). Tokom svakog ciklusa firmware:

1. ažurira ESP control state machine,
2. ažurira buzzer/alert logiku,
3. loguje ESP i napredni I/O status,
4. čita ATM90E26 merenja,
5. ažurira OLED,
6. ispisuje `MEAS` liniju na USART1,
7. šalje binarni `MeasureData` frame ESP32-u preko USART2.

### 2.3 Buzzer, EXTI i impulsni signali

Brzi eksterni događaji ne obrađuju se polling-om u glavnoj petlji. EXTI callback samo inkrementira broj ZX/IRQ/WARN_OUT događaja i, za `IRQ` i `WARN_OUT`, postavlja `alertPulsePending` flag (`main.c:362-376`). Glavna petlja zatim pokreće buzzer pulse od 120 ms (`main.c:121-136`). Na taj način prekidna rutina ostaje kratka, a zvučni signal se generiše iz regularnog main-loop konteksta.

Datasheet definiše ove pinove kao dijagnostičke i energetske izlaze ATM90E26 čipa. Firmware ih koristi kao signale za hardversku validaciju:

| Signal | Datasheet semantika | Kako firmware koristi signal |
|---|---|---|
| `ZX` | Izlaz za prolazak napona kroz nulu, režim se podešava u `MMode` registru | Broji se kao indikator aktivnosti mernog dela |
| `IRQ` | Interrupt izlaz, aktivira se kada se postavi relevantan događaj u `SysStatus` registru | Broji se i pokreće buzzer pulse |
| `WARN_OUT` | Fatal/warning izlaz, aktivira se na calibration/checksum greške i na voltage sag ako je `SagWo` omogućen | Broji se i pokreće buzzer pulse |
| `CF1` | Impulsni izlaz proporcionalan aktivnoj energiji | Broji se preko TIM2 input capture callback-a (`main.c:380-392`) |
| `CF2` | Impulsni izlaz proporcionalan reaktivnoj energiji | Broji se preko TIM2 input capture callback-a (`main.c:380-392`) |

Firmware u `ATM90E26_Init()` upisuje `FUNC_EN = 0x0030`, čime uključuje `SagEn` i `SagWo` bitove (`atm90e26.c:145`). Time se onemogućuju i default `RevPEn`/`RevQEn` bitovi za prekide pri promeni smera aktivne i reaktivne energije, jer ti događaji nisu korišćeni u ovoj iteraciji firmvera. To znači da je pad napona u ovoj konfiguraciji omogućen kao `SysStatus`/`IRQ` događaj i kao `WARN_OUT` signal. Tačan uzrok prekida se ne dekodira u EXTI callback-u, firmware broji ivice signala, daje zvučnu potvrdu preko buzzera za `IRQ`/`WARN_OUT`, i periodično čita `SysStatus` kroz ATM90E26 driver.

CF1/CF2 daju drugi, impulsni put ka energetskoj akumulaciji. Trenutna logika ukupnu energiju dobija čitanjem `AP_ENERGY`/`AN_ENERGY` registara, dok CF brojači ostaju dijagnostički indikator aktivnosti mernog dela.

### 2.4 ATM90E26 inicijalizacija i čitanje merenja

ATM90E26 driver koristi SPI pristup preko registara. Funkcije `read_reg_checked()` i `write_reg_checked()` ručno kontrolišu chip select pin, čekaju mikrosekundne intervale preko `delay_us()`, zatim obavljaju trobajtne SPI transakcije. SPI je podešen kao Mode 3 sa ručno kontrolisanim CS pinom, što odgovara načinu rada mernog čipa.

Inicijalizacija ATM90E26 nije samo upis kalibracionih vrednosti. Tok je:

```text
CS high + delay
  -> soft reset
  -> FUNC_EN write
  -> LAST_DATA provera upisanog podatka
  -> SAG threshold
  -> CS1 calibration bank + checksum
  -> CS2 adjustment bank + checksum
  -> close calibration banks
  -> SYS_STATUS read
  -> reject init if CAL/ADJ error bits are set
```

Driver proverava osnovnu SPI komunikaciju tako što posle upisa `FUNC_EN = 0x0030` čita `ATM_REG_LAST_DATA` (`atm90e26.c:150-154`). Kalibracione banke imaju odvojene checksum vrednosti: `calc_cs_one()` i `calc_cs_two()` (`atm90e26.c:74-92`), a rezultat se proverava preko `SYS_STATUS` registra (`atm90e26.c:220-229`). Kalibracione vrednosti su određene i validirane tokom hardverske validacije.

Periodično čitanje merenja radi `ATM90E26_ReadAll()` (`atm90e26.c:252`). Funkcija čita napon, struje, aktivnu, reaktivnu i prividnu snagu, frekvenciju, faktor snage, fazni ugao i registre energije. Energetski registri se sabiraju u `totalImportEnergy` i `totalExportEnergy` (`atm90e26.c:297-298`). Ove vrednosti žive u RAM-u STM32 mikrokontrolera, pa se resetuju posle STM32 reset-a.

### 2.5 STM32-ESP32 protokol

STM32 prema ESP32 šalje jednu `MeasureData` poruku enkodovanu pomoću nanopb posle uspešnog merenja. Šema je definisana u `Core/Proto/measure.proto`:

```text
MeasureData {
  current
  voltage
  power
  frequency
  power_usage
  sd_logs_enable
  wifi_enable
}
```

`UART_SendMeasurements()` popunjava C strukturu `MeasureData`, skalira sirove ATM90E26 vrednosti u fizičke jedinice i poziva `pb_encode()` (`uart_protocol.c:19-39`). Polja `sd_logs_enable` i `wifi_enable` sada se uvek šalju kao `true` (`uart_protocol.c:36-37`). Ona su ostavljena u šemi za naredne iteracije, pre svega za režim smanjene potrošnje u kome bi kontroler mogao da isključi WiFi i opciono SD logovanje kada se ploča napaja iz baterije umesto iz USB-a.

Pošto je UART bajt-stream bez prirodnih granica poruka, ispred protobuf payload-a dodaje se 4-byte big-endian dužina (`uart_protocol.c:43-46`). Konačni frame je:

```text
[length byte 0][length byte 1][length byte 2][length byte 3][protobuf payload]
```

Polje `power_usage` u trenutnoj implementaciji nosi vrednost `totalExport` registra (`uart_protocol.c:35`). Tokom hardverske validacije uočeno je da rastući energetski brojač u korišćenom žičnom rasporedu odgovara `AN_ENERGY` registru ATM90E26, koji u toj konfiguraciji predstavlja potrošnju. Mobilna aplikacija ovu vrednost prikazuje kao ukupnu potrošnju.

### 2.6 ESP control i servisni režimi

`esp_control.c` ima dve uloge. Prva je upravljanje ESP32 stanjem: enable pin, boot mode i USB-UART mux. U normalnom režimu ESP32 je uključen i drži se u app boot režimu (`esp_control.c:37-42`). Ovaj deo nije kozmetički: `MX_GPIO_Init()` postavlja `ESP_EN` na LOW (`gpio.c:63`), a `EspControl_Init()` ga prebacuje na HIGH zajedno sa ostalim ESP boot/mux signalima, čime modul preuzima kontrolu nad ESP32 boot/run stanjem.

Druga uloga je prosleđivanje USB DTR/RTS signala ka ESP32 boot/reset pinovima (`esp_control.c:45-55`). `BOOT_DEBUG` ulaz bira rutu USB-UART mux-a. Kada je izabran STM32 put, USB-UART se koristi za USART1 debug konzolu. Kada je izabran ESP32 put, firmware mapira DTR/RTS signale ka ESP32 boot/reset kontroli. `EspControl_Task()` periodično čita `BOOT_DEBUG`, debouncuje promenu i primenjuje odgovarajući režim (`esp_control.c:138-163`).

Put za prosleđivanje DTR/RTS signala nije hardverski validiran u test fazi zbog ograničenog vremena. ESP32 je flešovan direktnim hardverskim pristupom na ploči. Kod je zadržan u firmveru, a ova logika je odvojena od normalne ESP kontrole unutar istog modula, tako da eventualna validacija u sledećoj iteraciji ne dira merni ni komunikacioni deo.

### 2.7 Projektne odluke i kompromisi

**Podela slojeva.** STM32 meri i obavlja lokalnu dijagnostiku, ESP32 izlaže mrežni servis i vodi SD log, a mobilna aplikacija prikazuje podatke i čuva lokalnu istoriju merenja. Alternativa bi bila da ESP32 preuzme i merni deo, ili da se doda jači glavni kontroler. Izabrana podela je pogodna za hardversku validaciju: ako postoje `MEAS` i `TX2` logovi na STM32 strani, merni sloj radi, pa se problem traži u ESP32 parseru, WiFi transportu ili aplikaciji.

**HSI 8 MHz.** Inicijalna verzija firmvera je koristila interni HSI clock kako bi se smanjila zavisnost od hardvera prilikom prvog testiranja. Kasnije prebacivanje na HSE+PLL nije bilo prioritet zbog ograničenog vremena, pogotovo jer trenutni sistem nema veliku korist od preciznijeg ili bržeg takta. Merenje se radi na 1 Hz, brzine komunikacije su niske, a glavna petlja najveći deo vremena čeka periferije kroz blokirajuće HAL pozive. Eksterni 8 MHz oscilator ostaje rezerva za buduće zahteve koji bi opravdali PLL ili brži tok podataka.

**Kooperativni firmware bez RTOS-a.** Glavna petlja radi periodične zadatke, a prekidi samo prikupljaju događaje. Za trenutni scope sistema to je jednostavnije od RTOS taskova, redova i semafora. Ograničenje je to što blokirajući HAL pozivi mogu zadržati petlju ako periferija kasni, ali pri 1 Hz merenju i malom protoku podataka to je prihvatljiv kompromis.

**ATM90E26 driver.** Driver ne pretpostavlja da je upis uspeo samo zato što je HAL vratio `HAL_OK`. Init ima proveru preko `LAST_DATA`, CS1/CS2 checksum i `SYS_STATUS` proveru, a `main.c` pokušava inicijalizaciju do tri puta. Ovakav pristup omogućava razlikovanje SPI problema, checksum problema i neinicijalizovanog stanja, što je korisno tokom inicijalne hardverske validacije.

**Dijagnostika.** USART1 log koristi strukturisane linije (`BOOT`, `BOARD`, `ESP`, `OLED`, `IO`, `ATM`, `MEAS`, `TX2`), a moduli koji imaju šire stanje izlažu snapshot strukture. `BoardControl_GetSnapshot()` i `EspControl_GetSnapshot()` omogućavaju logger-u da dobije prikaz stanja bez direktnog čitanja GPIO pinova ili internih varijabli modula. To odvaja vlasnika stanja od potrošača stanja i olakšava proširenje loga.

**STM32-ESP frame poruke.** Protobuf preko UART-a daje jasnu šemu, dok prefiks dužine od 4 bajta omogućava ESP32 parseru da zna granice poruke. Ograničenje je što nema magic byte, verzije ni CRC-a. U trenutnom sistemu to je prihvatljivo jer je veza lokalna na ploči, ali naredna verzija bi trebalo da doda oporavak od desinhronizacije i korupcije bajtova.

**Telemetrija bez potvrde prijema.** STM32 šalje okvir i ne čeka ACK od ESP32. Time merni loop ostaje jednostavan i ne zavisi od mrežnog sloja, ali STM32 ne zna da li je ESP32 obradio payload. Produkciona verzija bi imala ACK, heartbeat ili statusni kanal.

## 3. ESP32 firmware i web servis

ESP32 kod se nalazi u `Code/ESP32`. Njegova uloga je da bude mrežni sloj sistema: prima `MeasureData` protobuf frejmove sa STM32 preko UART-a, dekodira ih pomoću nanopb biblioteke, čuva poslednje merenje, šalje JSON klijentima preko WebSocket-a i izlaže HTTP API za aplikaciju i lokalnu web stranicu (`src/main.cpp:34-68`, `src/main.cpp:231-250`).

ESP32 strana koristi svoju kopiju protobuf šeme u `proto/simple.proto`, sa istom `MeasureData` strukturom kao STM32 strana. Šema funkcioniše kao ugovor između dva firmvera. 

Web interfejs je izdvojen kao Astro projekat u `Code/ESP32/web`. Pre builda firmware-a PlatformIO pokreće `web_content.py`, koji izvršava `pnpm --dir web run build`, Astro zatim generiše statične fajlove u `data/` direktorijum (`web/astro.config.mjs`, `web_content.py`). Ti fajlovi se pakuju u LittleFS particiju, odvojenu od izvršnog firmware koda (`platformio.ini`, `littlefs.csv`). ESP32 ih servira iz LittleFS-a kroz web server (`src/main.cpp:103-146`).

Ova podela ima dve prednosti: firmware i web interfejs su logički odvojeni, a web aplikacija se razvija kao običan frontend projekat i tek se na kraju pakuje u flash memoriju uređaja.

SD kartica je povezana direktno na SPI ESP32-a. Kod koristi Arduino SD biblioteku, a kartica je formatirana kao FAT32 (`src/sd_card.cpp:19-23`). Merenja se upisuju u CSV fajlove oblika `measurement_XXX.csv`, sa sledećim redosledom vrednosti:

```text
timestamp,current,voltage,power,frequency,power_usage
```

CSV format je kompaktan i praktičan za kasniju obradu. Konzervativna procena za 1 Hz logovanje je oko 80 B po uzorku, uključujući separator, decimalne vrednosti i kraj reda. To je oko 6.9 MB dnevno:

```text
80 B * 86 400 uzoraka/dan ≈ 6.9 MB/dan
8 GB / 6.9 MB/dan ≈ 1 150 dana ≈ 38 meseci
```

U praksi rezultat zavisi od dužine decimalnih zapisa i stvarno dostupnog prostora na kartici, ali red veličine pokazuje da CSV log omogućava višemesečno čuvanje podataka i na maloj SD kartici.

## 4. Mobilna aplikacija

Mobilna aplikacija je Flutter aplikacija u `Code/Mobile/ohmsprint`. Projekat sadrži Android i iOS targete, tako da se isti kod koristi za obe mobilne platforme. Pošto je zadatak hakatona više fokusiran na firmware, ovaj deo dokumentacije je kraći. Fokus je na pronalaženju uređaja, transportu podataka, parsiranju merenja, fallback ponašanju i lokalnoj perzistenciji. UI detalji i izbori specifični za Flutter nisu centralni deo ove dokumentacije.

### 4.1 Discovery i transport

`MdnsDiscoveryService` traži uređaj preko mDNS-a. Primarni tip servisa je `_ohmsprint._tcp.local`, a fallback je `_http._tcp.local` (`mdns_discovery_service.dart:25-26`). Rezultat skeniranja je lista uređaja sa imenom, IP adresom i portom.

Kada korisnik izabere uređaj, `ConnectionNotifier` prvo pokušava WebSocket vezu. URL se gradi u obliku `ws://<ip>:<port>/ws` (`connection_provider.dart:479-485`). Ako WebSocket ne uspe više puta, aplikacija prelazi na HTTP polling (`connection_provider.dart:269-342`). HTTP polling servis pokušava `/api/readings`, zatim `/api/measurements` (`http_polling_service.dart:12`).

Pojednostavljena state machine slika je:

```text
Disconnected
   -> Connecting
   -> Connected over WebSocket
   -> Reconnecting WebSocket
   -> HTTP polling fallback
   -> Periodic WebSocket recovery probe
   -> Connected over WebSocket
```

HTTP fallback ima ograničen broj restarta (`_maxHttpFallbackRestarts = 5`, `connection_provider.dart:89`). Dok je aplikacija u tom režimu, periodično pokušava da vrati WebSocket transport (`connection_provider.dart:422-471`).

### 4.2 JSON model i veza sa ESP32 izlazom

Mobilna aplikacija ne dekodira STM32 protobuf direktno. ESP32 treba da prevede `MeasureData` u JSON objekat. `Measurement.fromJson()` prihvata i kratka i opisna imena polja (`measurement.dart:32-62`):

| Značenje | Kratko polje | Alternativno polje |
|---|---|---|
| Napon | `v` | `voltage` |
| Struja | `i` | `current` |
| Aktivna snaga | `p` | `power` |
| Frekvencija | `f` | `frequency` |
| Energija | `ei` | `e`, `power_usage` |
| Struja neutralnog voda | `in` | - |
| Reaktivna snaga | `q` | - |
| Prividna snaga | `s` | izračunava se ako nedostaje |
| Faktor snage | `pf` | izračunava se ako nedostaje |

Ovakav parser smanjuje spregu između ESP32 JSON formata i aplikacije. ESP32 može slati kompaktan format (`v`, `i`, `p`) ili opisni format (`voltage`, `current`, `power`) bez promene Flutter modela.

Aplikacija je tolerantna i na razlike između trenutne i budućih verzija firmvera. Ako ESP32 JSON ne sadrži `s` (prividna snaga) ili `pf` (faktor snage), aplikacija ih izvodi iz napona, struje i aktivne snage (`measurement.dart:37-40`). STM32 driver već čita `S_MEAN` i `POWER_F` registre (`atm90e26.c:274-281`), ali ih trenutna `measure.proto` šema ne šalje prema ESP32. Naredna verzija protokola bi mogla da doda ta polja bez promene UI modela aplikacije.

Ako payload sadrži polje `ev`, `ConnectionNotifier` ga tretira kao događaj kvaliteta napajanja, u suprotnom ga tretira kao merenje (`connection_provider.dart:206-210`). `ev` je JSON discriminator za `PowerQualityEvent`: aplikacija trenutno podržava događaje tipa `sag`, `swell`, `freq` i `lpf`, sa opisom i klasifikacijom ozbiljnosti u modelu događaja. STM32 firmware u ovoj iteraciji ne emituje event poruke, ovo je priprema za naredne verzije u kojima bi ESP32 ili STM32 mogli da koriste `IRQ`/`WARN_OUT` i ATM90E26 status registre za generisanje događaja kvaliteta napajanja.

### 4.3 Mock server i testiranje mobilne komunikacije

Repozitorijum sadrži Dart mock server u `Code/Mobile/ohmsprint/tool/mock_device_server.dart`. Server izlaže iste transportne tačke koje aplikacija koristi u radu:

| Endpoint | Namena |
|---|---|
| `/ws` | WebSocket stream merenja i događaja |
| `/api/readings` | HTTP polling merenja |
| `/api/measurements` | Alternativni HTTP endpoint |
| `/mock/config` | Promena ponašanja mock servera |
| `/mock/status` | Trenutno stanje mock servera |

Mock server može raditi samo preko WebSocket-a, samo preko HTTP-a ili u kombinovanom režimu, a podržava i simulaciju nestabilnog WebSocket transporta preko `ws-behavior` konfiguracije (`mock_device_server.dart:6-8`, `mock_device_server.dart:134-140`, `mock_device_server.dart:343-360`). Time se može testirati prelazak aplikacije sa WebSocket-a na HTTP fallback bez fizičkog uređaja.

JSON koji mock server emituje odgovara kratkom formatu koji aplikacija već parsira: `v`, `i`, `in`, `p`, `q`, `s`, `f`, `pf`, `ei`, `ee`, `t` (`mock_device_server.dart:580-594`). Zbog toga mock server ujedno služi kao praktična specifikacija ESP32 JSON izlaza.

### 4.4 Perzistencija

Mobilna aplikacija koristi lokalnu perzistenciju za istoriju merenja i druge podatke aplikacije. `MeasurementRepository` čuva serijalizovana merenja u Hive box strukturi i omogućava čitanje opsega po vremenu. Kumulativna energija koja preživljava reset STM32 planirana je kao naredna dopuna samo ako bude implementirana i testirana u aplikaciji. Bez te dopune, energija koju STM32 šalje predstavlja akumulaciju od poslednjeg STM32 pokretanja, dok mobilna aplikacija čuva istorijske uzorke koje je primila.

## 5. Validacija, dijagnostika i sledeći koraci

Prednost trenutne arhitekture je što se greška može pratiti kroz slojeve. USART1 debug log na STM32 strani daje sekvencu za hardversku validaciju:

```text
BOOT
  -> BOARD / ESP
  -> OLED
  -> IO
  -> ATM,init_ok
  -> MEAS
  -> TX2
  -> ESP32 JSON
  -> mobile stream
```

Primeri interpretacije:

| Simptom | Moguć uzrok problema |
|---|---|
| Nema `BOOT` loga | MCU boot, napajanje ili USART1 debug konekcija |
| `OLED,init,err=...`, ali postoje `MEAS` logovi | OLED/I2C problem, merenje nastavlja da radi |
| Nema `ATM,init_ok` | ATM90E26 SPI, reset, napajanje ili checksum/status provera |
| Postoji `MEAS`, ali nema `TX2` | STM32 čita merenja, ali ne šalje uspešno USART2 frame |
| Postoji `TX2`, ali aplikacija nema podatke | ESP32 parser, WiFi transport ili JSON format |
| WebSocket pada, ali HTTP radi | Mobile fallback path radi, problem je u WebSocket transportu |

Trenutna verzija ima sledeća poznata ograničenja:

1. STM32-ESP UART frame nema magic byte, verziju ni CRC.
2. STM32 telemetrija nema potvrdu prijema, ACK ni heartbeat odgovor iz ESP32.
3. Akumulirana energija na STM32 strani je u RAM-u i resetuje se posle STM32 reset-a.
4. USB DTR/RTS passthrough prema ESP32 postoji u firmveru, ali nije hardverski validiran u test fazi.
5. Nema watchdog mehanizma u trenutnoj firmware iteraciji.
6. STM32 firmware ne koristi HSE dostupan na ploči.
