from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List

import models
from schemas.vehicle import VehicleResponse
from core.security import get_petugas
from database import get_db

router = APIRouter(prefix="/api/petugas", tags=["Petugas"], dependencies=[Depends(get_petugas)])

@router.get("/vehicles/pending", response_model=List[VehicleResponse])
def get_pending_vehicles(db: Session = Depends(get_db)):
    # List vehicles that need approval by officer
    return db.query(models.Vehicle).filter(models.Vehicle.status_validasi == models.ValidationStatusEnum.pending).all()

@router.put("/vehicles/{vehicle_id}/verify", response_model=VehicleResponse)
def verify_vehicle(vehicle_id: int, status: str, db: Session = Depends(get_db)):
    if status not in [models.ValidationStatusEnum.disetujui, models.ValidationStatusEnum.ditolak]:
        raise HTTPException(status_code=400, detail="Invalid status input")
        
    vehicle = db.query(models.Vehicle).filter(models.Vehicle.id == vehicle_id).first()
    if not vehicle:
        raise HTTPException(status_code=404, detail="Vehicle not found")
        
    # Update state and commit
    vehicle.status_validasi = status
    db.commit()
    db.refresh(vehicle)
    return vehicle
@router.get("/access-requests/pending")
def get_pending_access_requests(db: Session = Depends(get_db)):
    from datetime import datetime, timezone
    requests = db.query(models.AccessRequest).filter(
        models.AccessRequest.status == models.AccessRequestStatusEnum.pending
    ).order_by(models.AccessRequest.waktu_request.asc()).all()
    
    result = []
    for r in requests:
        user = db.query(models.User).filter(models.User.id == r.user_id).first()
        vehicle = db.query(models.Vehicle).filter(models.Vehicle.id == r.vehicle_id).first()
        result.append({
            "id": r.id,
            "user_id": r.user_id,
            "user_nama": user.nama if user else "Unknown",
            "user_nim": user.nim_npp if user else "Unknown",
            "rfid_uid": user.rfid_uid if user else None,
            "vehicle_plat": vehicle.plat_nomor if vehicle else "Unknown",
            "vehicle_jenis": vehicle.jenis_kendaraan if vehicle else "Unknown",
            "jenis_aktivitas": r.jenis_aktivitas,
            "waktu_request": r.waktu_request.isoformat() if r.waktu_request else None,
            "is_flagged": user.is_flagged == 1 if user else False,
            "flag_reason": user.flag_reason if user else None,
        })
    return result

@router.put("/access-requests/{request_id}/respond")
def respond_to_access_request(request_id: int, action: str, catatan: str = "", db: Session = Depends(get_db)):
    from datetime import datetime, timezone
    if action not in ["disetujui", "ditolak"]:
        raise HTTPException(status_code=400, detail="Action harus 'disetujui' atau 'ditolak'")
    
    req = db.query(models.AccessRequest).filter(models.AccessRequest.id == request_id).first()
    if not req:
        raise HTTPException(status_code=404, detail="Request tidak ditemukan")
    if req.status != models.AccessRequestStatusEnum.pending:
        raise HTTPException(status_code=400, detail="Request sudah diproses")
    
    req.status = action
    req.waktu_respon = datetime.now(timezone.utc)
    req.catatan = catatan if catatan else None
    
    # If approved, create the actual ParkingLog
    if action == "disetujui":
        new_log = models.ParkingLog(
            user_id=req.user_id,
            vehicle_id=req.vehicle_id,
            jenis_aktivitas=req.jenis_aktivitas,
            status_akses=models.AccessStatusEnum.manual_petugas
        )
        db.add(new_log)
    
    db.commit()
    
    status_msg = "disetujui dan gate dibuka" if action == "disetujui" else "ditolak"
    return {"status": "success", "message": f"Permintaan telah {status_msg}"}

@router.get("/search")
def search_members(query: str, db: Session = Depends(get_db)):
    """Search users by NIM, Nama, or Vehicle Plate."""
    # Search in Users
    users = db.query(models.User).filter(
        (models.User.nim_npp.contains(query)) | 
        (models.User.nama.contains(query))
    ).limit(20).all()
    
    # Search in Vehicles
    vehicles = db.query(models.Vehicle).filter(models.Vehicle.plat_nomor.contains(query)).limit(20).all()
    vehicle_owners = [v.user for v in vehicles if v.user]
    
    # Merge and deduplicate
    all_users = {u.id: u for u in (users + vehicle_owners)}.values()
    
    result = []
    for u in all_users:
        v_list = [{"id": v.id, "plat": v.plat_nomor, "jenis": v.jenis_kendaraan, "status": v.status_validasi} for v in u.vehicles]
        result.append({
            "id": u.id,
            "nama": u.nama,
            "nim": u.nim_npp,
            "is_flagged": u.is_flagged == 1,
            "flag_reason": u.flag_reason,
            "vehicles": v_list
        })
    return result

@router.get("/session-stats")
def get_session_stats(db: Session = Depends(get_db), current_user: models.User = Depends(get_petugas)):
    """Get stats of actions performed by the current officer today."""
    from datetime import datetime, time, timezone
    today_start = datetime.combine(datetime.now(timezone.utc).date(), time.min)
    
    # AccessRequests handled by this officer (waktu_respon is when it was handled)
    # Note: we need to track WHICH officer handled it. 
    # For now, let's just use general log count or assume logs handled by anyone today for simplicity 
    # unless we want to add 'handled_by' to AccessRequest.
    # Let's count ParkingLogs of type 'manual_petugas' (since these are from requests)
    logs_count = db.query(models.ParkingLog).filter(
        models.ParkingLog.status_akses == models.AccessStatusEnum.manual_petugas,
        models.ParkingLog.waktu >= today_start
    ).count()
    
    # Count STNK approvals (using general count vs this officer - adding 'handled_by' would be better but let's keep it lean)
    pending_stnk = db.query(models.Vehicle).filter(models.Vehicle.status_validasi == models.ValidationStatusEnum.pending).count()
    
    return {
        "handled_count": logs_count,
        "pending_stnk": pending_stnk
    }

@router.put("/flag-user/{user_id}")
def toggle_flag(user_id: int, is_flagged: bool, reason: str = "", db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    user.is_flagged = 1 if is_flagged else 0
    user.flag_reason = reason if is_flagged else None
    db.commit()
    return {"status": "success", "is_flagged": is_flagged}

@router.get("/activity-chart")
def get_activity_chart(db: Session = Depends(get_db)):
    from datetime import datetime, timedelta, timezone
    from sqlalchemy import func
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
