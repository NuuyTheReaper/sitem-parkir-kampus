import os
import uuid
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
from typing import List

import models
from schemas.vehicle import VehicleCreate, VehicleResponse
from core.security import get_mahasiswa
from database import get_db
from datetime import datetime, timezone

router = APIRouter(prefix="/api/mahasiswa", tags=["Mahasiswa"], dependencies=[Depends(get_mahasiswa)])

UPLOAD_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "uploads", "stnk")
os.makedirs(UPLOAD_DIR, exist_ok=True)

@router.get("/vehicles", response_model=List[VehicleResponse])
def get_my_vehicles(current_user: models.User = Depends(get_mahasiswa), db: Session = Depends(get_db)):
    return db.query(models.Vehicle).filter(models.Vehicle.user_id == current_user.id).all()

@router.post("/vehicles", response_model=VehicleResponse)
def register_vehicle(vehicle: VehicleCreate, current_user: models.User = Depends(get_mahasiswa), db: Session = Depends(get_db)):
    if db.query(models.Vehicle).filter(
        models.Vehicle.plat_nomor == vehicle.plat_nomor,
        models.Vehicle.user_id == current_user.id
    ).first():
        raise HTTPException(status_code=400, detail="Anda sudah mendaftarkan plat nomor ini")
        
    db_vehicle = models.Vehicle(
        **vehicle.dict(),
        user_id=current_user.id,
        status_validasi=models.ValidationStatusEnum.pending
    )
    db.add(db_vehicle)
    db.commit()
    db.refresh(db_vehicle)
    return db_vehicle

@router.post("/vehicles/{vehicle_id}/upload-stnk")
async def upload_stnk(vehicle_id: int, file: UploadFile = File(...), current_user: models.User = Depends(get_mahasiswa), db: Session = Depends(get_db)):
    """Upload foto STNK untuk verifikasi kendaraan."""
    vehicle = db.query(models.Vehicle).filter(
        models.Vehicle.id == vehicle_id,
        models.Vehicle.user_id == current_user.id
    ).first()
    if not vehicle:
        raise HTTPException(status_code=404, detail="Kendaraan tidak ditemukan")
    
    # Validate file type
    import mimetypes
    content_type = file.content_type
    if content_type == "application/octet-stream" and file.filename:
        guessed_type, _ = mimetypes.guess_type(file.filename)
        if guessed_type:
            content_type = guessed_type

    allowed_types = ["image/jpeg", "image/png", "image/webp"]
    if content_type not in allowed_types:
        raise HTTPException(status_code=400, detail="Format file harus JPG, PNG, atau WebP")
    
    # Save file
    ext = file.filename.split(".")[-1] if "." in file.filename else "jpg"
    filename = f"stnk_{vehicle_id}_{uuid.uuid4().hex[:8]}.{ext}"
    filepath = os.path.join(UPLOAD_DIR, filename)
    
    content = await file.read()
    with open(filepath, "wb") as f:
        f.write(content)
    
    # Update vehicle record
    vehicle.foto_stnk = f"/uploads/stnk/{filename}"
    db.commit()
    db.refresh(vehicle)
    
    return {"status": "success", "message": "Foto STNK berhasil diupload", "path": vehicle.foto_stnk}

@router.get("/status-parkir")
def get_parking_status(current_user: models.User = Depends(get_mahasiswa), db: Session = Depends(get_db)):
    last_log = db.query(models.ParkingLog).filter(
        models.ParkingLog.user_id == current_user.id
    ).order_by(models.ParkingLog.waktu.desc()).first()
    
    if not last_log:
        return {"status": "Tidak Sedang Parkir", "waktu_terakhir": None}
    
    status_str = "Sedang Parkir" if last_log.jenis_aktivitas == models.ActivityTypeEnum.masuk else "Di Luar Kampus"
    return {
        "status": status_str, 
        "waktu_terakhir": last_log.waktu,
        "is_flagged": bool(current_user.is_flagged),
        "flag_reason": current_user.flag_reason
    }

@router.post("/access-request")
async def create_access_request(action: str, current_user: models.User = Depends(get_mahasiswa), db: Session = Depends(get_db)):
    if action not in ["masuk", "keluar"]:
        raise HTTPException(status_code=400, detail="Invalid action")
    
    # Check for approved vehicle
    vehicle = db.query(models.Vehicle).filter(
        models.Vehicle.user_id == current_user.id,
        models.Vehicle.status_validasi == models.ValidationStatusEnum.disetujui
    ).first()
    
    if not vehicle:
        raise HTTPException(status_code=400, detail="Kamu belum memiliki kendaraan yang disetujui")

    # Check for existing pending request
    existing = db.query(models.AccessRequest).filter(
        models.AccessRequest.user_id == current_user.id,
        models.AccessRequest.status == models.AccessRequestStatusEnum.pending
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Masih ada permintaan yang belum diproses")

    new_request = models.AccessRequest(
        user_id=current_user.id,
        vehicle_id=vehicle.id,
        jenis_aktivitas=models.ActivityTypeEnum.masuk if action == "masuk" else models.ActivityTypeEnum.keluar,
    )
    db.add(new_request)
    db.commit()
    db.refresh(new_request)
    
    # ── Real-time WebSocket notification to petugas ──
    try:
        from routers.iot import petugas_notifier
        await petugas_notifier.notify_new_request({
            "user_nama": current_user.nama,
            "user_nim": current_user.nim_npp,
            "vehicle_plat": vehicle.plat_nomor,
            "vehicle_jenis": vehicle.jenis_kendaraan,
            "jenis_aktivitas": action,
            "request_id": new_request.id,
        })
    except Exception:
        pass  # Don't fail the request if WS broadcast fails
    
    return {"status": "success", "message": f"Permintaan {action} telah dikirim ke petugas", "request_id": new_request.id}

@router.get("/my-requests")
def get_my_requests(current_user: models.User = Depends(get_mahasiswa), db: Session = Depends(get_db)):
    requests = db.query(models.AccessRequest).filter(
        models.AccessRequest.user_id == current_user.id
    ).order_by(models.AccessRequest.waktu_request.desc()).limit(10).all()
    
    result = []
    for r in requests:
        result.append({
            "id": r.id,
            "jenis_aktivitas": r.jenis_aktivitas,
            "status": r.status,
            "waktu_request": r.waktu_request.isoformat() if r.waktu_request else None,
            "waktu_respon": r.waktu_respon.isoformat() if r.waktu_respon else None,
            "catatan": r.catatan,
        })
    return result

@router.get("/announcements")
def get_announcements(db: Session = Depends(get_db)):
    from sqlalchemy import or_
    now = datetime.now(timezone.utc)
    anns = db.query(models.Announcement).filter(
        or_(models.Announcement.expires_at == None, models.Announcement.expires_at > now)
    ).order_by(models.Announcement.created_at.desc()).limit(10).all()
    return [
        {
            "id": a.id,
            "message": a.message,
            "created_at": a.created_at,
            "sender": a.sender.nama
        }
        for a in anns
    ]

@router.get("/riwayat-parkir")
def get_parking_history(current_user: models.User = Depends(get_mahasiswa), db: Session = Depends(get_db)):
    logs = db.query(models.ParkingLog).filter(
        models.ParkingLog.user_id == current_user.id
    ).order_by(models.ParkingLog.waktu.desc()).limit(30).all()
    
    result = []
    for log in logs:
        vehicle = db.query(models.Vehicle).filter(models.Vehicle.id == log.vehicle_id).first()
        result.append({
            "id": log.id,
            "waktu": log.waktu.isoformat() if log.waktu else None,
            "jenis_aktivitas": log.jenis_aktivitas,
            "status_akses": log.status_akses,
            "plat_nomor": vehicle.plat_nomor if vehicle else "Unknown",
        })
    return result
