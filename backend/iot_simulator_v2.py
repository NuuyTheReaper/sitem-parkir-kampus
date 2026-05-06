"""
IoT Gateway Simulator v2 — Dual Validation Mode
═════════════════════════════════════════════════

Simulator ini mensimulasikan perilaku ESP32 yang melakukan:
  1. Tap RFID (input manual UID)
  2. Request ML Service untuk scan plat (otomatis/manual)
  3. Kirim ke backend untuk validasi ganda
  4. Tampilkan respon (buka/tutup gerbang)

Jalankan:
  python iot_simulator_v2.py
  
Pastikan backend berjalan di http://127.0.0.1:8000
Opsional: ML Service berjalan di http://127.0.0.1:5000
"""

import requests
import json
import time

# ═══════════════════════════════════════════
#  KONFIGURASI
# ═══════════════════════════════════════════

BACKEND_URL = "http://127.0.0.1:8000/api"
ML_SERVICE_URL = "http://127.0.0.1:5000/api/scan-plate"

# Shortcut RFID UIDs (sesuai seed.py)
KNOWN_RFIDS = {
    "1": {"uid": "RFID_BUDI_123", "nama": "Budi Santoso", "plat": "G 1234 AB"},
    "2": {"uid": "RFID_SITI_456", "nama": "Siti Aminah", "plat": "G 5678 CD"},
}


def print_header():
    print("\n" + "═" * 60)
    print("  🏫 SMART CAMPUS PARKING — IoT SIMULATOR v2.0")
    print("  Mode: Validasi Ganda (RFID + ML Plate Detection)")
    print("═" * 60)
    print("  Backend: " + BACKEND_URL)
    print("  ML Svc : " + ML_SERVICE_URL)
    print("─" * 60)


def print_rfid_shortcuts():
    print("\n📋 Shortcut RFID (tekan angka untuk quick-select):")
    for key, data in KNOWN_RFIDS.items():
        print(f"   [{key}] {data['uid']} — {data['nama']} ({data['plat']})")
    print(f"   [0] Input manual")


def get_rfid_input() -> str:
    """Mendapatkan RFID UID dari user (simulasi tap kartu)."""
    print_rfid_shortcuts()
    choice = input("\n🔑 Tap RFID (pilih shortcut atau ketik UID): ").strip()
    
    if choice in KNOWN_RFIDS:
        uid = KNOWN_RFIDS[choice]["uid"]
        print(f"   → UID: {uid}")
        return uid
    elif choice == "0" or choice == "":
        uid = input("   Masukkan UID RFID: ").strip()
        return uid if uid else "UNKNOWN_RFID"
    else:
        # Assume it's a direct UID input
        return choice


def request_ml_scan(gate_id: str) -> tuple[str, float]:
    """
    Request ML Service untuk scan plat nomor.
    Returns (detected_plate, confidence)
    """
    try:
        payload = {
            "gate_id": gate_id,
            "request_type": "capture_and_detect"
        }
        response = requests.post(ML_SERVICE_URL, json=payload, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            plate = data.get("detected_plate", "")
            conf = data.get("confidence", 0.0)
            print(f"   📷 ML Detection: '{plate}' (confidence: {conf:.2f})")
            return plate, conf
        else:
            print(f"   ⚠️ ML Service error: {response.status_code}")
            return "", 0.0
            
    except requests.exceptions.ConnectionError:
        print("   ⚠️ ML Service tidak tersedia (offline)")
        print("   → Gunakan input manual untuk plat nomor")
        plate = input("   Masukkan plat nomor (simulasi deteksi kamera): ").strip()
        conf_str = input("   Masukkan confidence (0.0-1.0, default 0.95): ").strip()
        conf = float(conf_str) if conf_str else 0.95
        return plate, conf
    except Exception as e:
        print(f"   ❌ ML Error: {e}")
        return "", 0.0


def send_dual_validation(rfid_uid: str, plate: str, confidence: float, gate_type: str, gate_id: str):
    """Kirim request validasi ganda ke backend."""
    payload = {
        "rfid_uid": rfid_uid,
        "detected_plate": plate,
        "ml_confidence": confidence,
        "gate_type": gate_type,
        "gate_id": gate_id
    }
    
    print(f"\n📡 Mengirim ke backend: POST /api/gate/dual-validate")
    print(f"   Payload: {json.dumps(payload, indent=2)}")
    
    try:
        response = requests.post(f"{BACKEND_URL}/gate/dual-validate", json=payload, timeout=8)
        data = response.json()
        
        print(f"\n{'─' * 40}")
        print(f"  📨 RESPON SERVER (HTTP {response.status_code})")
        print(f"{'─' * 40}")
        
        if response.status_code == 200:
            action = data.get("action", "unknown")
            message = data.get("message", "")
            student = data.get("student_name", "-")
            plate_num = data.get("plate_number", "-")
            detail = data.get("validation_detail", "-")
            
            if action == "open_gate":
                print(f"  ✅ AKSES DIIZINKAN")
                print(f"  🚧 Servo: PALANG TERBUKA ↑")
                print(f"  👤 Mahasiswa: {student}")
                print(f"  🏍️  Plat: {plate_num}")
            else:
                print(f"  ❌ AKSES DITOLAK")
                print(f"  🚧 Servo: PALANG TETAP TERTUTUP ═")
                print(f"  🔔 Buzzer: BEEP BEEP BEEP!")
            
            print(f"  💬 Pesan: {message}")
            print(f"  📋 Detail: {detail}")
        else:
            print(f"  ⚠️ Error: {data}")
            
    except Exception as e:
        print(f"  ❌ Gagal terhubung ke server: {e}")


def send_legacy_scan(rfid_uid: str, plate: str, gate_type: str):
    """Legacy mode: gunakan endpoint /scan lama."""
    payload = {
        "rfid_uid": rfid_uid,
        "plat_nomor_ml": plate,
        "gate_type": gate_type
    }
    
    print(f"\n📡 [LEGACY] Mengirim ke: POST /api/gate/scan")
    
    try:
        response = requests.post(f"{BACKEND_URL}/gate/scan", json=payload, timeout=8)
        data = response.json()
        
        if response.status_code == 200:
            if data.get("action") == "open_gate":
                print(f"  ✅ GERBANG TERBUKA — {data.get('message')}")
            else:
                print(f"  ❌ DITOLAK — {data.get('message')}")
        else:
            print(f"  ⚠️ Error {response.status_code}: {data}")
    except Exception as e:
        print(f"  ❌ Error: {e}")


# ═══════════════════════════════════════════
#  MAIN LOOP
# ═══════════════════════════════════════════

def main():
    print_header()
    
    while True:
        try:
            print(f"\n{'═' * 60}")
            print("  MENU UTAMA")
            print("─" * 60)
            print("  1. 🆕 Scan Kendaraan (Validasi Ganda — RFID + ML)")
            print("  2. 📟 Scan Kendaraan (Legacy — tanpa ML)")
            print("  3. 📊 Cek Kapasitas Parkir")
            print("  4. 🚪 Keluar")
            print("─" * 60)
            
            choice = input("  Pilih aksi (1-4): ").strip()
            
            if choice == "4":
                print("\n👋 Simulator berhenti. Sampai jumpa!")
                break
            
            if choice == "3":
                try:
                    resp = requests.get(f"{BACKEND_URL}/gate/stats/capacity", timeout=5)
                    data = resp.json()
                    print(f"\n📊 Kapasitas Parkir:")
                    print(f"   Total : {data['total']} slot")
                    print(f"   Terisi: {data['parked']} kendaraan")
                    print(f"   Kosong: {data['available']} slot")
                except Exception as e:
                    print(f"   Error: {e}")
                continue
            
            if choice not in ["1", "2"]:
                print("   Pilihan tidak valid.")
                continue
            
            # Gate type
            gate_type = input("\n🚪 Gerbang (masuk/keluar): ").strip().lower()
            if gate_type not in ["masuk", "keluar"]:
                print("   Harus 'masuk' atau 'keluar'!")
                continue
            
            gate_id = f"GATE_{'MASUK' if gate_type == 'masuk' else 'KELUAR'}_1"
            
            # RFID input
            rfid_uid = get_rfid_input()
            
            if choice == "1":
                # ── MODE VALIDASI GANDA ──
                print(f"\n📷 Meminta ML Service scan plat nomor...")
                plate, confidence = request_ml_scan(gate_id)
                
                if not plate:
                    plate = input("   Masukkan plat nomor manual: ").strip()
                    confidence = 0.95
                
                send_dual_validation(rfid_uid, plate, confidence, gate_type, gate_id)
                
            elif choice == "2":
                # ── MODE LEGACY ──
                plate = input("\n🏍️  Masukkan plat nomor: ").strip()
                send_legacy_scan(rfid_uid, plate, gate_type)
            
            time.sleep(1)
            
        except KeyboardInterrupt:
            print("\n\n👋 Simulator berhenti. Sampai jumpa!")
            break


if __name__ == "__main__":
    main()
