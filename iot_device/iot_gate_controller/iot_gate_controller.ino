/*
  ====================================================================
  Smart Campus Parking System - IoT Gate Controller (ESP8266)
  ====================================================================
  Komponen:
  - ESP8266 (NodeMCU v3 / D1 Mini)
  - RFID Reader MFRC522 (RC522)
  - Servo Motor (SG90 / MG996R)
  - Push Button (Untuk pilihan mode: Masuk, Keluar, Darurat, Daftar)
  - LCD 16x2 I2C (Sebagai indikator visual status & informasi)
  - Active Buzzer (Sebagai indikator audio)
  
  Pin Connection Guide:
  - MFRC522 RFID:
    * RST  -> RX (GPIO 3)
    * SDA  -> D8 (GPIO 15)
    * MOSI -> D7 (GPIO 13)
    * MISO -> D6 (GPIO 12)
    * SCK  -> D5 (GPIO 14)
    * 3V3  -> 3.3V
    * GND  -> GND
  - Servo Motor:
    * Signal -> D4 (GPIO 2)
    * VCC    -> 5V (Vin pada NodeMCU jika menggunakan USB 5V)
    * GND    -> GND
  - LCD 16x2 I2C:
    * SDA  -> D2 (GPIO 4)
    * SCL  -> D1 (GPIO 5)
    * VCC  -> 5V / 3.3V
    * GND  -> GND
  - Active Buzzer:
    * Positive -> D0 (GPIO 16)
    * Negative -> GND
  - Push Button:
    * Pin      -> D3 (GPIO 0)
    * Pin lain -> GND
  ====================================================================
*/

#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <WiFiClientSecure.h>
#include <SPI.h>
#include <MFRC522.h>
#include <Servo.h>
#include <ArduinoJson.h> // Pastikan library ArduinoJson terinstall di Arduino IDE
#include <Wire.h>
#include <LiquidCrystal_I2C.h>

// --- Konfigurasi Wi-Fi ---
// Hubungkan ESP8266 ke Wi-Fi yang sama dengan PC/Laptop Anda untuk uji coba lokal.
const char* ssid = "Makoto.wifi";          // Ganti dengan nama Wi-Fi Anda
const char* password = "harisabtu";  // Ganti dengan password Wi-Fi Anda

// --- Konfigurasi Backend & Firebase ---
const String backendUrl = "https://parkirkampus.my.id/api/gate/capture-validate";
const String firebaseHost = "https://parking-system-2546df-default-rtdb.firebaseio.com";
const String firebaseAuth = "lwFhrCtxQwicVlNIuitXN98Dup4ESSdYSXKSKMdn";

// --- Definisikan PIN ---
#define PIN_RST          3  // RX (GPIO 3) - RFID Reset
#define PIN_SDA          15 // D8
#define PIN_SERVO        2  // D4 (Membuka gerbang pada pin D4)
#define PIN_BUZZER       16 // D0 (GPIO 16) - Buzzer indikator
#define PIN_SDA_LCD      4  // D2 (GPIO 4) - I2C SDA untuk LCD
#define PIN_SCL_LCD      5  // D1 (GPIO 5) - I2C SCL untuk LCD
#define PIN_BUTTON       0  // D3 (GPIO 0) - Tombol Pilihan Mode (Active-low dengan PULLUP)

// --- Konfigurasi LCD I2C ---
#define LCD_ADDR         0x27 // Alamat I2C umum (0x27 atau 0x3F)
#define LCD_COLS         16
#define LCD_ROWS         2

// --- Inisialisasi Objek ---
MFRC522 mfrc522(PIN_SDA, PIN_RST);
Servo gateServo;
LiquidCrystal_I2C lcd(LCD_ADDR, LCD_COLS, LCD_ROWS);

// --- Variabel State ---
enum GateMode { MODE_MASUK, MODE_KELUAR, MODE_DARURAT, MODE_DAFTAR };
GateMode currentMode = MODE_MASUK; // Default mode: Masuk

// Variabel untuk Button (Interrupt-driven)
volatile bool shortClick = false;
volatile bool isHolding = false;
volatile unsigned long pressStartTime = 0;
volatile unsigned long lastInterruptTime = 0;
unsigned long lastButtonPressTime = 0; // Menunda Firebase check saat tombol aktif
bool wasConnected = false;

// Variabel untuk Backend HTTP polling interval (non-blocking)
unsigned long lastBackendCheck = 0;
const unsigned long backendCheckInterval = 5000; // Cek setiap 5 detik

// --- Fungsi Indikator Buzzer ---
void beepTap() {
  digitalWrite(PIN_BUZZER, HIGH);
  delay(100);
  digitalWrite(PIN_BUZZER, LOW);
}

void beepSuccess() {
  digitalWrite(PIN_BUZZER, HIGH);
  delay(100);
  digitalWrite(PIN_BUZZER, LOW);
  delay(100);
  digitalWrite(PIN_BUZZER, HIGH);
  delay(100);
  digitalWrite(PIN_BUZZER, LOW);
}

void beepFail() {
  digitalWrite(PIN_BUZZER, HIGH);
  delay(600);
  digitalWrite(PIN_BUZZER, LOW);
}

void beepWiFiConnected() {
  // Indikator bunyi 3x bip cepat saat Wi-Fi terhubung
  for (int i = 0; i < 3; i++) {
    digitalWrite(PIN_BUZZER, HIGH);
    delay(80);
    digitalWrite(PIN_BUZZER, LOW);
    delay(80);
  }
}

// Prototype fungsi interupsi
void IRAM_ATTR handleButtonISR();

void setup() {
  // Menggunakan SERIAL_TX_ONLY agar pin RX (GPIO 3 / D9) dibebaskan untuk input digital button.
  // Input Serial (simulasi tombol) tidak akan berfungsi, namun output log Serial tetap berjalan.
  Serial.begin(115200, SERIAL_8N1, SERIAL_TX_ONLY);
  SPI.begin();
  mfrc522.PCD_Init();
  
  // Setup Servo
  gateServo.attach(PIN_SERVO);
  gateServo.write(0); // Posisi gerbang tertutup (0 derajat)

  // Setup Pin Mode Buzzer
  pinMode(PIN_BUZZER, OUTPUT);
  digitalWrite(PIN_BUZZER, LOW);

  // Setup Pin Mode Button & Interrupt (CHANGE)
  pinMode(PIN_BUTTON, INPUT_PULLUP);
  attachInterrupt(digitalPinToInterrupt(PIN_BUTTON), handleButtonISR, CHANGE);

  // Setup LCD I2C
  Wire.begin(PIN_SDA_LCD, PIN_SCL_LCD);
  lcd.init();
  lcd.backlight();
  
  // Tampilkan loading screen awal
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Smart Parking");
  lcd.setCursor(0, 1);
  lcd.print("System Ready...");
  delay(1500);

  // Inisialisasi Indikator Awal (Mode Masuk Aktif)
  updateLedIndicators();

  Serial.println("\n--- Sistem Siap ---");
  Serial.println("Silakan tempelkan kartu (misal: KTM) ke modul reader...");
  Serial.println("\n--- Panduan Simulasi Button via Serial Monitor ---");
  Serial.println(" Kirim karakter berikut ke Serial Monitor (baudrate 115200):");
  Serial.println(" 'c' : Simulasikan klik tombol (ketik 'c' beberapa kali untuk multi-click)");
  Serial.println(" '1' : Ganti ke Mode Masuk");
  Serial.println(" '2' : Ganti ke Mode Keluar");
  Serial.println(" '3' : Aktifkan Mode Darurat (Buka Gerbang)");
  Serial.println(" '4' : Ganti ke Mode Daftar Kartu Baru");
  Serial.println("--------------------------------------------------");

  // Koneksi Wi-Fi
  connectToWiFi();
}

void loop() {
  // Pastikan Wi-Fi tetap terhubung
  if (WiFi.status() != WL_CONNECTED) {
    if (wasConnected) {
      wasConnected = false;
      Serial.println("\n[WIFI] Koneksi Terputus!");
      
      // Tampilkan indikator koneksi terputus di LCD
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print("Koneksi Terputus");
      lcd.setCursor(0, 1);
      lcd.print("Menghubungkan...");
      
      // Bunyikan bip kegagalan 2 kali berturut-turut sebagai tanda
      beepFail();
      delay(200);
      beepFail();
    }
    connectToWiFi();
  } else {
    wasConnected = true;
  }

  // 2. Baca Input Button (Multi-click detection)
  handleButtonInput();

  // 3. Baca RFID Card jika ada kartu yang di-tap
  bool cardProcessed = handleRfidInput();

  // 4. Cek Backend Trigger secara berkala (hanya jika tidak ada aktivitas tombol/RFID baru-baru ini)
  if (!cardProcessed && (millis() - lastButtonPressTime >= 10000) && (millis() - lastBackendCheck >= backendCheckInterval)) {
    lastBackendCheck = millis();
    checkBackendTrigger();
  }
}

// ====================================================================
// FUNGSI UTAMA KONTROL PERANGKAT
// ====================================================================

// Fungsi untuk menghubungkan ke Wi-Fi
void connectToWiFi() {
  Serial.print("Connecting to Wi-Fi: ");
  Serial.println(ssid);
  WiFi.begin(ssid, password);
  
  // Tampilkan status koneksi di LCD
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Connecting WiFi");
  lcd.setCursor(0, 1);
  lcd.print(ssid);

  int attempt = 0;
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
    lcd.setCursor(15, 0);
    lcd.print(attempt % 2 == 0 ? "." : " ");
    attempt++;
  }
  Serial.println("\nWi-Fi Connected!");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());
  
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("WiFi Connected!");
  lcd.setCursor(0, 1);
  lcd.print(WiFi.localIP().toString());
  
  // Set status koneksi terhubung
  wasConnected = true;
  
  // Bunyikan buzzer sebagai indikator Wi-Fi terkoneksi
  beepWiFiConnected();
  
  delay(1500);
  
  updateLedIndicators();
}

// Fungsi Mengupdate LCD Indikator berdasarkan Mode Aktif (sebelumnya LED Indikator)
void updateLedIndicators() {
  lcd.clear();
  
  if (currentMode == MODE_MASUK) {
    lcd.setCursor(0, 0);
    lcd.print("Gate: MASUK");
    lcd.setCursor(0, 1);
    lcd.print("Silakan Tap...");
    Serial.println("[MODE] Masuk (Mode 1) - SIAP TAP");
  } 
  else if (currentMode == MODE_KELUAR) {
    lcd.setCursor(0, 0);
    lcd.print("Gate: KELUAR");
    lcd.setCursor(0, 1);
    lcd.print("Silakan Tap...");
    Serial.println("[MODE] Keluar (Mode 2) - SIAP TAP");
  } 
  else if (currentMode == MODE_DARURAT) {
    lcd.setCursor(0, 0);
    lcd.print("Gate: DARURAT");
    lcd.setCursor(0, 1);
    lcd.print("Gerbang Terbuka!");
    Serial.println("[MODE] Darurat (Mode 3) - GERBANG TERBUKA");
  }
  else if (currentMode == MODE_DAFTAR) {
    lcd.setCursor(0, 0);
    lcd.print("Mode: DAFTAR");
    lcd.setCursor(0, 1);
    lcd.print("Tempel Kartu...");
    Serial.println("[MODE] Daftar Kartu Baru (Mode 4) - SIAP TAP");
  }
}

// Fungsi membuka gerbang servo secara otomatis
void openGate() {
  Serial.println("[SERVO] Membuka gerbang...");
  gateServo.write(90); // Buka gerbang ke 90 derajat
  delay(5000);         // Tunggu kendaraan lewat selama 5 detik
  Serial.println("[SERVO] Menutup gerbang...");
  gateServo.write(0);  // Tutup kembali gerbang ke 0 derajat
}

// Fungsi ISR untuk membaca tombol secara asynchronous (CHANGE)
void IRAM_ATTR handleButtonISR() {
  int pinVal = digitalRead(PIN_BUTTON);
  unsigned long now = millis();
  
  if (pinVal == LOW) { // Pressed
    if (!isHolding && (now - lastInterruptTime > 50)) { // Debounce press
      isHolding = true;
      pressStartTime = now;
      lastInterruptTime = now;
    }
  } else { // Released
    if (isHolding) {
      unsigned long duration = now - pressStartTime;
      isHolding = false;
      lastInterruptTime = now;
      if (duration > 50 && duration < 2000) { // Rentang klik pendek (50ms - 2s)
        shortClick = true;
      }
    }
  }
}

// Fungsi mendeteksi input button (Siklus/Rotasi: Masuk -> Keluar -> Daftar -> Masuk)
// Serta long press 5 detik untuk memicu Mode Darurat
void handleButtonInput() {
  unsigned long now = millis();

  // 1. Deteksi Long Press 5 Detik (Mode Darurat) dari Mode Mana Saja
  if (isHolding && (now - pressStartTime >= 5000)) {
    isHolding = false; // Reset status hold agar tidak memicu berulang kali
    shortClick = false; // Batalkan antrean klik pendek jika ada
    lastButtonPressTime = now; // Tunda Firebase check
    
    currentMode = MODE_DARURAT;
    updateLedIndicators();
    triggerEmergencyLocal();
  }

  // 2. Deteksi Short Click (Rotasi Mode: Masuk -> Keluar -> Daftar -> Masuk)
  if (shortClick) {
    shortClick = false; // Reset flag
    lastButtonPressTime = now; // Tunda Firebase check
    
    // Rotasi mode (melewati Darurat karena Darurat menggunakan Long Press)
    if (currentMode == MODE_MASUK) {
      currentMode = MODE_KELUAR;
    } else if (currentMode == MODE_KELUAR) {
      currentMode = MODE_DAFTAR;
    } else if (currentMode == MODE_DARURAT) {
      currentMode = MODE_DAFTAR;
    } else if (currentMode == MODE_DAFTAR) {
      currentMode = MODE_MASUK;
    }
    
    updateLedIndicators();
  }

  // 3. Simulasikan button menggunakan Serial input
  if (Serial.available() > 0) {
    char c = Serial.read();
    
    // Abaikan newline / carriage return
    if (c != '\n' && c != '\r') {
      Serial.print("[SERIAL INPUT] Karakter diterima: '");
      Serial.print(c);
      Serial.println("'");

      if (c == 'c' || c == 'C') {
        // Simulasikan klik pendek
        shortClick = true;
      }
      else if (c == 'l' || c == 'L') {
        // Simulasikan tekan lama (5 detik)
        isHolding = true;
        pressStartTime = now - 5000; // Set agar langsung terdeteksi long press di loop berikutnya
      }
      else if (c == '1') {
        currentMode = MODE_MASUK;
        updateLedIndicators();
      }
      else if (c == '2') {
        currentMode = MODE_KELUAR;
        updateLedIndicators();
      }
      else if (c == '3') {
        currentMode = MODE_DARURAT;
        updateLedIndicators();
        triggerEmergencyLocal();
      }
      else if (c == '4') {
        currentMode = MODE_DAFTAR;
        updateLedIndicators();
      }
      else {
        Serial.println("--- Panduan Serial Command ---");
        Serial.println(" 'c' : Simulasikan klik pendek tombol");
        Serial.println(" 'l' : Simulasikan tekan lama (5 detik)");
        Serial.println(" '1' : Set MODE_MASUK");
        Serial.println(" '2' : Set MODE_KELUAR");
        Serial.println(" '3' : Set MODE_DARURAT");
        Serial.println(" '4' : Set MODE_DAFTAR");
        Serial.println("-----------------------------");
      }
    }
  }
}

// Fungsi darurat: Buka servo lokal & nyalakan buzzer alarm
void triggerEmergencyLocal() {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("GERBANG DARURAT!");
  lcd.setCursor(0, 1);
  lcd.print("TERBUKA!");

  // Alarm buzzer berbunyi cepat/intermiten
  for (int i = 0; i < 5; i++) {
    digitalWrite(PIN_BUZZER, HIGH);
    delay(150);
    digitalWrite(PIN_BUZZER, LOW);
    delay(150);
  }
  
  // Buka Servo
  openGate();

  // Update mode LCD kembali ke normal
  updateLedIndicators();
}

// Fungsi mendeteksi & memproses RFID (mengembalikan true jika ada kartu terbaca)
bool handleRfidInput() {
  // Cek apakah ada kartu baru mendekat
  if (!mfrc522.PICC_IsNewCardPresent()) {
    return false;
  }
  // Cek apakah kartu bisa dibaca
  if (!mfrc522.PICC_ReadCardSerial()) {
    return false;
  }

  // Konversi UID Kartu ke Hex String
  String rfidUid = "";
  for (byte i = 0; i < mfrc522.uid.size; i++) {
    rfidUid += String(mfrc522.uid.uidByte[i] < 0x10 ? "0" : "");
    rfidUid += String(mfrc522.uid.uidByte[i], HEX);
  }
  rfidUid.toUpperCase();
  
  Serial.print("\n[RFID] Kartu terdeteksi: ");
  Serial.println(rfidUid);

  // Indikator audio & visual saat tap rfid
  beepTap();
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Kartu Terbaca");
  lcd.setCursor(0, 1);
  lcd.print("Memproses...");

  // Hentikan proses pembacaan kartu saat ini
  mfrc522.PICC_HaltA();

  // Kirim sesuai Mode Aktif
  if (currentMode == MODE_DAFTAR) {
    sendRegistrationRequest(rfidUid);
  } else {
    sendValidationRequest(rfidUid);
  }
  return true;
}

// Fungsi mengirim request validasi ganda ke API Backend
void sendValidationRequest(String uid) {
  WiFiClient clientPlain;
  WiFiClientSecure clientSecure;
  HTTPClient http;
  
  Serial.print("[MEMORI] Free heap sebelum backend POST: ");
  Serial.print(ESP.getFreeHeap());
  Serial.print(" B | WiFi RSSI: ");
  Serial.print(WiFi.RSSI());
  Serial.println(" dBm");

  Serial.println("[HTTP] Mengirim data ke backend...");
  if (backendUrl.startsWith("https://")) {
    clientSecure.setInsecure();
    http.begin(clientSecure, backendUrl);
  } else {
    http.begin(clientPlain, backendUrl);
  }
  http.setTimeout(30000); // Set timeout ke 30 detik karena proses ANPR & OCR di backend butuh waktu
  http.addHeader("Content-Type", "application/json");

  // Siapkan Payload JSON
  StaticJsonDocument<200> doc;
  doc["rfid_uid"] = uid;
  doc["gate_type"] = (currentMode == MODE_MASUK) ? "masuk" : "keluar";
  doc["gate_id"] = "GATE_ESP8266";

  String requestBody;
  serializeJson(doc, requestBody);

  int httpResponseCode = http.POST(requestBody);

  if (httpResponseCode > 0) {
    String response = http.getString();
    Serial.print("[HTTP] Response code: ");
    Serial.println(httpResponseCode);
    Serial.println("[HTTP] Response body: " + response);

    // Parse Response
    StaticJsonDocument<500> respDoc;
    DeserializationError error = deserializeJson(respDoc, response);
    if (!error) {
      String action = respDoc["action"]; // "open_gate" atau "keep_closed"
      String message = respDoc["message"];
      String studentName = respDoc["student_name"];
      String plateNumber = respDoc["plate_number"];

      Serial.print("[VALIDASI] ");
      Serial.print(studentName);
      if (plateNumber.length() > 0) {
        Serial.print(" (Plat: " + plateNumber + ")");
      }
      Serial.print(" - ");
      Serial.println(message);

      action.trim();
      if (action.equalsIgnoreCase("open_gate")) {
        Serial.println("[VALIDASI] Sukses! Membuka gerbang.");
        
        // Indikator visual & audio sukses masuk/keluar
        beepSuccess();
        lcd.clear();
        if (currentMode == MODE_MASUK) {
          lcd.setCursor(0, 0);
          lcd.print("Silakan Masuk");
        } else {
          lcd.setCursor(0, 0);
          lcd.print("Silakan Keluar");
        }
        
        // Tampilkan nama mahasiswa (maksimal 16 karakter)
        lcd.setCursor(0, 1);
        if (studentName.length() > 0) {
          lcd.print(studentName.substring(0, 16));
        } else if (plateNumber.length() > 0) {
          lcd.print(plateNumber.substring(0, 16));
        } else {
          lcd.print("Gate Terbuka");
        }

        // Jalankan perintah buka gate
        openGate();
        updateLedIndicators(); // Kembalikan ke tampilan standby/idle
      } else {
        Serial.print("[VALIDASI] Gagal/Ditolak! Status gerbang tetap tertutup (action: ");
        Serial.print(action);
        Serial.println(")");
        
        // Indikator visual & audio gagal
        beepFail();
        lcd.clear();
        lcd.setCursor(0, 0);
        lcd.print("Akses Ditolak!");
        lcd.setCursor(0, 1);
        if (message.length() > 0) {
          lcd.print(message.substring(0, 16));
        } else {
          lcd.print("Kartu/Plat Salah");
        }
        
        delay(2500); // Tahan pesan penolakan selama 2.5 detik
        updateLedIndicators(); // Kembalikan ke tampilan standby/idle
      }
    } else {
      Serial.print("[JSON] Gagal mengurai JSON response: ");
      Serial.println(error.c_str());
      
      // Indikator error parser
      beepFail();
      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print("Error Parser!");
      lcd.setCursor(0, 1);
      lcd.print("Coba Lagi");
      delay(2000);
      updateLedIndicators();
    }
  } else {
    Serial.print("[HTTP] Error sending POST: ");
    Serial.println(httpResponseCode);
    
    // Indikator error koneksi
    beepFail();
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Error Koneksi!");
    lcd.setCursor(0, 1);
    lcd.print("HTTP: " + String(httpResponseCode));
    delay(2500);
    updateLedIndicators();
  }
  
  http.end();
}

// Fungsi mengirim request pendaftaran kartu baru ke API Backend
void sendRegistrationRequest(String uid) {
  WiFiClient clientPlain;
  WiFiClientSecure clientSecure;
  HTTPClient http;
  
  // Ubah URL endpoint pendaftaran: /api/gate/register-tap?rfid_uid=HEX_UID
  String regUrl = backendUrl;
  regUrl.replace("/capture-validate", "/register-tap?rfid_uid=" + uid);
  
  Serial.print("[MEMORI] Free heap sebelum backend reg POST: ");
  Serial.print(ESP.getFreeHeap());
  Serial.print(" B | WiFi RSSI: ");
  Serial.print(WiFi.RSSI());
  Serial.println(" dBm");

  Serial.print("[HTTP] Mengirim pendaftaran kartu ke: ");
  Serial.println(regUrl);
  
  if (regUrl.startsWith("https://")) {
    clientSecure.setInsecure();
    http.begin(clientSecure, regUrl);
  } else {
    http.begin(clientPlain, regUrl);
  }
  http.setTimeout(10000); // Set timeout ke 10 detik
  int httpResponseCode = http.POST(""); // Kirim POST kosong karena UID ada di parameter URL

  if (httpResponseCode > 0) {
    String response = http.getString();
    Serial.print("[HTTP] Response code: ");
    Serial.println(httpResponseCode);
    Serial.println("[HTTP] Response body: " + response);

    // Sukses: Bunyi beep sukses & tampilkan pesan sukses
    beepSuccess();
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Daftar Sukses!");
    lcd.setCursor(0, 1);
    lcd.print("Kembali ke MASUK");
    delay(2500);
    
    // Kembalikan mode ke default (MASUK) setelah pendaftaran berhasil
    currentMode = MODE_MASUK;
    updateLedIndicators();
  } else {
    Serial.print("[HTTP] Error sending POST: ");
    Serial.println(httpResponseCode);

    // Gagal: Beep gagal & tampilkan pesan gagal
    beepFail();
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Daftar Gagal!");
    lcd.setCursor(0, 1);
    lcd.print("Coba Lagi");
    delay(2500);
    
    updateLedIndicators();
  }
  
  http.end();
}

// Fungsi membaca trigger gerbang dari Firebase Realtime Database via HTTPS REST API
void checkBackendTrigger() {
  WiFiClientSecure client;
  HTTPClient http;
  
  // Mengabaikan verifikasi sertifikat SSL untuk koneksi HTTPS ke Firebase
  client.setInsecure();
  
  String gateId = (currentMode == MODE_MASUK || currentMode == MODE_DAFTAR) ? "GATE_MASUK_1" : "GATE_KELUAR_1";
  String checkUrl = firebaseHost + "/gates/" + gateId + "/servo_trigger.json?auth=" + firebaseAuth;
  String resetUrl = firebaseHost + "/gates/" + gateId + "/servo_trigger.json?auth=" + firebaseAuth;

  Serial.print("[MEMORI] Free heap sebelum Firebase GET (");
  Serial.print(gateId);
  Serial.print("): ");
  Serial.print(ESP.getFreeHeap());
  Serial.print(" B | WiFi RSSI: ");
  Serial.print(WiFi.RSSI());
  Serial.println(" dBm");
  
  http.begin(client, checkUrl);
  http.setTimeout(2000); // Batasi timeout ke 2 detik
  int httpResponseCode = http.GET();
  
  if (httpResponseCode == 200) {
    String response = http.getString();
    response.trim();
    int triggerValue = response.toInt();
    
    if (triggerValue == 1) {
      Serial.println("[FIREBASE TRIGGER] Sinyal Buka Gerbang Diterima!");
      http.end(); // Akhiri GET request
      
      // Reset trigger ke 0 di Firebase menggunakan PUT
      http.begin(client, resetUrl);
      http.addHeader("Content-Type", "application/json");
      http.setTimeout(2000);
      int putCode = http.PUT("0");
      if (putCode == 200) {
        Serial.println("[FIREBASE TRIGGER] Trigger berhasil di-reset kembali ke 0.");
      } else {
        Serial.print("[FIREBASE TRIGGER] Gagal mereset trigger di Firebase: HTTP ");
        Serial.println(putCode);
      }
      http.end();
      
      // Buka Gerbang setelah reset berhasil
      openGate();
    }
  } else {
    Serial.print("[FIREBASE TRIGGER] HTTP GET gagal, error code: ");
    Serial.println(httpResponseCode);
  }
  http.end(); // Selalu tutup koneksi secara bersih
}
