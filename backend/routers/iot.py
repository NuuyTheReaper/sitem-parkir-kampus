"""
IoT Integration Router — Dual Validation Gate System

Endpoint-endpoint untuk komunikasi antara:
  - Mikrokontroler ESP32 (RFID reader + servo control)
  - ML Service (YOLOv8 + OCR plate detection)
  - Petugas Dashboard (WebSocket live monitor)

Alur Validasi Ganda:
  1. ESP32 tap RFID → kirim UID ke backend
  2. Kamera capture → ML detect plate → kirim ke backend
  3. Backend: normalize + compare plate DB vs ML
  4. Backend kirim response → ESP32 buka/tutup gerbang
"""

from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect, File, UploadFile, Form
from sqlalchemy.orm import Session
from datetime import datetime, timezone, timedelta
import asyncio
import logging

def to_jakarta_time(dt: datetime) -> datetime:
    if dt is None:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    jakarta_tz = timezone(timedelta(hours=7))
    return dt.astimezone(jakarta_tz)
import httpx
import os

from core.security import get_petugas
from core.config import settings
from core.plate_validator import normalize_plate, validate_plate_match, find_matching_vehicle

import models
from schemas.parking import GateScanRequest, GateScanResponse
from schemas.ml import (
    ANPRScanResponse,
    CaptureValidationRequest,
    MLPlateDetectionRequest,
    MLPlateDetectionResponse,
    DualValidationRequest,
    DualValidationResponse,
)
from database import get_db

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/gate", tags=["IoT Integrations & WebSockets"])


# ═══════════════════════════════════════════════════════════════════
#  WebSocket Connection Managers
# ═══════════════════════════════════════════════════════════════════

class ConnectionManager:
    """Manages WebSocket connections for the Petugas Live Monitor."""
    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast(self, message: dict):
        for connection in list(self.active_connections):
            try:
                await connection.send_json(message)
            except Exception:
                self.disconnect(connection)

manager = ConnectionManager()


class PetugasNotificationManager:
    """Separate WebSocket channel for real-time notifications to petugas."""
    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def notify_new_request(self, data: dict):
        """Broadcast new access request notification to all connected petugas."""
        for connection in list(self.active_connections):
            try:
                await connection.send_json({
                    "type": "new_access_request",
                    **data
                })
            except Exception:
                self.disconnect(connection)

petugas_notifier = PetugasNotificationManager()


# Temporary storage for ML plate detections per gate (in production, use Redis)
# Format: {"GATE_MASUK_1": {"plate": "G5090DB", "confidence": 0.95, "timestamp": ...}}
_ml_plate_buffer: dict[str, dict] = {}

# State variable for physical gate trigger (manually triggered via petugas response / emergency action)
local_servo_trigger: int = 0

# Coordination maps to handle frontend-triggered webcam capture on RFID tap
# Key: rfid_uid, Value: asyncio.Event
_pending_captures: dict[str, asyncio.Event] = {}
# Key: rfid_uid, Value: DualValidationResponse
_capture_results: dict[str, dict] = {}


# ═══════════════════════════════════════════════════════════════════
#  WebSocket Endpoints
# ═══════════════════════════════════════════════════════════════════

@router.websocket("/monitor/live")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        manager.disconnect(websocket)


@router.websocket("/petugas/notifications")
async def petugas_notification_ws(websocket: WebSocket):
    """WebSocket endpoint for petugas real-time notifications."""
    await petugas_notifier.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            if data == "ping":
                await websocket.send_text("pong")
    except WebSocketDisconnect:
        petugas_notifier.disconnect(websocket)


# ═══════════════════════════════════════════════════════════════════
#  ENDPOINT 1: ML Plate Detection Submission
#  Dipanggil oleh ML Service (YOLOv8 + OCR) setelah proses frame kamera
# ═══════════════════════════════════════════════════════════════════

@router.post("/ml/plate-detect", response_model=MLPlateDetectionResponse)
async def receive_ml_plate_detection(request: MLPlateDetectionRequest, db: Session = Depends(get_db)):
    """
    Endpoint untuk ML Service mengirim hasil deteksi plat nomor.
    
    ML Service (YOLOv8 + EasyOCR) mengirim data plat yang terdeteksi
    dari frame kamera secara real-time. Data disimpan di buffer
    menunggu request RFID dari ESP32.
    
    Alur:
    1. Kamera capture frame → ML proses → kirim hasil ke endpoint ini
    2. Data disimpan di _ml_plate_buffer[gate_id]
    3. Ketika ESP32 tap RFID, backend ambil data dari buffer
    """
    _ml_plate_buffer[request.gate_id] = {
        "plate": request.detected_plate,
        "confidence": request.confidence,
        "image_path": request.image_path,
        "timestamp": to_jakarta_time(request.timestamp or datetime.now(timezone.utc)),
    }
    
    logger.info(
        f"[ML] Plate detected at {request.gate_id}: "
        f"{request.detected_plate} (conf: {request.confidence:.2f})"
    )
    
    # Otomatis buat antrean 'Permintaan Gerbang' jika plat milik tamu darurat
    guest = db.query(models.EmergencyGuest).filter(
        models.EmergencyGuest.plat_nomor == request.detected_plate,
        models.EmergencyGuest.status == "di_dalam"
    ).first()
    
    msg_suffix = ""
    if guest and "keluar" in request.gate_id.lower():
        existing = db.query(models.AccessRequest).filter(
            models.AccessRequest.emergency_guest_id == guest.id,
            models.AccessRequest.status == models.AccessRequestStatusEnum.pending
        ).first()
        if not existing:
            new_req = models.AccessRequest(
                emergency_guest_id=guest.id,
                jenis_aktivitas=models.ActivityTypeEnum.keluar,
            )
            db.add(new_req)
            db.commit()
            db.refresh(new_req)
            msg_suffix = " (Permintaan Keluar Darurat Dibuat)"
            try:
                await petugas_notifier.notify_new_request({
                    "user_nama": guest.nama + " (Darurat)",
                    "user_nim": "TAMU DARURAT",
                    "vehicle_plat": guest.plat_nomor,
                    "vehicle_jenis": "Mobil/Motor",
                    "jenis_aktivitas": "keluar",
                    "request_id": new_req.id,
                })
            except Exception:
                pass
    
    return MLPlateDetectionResponse(
        status="received",
        message=f"Plate '{request.detected_plate}' stored for gate {request.gate_id}{msg_suffix}",
        gate_id=request.gate_id,
    )


# ═══════════════════════════════════════════════════════════════════
#  ENDPOINT 2: Dual Validation (RFID + ML)  ★ ENDPOINT UTAMA ★
#  Dipanggil oleh ESP32 setelah tap RFID
# ═══════════════════════════════════════════════════════════════════

@router.post("/dual-validate", response_model=DualValidationResponse)
async def dual_validation_gate(
    request: DualValidationRequest,
    db: Session = Depends(get_db)
):
    """
    Endpoint untuk device/gateway yang sudah punya hasil deteksi plat.
    """
    return await _run_dual_validation(request, db)


@router.post("/capture-validate", response_model=DualValidationResponse)
async def capture_and_validate_gate(
    request: CaptureValidationRequest,
    db: Session = Depends(get_db),
):
    """
    Endpoint untuk ESP32/gate controller ketika plat belum tersedia.

    Alur:
    1. ESP32 kirim RFID + gate_type ke backend.
    2. Jika ada monitor browser aktif, backend men-trigger monitor untuk memotret webcam.
    3. Jika tidak ada / timeout, fallback ke ANPR service mengambil frame IP camera.
    4. Backend menjalankan validasi ganda memakai RFID + hasil ANPR.
    """
    if request.gate_type not in ["masuk", "keluar"]:
        raise HTTPException(status_code=400, detail="gate_type harus 'masuk' atau 'keluar'")

    # Cek jika ada browser (dashboard petugas) yang sedang aktif terhubung lewat websocket
    if manager.active_connections:
        rfid = request.rfid_uid
        event = asyncio.Event()
        _pending_captures[rfid] = event
        
        logger.info(f"[FE-Capture] Meminta capture dari browser untuk RFID {rfid}...")
        
        # Kirim trigger ke frontend untuk mengambil gambar
        await manager.broadcast({
            "type": "trigger_capture",
            "rfid_uid": rfid,
            "gate_id": request.gate_id or "GATE_ESP8266",
            "gate_type": request.gate_type,
        })
        
        # Tunggu respon upload dari browser (maksimal 15 detik)
        try:
            await asyncio.wait_for(event.wait(), timeout=15.0)
            result = _capture_results.pop(rfid, None)
            if result:
                logger.info(f"[FE-Capture] Berhasil memproses capture browser untuk RFID {rfid}")
                return result
        except asyncio.TimeoutError:
            logger.warning(f"[FE-Capture] Timeout menunggu capture browser untuk RFID {rfid}")
        finally:
            _pending_captures.pop(rfid, None)

    # Fallback ke alur standard RTSP jika tidak ada monitor browser aktif atau terjadi timeout
    # Dapatkan fallback plate dinonaktifkan agar sistem selalu melakukan pemindaian plat riil via kamera/webcam
    fallback_plate = None

    try:
        scan = await _request_anpr_scan(
            gate_id=request.gate_id or "GATE_DEFAULT",
            camera_url=request.camera_url,
            fallback_plate=fallback_plate,
        )
    except HTTPException as exc:
        await manager.broadcast({
            "type": "error",
            "message": f"ANPR gagal membaca kamera: {exc.detail}",
            "rfid": request.rfid_uid,
            "gate": request.gate_id,
        })
        return DualValidationResponse(
            action="keep_closed",
            message="ANPR service gagal membaca plat",
            validation_detail=str(exc.detail),
        )

    dual_request = DualValidationRequest(
        rfid_uid=request.rfid_uid,
        detected_plate=scan.detected_plate,
        ml_confidence=scan.confidence,
        gate_type=request.gate_type,
        gate_id=scan.gate_id,
    )
    return await _run_dual_validation(dual_request, db, image_path=scan.image_path)


@router.post("/upload-capture-response")
async def upload_capture_response(
    rfid_uid: str = Form(..., description="UID kartu RFID"),
    gate_type: str = Form(..., description="'masuk' atau 'keluar'"),
    gate_id: str = Form("GATE_DEFAULT", description="ID gerbang"),
    file: UploadFile = File(..., description="Foto hasil capture browser"),
    db: Session = Depends(get_db)
):
    """
    Endpoint yang dipanggil oleh browser (dashboard petugas) untuk mengirimkan
    foto webcam hasil trigger otomatis dari tap RFID.
    """
    content = await file.read()
    logger.warning(f"[FE-Capture] MENERIMA FOTO dari browser untuk RFID: {rfid_uid}, Nama File: {file.filename}, Ukuran: {len(content)} bytes")
    
    # 1. Kirim file foto ke ML Service via predict-image
    ml_url = f"{settings.ANPR_SERVICE_URL.rstrip('/')}/api/predict-image"
    detected_plate = ""
    confidence = 0.0
    image_path = None
    
    try:
        async with httpx.AsyncClient(timeout=settings.ANPR_SCAN_TIMEOUT_SECONDS) as client:
            files = {"file": (file.filename, content, file.content_type or "image/jpeg")}
            data = {"gate_id": gate_id}
            response = await client.post(ml_url, files=files, data=data)
            if response.status_code == 200:
                res_data = response.json()
                detected_plate = res_data.get("detected_plate", "")
                confidence = res_data.get("confidence", 0.0)
                image_path = res_data.get("image_path", "")
    except Exception as e:
        logger.error(f"[FE-Capture] ML Prediction failed: {e}")
        
    logger.warning(f"[FE-Capture] Hasil ML untuk RFID {rfid_uid}: Plat='{detected_plate}', Conf={confidence}, ImagePath='{image_path}'")
        
    # 2. Jalankan validasi ganda
    dual_request = DualValidationRequest(
        rfid_uid=rfid_uid,
        detected_plate=detected_plate,
        ml_confidence=confidence,
        gate_type=gate_type,
        gate_id=gate_id,
    )
    result = await _run_dual_validation(dual_request, db, image_path=image_path)
    
    # 3. Notifikasi event agar thread /capture-validate yang sedang menunggu bisa terbangun
    if rfid_uid in _pending_captures:
        _capture_results[rfid_uid] = result
        _pending_captures[rfid_uid].set()
        
    return {"status": "success", "message": "Captured response validation complete"}


@router.post("/upload-validate", response_model=DualValidationResponse)
async def upload_and_validate_gate(
    rfid_uid: str = Form(..., description="UID kartu RFID yang di-tap"),
    gate_type: str = Form(..., description="'masuk' atau 'keluar'"),
    gate_id: str = Form("GATE_DEFAULT", description="ID gerbang fisik"),
    file: UploadFile = File(..., description="Foto dari ESP32-CAM"),
    db: Session = Depends(get_db)
):
    """
    Endpoint untuk ESP32-CAM mengirim RFID UID dan foto yang ditangkap secara bersamaan.
    
    Alur:
    1. Simpan foto yang diupload ke folder uploads/scans/.
    2. Kirim foto ke ML Service via POST multipart file.
    3. Jalankan alur validasi ganda menggunakan RFID + hasil ML.
    """
    if gate_type not in ["masuk", "keluar"]:
        raise HTTPException(status_code=400, detail="gate_type harus 'masuk' atau 'keluar'")
        
    # 1. Simpan foto
    uploads_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "uploads")
    scans_dir = os.path.join(uploads_dir, "scans")
    os.makedirs(scans_dir, exist_ok=True)
    
    timestamp_str = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    clean_gate_id = "".join([c for c in gate_id if c.isalnum() or c in ["_", "-"]])
    filename = f"{clean_gate_id}_{timestamp_str}.jpg"
    file_path = os.path.join(scans_dir, filename)
    relative_path = f"/uploads/scans/{filename}"
    
    try:
        content = await file.read()
        with open(file_path, "wb") as buffer:
            buffer.write(content)
    except Exception as e:
        logger.error(f"Gagal menyimpan foto upload ESP32-CAM: {e}")
        raise HTTPException(status_code=500, detail="Gagal menyimpan foto di backend")
        
    # 2. Kirim ke ML Service untuk scan plat
    ml_url = f"{settings.ANPR_SERVICE_URL.rstrip('/')}/api/predict-image"
    try:
        async with httpx.AsyncClient(timeout=settings.ANPR_SCAN_TIMEOUT_SECONDS) as client:
            files = {"file": (filename, content, "image/jpeg")}
            data = {"gate_id": gate_id}
            response = await client.post(ml_url, files=files, data=data)
            response.raise_for_status()
            ml_result = response.json()
    except httpx.HTTPStatusError as exc:
        detail = exc.response.text[:300] if exc.response is not None else str(exc)
        logger.error(f"[ANPR] ML Service error for upload: {detail}")
        await manager.broadcast({
            "type": "error",
            "message": f"ML Service error saat membaca plat dari foto: {detail}",
            "rfid": rfid_uid,
            "gate": gate_id,
            "image_path": relative_path,
        })
        return DualValidationResponse(
            action="keep_closed",
            message="ML service gagal membaca plat",
            validation_detail=detail,
        )
    except (httpx.TimeoutException, httpx.RequestError) as exc:
        logger.error(f"[ANPR] ML Service unavailable: {exc}")
        await manager.broadcast({
            "type": "error",
            "message": "ML Service tidak merespons",
            "rfid": rfid_uid,
            "gate": gate_id,
            "image_path": relative_path,
        })
        return DualValidationResponse(
            action="keep_closed",
            message="ML service tidak bisa dihubungi",
            validation_detail=str(exc),
        )
        
    # 3. Jalankan alur validasi ganda
    detected_plate = ml_result.get("detected_plate", "")
    confidence = ml_result.get("confidence", 0.0)
    
    dual_request = DualValidationRequest(
        rfid_uid=rfid_uid,
        detected_plate=detected_plate,
        ml_confidence=confidence,
        gate_type=gate_type,
        gate_id=gate_id
    )
    
    result = await _run_dual_validation(dual_request, db, image_path=relative_path)
    if result.action == "open_gate" and gate_id != "GATE_ESP8266":
        from core.firebase import trigger_physical_servo
        await trigger_physical_servo(gate_id)
    return result


async def _request_anpr_scan(
    gate_id: str, 
    camera_url: str | None = None,
    fallback_plate: str | None = None
) -> ANPRScanResponse:
    """Call the separated ANPR service and normalize connection errors."""
    base_url = settings.ANPR_SERVICE_URL.rstrip("/")
    payload = {"gate_id": gate_id}
    if camera_url:
        payload["camera_url"] = camera_url
    if fallback_plate:
        payload["fallback_plate"] = fallback_plate

    try:
        async with httpx.AsyncClient(timeout=settings.ANPR_SCAN_TIMEOUT_SECONDS) as client:
            response = await client.post(f"{base_url}/api/scan-plate", json=payload)
            response.raise_for_status()
            return ANPRScanResponse(**response.json())
    except httpx.HTTPStatusError as exc:
        detail = exc.response.text[:300] if exc.response is not None else str(exc)
        logger.error("[ANPR] Service returned error for %s: %s", gate_id, detail)
        raise HTTPException(
            status_code=502,
            detail=f"ANPR service error saat scan gate {gate_id}",
        ) from exc
    except (httpx.TimeoutException, httpx.RequestError) as exc:
        logger.error("[ANPR] Service unavailable for %s: %s", gate_id, exc)
        raise HTTPException(
            status_code=503,
            detail=f"ANPR service tidak bisa diakses untuk gate {gate_id}",
        ) from exc


async def _run_dual_validation(
    request: DualValidationRequest,
    db: Session,
    image_path: str = None,
) -> DualValidationResponse:
    """
    ★ ENDPOINT VALIDASI GANDA ★
    
    Endpoint utama yang menjalankan alur validasi ganda:
    
    STEP 1 — Cek RFID di Database
        Cari user berdasarkan rfid_uid → ambil data mahasiswa & kendaraan terdaftar
        
    STEP 2 — Normalisasi Plat Nomor  
        DB:  "G 5090 DB" → "G5090DB"
        ML:  "g-5090-db" → "G5090DB"
        
    STEP 3 — Pencocokan (Match)
        Bandingkan normalized plate DB == normalized plate ML
        
    STEP 4 — Eksekusi
        Cocok  → open_gate + catat log masuk/keluar
        Gagal  → keep_closed + buzzer
    """
    
    # ─── STEP 1: Cek RFID di Database ───
    user = (
        db.query(models.User)
        .filter(models.User.rfid_uid == request.rfid_uid)
        .first()
    )
    
    if not user:
        # RFID tidak terdaftar
        await manager.broadcast({
            "type": "error",
            "message": "❌ Kartu RFID tidak terdaftar dalam sistem.",
            "rfid": request.rfid_uid,
            "plate": request.detected_plate,
            "gate": request.gate_id,
            "image_path": image_path,
        })
        logger.warning(f"[GATE] Unregistered RFID: {request.rfid_uid}")
        return DualValidationResponse(
            action="keep_closed",
            message="RFID tidak terdaftar",
            validation_detail="UID kartu tidak ditemukan di database"
        )
    
    # Cek apakah user di-flag (blacklisted)
    if user.is_flagged:
        await manager.broadcast({
            "type": "error",
            "message": f"⚠️ Mahasiswa {user.nama} di-FLAG: {user.flag_reason}",
            "rfid": request.rfid_uid,
            "plate": request.detected_plate,
            "user": user.nama,
            "image_path": image_path,
        })
        return DualValidationResponse(
            action="keep_closed",
            message=f"Akses ditolak — akun di-flag: {user.flag_reason}",
            student_name=user.nama,
            validation_detail="User flagged/blacklisted"
        )
    
    # ─── STEP 2 & 3: Normalisasi + Pencocokan Plat ───
    # Ambil hanya kendaraan yang sudah disetujui (status_validasi == disetujui)
    approved_vehicles = [
        v for v in user.vehicles
        if v.status_validasi == models.ValidationStatusEnum.disetujui
    ]
    
    if not approved_vehicles:
        await manager.broadcast({
            "type": "error",
            "message": f"Mahasiswa {user.nama}: belum ada kendaraan yang disetujui.",
            "user": user.nama,
            "plate": request.detected_plate,
            "image_path": image_path,
        })
        return DualValidationResponse(
            action="keep_closed",
            message="Tidak ada kendaraan tervalidasi untuk user ini",
            student_name=user.nama,
            validation_detail="Semua kendaraan masih pending/ditolak"
        )
    
    # Gunakan find_matching_vehicle dengan normalisasi string
    target_vehicle = find_matching_vehicle(approved_vehicles, request.detected_plate)
    
    if not target_vehicle:
        # Log detail pencocokan untuk debugging
        db_plates = [v.plat_nomor for v in approved_vehicles]
        norm_db = [normalize_plate(p) for p in db_plates]
        norm_ml = normalize_plate(request.detected_plate)
        
        validation_result = validate_plate_match(
            plate_from_db=approved_vehicles[0].plat_nomor,
            plate_from_ml=request.detected_plate,
            confidence=request.ml_confidence,
        )
        
        await manager.broadcast({
            "type": "error",
            "message": (
                f"❌ Validasi Ganda GAGAL — {user.nama}\n"
                f"  Plat DB: {db_plates} (norm: {norm_db})\n"
                f"  Plat ML: '{request.detected_plate}' (norm: '{norm_ml}')\n"
                f"  Confidence: {request.ml_confidence:.2f}"
            ),
            "user": user.nama,
            "plate": request.detected_plate,
            "image_path": image_path,
        })
        
        logger.warning(
            f"[GATE] Plate mismatch for {user.nama}: "
            f"DB={norm_db}, ML='{norm_ml}', conf={request.ml_confidence}"
        )
        
        return DualValidationResponse(
            action="keep_closed",
            message="Plat nomor tidak cocok dengan data terdaftar",
            student_name=user.nama,
            plate_number=request.detected_plate,
            validation_detail=validation_result["reason"]
        )
    
    # ─── Cek confidence ML ───
    if request.ml_confidence < 0.70:
        await manager.broadcast({
            "type": "error",
            "message": (
                f"⚠️ Confidence ML rendah ({request.ml_confidence:.0%}) "
                f"untuk {user.nama} — butuh verifikasi manual"
            ),
            "user": user.nama,
            "plate": request.detected_plate,
            "image_path": image_path,
        })
        return DualValidationResponse(
            action="keep_closed",
            message=f"Confidence ML terlalu rendah: {request.ml_confidence:.0%}",
            student_name=user.nama,
            plate_number=target_vehicle.plat_nomor,
            validation_detail=f"ML confidence {request.ml_confidence:.2f} < 0.70 threshold"
        )
    
    # ─── STEP 4: Validasi Berhasil → Log & Buka Gerbang ───
    
    # Tentukan jenis aktivitas (masuk/keluar)
    gate_type = request.gate_type
    if gate_type not in ["masuk", "keluar"]:
        raise HTTPException(status_code=400, detail="gate_type harus 'masuk' atau 'keluar'")
    
    # Cek duplikasi: jika gate_type masuk, pastikan user belum di dalam
    # Jika gate_type keluar, pastikan user sudah di dalam
    last_log = (
        db.query(models.ParkingLog)
        .filter(
            models.ParkingLog.user_id == user.id,
        )
        .order_by(models.ParkingLog.waktu.desc())
        .first()
    )
    
    if last_log:
        if gate_type == "masuk" and last_log.jenis_aktivitas == models.ActivityTypeEnum.masuk:
            await manager.broadcast({
                "type": "error",
                "message": f"⚠️ Duplikasi Entry — {user.nama} sudah tercatat di dalam area parkir.",
                "user": user.nama,
                "plate": target_vehicle.plat_nomor,
                "image_path": image_path,
            })
            return DualValidationResponse(
                action="keep_closed",
                message="Mahasiswa sudah tercatat di dalam area parkir",
                student_name=user.nama,
                plate_number=target_vehicle.plat_nomor,
                validation_detail="Duplikasi entry — belum ada log keluar"
            )
        elif gate_type == "keluar" and last_log.jenis_aktivitas == models.ActivityTypeEnum.keluar:
            await manager.broadcast({
                "type": "error",
                "message": f"⚠️ Duplikasi Exit — {user.nama} sudah tercatat keluar dari area parkir.",
                "user": user.nama,
                "plate": target_vehicle.plat_nomor,
                "image_path": image_path,
            })
            return DualValidationResponse(
                action="keep_closed",
                message="Mahasiswa sudah tercatat keluar dari area parkir",
                student_name=user.nama,
                plate_number=target_vehicle.plat_nomor,
                validation_detail="Duplikasi exit — belum ada log masuk"
            )
    
    # Buat log parkir
    log = models.ParkingLog(
        user_id=user.id,
        vehicle_id=target_vehicle.id,
        jenis_aktivitas=gate_type,
        status_akses=models.AccessStatusEnum.otomatis,
    )
    db.add(log)
    db.commit()
    db.refresh(log)
    
    # Broadcast ke Live Monitor (Petugas Dashboard)
    validation_detail = validate_plate_match(
        target_vehicle.plat_nomor,
        request.detected_plate,
        request.ml_confidence,
    )
    
    action_label = "MASUK" if gate_type == "masuk" else "KELUAR"
    await manager.broadcast({
        "type": "success",
        "message": (
            f"✅ Validasi Ganda BERHASIL — {action_label}\n"
            f"  Mahasiswa: {user.nama}\n"
            f"  Plat: {target_vehicle.plat_nomor}\n"
            f"  Confidence ML: {request.ml_confidence:.0%}"
        ),
        "user": user.nama,
        "plate": target_vehicle.plat_nomor,
        "time": to_jakarta_time(log.waktu).isoformat(),
        "gate": request.gate_id,
        "image_path": image_path,
    })
    
    logger.info(
        f"[GATE] ✅ {action_label} validated for {user.nama} "
        f"plate={target_vehicle.plat_nomor} gate={request.gate_id}"
    )
    
    return DualValidationResponse(
        action="open_gate",
        message=f"Akses {gate_type} diizinkan",
        student_name=user.nama,
        plate_number=target_vehicle.plat_nomor,
        validation_detail=validation_detail["reason"]
    )


# ═══════════════════════════════════════════════════════════════════
#  ENDPOINT LEGACY: /scan (backward compatible dengan IoT simulator lama)
# ═══════════════════════════════════════════════════════════════════

@router.post("/scan", response_model=GateScanResponse)
async def process_gate_scan(scan: GateScanRequest, db: Session = Depends(get_db)):
    """
    Legacy endpoint — kompatibel dengan iot_simulator.py yang sudah ada.
    Internally redirects to dual validation logic.
    """
    # 1. Find User by RFID tag read
    user = db.query(models.User).filter(models.User.rfid_uid == scan.rfid_uid).first()
    
    if not user:
        await manager.broadcast({
            "type": "error",
            "message": "Unregistered RFID card scanned.",
            "rfid": scan.rfid_uid,
            "plate": scan.plat_nomor_ml
        })
        return {"action": "keep_closed", "message": "RFID not found"}
    
    # 2. Check if scanned plate matches an APPROVED vehicle (WITH normalization)
    approved_vehicles = [
        v for v in user.vehicles
        if v.status_validasi == models.ValidationStatusEnum.disetujui
    ]
    
    target_vehicle = find_matching_vehicle(approved_vehicles, scan.plat_nomor_ml)
            
    if not target_vehicle:
        await manager.broadcast({
            "type": "error",
            "message": f"Kendaraan {scan.plat_nomor_ml} tidak sesuai atau belum disetujui.",
            "user": user.nama,
            "plate": scan.plat_nomor_ml
        })
        return {"action": "keep_closed", "message": "Vehicle not approved or mismatch"}
        
    # 3. Validated: Create Parking Log entry
    log = models.ParkingLog(
        user_id=user.id,
        vehicle_id=target_vehicle.id,
        jenis_aktivitas=scan.gate_type,
        status_akses=models.AccessStatusEnum.otomatis
    )
    db.add(log)
    db.commit()
    db.refresh(log)
    
    # 4. Broadcast success log to the Live Monitor Socket for petugas dashboard
    await manager.broadcast({
        "type": "success",
        "message": f"Akses {scan.gate_type} diizinkan otomatis.",
        "user": user.nama,
        "plate": target_vehicle.plat_nomor,
        "time": to_jakarta_time(log.waktu).isoformat()
    })
    
    return {"action": "open_gate", "message": "Access granted"}


@router.post("/register-tap")
async def register_tap(rfid_uid: str, gate_id: str = "GATE_MASUK_1", db: Session = Depends(get_db)):
    """
    Endpoint untuk mendaftarkan kartu RFID baru.
    Menerima tap dari ESP8266 (Mode 4x click), mem-broadcast ke Live Monitor,
    dan menyimpan UID kartu ke Firebase Realtime Database agar bisa dibaca oleh UI Admin.
    """
    # Broadcast ke WebSocket Live Monitor
    await manager.broadcast({
        "type": "rfid_register",
        "rfid_uid": rfid_uid,
        "message": f"Kartu RFID {rfid_uid} terdeteksi dan siap didaftarkan"
    })
    
    # Simpan ke Firebase Realtime Database
    if settings.FIREBASE_DB_URL:
        url = f"{settings.FIREBASE_DB_URL.rstrip('/')}/gates/{gate_id}/last_scanned_rfid.json"
        params = {}
        if settings.FIREBASE_DB_SECRET:
            params["auth"] = settings.FIREBASE_DB_SECRET
        try:
            async with httpx.AsyncClient() as client:
                await client.put(url, params=params, json=rfid_uid, timeout=5)
        except Exception as e:
            logger.error(f"Error writing last scanned RFID to Firebase: {e}")
            
    return {"status": "success", "rfid_uid": rfid_uid}


# ═══════════════════════════════════════════════════════════════════
#  ENDPOINT: Emergency Gate Override (Petugas Manual)
# ═══════════════════════════════════════════════════════════════════

@router.post("/emergency-action")
async def emergency_gate_action(
    gate: str, 
    reason: str, 
    nama: str = None, 
    kendaraan: str = None, 
    guest_id: int = None,
    db: Session = Depends(get_db), 
    current_user: models.User = Depends(get_petugas)
):
    """Petugas manual override to open gate in emergency."""
    if gate not in ["masuk", "keluar"]:
        raise HTTPException(status_code=400, detail="Gate must be 'masuk' or 'keluar'")
        
    display_name = current_user.nama
    display_plate = "MANUAL"
    is_registered_student = False

    # Check if this is a registered student's vehicle
    if kendaraan:
        normalized_input = normalize_plate(kendaraan)
        # Search all vehicles (including pending/ditolak)
        vehicles = db.query(models.Vehicle).all()
        for v in vehicles:
            if normalize_plate(v.plat_nomor) == normalized_input:
                registered_vehicle = v
                registered_user = v.user
                
                # Automatically approve the vehicle if it's not approved yet
                if registered_vehicle.status_validasi != models.ValidationStatusEnum.disetujui:
                    registered_vehicle.status_validasi = models.ValidationStatusEnum.disetujui
                
                # Auto-approve any pending AccessRequest for this user
                pending_reqs = db.query(models.AccessRequest).filter(
                    models.AccessRequest.user_id == registered_user.id,
                    models.AccessRequest.status == models.AccessRequestStatusEnum.pending
                ).all()
                for pr in pending_reqs:
                    pr.status = models.AccessRequestStatusEnum.disetujui
                    pr.waktu_respon = datetime.now(timezone.utc)
                    pr.catatan = "Disetujui otomatis melalui Emergency Gate"
                
                # Create log under the student's ID
                new_log = models.ParkingLog(
                    user_id=registered_user.id,
                    vehicle_id=registered_vehicle.id,
                    jenis_aktivitas=gate,
                    status_akses=models.AccessStatusEnum.darurat
                )
                db.add(new_log)
                db.commit()
                
                display_name = registered_user.nama
                display_plate = registered_vehicle.plat_nomor
                is_registered_student = True
                break

    if not is_registered_student:
        guest_id_to_log = None
        if gate == "masuk":
            if not nama or not kendaraan:
                raise HTTPException(status_code=400, detail="Nama dan kendaraan wajib diisi untuk gate masuk")
                
            guest = models.EmergencyGuest(
                nama=nama,
                plat_nomor=kendaraan,
                alasan=reason,
                petugas_masuk_id=current_user.id
            )
            db.add(guest)
            db.commit()
            db.refresh(guest)
            display_name = guest.nama
            display_plate = guest.plat_nomor
            guest_id_to_log = guest.id
            
        elif gate == "keluar":
            if guest_id:
                guest = db.query(models.EmergencyGuest).filter(
                    models.EmergencyGuest.id == guest_id,
                    models.EmergencyGuest.status == "di_dalam"
                ).first()
                
                if guest:
                    guest.waktu_keluar = datetime.now(timezone.utc)
                    guest.petugas_keluar_id = current_user.id
                    guest.status = "sudah_keluar"
                    db.commit()
                    display_name = guest.nama
                    display_plate = guest.plat_nomor
                    guest_id_to_log = guest.id
                else:
                    display_name = "Guest Not Found"
            else:
                # Manual exit without guest_id
                if not nama or not kendaraan:
                    raise HTTPException(status_code=400, detail="Nama dan kendaraan wajib diisi jika tidak memilih tamu dari daftar")
                
                # Find if there is an active guest with this plate
                normalized_plate_input = normalize_plate(kendaraan)
                active_guests = db.query(models.EmergencyGuest).filter(
                    models.EmergencyGuest.status == "di_dalam"
                ).all()
                
                found_guest = None
                for g in active_guests:
                    if normalize_plate(g.plat_nomor) == normalized_plate_input:
                        found_guest = g
                        break
                
                if found_guest:
                    found_guest.waktu_keluar = datetime.now(timezone.utc)
                    found_guest.petugas_keluar_id = current_user.id
                    found_guest.status = "sudah_keluar"
                    db.commit()
                    display_name = found_guest.nama
                    display_plate = found_guest.plat_nomor
                    guest_id_to_log = found_guest.id
                else:
                    # Create a new EmergencyGuest checked out immediately
                    new_guest = models.EmergencyGuest(
                        nama=nama,
                        plat_nomor=kendaraan,
                        alasan=reason,
                        petugas_masuk_id=current_user.id,
                        petugas_keluar_id=current_user.id,
                        waktu_keluar=datetime.now(timezone.utc),
                        status="sudah_keluar"
                    )
                    db.add(new_guest)
                    db.commit()
                    db.refresh(new_guest)
                    display_name = new_guest.nama
                    display_plate = new_guest.plat_nomor
                    guest_id_to_log = new_guest.id

        # Log it as manual_petugas activity (for non-registered users, linking the guest)
        new_log = models.ParkingLog(
            user_id=current_user.id,
            vehicle_id=1,  # Dummy vehicle ID
            emergency_guest_id=guest_id_to_log,
            jenis_aktivitas=gate,
            status_akses=models.AccessStatusEnum.darurat
        )
        db.add(new_log)
        db.commit()
    
    # Broadcast to live monitor so it shows up in logs
    await manager.broadcast({
        "type": "error", # Highlight as yellow/warning in UI
        "message": f"🚨 EMERGENCY OVERRIDE ({gate.upper()})",
        "user": display_name,
        "plate": display_plate,
        "remark": reason
    })

    # Trigger physical servo via Firebase Realtime Database
    from core.firebase import trigger_physical_servo
    gate_id = "GATE_MASUK_1" if gate == "masuk" else "GATE_KELUAR_1"
    await trigger_physical_servo(gate_id)
    
    return {"status": "success", "message": f"Gate {gate} dibuka manual untuk {display_name}"}


@router.get("/emergency-guests")
def get_emergency_guests(db: Session = Depends(get_db), current_user: models.User = Depends(get_petugas)):
    """Mendapatkan daftar tamu darurat yang masih di dalam."""
    guests = db.query(models.EmergencyGuest).filter(models.EmergencyGuest.status == "di_dalam").all()
    return [
        {
            "id": g.id,
            "nama": g.nama,
            "plat_nomor": g.plat_nomor,
            "alasan": g.alasan,
            "waktu_masuk": to_jakarta_time(g.waktu_masuk).isoformat()
        } for g in guests
    ]


@router.post("/scan-emergency-plate")
async def scan_emergency_plate(
    gate_type: str = Form(...),
    camera_url: str = Form(None),
    file: UploadFile = File(None),
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_petugas)
):
    """
    Triggers an ANPR scan on the camera or processes an uploaded photo for the emergency gate,
    and returns the scanned plate and the previous name associated with that plate.
    """
    if gate_type not in ["masuk", "keluar"]:
        raise HTTPException(status_code=400, detail="gate_type must be 'masuk' or 'keluar'")

    gate_id = f"GATE_{gate_type.upper()}_EMERGENCY"
    detected_plate = ""

    if file is not None:
        try:
            content = await file.read()
            # Send file to ML Service via POST multipart file to /api/predict-image
            ml_url = f"{settings.ANPR_SERVICE_URL.rstrip('/')}/api/predict-image"
            async with httpx.AsyncClient(timeout=settings.ANPR_SCAN_TIMEOUT_SECONDS) as client:
                files = {"file": (file.filename, content, file.content_type or "image/jpeg")}
                data = {"gate_id": gate_id}
                response = await client.post(ml_url, files=files, data=data)
                response.raise_for_status()
                ml_result = response.json()
                detected_plate = ml_result.get("detected_plate", "")
        except Exception as e:
            logger.error(f"Error scanning emergency plate from uploaded file: {e}")
            detected_plate = ""
    else:
        try:
            scan = await _request_anpr_scan(
                gate_id=gate_id,
                camera_url=camera_url,
            )
            detected_plate = scan.detected_plate or ""
        except Exception as e:
            logger.error(f"Error scanning emergency plate: {e}")
            detected_plate = ""

    previous_name = ""
    if detected_plate:
        normalized_detected = normalize_plate(detected_plate)
        # Find latest emergency guest with this plate
        recent_guests = db.query(models.EmergencyGuest).order_by(models.EmergencyGuest.id.desc()).all()
        for g in recent_guests:
            if normalize_plate(g.plat_nomor) == normalized_detected:
                previous_name = g.nama
                break

    return {
        "status": "success",
        "detected_plate": detected_plate,
        "previous_name": previous_name
    }


@router.get("/emergency-guest-lookup")
def lookup_emergency_guest(
    plate: str,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_petugas)
):
    """
    Looks up the previous guest name associated with the provided plate number.
    """
    if not plate:
        return {"status": "success", "previous_name": ""}

    normalized_detected = normalize_plate(plate)
    previous_name = ""
    recent_guests = db.query(models.EmergencyGuest).order_by(models.EmergencyGuest.id.desc()).all()
    for g in recent_guests:
        if normalize_plate(g.plat_nomor) == normalized_detected:
            previous_name = g.nama
            break

    return {
        "status": "success",
        "previous_name": previous_name
    }


# ═══════════════════════════════════════════════════════════════════
#  ENDPOINT: Parking Capacity Stats
# ═══════════════════════════════════════════════════════════════════

@router.get("/stats/capacity")
def get_parking_capacity(db: Session = Depends(get_db)):
    """Calculate current parking occupancy."""
    total_capacity = 100 # Default
    
    # Simple occupancy: Entered - Exited
    entered = db.query(models.ParkingLog).filter(models.ParkingLog.jenis_aktivitas == models.ActivityTypeEnum.masuk).count()
    exited = db.query(models.ParkingLog).filter(models.ParkingLog.jenis_aktivitas == models.ActivityTypeEnum.keluar).count()
    
    parked_count = max(0, entered - exited)
    
    return {
        "total": total_capacity,
        "parked": parked_count,
        "available": max(0, total_capacity - parked_count)
    }


# ═══════════════════════════════════════════════════════════════════
#  ENDPOINT: RTSP to MJPEG Stream Proxy
# ═══════════════════════════════════════════════════════════════════
from fastapi.responses import StreamingResponse

@router.get("/camera-stream")
def proxy_camera_stream(camera_url: str):
    """
    Proxy & Transcode RTSP stream dari IP Cam menjadi MJPEG agar bisa dirender di Web.
    """
    import cv2
    import time

    def generate_frames():
        cap = cv2.VideoCapture(camera_url)
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

        while True:
            success, frame = cap.read()
            if not success:
                time.sleep(1)
                cap = cv2.VideoCapture(camera_url)
                continue
            
            # Compress to JPEG with 80% quality
            ret, buffer = cv2.imencode('.jpg', frame, [int(cv2.IMWRITE_JPEG_QUALITY), 80])
            if not ret:
                continue

            frame_bytes = buffer.tobytes()
            yield (b'--frame\r\n'
                   b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')
            
            time.sleep(0.04)

    return StreamingResponse(
        generate_frames(), 
        media_type="multipart/x-mixed-replace; boundary=frame"
    )


# ═══════════════════════════════════════════════════════════════════
#  ENDPOINTS: Local HTTP Gate Trigger (Bypass Firebase for ESP8266)
# ═══════════════════════════════════════════════════════════════════

@router.get("/check-trigger")
async def check_gate_trigger():
    """
    Called by ESP8266 via fast HTTP GET polling to check if gate should be opened.
    Returns: {"trigger": 1} if remote manual open is requested, otherwise {"trigger": 0}
    """
    global local_servo_trigger
    return {"trigger": local_servo_trigger}


@router.post("/reset-trigger")
async def reset_gate_trigger(gate_id: str = "GATE_MASUK_1"):
    """
    Called by ESP8266 via HTTP POST after receiving a trigger to reset back to 0.
    """
    global local_servo_trigger
    local_servo_trigger = 0
    logger.info(f"[HTTP Trigger] Reset local_servo_trigger to 0 for {gate_id}")
    
    # Reset Firebase servo_trigger to 0
    from core.firebase import reset_physical_servo
    await reset_physical_servo(gate_id)
    
    return {"status": "success", "trigger": local_servo_trigger}