"""
Pydantic schemas untuk komunikasi antara ML Service dan Backend.
"""

from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class MLPlateDetectionRequest(BaseModel):
    """
    Request dari ML Service ke Backend setelah berhasil mendeteksi plat nomor.
    Dikirim oleh service ML (YOLOv8 + OCR) setelah memproses frame kamera.
    """
    gate_id: str = Field(..., description="ID gerbang (misal: 'GATE_MASUK_1')")
    detected_plate: str = Field(..., description="Teks plat nomor hasil OCR")
    confidence: float = Field(..., ge=0.0, le=1.0, description="Skor confidence deteksi (0.0-1.0)")
    image_path: Optional[str] = Field(None, description="Path ke gambar bukti deteksi")
    timestamp: Optional[datetime] = Field(None, description="Waktu deteksi frame")
    

class MLPlateDetectionResponse(BaseModel):
    """
    Respon Backend ke ML Service.
    """
    status: str  # "received", "error"
    message: str
    gate_id: str


class DualValidationRequest(BaseModel):
    """
    Request gabungan dari mikrokontroler/gateway controller.
    Menggabungkan data RFID tap + hasil deteksi ML dalam satu request.
    
    Alur:
    1. ESP32 membaca RFID → dapat rfid_uid
    2. ESP32 meminta ML Service memproses kamera → dapat detected_plate
    3. ESP32 mengirim keduanya ke backend dalam satu request ini
    """
    rfid_uid: str = Field(..., description="UID kartu RFID yang di-tap")
    detected_plate: str = Field(..., description="Plat nomor hasil deteksi ML/OCR")
    ml_confidence: float = Field(
        default=1.0, ge=0.0, le=1.0,
        description="Skor confidence dari ML, default 1.0 jika tidak ada ML"
    )
    gate_type: str = Field(..., description="'masuk' atau 'keluar'")
    gate_id: Optional[str] = Field("GATE_DEFAULT", description="ID gerbang fisik")


class DualValidationResponse(BaseModel):
    """
    Respon Backend ke mikrokontroler setelah validasi ganda.
    Mikrokontroler akan membaca field 'action' untuk mengontrol servo/buzzer.
    """
    action: str  # "open_gate" atau "keep_closed"
    message: str
    student_name: Optional[str] = None
    plate_number: Optional[str] = None
    validation_detail: Optional[str] = None  # Detail pencocokan untuk logging


class CaptureValidationRequest(BaseModel):
    """
    Request dari alat gate ketika backend perlu meminta ANPR service
    mengambil frame kamera dan membaca plat terlebih dahulu.
    """
    rfid_uid: str = Field(..., description="UID kartu RFID yang di-tap")
    gate_type: str = Field(..., description="'masuk' atau 'keluar'")
    gate_id: Optional[str] = Field("GATE_DEFAULT", description="ID gerbang fisik")
    camera_url: Optional[str] = Field(
        None,
        description="Override URL kamera. Umumnya kosong; ANPR service memakai env per gate.",
    )


class ANPRScanRequest(BaseModel):
    """
    Request backend ke ANPR service terpisah.
    """
    gate_id: str = Field(..., description="ID gerbang fisik")
    camera_url: Optional[str] = Field(None, description="Override URL kamera untuk gate ini")


class ANPRScanResponse(BaseModel):
    """
    Response ANPR service setelah YOLO + OCR selesai membaca frame kamera.
    """
    detected_plate: str = Field("", description="Plat nomor hasil OCR")
    confidence: float = Field(0.0, ge=0.0, le=1.0, description="Confidence gabungan")
    gate_id: str = Field(..., description="ID gerbang fisik")
    timestamp: Optional[datetime] = Field(None, description="Waktu scan")
    model_version: Optional[str] = Field(None, description="Versi/nama model ANPR")
    image_path: Optional[str] = Field(None, description="Path bukti gambar jika disimpan")
