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
    * Signal -> D4 (GPIO 2)
    * VCC    -> 5V (Vin pada NodeMCU jika menggunakan USB 5V)
    * GND    -> GND
  - Push Button:
    * Pin    -> Dipostpone (Disimulasikan via Serial Input)
  - LED Indikator:
    * LED Masuk  -> D0 (GPIO 16)
    * LED Keluar -> D1 (GPIO 5) (Dipindahkan dari D4 karena D4 untuk Servo)
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
#define PIN_BUTTON       5  // D1 (Dipostpone, input button disimulasikan via Serial)
#define PIN_LED_MASUK    16 // D0
#define PIN_LED_KELUAR   5  // D1 (Dipindahkan dari D4 karena D4 digunakan untuk Servo)

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
  pinMode(PIN_LED_MASUK, OUTPUT);
  pinMode(PIN_LED_KELUAR, OUTPUT);

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
    connectToWiFi();
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
  // Simulasikan button menggunakan Serial input
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
        openGate();
      } else {
        Serial.print("[VALIDASI] Gagal/Ditolak! Status gerbang tetap tertutup (action: ");
        Serial.print(action);
        Serial.println(")");
        
        // Blink LED error (Deny)
        for (int i = 0; i < 3; i++) {
          digitalWrite(PIN_LED_MASUK, LOW);
          digitalWrite(PIN_LED_KELUAR, LOW);
          delay(200);
          updateLedIndicators();
          delay(200);
        }
      }
    } else {
      Serial.print("[JSON] Gagal mengurai JSON response: ");
      Serial.println(error.c_str());
    }
  } else {
    Serial.print("[HTTP] Error sending POST: ");
    Serial.println(httpResponseCode);
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
  bool shouldReset = false;

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

      // Tandai bahwa trigger perlu di-reset
      shouldReset = true;
    }
  }
  http.end(); // Tutup koneksi HTTPS pertama terlebih dahulu untuk menghemat memori (RAM)

  // Jalankan reset jika diperlukan setelah koneksi sebelumnya ditutup
  if (shouldReset) {
    resetFirebaseTrigger();
  }
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
