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
    * RST  -> D3 (GPIO 0)
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
    * Pin      -> D9 (GPIO 3 / RX) - Catatan: Bisa disesuaikan ke pin lain jika ada bentrok Serial
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
const char* ssid = "Faris Maulana";          // Ganti dengan nama Wi-Fi Anda
const char* password = "Adiwerna2345";  // Ganti dengan password Wi-Fi Anda

// --- Konfigurasi Backend & Firebase ---
// Gunakan IP Address lokal atau domain hosted
const String backendUrl = "https://parkirkampus.my.id/api/gate/capture-validate";
const String firebaseHost = "parking-system-2546df-default-rtdb.firebaseio.com";
const String firebaseSecret = "lwFhrCtxQwicVlNIuitXN98Dup4ESSdYSXKSKMdn";

// --- Definisikan PIN ---
#define PIN_RST          0  // D3
#define PIN_SDA          15 // D8
#define PIN_SERVO        2  // D4 (Membuka gerbang pada pin D4)
#define PIN_BUZZER       16 // D0 (GPIO 16) - Buzzer indikator
#define PIN_SDA_LCD      4  // D2 (GPIO 4) - I2C SDA untuk LCD
#define PIN_SCL_LCD      5  // D1 (GPIO 5) - I2C SCL untuk LCD
#define PIN_BUTTON       3  // D9 (GPIO 3 / RX) - Tombol Pilihan Mode (Active-low dengan PULLUP)

// --- Konfigurasi LCD I2C ---
#define LCD_ADDR         0x27 // Alamat I2C umum (0x27 atau 0x3F)
#define LCD_COLS         16
#define LCD_ROWS         2

// --- Inisialisasi Objek ---
MFRC522 mfrc522(PIN_SDA, PIN_RST);
Servo gateServo;
LiquidCrystal_I2C lcd(LCD_ADDR, LCD_COLS, LCD_ROWS);

// --- Variabel State ---
enum GateMode { MODE_MASUK, MODE_KELUAR, MODE_DAFTAR };
GateMode currentMode = MODE_MASUK; // Default mode: Masuk

// Variabel untuk Button Debounce & Click Counter
int buttonState = HIGH;
int lastButtonState = HIGH;
unsigned long lastDebounceTime = 0;
unsigned long debounceDelay = 50;
unsigned long lastClickTime = 0;
const unsigned long clickWindow = 800; // Window waktu untuk deteksi multi-click (ms)
int clickCount = 0;
bool wasConnected = false;

// Variabel untuk Firebase polling interval (non-blocking)
unsigned long lastFirebaseCheck = 0;
const unsigned long firebaseCheckInterval = 2000; // Cek setiap 2 detik

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

void setup() {
  Serial.begin(115200);
  SPI.begin();
  mfrc522.PCD_Init();
  
  // Setup Servo
  gateServo.attach(PIN_SERVO);
  gateServo.write(0); // Posisi gerbang tertutup (0 derajat)

  // Setup Pin Mode Buzzer
  pinMode(PIN_BUZZER, OUTPUT);
  digitalWrite(PIN_BUZZER, LOW);

  // Setup Pin Mode Button
  pinMode(PIN_BUTTON, INPUT_PULLUP);

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
  handleRfidInput();

  // 4. Cek Firebase Trigger secara berkala (non-blocking)
  if (millis() - lastFirebaseCheck >= firebaseCheckInterval) {
    lastFirebaseCheck = millis();
    checkFirebaseTrigger();
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
  lcd.setCursor(0, 0);
  lcd.print("Smart Parking");
  lcd.setCursor(0, 1);
  
  if (currentMode == MODE_MASUK) {
    lcd.print("Gate: MASUK");
    Serial.println("[MODE] Masuk (1x click)");
  } 
  else if (currentMode == MODE_KELUAR) {
    lcd.print("Gate: KELUAR");
    Serial.println("[MODE] Keluar (2x click)");
  } 
  else if (currentMode == MODE_DAFTAR) {
    lcd.print("Mode: DAFTAR");
    Serial.println("[MODE] Daftar Kartu Baru (4x click)");
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

// Fungsi mendeteksi input button (1x Masuk, 2x Keluar, 3x Darurat, 4x Daftar)
void handleButtonInput() {
  // 1. Baca Input Tombol Fisik dengan Debouncing
  int reading = digitalRead(PIN_BUTTON);
  if (reading != lastButtonState) {
    lastDebounceTime = millis();
  }
  if ((millis() - lastDebounceTime) > debounceDelay) {
    if (reading != buttonState) {
      buttonState = reading;
      if (buttonState == LOW) { // Tombol ditekan (Active-low)
        clickCount++;
        lastClickTime = millis();
        Serial.print("[TOMBOL] Klik fisik ke-");
        Serial.println(clickCount);
      }
    }
  }
  lastButtonState = reading;

  // 2. Simulasikan button menggunakan Serial input
  if (Serial.available() > 0) {
    char c = Serial.read();
    
    // Abaikan newline / carriage return
    if (c != '\n' && c != '\r') {
      Serial.print("[SERIAL INPUT] Karakter diterima: '");
      Serial.print(c);
      Serial.println("'");

      if (c == 'c' || c == 'C') {
        // Simulasikan satu klik tombol
        clickCount++;
        lastClickTime = millis();
        Serial.print("[SIMULASI] Klik ke-");
        Serial.println(clickCount);
      }
      else if (c == '1') {
        // Langsung pindah ke Mode Masuk
        currentMode = MODE_MASUK;
        updateLedIndicators();
      }
      else if (c == '2') {
        // Langsung pindah ke Mode Keluar
        currentMode = MODE_KELUAR;
        updateLedIndicators();
      }
      else if (c == '3') {
        // Langsung picu Darurat (Buka Gerbang)
        Serial.println("[DARURAT] Gerbang Darurat Diaktifkan via Serial!");
        triggerEmergencyLocal();
      }
      else if (c == '4') {
        // Langsung pindah ke Mode Daftar
        currentMode = MODE_DAFTAR;
        updateLedIndicators();
      }
      else {
        Serial.println("--- Panduan Serial Command ---");
        Serial.println(" 'c' : Simulasikan 1x klik button (bisa diketik beberapa kali dengan cepat)");
        Serial.println(" '1' : Set MODE_MASUK");
        Serial.println(" '2' : Set MODE_KELUAR");
        Serial.println(" '3' : Set DARURAT (Buka Gerbang)");
        Serial.println(" '4' : Set MODE_DAFTAR");
        Serial.println("-----------------------------");
      }
    }
  }

  // Evaluasi jumlah klik setelah melewati window waktu
  if (clickCount > 0 && (millis() - lastClickTime) > clickWindow) {
    if (clickCount == 1) {
      currentMode = MODE_MASUK;
      updateLedIndicators();
    } 
    else if (clickCount == 2) {
      currentMode = MODE_KELUAR;
      updateLedIndicators();
    } 
    else if (clickCount == 3) {
      Serial.println("[DARURAT] Gerbang Darurat Diaktifkan via Multi-Click Simulasi!");
      triggerEmergencyLocal();
    }
    else if (clickCount >= 4) {
      currentMode = MODE_DAFTAR;
      updateLedIndicators();
    }
    clickCount = 0; // Reset counter klik
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

// Fungsi mendeteksi & memproses RFID
void handleRfidInput() {
  // Cek apakah ada kartu baru mendekat
  if (!mfrc522.PICC_IsNewCardPresent()) {
    return;
  }
  // Cek apakah kartu bisa dibaca
  if (!mfrc522.PICC_ReadCardSerial()) {
    return;
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
}

// Fungsi mengirim request validasi ganda ke API Backend
void sendValidationRequest(String uid) {
  WiFiClient clientPlain;
  WiFiClientSecure clientSecure;
  HTTPClient http;
  
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

// Fungsi membaca trigger gerbang dari Firebase Realtime Database
void checkFirebaseTrigger() {
  WiFiClientSecure client;
  client.setInsecure(); // ESP8266 mengabaikan verifikasi SSL certificate
  HTTPClient http;

  String url = "https://" + firebaseHost + "/gate/servo_trigger.json";
  if (firebaseSecret != "") {
    url += "?auth=" + firebaseSecret;
  }

  http.begin(client, url);
  int httpResponseCode = http.GET();

  if (httpResponseCode == 200) {
    String response = http.getString();
    int triggerValue = response.toInt();

    if (triggerValue == 1) {
      Serial.println("[FIREBASE] Sinyal Buka Gerbang Diterima!");
      
      // Reset trigger ke 0 DULU sebelum membuka gerbang,
      // untuk menghemat memori (heap RAM) dengan menggunakan objek koneksi yang sama.
      http.end(); // Tutup sesi GET
      
      http.begin(client, url); // Buka kembali menggunakan objek client yang sama
      http.addHeader("Content-Type", "application/json");
      int putCode = http.PUT("0");
      if (putCode == 200) {
        Serial.println("[FIREBASE] Trigger berhasil di-reset kembali ke 0.");
      } else {
        Serial.print("[FIREBASE] Gagal mereset trigger: HTTP ");
        Serial.println(putCode);
      }
      
      // Buka Gerbang setelah trigger di-reset (menghindari delay blocking mempengaruhi reset)
      openGate();
    }
  }
  http.end();
}
