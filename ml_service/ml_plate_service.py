"""
ML Service Simulator — YOLOv8 + EasyOCR Plate Detection
════════════════════════════════════════════════════════

Simulator ini mensimulasikan service ML yang berjalan di server terpisah.
Dalam production, service ini menjalankan:
  - YOLOv8 untuk deteksi area plat nomor pada frame kamera
  - EasyOCR / PaddleOCR untuk membaca teks plat nomor

Service ini memiliki 2 mode:
  1. HTTP Server (endpoint /api/scan-plate)  — dipanggil oleh ESP32
  2. Push Mode (POST ke backend /api/gate/ml/plate-detect) — kirim proaktif

Requirements:
  pip install fastapi uvicorn requests

Untuk production sebenarnya, tambahkan:
  pip install ultralytics easyocr opencv-python numpy
"""

import random
import time
from datetime import datetime, timezone
from fastapi import FastAPI
from pydantic import BaseModel
from typing import Optional
import requests
import uvicorn

# ═══════════════════════════════════════════
#  KONFIGURASI
# ═══════════════════════════════════════════

BACKEND_URL = "http://127.0.0.1:8000/api/gate/ml/plate-detect"

# Plat nomor yang "terlihat" oleh kamera simulator
# Dalam production, ini diganti oleh output YOLOv8 + OCR
SIMULATED_PLATES = [
    {"plate": "G 1234 AB", "confidence": 0.95},  # Budi Santoso (Motor)
    {"plate": "G 5678 CD", "confidence": 0.92},  # Siti Aminah (Motor)
    {"plate": "G5090DB",   "confidence": 0.88},   # Unknown plate
    {"plate": "G 1234 AB", "confidence": 0.45},   # Low confidence
    {"plate": "",          "confidence": 0.0},     # No detection
]

# ═══════════════════════════════════════════
#  ML SERVICE (FastAPI)
# ═══════════════════════════════════════════

app = FastAPI(title="ML Plate Detection Service", version="1.0.0")


class ScanRequest(BaseModel):
    gate_id: str
    request_type: str = "capture_and_detect"


class ScanResponse(BaseModel):
    detected_plate: str
    confidence: float
    timestamp: str
    gate_id: str
    model_version: str = "yolov8n-plate-v1.0"


@app.post("/api/scan-plate", response_model=ScanResponse)
async def scan_plate(request: ScanRequest):
    """
    Endpoint yang dipanggil oleh ESP32 untuk meminta ML scan plat nomor.
    
    Dalam PRODUCTION, alur ini:
    1. Capture frame dari IP Camera / USB Camera
    2. Jalankan YOLOv8 inference → detect bounding box plat
    3. Crop area plat → jalankan EasyOCR
    4. Return teks plat + confidence
    
    Dalam SIMULATOR, kita random pick dari daftar plat.
    """
    
    # ── SIMULATOR: Random pick ──
    detection = random.choice(SIMULATED_PLATES)
    
    """
    ── PRODUCTION CODE (uncomment saat deploy) ──
    
    import cv2
    from ultralytics import YOLO
    import easyocr
    
    # Load model (singleton, load 1x saat startup)
    # model = YOLO("yolov8n_plate.pt")  # Custom trained model
    # reader = easyocr.Reader(['id'])     # Indonesian plate reader
    
    # Capture frame
    # cap = cv2.VideoCapture(f"rtsp://camera_{request.gate_id}/stream")
    # ret, frame = cap.read()
    # cap.release()
    
    # Detect plate region
    # results = model(frame)
    # for box in results[0].boxes:
    #     x1, y1, x2, y2 = map(int, box.xyxy[0])
    #     conf = float(box.conf[0])
    #     plate_crop = frame[y1:y2, x1:x2]
    #     
    #     # OCR on cropped plate
    #     ocr_results = reader.readtext(plate_crop)
    #     if ocr_results:
    #         detected_text = ocr_results[0][1]  # Teks plat
    #         ocr_conf = ocr_results[0][2]        # OCR confidence
    #         
    #         detection = {
    #             "plate": detected_text,
    #             "confidence": min(conf, ocr_conf)  # Combined confidence
    #         }
    """
    
    # Simulasi processing delay (ML inference ~200-500ms)
    # time.sleep(0.3)
    
    print(f"[ML] Gate {request.gate_id}: Detected '{detection['plate']}' "
          f"(conf: {detection['confidence']:.2f})")
    
    return ScanResponse(
        detected_plate=detection["plate"],
        confidence=detection["confidence"],
        timestamp=datetime.now(timezone.utc).isoformat(),
        gate_id=request.gate_id,
    )


@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "ML Plate Detection",
        "model": "YOLOv8n + EasyOCR (Simulator)",
        "gpu_available": False,  # Set True jika ada GPU
    }


# ═══════════════════════════════════════════
#  PUSH MODE: Kirim deteksi ke backend secara proaktif
# ═══════════════════════════════════════════

def push_detection_to_backend(gate_id: str, plate: str, confidence: float):
    """
    Mode alternatif: ML Service mengirim hasil deteksi ke backend
    tanpa menunggu request dari ESP32.
    
    Digunakan ketika kamera secara kontinu mendeteksi plat
    dan menyimpannya di backend buffer.
    """
    payload = {
        "gate_id": gate_id,
        "detected_plate": plate,
        "confidence": confidence,
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
    
    try:
        response = requests.post(BACKEND_URL, json=payload, timeout=5)
        if response.status_code == 200:
            print(f"[PUSH] ✅ Sent to backend: {plate} ({confidence:.2f})")
        else:
            print(f"[PUSH] ⚠️ Backend error: {response.status_code}")
    except Exception as e:
        print(f"[PUSH] ❌ Failed: {e}")


# ═══════════════════════════════════════════
#  MAIN
# ═══════════════════════════════════════════

if __name__ == "__main__":
    print("=" * 60)
    print("  🤖 ML PLATE DETECTION SERVICE (SIMULATOR)")
    print("  Endpoint: http://127.0.0.1:5000/api/scan-plate")
    print("=" * 60)
    
    uvicorn.run(app, host="0.0.0.0", port=5000)
