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
import re
from huggingface_hub import hf_hub_download
import threading
from fastapi.responses import StreamingResponse

# ═══════════════════════════════════════════
#  KONFIGURASI & STRATEGI FALLBACK
# ═══════════════════════════════════════════

BACKEND_URL = os.getenv("BACKEND_URL", "http://127.0.0.1:8000/api/gate/ml/plate-detect")

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
    {"plate": "G 3050 ANF", "confidence": 0.96},
    {"plate": "G5090DB",   "confidence": 0.88},
    {"plate": "G 1234 AB", "confidence": 0.45},
    {"plate": "",          "confidence": 0.0},
]

USE_REAL_ML = False
yolo_model = None
ocr_reader = None

def normalize_ocr_char(char, expected_type):
    char = char.upper()
    if expected_type == 'letter':
        mapping = {
            '6': 'G',
            'C': 'G',
            '0': 'D',
            '1': 'I',
            '2': 'Z',
            '3': 'E',
            '4': 'A',
            '5': 'S',
            '8': 'B'
        }
        return mapping.get(char, char)
    elif expected_type == 'digit':
        mapping = {
            'O': '0',
            'D': '0',
            'I': '1',
            'L': '1',
            'Z': '2',
            'E': '3',
            'A': '4',
            'S': '5',
            'G': '6',
            'B': '8'
        }
        return mapping.get(char, char)
    return char

def format_plat_indonesia(ocr_input):
    if isinstance(ocr_input, list):
        combined = " ".join(ocr_input).upper()
    else:
        combined = str(ocr_input).upper()
        
    words = combined.split()
    all_segments = []
    
    for w in words:
        w_clean = re.sub(r'[^A-Z0-9]', '', w)
        if not w_clean:
            continue
            
        # Karakter awal misread '6' atau 'C' -> 'G'
        if w_clean[0] in ['6', 'C'] and len(w_clean) > 1:
            w_clean = normalize_ocr_char(w_clean[0], 'letter') + w_clean[1:]
            
        segs = re.findall(r'([A-Z]+|[0-9]+)', w_clean)
        all_segments.extend(segs)
        
    prefix = ""
    number = ""
    suffix = ""
    
    for seg in all_segments:
        if not prefix:
            prefix_cand = "".join([normalize_ocr_char(c, 'letter') for c in seg])
            if prefix_cand.isalpha() and len(prefix_cand) <= 2:
                prefix = prefix_cand
            continue
            
        if not number:
            number_cand = "".join([normalize_ocr_char(c, 'digit') for c in seg])
            if number_cand.isdigit() and len(number_cand) <= 4:
                number = number_cand
            continue
            
        if not suffix:
            suffix_cand = "".join([normalize_ocr_char(c, 'letter') for c in seg])
            if suffix_cand.isalpha() and len(suffix_cand) <= 3:
                suffix = suffix_cand
                break
                
    if prefix and number and suffix:
        return f"{prefix} {number} {suffix}"
    elif prefix and number:
        return f"{prefix} {number}"
        
    return combined

try:
    from ultralytics import YOLO
    import easyocr
    
    # Prioritaskan model lokal dari program yang dikirim user
    if os.path.exists(MODEL_PATH):
        model_path = MODEL_PATH
        print(f"[ML Service] Menggunakan model lokal user: {model_path}")
    else:
        print("[ML Service] Model lokal tidak ditemukan. Mencoba mengunduh dari Hugging Face Hub...")
        try:
            model_path = hf_hub_download(repo_id="wuriyanto/yolo8-indonesian-license-plate-detection", filename="model.pt")
            print(f"[ML Service] Model Hugging Face diunduh ke: {model_path}")
        except Exception as e:
            print(f"[ML Service] Gagal mengunduh model dari Hugging Face: {e}")
            model_path = MODEL_PATH

    if os.path.exists(model_path):
        print("[ML Service] Loading YOLOv8 & EasyOCR...")
        yolo_model = YOLO(model_path)
        ocr_reader = easyocr.Reader(['en'], gpu=False) # Aktifkan gpu=True jika CUDA terpasang
        USE_REAL_ML = True
        print("[ML Service] ✅ RUNNING IN PRODUCTION MODE (REAL ML DETECTIONS)")
    else:
        print(f"[ML Service] ⚠️ Model weights NOT found at {model_path}")
        print("[ML Service] ⚠️ Running in SIMULATOR mode. Please check model path.")
except ImportError:
    print("[ML Service] ⚠️ ML dependencies not installed. Running in SIMULATOR mode.")

# ═══════════════════════════════════════════
#  CAMERA STREAMER & FASTAPI SETUP
# ═══════════════════════════════════════════

CAMERA_SOURCE = os.getenv("CAMERA_URL") or "1" # Default ke 1 untuk webcam eksternal, ganti ke 0 jika memakai webcam internal
camera_streamer = None

class CameraStreamer:
    def __init__(self, source):
        self.source = source
        self.cap = None
        self.frame = None
        self.ret = False
        self.running = False
        self.lock = threading.Lock()
        self.thread = None

    def start(self):
        if self.running:
            return
        self.running = True
        self.thread = threading.Thread(target=self._update, daemon=True)
        self.thread.start()

    def _update(self):
        print(f"[CameraStreamer] Starting background camera stream from: {self.source}")
        source_val = int(self.source) if isinstance(self.source, str) and self.source.isdigit() else self.source
        self.cap = cv2.VideoCapture(source_val)
        
        while self.running:
            ret, frame = self.cap.read()
            with self.lock:
                self.ret = ret
                if ret:
                    self.frame = frame.copy()
                else:
                    self.frame = None
            if not ret:
                print(f"[CameraStreamer] Connection failed or lost for source: {self.source}. Retrying in 2s...")
                time.sleep(2)
                self.cap.release()
                self.cap = cv2.VideoCapture(source_val)
            time.sleep(0.03) # ~30 FPS

    def get_frame(self):
        with self.lock:
            return self.ret, self.frame

    def stop(self):
        self.running = False
        if self.thread:
            self.thread.join()
        if self.cap:
            self.cap.release()

app = FastAPI(title="ML Plate Detection Service", version="1.0.0")

from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
def startup_event():
    global camera_streamer
    camera_streamer = CameraStreamer(CAMERA_SOURCE)
    camera_streamer.start()

@app.on_event("shutdown")
def shutdown_event():
    global camera_streamer
    if camera_streamer:
        camera_streamer.stop()

@app.get("/api/stream")
def stream_camera():
    """
    Endpoint untuk streaming MJPEG dari webcam eksternal (CameraStreamer) secara realtime ke browser/dashboard.
    """
    def generate_frames():
        while True:
            ret, frame = camera_streamer.get_frame()
            if not ret or frame is None:
                time.sleep(0.1)
                continue
            ret, buffer = cv2.imencode('.jpg', frame)
            if not ret:
                continue
            frame_bytes = buffer.tobytes()
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')
            time.sleep(0.05) # Batasi FPS ke ~20
            
    return StreamingResponse(generate_frames(), media_type="multipart/x-mixed-replace; boundary=frame")

class ScanRequest(BaseModel):
    gate_id: str
    request_type: str = "capture_and_detect"
    camera_url: Optional[str] = None
    fallback_plate: Optional[str] = None

class ScanResponse(BaseModel):
    detected_plate: str
    confidence: float
    timestamp: str
    gate_id: str
    model_version: str = "yolov8n-plate-v4.0"
    image_path: Optional[str] = None

@app.post("/api/scan-plate", response_model=ScanResponse)
async def scan_plate(request: ScanRequest):
    """
    Endpoint untuk mendeteksi plat dari RTSP / HTTP / Webcam stream kamera atau file gambar lokal.
    """
    frame = None
    ret = False

    if USE_REAL_ML:
        try:
            # 1. Cek apakah request.camera_url adalah path ke file gambar lokal yang ada di disk
            if isinstance(request.camera_url, str) and os.path.isfile(request.camera_url):
                print(f"[ML Service] Membaca file gambar lokal: {request.camera_url}")
                frame = cv2.imread(request.camera_url)
                ret = frame is not None
            else:
                # 2. Ambil dari background streamer (Webcam Eksternal) yang sedang berjalan
                ret, frame = camera_streamer.get_frame()
                if not ret or frame is None:
                    # Fallback jika streamer background kosong, coba baca langsung sekali
                    print("[ML Service] Streamer background kosong. Mencoba membaca langsung...")
                    source_val = int(CAMERA_SOURCE) if CAMERA_SOURCE.isdigit() else CAMERA_SOURCE
                    cap = cv2.VideoCapture(source_val)
                    ret, frame = cap.read()
                    cap.release()
            
            if ret and frame is not None:
                detected_plate, confidence = _process_ml_inference(frame)
                
                # Jika real ML aktif tapi gagal mendeteksi plat pada frame,
                # gunakan fallback_plate jika dikirim oleh request (untuk simulasi RFID)
                if not detected_plate and request.fallback_plate:
                    detected_plate = request.fallback_plate
                    confidence = 0.95
                    print(f"[ML Real Inference Empty] Fallback ke plat terdaftar: '{detected_plate}'")
                
                # Simpan frame ke folder uploads/scans agar bisa diakses backend
                backend_uploads_dir = os.path.join(BASE_DIR, "backend", "uploads", "scans")
                os.makedirs(backend_uploads_dir, exist_ok=True)
                
                timestamp_str = datetime.now().strftime("%Y%m%d_%H%M%S")
                filename = f"capture_{request.gate_id}_{timestamp_str}.jpg"
                filepath = os.path.join(backend_uploads_dir, filename)
                relative_path = f"/uploads/scans/{filename}"
                
                cv2.imwrite(filepath, frame)
                print(f"[ML Service] Foto berhasil disimpan ke {filepath}")
                
                return ScanResponse(
                    detected_plate=detected_plate,
                    confidence=confidence,
                    timestamp=datetime.now(timezone.utc).isoformat(),
                    gate_id=request.gate_id,
                    image_path=relative_path,
                )
            else:
                print(f"[ML Error] Gagal memperoleh gambar dari sumber: {video_source}")
        except Exception as e:
            print(f"[ML Error] Error saat mengambil gambar dari {video_source}: {e}")
            
    # 4. Fallback ke simulator cerdas jika input RFID memiliki plat terdaftar
    if request.fallback_plate:
        detected_plate = request.fallback_plate
        confidence = 0.95
        print(f"[ML Simulator Cerdas] Kamera gagal. Menggunakan plat terdaftar dari kartu RFID: '{detected_plate}' (conf: {confidence})")
    else:
        detection = random.choice(SIMULATED_PLATES)
        detected_plate = detection["plate"]
        confidence = detection["confidence"]
        print(f"[ML Simulator Fallback] Kamera gagal & no fallback. Menggunakan plat acak: '{detected_plate}' (conf: {confidence:.2f})")
        
    return ScanResponse(
        detected_plate=detected_plate,
        confidence=confidence,
        timestamp=datetime.now(timezone.utc).isoformat(),
        gate_id=request.gate_id,
        image_path=None,
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
            if conf < 0.25: # Batas YOLO
                continue
                
            x1, y1, x2, y2 = map(int, box.xyxy[0])
            
            # 1. Coba deteksi di raw crop terlebih dahulu (sesuai main_anpr.py user)
            plate_crop_raw = frame[y1:y2, x1:x2]
            
            if plate_crop_raw.size > 0:
                ocr_results = ocr_reader.readtext(plate_crop_raw)
                if ocr_results:
                    texts = [t[1] for t in ocr_results]
                    plat_final = format_plat_indonesia(texts)
                    
                    # Cek apakah plat berhasil di-parse secara lengkap (Prefix + Nomor + Suffix)
                    # Plat lengkap minimal memiliki format seperti "G 1234 A" (minimal 3 kata terpisah oleh spasi)
                    if plat_final and len(plat_final.split()) == 3:
                        if conf > max_confidence:
                            detected_plate = plat_final
                            max_confidence = conf
                        continue
            
            # 2. Fallback: jika raw crop gagal, coba dengan preprocessing
            crop_y1 = max(0, y1 - 5)
            crop_y2 = min(frame.shape[0], y2 + 5)
            crop_x1 = max(0, x1 - 5)
            crop_x2 = min(frame.shape[1], x2 + 5)
            plate_crop_pad = frame[crop_y1:crop_y2, crop_x1:crop_x2]
            
            if plate_crop_pad.size > 0:
                gray_crop = cv2.cvtColor(plate_crop_pad, cv2.COLOR_BGR2GRAY)
                resized_crop = cv2.resize(gray_crop, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
                thresh_crop = cv2.threshold(resized_crop, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)[1]
                
                ocr_results_prep = ocr_reader.readtext(thresh_crop)
                if ocr_results_prep:
                    texts = [t[1] for t in ocr_results_prep]
                    plat_final = format_plat_indonesia(texts)
                    if plat_final and len(plat_final.split()) == 3:
                        if conf > max_confidence:
                            detected_plate = plat_final
                            max_confidence = conf
                            
    return detected_plate, max_confidence

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
    print("  ML PLATE DETECTION SERVICE")
    print(f"  Mode: {'PRODUCTION (Real ML)' if USE_REAL_ML else 'DEVELOPMENT (Simulator)'}")
    print("  Endpoint: http://127.0.0.1:8765")
    print("=" * 60)
    
    uvicorn.run(app, host="0.0.0.0", port=8765)
