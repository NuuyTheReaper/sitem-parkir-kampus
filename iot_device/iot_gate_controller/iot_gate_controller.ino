/*
  ====================================================================
  Smart Campus Parking System - IoT Gate Controller (ESP8266)
  ====================================================================
  Komponen:
  - ESP8266 (NodeMCU v3 / D1 Mini)
  - RFID Reader MFRC522 (RC522)
  - Servo Motor (SG90 / MG996R)
  - Push Button (Untuk pilihan mode: Masuk, Keluar, Darurat, Daftar)
  - LED Masuk & LED Keluar (Sebagai indikator mode aktif)
  
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
    * Signal -> D2 (GPIO 4)
    * VCC    -> 5V (Vin pada NodeMCU jika menggunakan USB 5V)
    * GND    -> GND
  - Push Button:
    * Pin    -> D1 (GPIO 5) (Dihubungkan ke GND saat ditekan)
  - LED Indikator:
    * LED Masuk  -> D0 (GPIO 16)
    * LED Keluar -> D4 (GPIO 2 - Onboard LED NodeMCU)
  ====================================================================
*/

#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <WiFiClientSecure.h>
#include <SPI.h>
#include <MFRC522.h>
#include <Servo.h>
#include <ArduinoJson.h> // Pastikan library ArduinoJson terinstall di Arduino IDE

// --- Konfigurasi Wi-Fi ---
const char* ssid = "NAMA_WIFI_ANDA";
const char* password = "PASSWORD_WIFI_ANDA";

// --- Konfigurasi Backend & Firebase ---
const String backendUrl = "http://ALAMAT_BACKEND_HOSTING_ANDA/api/gate/capture-validate";
const String firebaseHost = "parking-system-2546df-default-rtdb.firebaseio.com";
const String firebaseSecret = "lwFhrCtxQwicVlNIuitXN98Dup4ESSdYSXKSKMdn";

// --- Definisikan PIN ---
#define PIN_RST          0  // D3
#define PIN_SDA          15 // D8
#define PIN_SERVO        4  // D2
#define PIN_BUTTON       5  // D1
#define PIN_LED_MASUK    16 // D0
#define PIN_LED_KELUAR   2  // D4 (Onboard LED)

// --- Inisialisasi Objek ---
MFRC522 mfrc522(PIN_SDA, PIN_RST);
Servo gateServo;

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

void setup() {
  Serial.begin(115200);
  SPI.begin();
  mfrc522.PCD_Init();
  
  // Setup Servo
  gateServo.attach(PIN_SERVO);
  gateServo.write(0); // Posisi gerbang tertutup (0 derajat)

  // Setup Pin Mode
  pinMode(PIN_BUTTON, INPUT_PULLUP);
  pinMode(PIN_LED_MASUK, OUTPUT);
  pinMode(PIN_LED_KELUAR, OUTPUT);

  // Inisialisasi Indikator Awal (Mode Masuk Aktif)
  updateLedIndicators();

  // Koneksi Wi-Fi
  connectToWiFi();
}

void loop() {
  // Pastikan Wi-Fi tetap terhubung
  if (WiFi.status() != WL_CONNECTED) {
    connectToWiFi();
  }

  // 1. Cek Trigger Servo dari Firebase (Setiap 2 Detik sekali)
  static unsigned long lastFirebaseCheck = 0;
  if (millis() - lastFirebaseCheck > 2000) {
    checkFirebaseTrigger();
    lastFirebaseCheck = millis();
  }

  // 2. Baca Input Button (Multi-click detection)
  handleButtonInput();

  // 3. Baca RFID Card jika ada kartu yang di-tap
  handleRfidInput();
}

// ====================================================================
// FUNGSI UTAMA KONTROL PERANGKAT
// ====================================================================

// Fungsi untuk menghubungkan ke Wi-Fi
void connectToWiFi() {
  Serial.print("Connecting to Wi-Fi: ");
  Serial.println(ssid);
  WiFi.begin(ssid, password);
  
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWi-Fi Connected!");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());
}

// Fungsi Mengupdate LED Indikator berdasarkan Mode Aktif
void updateLedIndicators() {
  if (currentMode == MODE_MASUK) {
    digitalWrite(PIN_LED_MASUK, HIGH);  // LED Masuk ON
    digitalWrite(PIN_LED_KELUAR, LOW);  // LED Keluar OFF
    Serial.println("[MODE] Masuk (1x click)");
  } 
  else if (currentMode == MODE_KELUAR) {
    digitalWrite(PIN_LED_MASUK, LOW);   // LED Masuk OFF
    digitalWrite(PIN_LED_KELUAR, HIGH); // LED Keluar ON
    Serial.println("[MODE] Keluar (2x click)");
  } 
  else if (currentMode == MODE_DAFTAR) {
    // Keduanya menyala stabil untuk menandakan mode pendaftaran kartu aktif
    digitalWrite(PIN_LED_MASUK, HIGH);
    digitalWrite(PIN_LED_KELUAR, HIGH);
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
  int reading = digitalRead(PIN_BUTTON);

  // Debouncing
  if (reading != lastButtonState) {
    lastDebounceTime = millis();
  }

  if ((millis() - lastDebounceTime) > debounceDelay) {
    if (reading != buttonState) {
      buttonState = reading;

      // Jika tombol ditekan (transisi HIGH ke LOW)
      if (buttonState == LOW) {
        clickCount++;
        lastClickTime = millis();
        Serial.print("Click ke-");
        Serial.println(clickCount);
      }
    }
  }
  lastButtonState = reading;

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
      Serial.println("[DARURAT] Gerbang Darurat Diaktifkan!");
      triggerEmergencyLocal();
    }
    else if (clickCount >= 4) {
      currentMode = MODE_DAFTAR;
      updateLedIndicators();
    }
    clickCount = 0; // Reset counter klik
  }
}

// Fungsi darurat: Buka servo lokal & kirim update trigger ke Firebase
void triggerEmergencyLocal() {
  // Nyalakan kedua LED berkedip cepat sebagai alarm darurat
  for (int i = 0; i < 5; i++) {
    digitalWrite(PIN_LED_MASUK, HIGH);
    digitalWrite(PIN_LED_KELUAR, HIGH);
    delay(100);
    digitalWrite(PIN_LED_MASUK, LOW);
    digitalWrite(PIN_LED_KELUAR, LOW);
    delay(100);
  }
  
  // Update mode LED kembali ke normal
  updateLedIndicators();

  // Buka Servo
  openGate();
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
  WiFiClient client;
  HTTPClient http;
  
  Serial.println("[HTTP] Mengirim data ke backend...");
  http.begin(client, backendUrl);
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

      Serial.print("[VALIDASI] ");
      Serial.print(studentName);
      Serial.print(" - ");
      Serial.println(message);

      if (action == "open_gate") {
        openGate();
      } else {
        // Blink LED error (Deny)
        for (int i = 0; i < 3; i++) {
          digitalWrite(PIN_LED_MASUK, LOW);
          digitalWrite(PIN_LED_KELUAR, LOW);
          delay(200);
          updateLedIndicators();
          delay(200);
        }
      }
    }
  } else {
    Serial.print("[HTTP] Error sending POST: ");
    Serial.println(httpResponseCode);
  }
  
  http.end();
}

// Fungsi mengirim request pendaftaran kartu baru ke API Backend
void sendRegistrationRequest(String uid) {
  WiFiClient client;
  HTTPClient http;
  
  // Ubah URL endpoint pendaftaran: /api/gate/register-tap?rfid_uid=HEX_UID
  String regUrl = backendUrl;
  regUrl.replace("/capture-validate", "/register-tap?rfid_uid=" + uid);
  
  Serial.print("[HTTP] Mengirim pendaftaran kartu ke: ");
  Serial.println(regUrl);
  
  http.begin(client, regUrl);
  int httpResponseCode = http.POST(""); // Kirim POST kosong karena UID ada di parameter URL

  if (httpResponseCode > 0) {
    String response = http.getString();
    Serial.print("[HTTP] Response code: ");
    Serial.println(httpResponseCode);
    Serial.println("[HTTP] Response body: " + response);

    // Sukses: Berikan feedback LED kedip cepat bersamaan 3x
    for (int i = 0; i < 3; i++) {
      digitalWrite(PIN_LED_MASUK, LOW);
      digitalWrite(PIN_LED_KELUAR, LOW);
      delay(100);
      digitalWrite(PIN_LED_MASUK, HIGH);
      digitalWrite(PIN_LED_KELUAR, HIGH);
      delay(100);
    }
    
    // Kembalikan mode ke default (MASUK) setelah pendaftaran berhasil
    currentMode = MODE_MASUK;
    updateLedIndicators();
  } else {
    Serial.print("[HTTP] Error sending POST: ");
    Serial.println(httpResponseCode);

    // Gagal: Kedip LED bergantian
    for (int i = 0; i < 3; i++) {
      digitalWrite(PIN_LED_MASUK, HIGH);
      digitalWrite(PIN_LED_KELUAR, LOW);
      delay(150);
      digitalWrite(PIN_LED_MASUK, LOW);
      digitalWrite(PIN_LED_KELUAR, HIGH);
      delay(150);
    }
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
      
      // Buka Gerbang
      openGate();

      // Reset Trigger ke 0 di Firebase agar tidak terbuka berulang kali
      resetFirebaseTrigger();
    }
  }
  http.end();
}

// Fungsi meriset trigger gerbang kembali ke 0 di Firebase
void resetFirebaseTrigger() {
  WiFiClientSecure client;
  client.setInsecure();
  HTTPClient http;

  String url = "https://" + firebaseHost + "/gate/servo_trigger.json";
  if (firebaseSecret != "") {
    url += "?auth=" + firebaseSecret;
  }

  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");

  // PUT nilai 0 ke path trigger
  int httpResponseCode = http.PUT("0");
  if (httpResponseCode == 200) {
    Serial.println("[FIREBASE] Trigger berhasil di-reset kembali ke 0.");
  } else {
    Serial.print("[FIREBASE] Gagal mereset trigger: HTTP ");
    Serial.println(httpResponseCode);
  }
  http.end();
}
