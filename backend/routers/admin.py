from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from typing import List
import io, csv

import models
from schemas.user import UserResponse, UserCreate, UserUpdate, ProdiResponse, ProdiCreate
from core.security import get_admin, get_password_hash
from database import get_db
from datetime import datetime, timedelta, timezone
from sqlalchemy import func

router = APIRouter(prefix="/api/admin", tags=["Admin"], dependencies=[Depends(get_admin)])

# ── Timer: Auto-expire pending requests older than 10 minutes ──
REQUEST_EXPIRE_MINUTES = 10

@router.post("/expire-old-requests")
def expire_old_requests(db: Session = Depends(get_db)):
    """Manually trigger expiration of old pending requests."""
    cutoff = datetime.now(timezone.utc) - timedelta(minutes=REQUEST_EXPIRE_MINUTES)
    old_requests = db.query(models.AccessRequest).filter(
        models.AccessRequest.status == models.AccessRequestStatusEnum.pending,
        models.AccessRequest.waktu_request < cutoff
    ).all()
    
    count = 0
    for req in old_requests:
        req.status = models.AccessRequestStatusEnum.ditolak
        req.waktu_respon = datetime.now(timezone.utc)
        req.catatan = f"Otomatis ditolak: tidak direspons dalam {REQUEST_EXPIRE_MINUTES} menit"
        count += 1
    
    db.commit()
    return {"status": "success", "expired_count": count}

@router.get("/mahasiswa", response_model=List[UserResponse])
def get_all_mahasiswa(db: Session = Depends(get_db)):
    return db.query(models.User).filter(models.User.role == models.RoleEnum.mahasiswa).all()

@router.post("/mahasiswa", response_model=UserResponse)
async def create_mahasiswa(user: UserCreate, db: Session = Depends(get_db)):
    if db.query(models.User).filter(models.User.nim_npp == user.nim_npp).first():
        raise HTTPException(status_code=400, detail="NIM already registered")
    if user.rfid_uid and db.query(models.User).filter(models.User.rfid_uid == user.rfid_uid).first():
        raise HTTPException(status_code=400, detail="RFID already registered")
        
    db_user = models.User(
        nim_npp=user.nim_npp,
        nama=user.nama,
        prodi_id=user.prodi_id,
        angkatan=user.angkatan,
        rfid_uid=user.rfid_uid,
        role=models.RoleEnum.mahasiswa,
        password_hash=get_password_hash(user.password)
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    try:
        from routers.iot import manager
        await manager.broadcast({"type": "update", "message": "mahasiswa_created"})
    except Exception:
        pass
    return db_user

@router.put("/mahasiswa/{user_id}", response_model=UserResponse)
async def update_mahasiswa(user_id: int, user_update: UserUpdate, db: Session = Depends(get_db)):
    db_user = db.query(models.User).filter(models.User.id == user_id, models.User.role == models.RoleEnum.mahasiswa).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="Mahasiswa not found")
    
    if user_update.nim_npp:
        if db.query(models.User).filter(models.User.nim_npp == user_update.nim_npp, models.User.id != user_id).first():
            raise HTTPException(status_code=400, detail="NIM already registered")
        db_user.nim_npp = user_update.nim_npp
    if user_update.nama: db_user.nama = user_update.nama
    if user_update.prodi_id is not None: db_user.prodi_id = user_update.prodi_id
    if user_update.angkatan is not None: db_user.angkatan = user_update.angkatan
    if user_update.rfid_uid:
        if db.query(models.User).filter(models.User.rfid_uid == user_update.rfid_uid, models.User.id != user_id).first():
            raise HTTPException(status_code=400, detail="RFID already registered")
        db_user.rfid_uid = user_update.rfid_uid
    if user_update.password: db_user.password_hash = get_password_hash(user_update.password)
    
    db.commit()
    db.refresh(db_user)
    try:
        from routers.iot import manager
        await manager.broadcast({"type": "update", "message": "mahasiswa_updated"})
    except Exception:
        pass
    return db_user

@router.delete("/mahasiswa/{user_id}")
async def delete_mahasiswa(user_id: int, db: Session = Depends(get_db)):
    db_user = db.query(models.User).filter(models.User.id == user_id, models.User.role == models.RoleEnum.mahasiswa).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="Mahasiswa not found")
    db.delete(db_user)
    db.commit()
    try:
        from routers.iot import manager
        await manager.broadcast({"type": "update", "message": "mahasiswa_deleted"})
    except Exception:
        pass
    return {"status": "success", "message": "Mahasiswa deleted"}

@router.get("/petugas", response_model=List[UserResponse])
def get_all_petugas(db: Session = Depends(get_db)):
    return db.query(models.User).filter(models.User.role == models.RoleEnum.petugas).all()

@router.post("/petugas", response_model=UserResponse)
async def create_petugas(user: UserCreate, db: Session = Depends(get_db)):
    if db.query(models.User).filter(models.User.nim_npp == user.nim_npp).first():
        raise HTTPException(status_code=400, detail="NPP already registered")
        
    db_user = models.User(
        nim_npp=user.nim_npp,
        nama=user.nama,
        role=models.RoleEnum.petugas,
        password_hash=get_password_hash(user.password)
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    try:
        from routers.iot import manager
        await manager.broadcast({"type": "update", "message": "petugas_created"})
    except Exception:
        pass
    return db_user

@router.put("/petugas/{user_id}", response_model=UserResponse)
async def update_petugas(user_id: int, user_update: UserUpdate, db: Session = Depends(get_db)):
    db_user = db.query(models.User).filter(models.User.id == user_id, models.User.role == models.RoleEnum.petugas).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="Petugas not found")
        
    if user_update.nim_npp:
        if db.query(models.User).filter(models.User.nim_npp == user_update.nim_npp, models.User.id != user_id).first():
            raise HTTPException(status_code=400, detail="NPP already registered")
        db_user.nim_npp = user_update.nim_npp
    if user_update.nama: db_user.nama = user_update.nama
    if user_update.password: db_user.password_hash = get_password_hash(user_update.password)
    
    db.commit()
    db.refresh(db_user)
    try:
        from routers.iot import manager
        await manager.broadcast({"type": "update", "message": "petugas_updated"})
    except Exception:
        pass
    return db_user

@router.delete("/petugas/{user_id}")
async def delete_petugas(user_id: int, db: Session = Depends(get_db)):
    db_user = db.query(models.User).filter(models.User.id == user_id, models.User.role == models.RoleEnum.petugas).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="Petugas not found")
    db.delete(db_user)
    db.commit()
    try:
        from routers.iot import manager
        await manager.broadcast({"type": "update", "message": "petugas_deleted"})
    except Exception:
        pass
    return {"status": "success", "message": "Petugas deleted"}

@router.get("/dashboard-stats")
def get_dashboard_stats(db: Session = Depends(get_db)):
    total_mahasiswa = db.query(models.User).filter(models.User.role == models.RoleEnum.mahasiswa).count()
    total_petugas = db.query(models.User).filter(models.User.role == models.RoleEnum.petugas).count()
    
    today = datetime.now(timezone.utc).date()
    masuk_today = db.query(models.ParkingLog).filter(
        func.date(models.ParkingLog.waktu) == today,
        models.ParkingLog.jenis_aktivitas == models.ActivityTypeEnum.masuk
    ).count()
    
    keluar_today = db.query(models.ParkingLog).filter(
        func.date(models.ParkingLog.waktu) == today,
        models.ParkingLog.jenis_aktivitas == models.ActivityTypeEnum.keluar
    ).count()
    
    return {
        "total_mahasiswa": total_mahasiswa,
        "total_petugas": total_petugas,
        "masuk_today": masuk_today,
        "keluar_today": keluar_today
    }

@router.get("/activity-chart")
def get_activity_chart(db: Session = Depends(get_db)):
    results = []
    for i in range(6, -1, -1):
        day = (datetime.now(timezone.utc) - timedelta(days=i)).date()
        in_count = db.query(models.ParkingLog).filter(
            func.date(models.ParkingLog.waktu) == day,
            models.ParkingLog.jenis_aktivitas == models.ActivityTypeEnum.masuk
        ).count()
        out_count = db.query(models.ParkingLog).filter(
            func.date(models.ParkingLog.waktu) == day,
            models.ParkingLog.jenis_aktivitas == models.ActivityTypeEnum.keluar
        ).count()
        results.append({
            "day": day.strftime("%a"),
            "masuk": in_count,
            "keluar": out_count
        })
    return results

# Prodi CRUD
@router.get("/prodi", response_model=List[ProdiResponse])
def get_all_prodi(db: Session = Depends(get_db)):
    return db.query(models.Prodi).all()

@router.post("/prodi", response_model=ProdiResponse)
async def create_prodi(prodi: ProdiCreate, db: Session = Depends(get_db)):
    db_prodi = models.Prodi(nama=prodi.nama)
    db.add(db_prodi)
    db.commit()
    db.refresh(db_prodi)
    try:
        from routers.iot import manager
        await manager.broadcast({"type": "update", "message": "prodi_created"})
    except Exception:
        pass
    return db_prodi

@router.delete("/prodi/{prodi_id}")
async def delete_prodi(prodi_id: int, db: Session = Depends(get_db)):
    db_prodi = db.query(models.Prodi).filter(models.Prodi.id == prodi_id).first()
    if not db_prodi:
        raise HTTPException(status_code=404, detail="Prodi not found")
    db.delete(db_prodi)
    db.commit()
    try:
        from routers.iot import manager
        await manager.broadcast({"type": "update", "message": "prodi_deleted"})
    except Exception:
        pass
    return {"status": "success"}

@router.get("/reports")
def get_parking_reports(db: Session = Depends(get_db)):
    logs = db.query(models.ParkingLog).order_by(models.ParkingLog.waktu.desc()).limit(200).all()
    result = []
    for log in logs:
        user = db.query(models.User).filter(models.User.id == log.user_id).first()
        vehicle = db.query(models.Vehicle).filter(models.Vehicle.id == log.vehicle_id).first()
        result.append({
            "id": log.id,
            "user_id": log.user_id,
            "user_nama": user.nama if user else "Unknown",
            "user_nim": user.nim_npp if user else "-",
            "vehicle_id": log.vehicle_id,
            "vehicle_plat": vehicle.plat_nomor if vehicle else "-",
            "vehicle_jenis": vehicle.jenis_kendaraan if vehicle else "-",
            "jenis_aktivitas": log.jenis_aktivitas,
            "status_akses": log.status_akses,
            "waktu": log.waktu.isoformat() if log.waktu else None,
        })
    return result

# ── Export Logs as CSV ──────────────────────────────────────
@router.get("/reports/export-csv")
def export_logs_csv(db: Session = Depends(get_db)):
    """Export all parking logs as a downloadable CSV file."""
    logs = db.query(models.ParkingLog).order_by(models.ParkingLog.waktu.desc()).limit(500).all()
    
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["No", "Nama", "NIM/NPP", "Plat Nomor", "Jenis Kendaraan", "Aktivitas", "Status Akses", "Waktu"])
    
    for idx, log in enumerate(logs, 1):
        user = db.query(models.User).filter(models.User.id == log.user_id).first()
        vehicle = db.query(models.Vehicle).filter(models.Vehicle.id == log.vehicle_id).first()
        writer.writerow([
            idx,
            user.nama if user else "Unknown",
            user.nim_npp if user else "-",
            vehicle.plat_nomor if vehicle else "-",
            vehicle.jenis_kendaraan if vehicle else "-",
            log.jenis_aktivitas,
            log.status_akses,
            log.waktu.strftime("%Y-%m-%d %H:%M:%S") if log.waktu else "-",
        ])
    
    output.seek(0)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    return StreamingResponse(
        io.BytesIO(output.getvalue().encode("utf-8")),
        media_type="text/csv",
        headers={"Content-Disposition": f"attachment; filename=parking_logs_{timestamp}.csv"}
    )

from pydantic import BaseModel
from typing import Optional

class BroadcastRequest(BaseModel):
    message: str
    expires_at: Optional[datetime] = None

@router.get("/announcements")
def get_announcements_admin(db: Session = Depends(get_db)):
    anns = db.query(models.Announcement).order_by(models.Announcement.created_at.desc()).all()
    return [
        {
            "id": a.id,
            "message": a.message,
            "created_at": a.created_at,
            "expires_at": a.expires_at,
            "sender": a.sender.nama if a.sender else "Unknown"
        }
        for a in anns
    ]

@router.post("/broadcast")
async def send_broadcast(req: BroadcastRequest, db: Session = Depends(get_db), current_user: models.User = Depends(get_admin)):
    """Send a broadcast announcement to all users."""
    from routers.iot import manager
    
    # Save to database
    announcement = models.Announcement(
        message=req.message,
        expires_at=req.expires_at,
        sender_id=current_user.id
    )
    db.add(announcement)
    db.commit()
    db.refresh(announcement)
    
    # Broadcast via WebSocket
    await manager.broadcast({
        "type": "announcement",
        "message": req.message,
        "sender": current_user.nama,
        "time": announcement.created_at.isoformat()
    })
    
    return {"status": "success", "message": "Broadcast terkirim", "id": announcement.id}

@router.put("/announcements/{ann_id}")
async def update_announcement(ann_id: int, req: BroadcastRequest, db: Session = Depends(get_db)):
    ann = db.query(models.Announcement).filter(models.Announcement.id == ann_id).first()
    if not ann:
        raise HTTPException(status_code=404, detail="Pengumuman tidak ditemukan")
    
    ann.message = req.message
    ann.expires_at = req.expires_at
    db.commit()
    try:
        from routers.iot import manager
        await manager.broadcast({"type": "update", "message": "announcement_updated"})
    except Exception:
        pass
    return {"status": "success", "message": "Pengumuman diperbarui"}

@router.delete("/announcements/{ann_id}")
async def delete_announcement(ann_id: int, db: Session = Depends(get_db)):
    ann = db.query(models.Announcement).filter(models.Announcement.id == ann_id).first()
    if not ann:
        raise HTTPException(status_code=404, detail="Pengumuman tidak ditemukan")
    
    db.delete(ann)
    db.commit()
    try:
        from routers.iot import manager
        await manager.broadcast({"type": "update", "message": "announcement_deleted"})
    except Exception:
        pass
    return {"status": "success", "message": "Pengumuman dihapus"}
