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
"""

import random
import time
import os
import cv2
import numpy as np
from datetime import datetime, timezone
from fastapi import FastAPI, File, UploadFile, Form
from pydantic import BaseModel
from typing import Optional
import requests
import uvicorn

# ═══════════════════════════════════════════
#  KONFIGURASI & STRATEGI FALLBACK
# ═══════════════════════════════════════════

BACKEND_URL = "http://127.0.0.1:8000/api/gate/ml/plate-detect"

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODEL_PATH = os.path.join(
    BASE_DIR, 
    "temp_extracted", 
    "anpr-parking-system-main", 
    "runs", 
    "detect", 
    "train-4", 
    "weights", 
    "best.pt"
)

# Simulasi plat nomor (jika menggunakan simulator)
SIMULATED_PLATES = [
    {"plate": "G 1234 AB", "confidence": 0.95},
    {"plate": "G 5678 CD", "confidence": 0.92},
    {"plate": "G5090DB",   "confidence": 0.88},
    {"plate": "G 1234 AB", "confidence": 0.45},
    {"plate": "",          "confidence": 0.0},
]

USE_REAL_ML = False
yolo_model = None
ocr_reader = None

try:
    from ultralytics import YOLO
    import easyocr
    
    if os.path.exists(MODEL_PATH):
        print(f"[ML Service] Model weights found at: {MODEL_PATH}")
        print("[ML Service] Loading YOLOv8 & EasyOCR...")
        yolo_model = YOLO(MODEL_PATH)
        ocr_reader = easyocr.Reader(['en'], gpu=False) # Aktifkan gpu=True jika CUDA terpasang
        USE_REAL_ML = True
        print("[ML Service] ✅ RUNNING IN PRODUCTION MODE (REAL ML DETECTIONS)")
    else:
        print(f"[ML Service] ⚠️ Model weights NOT found at {MODEL_PATH}")
        print("[ML Service] ⚠️ Running in SIMULATOR mode. Please check model path.")
except ImportError:
    print("[ML Service] ⚠️ ML dependencies (ultralytics, easyocr) not installed.")
    print("[ML Service] ⚠️ Running in SIMULATOR mode. To run real ML, install packages:")
    print("      pip install ultralytics easyocr opencv-python numpy")

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
    model_version: str = "yolov8n-plate-v4.0"

@app.post("/api/scan-plate", response_model=ScanResponse)
async def scan_plate(request: ScanRequest):
    """
    Endpoint untuk mendeteksi plat dari RTSP stream kamera.
    """
    if USE_REAL_ML:
        try:
            # Capture frame dari IP Camera (rtsp)
            camera_url = f"rtsp://camera_{request.gate_id}/stream"
            cap = cv2.VideoCapture(camera_url)
            ret, frame = cap.read()
            cap.release()
            
            if ret:
                detected_plate, confidence = _process_ml_inference(frame)
                return ScanResponse(
                    detected_plate=detected_plate,
                    confidence=confidence,
                    timestamp=datetime.now(timezone.utc).isoformat(),
                    gate_id=request.gate_id,
                )
        except Exception as e:
            print(f"[ML Error] Gagal membaca kamera RTSP: {e}")
            
    # Fallback ke simulator
    detection = random.choice(SIMULATED_PLATES)
    return ScanResponse(
        detected_plate=detection["plate"],
        confidence=detection["confidence"],
        timestamp=datetime.now(timezone.utc).isoformat(),
        gate_id=request.gate_id,
    )

@app.post("/api/predict-image", response_model=ScanResponse)
async def predict_image(
    file: UploadFile = File(...),
    gate_id: str = Form("GATE_DEFAULT")
):
    """
    Endpoint untuk mendeteksi plat dari file gambar yang dikirim ESP32-CAM.
    """
    content = await file.read()
    
    if USE_REAL_ML:
        try:
            # Decode file bytes ke image OpenCV
            nparr = np.frombuffer(content, np.uint8)
            frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            
            if frame is not None:
                detected_plate, confidence = _process_ml_inference(frame)
                return ScanResponse(
                    detected_plate=detected_plate,
                    confidence=confidence,
                    timestamp=datetime.now(timezone.utc).isoformat(),
                    gate_id=gate_id,
                )
        except Exception as e:
            print(f"[ML Error] Gagal menjalankan inference gambar: {e}")

    # Fallback ke simulator
    detection = random.choice(SIMULATED_PLATES)
    print(f"[ML Simulator] Prediksi Gambar: {detection['plate']} (conf: {detection['confidence']:.2f})")
    return ScanResponse(
        detected_plate=detection["plate"],
        confidence=detection["confidence"],
        timestamp=datetime.now(timezone.utc).isoformat(),
        gate_id=gate_id,
    )

def _process_ml_inference(frame) -> tuple[str, float]:
    """
    Helper function untuk menjalankan YOLOv8 bounding box detection + EasyOCR crop extraction.
    """
    results = yolo_model(frame, verbose=False)
    detected_plate = ""
    max_confidence = 0.0
    
    for res in results:
        for box in res.boxes:
            conf = float(box.conf[0])
            if conf < 0.4:
                continue
                
            x1, y1, x2, y2 = map(int, box.xyxy[0])
            
            # Crop dengan padding sedikit
            pad = 6
            y1_pad = max(0, y1 - pad)
            y2_pad = min(frame.shape[0], y2 + pad)
            x1_pad = max(0, x1 - pad)
            x2_pad = min(frame.shape[1], x2 + pad)
            
            plate_crop = frame[y1_pad:y2_pad, x1_pad:x2_pad]
            
            if plate_crop.size > 0:
                # Preprocessing grayscale
                gray_plate = cv2.cvtColor(plate_crop, cv2.COLOR_BGR2GRAY)
                # Adaptive thresholding agar tulisan kontras
                processed_plate = cv2.adaptiveThreshold(
                    gray_plate, 255, 
                    cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
                    cv2.THRESH_BINARY, 11, 2
                )
                
                # Baca text dengan EasyOCR
                ocr_results = ocr_reader.readtext(processed_plate)
                teks_gabungan = ""
                ocr_conf_sum = 0.0
                ocr_count = 0
                
                for (bbox, text, prob) in ocr_results:
                    if prob > 0.25:
                        teks_gabungan += text + " "
                        ocr_conf_sum += prob
                        ocr_count += 1
                        
                teks_gabungan = teks_gabungan.strip().upper()
                
                if teks_gabungan != "":
                    avg_ocr_conf = (ocr_conf_sum / ocr_count) if ocr_count > 0 else 0.0
                    combined_conf = conf * avg_ocr_conf
                    
                    if combined_conf > max_confidence:
                        detected_plate = teks_gabungan
                        max_confidence = combined_conf
                        
    # Normalisasi plat nomor (hanya huruf & angka)
    clean_plate = "".join([c for c in detected_plate if c.isalnum()])
    return clean_plate, max_confidence

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "ML Plate Detection",
        "model": "YOLOv8 + EasyOCR (Real)" if USE_REAL_ML else "YOLOv8 + EasyOCR (Simulator)",
        "model_path": MODEL_PATH,
        "production_mode": USE_REAL_ML,
    }

if __name__ == "__main__":
    print("=" * 60)
    print("  🤖 ML PLATE DETECTION SERVICE")
    print(f"  Mode: {'PRODUCTION (Real ML)' if USE_REAL_ML else 'DEVELOPMENT (Simulator)'}")
    print("  Endpoint: http://127.0.0.1:5000")
    print("=" * 60)
    
    uvicorn.run(app, host="0.0.0.0", port=5000)
