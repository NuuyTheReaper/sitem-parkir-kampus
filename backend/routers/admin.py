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

def to_jakarta_time(dt: datetime) -> datetime:
    if dt is None:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    jakarta_tz = timezone(timedelta(hours=7))
    return dt.astimezone(jakarta_tz)

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
        raise HTTPException(status_code=400, detail="NIM ini sudah terdaftar pada pengguna lain")
    if user.rfid_uid and db.query(models.User).filter(models.User.rfid_uid == user.rfid_uid).first():
        raise HTTPException(status_code=400, detail="Kartu RFID ini sudah terdaftar pada pengguna lain")
        
    db_user = models.User(
        nim_npp=user.nim_npp,
        nama=user.nama,
        prodi_id=user.prodi_id,
        angkatan=user.angkatan,
        rfid_uid=user.rfid_uid,
        role=models.RoleEnum.mahasiswa,
        password_hash=get_password_hash(user.password)
    )
    if user.rfid_uid:
        db_user.rfid_cards.append(models.RFIDCard(rfid_uid=user.rfid_uid))
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
            raise HTTPException(status_code=400, detail="NIM ini sudah terdaftar pada pengguna lain")
        db_user.nim_npp = user_update.nim_npp
    if user_update.nama: db_user.nama = user_update.nama
    if user_update.prodi_id is not None: db_user.prodi_id = user_update.prodi_id
    if user_update.angkatan is not None: db_user.angkatan = user_update.angkatan
    if user_update.rfid_uid is not None:
        if user_update.rfid_uid != "":
            if user_update.rfid_uid != db_user.rfid_uid:
                if db.query(models.User).filter(models.User.rfid_uid == user_update.rfid_uid, models.User.id != user_id).first():
                    raise HTTPException(status_code=400, detail="Kartu RFID ini sudah terdaftar pada pengguna lain")
                db_user.rfid_uid = user_update.rfid_uid
                db_user.rfid_cards.clear()
                db_user.rfid_cards.append(models.RFIDCard(rfid_uid=user_update.rfid_uid))
        else:
            db_user.rfid_uid = None
            db_user.rfid_cards.clear()
            
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
        raise HTTPException(status_code=400, detail="NPP ini sudah terdaftar pada pengguna lain")
        
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
            raise HTTPException(status_code=400, detail="NPP ini sudah terdaftar pada pengguna lain")
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
        if log.emergency_guest_id:
            guest = db.query(models.EmergencyGuest).filter(models.EmergencyGuest.id == log.emergency_guest_id).first()
            user_nama = guest.nama if guest else "Tamu Darurat"
            user_nim = "Tamu Darurat"
            vehicle_plat = guest.plat_nomor if guest else "-"
            vehicle_jenis = "Mobil/Motor"
        else:
            user = db.query(models.User).filter(models.User.id == log.user_id).first()
            vehicle = db.query(models.Vehicle).filter(models.Vehicle.id == log.vehicle_id).first()
            user_nama = user.nama if user else "Unknown"
            user_nim = user.nim_npp if user else "-"
            vehicle_plat = vehicle.plat_nomor if vehicle else "-"
            vehicle_jenis = vehicle.jenis_kendaraan if vehicle else "-"
            
        if log.status_akses == models.AccessStatusEnum.darurat:
            status_akses_display = "Emergency gate"
        elif log.status_akses == models.AccessStatusEnum.manual_petugas:
            status_akses_display = "manual_petugas"
        else:
            status_akses_display = log.status_akses
        
        result.append({
            "id": log.id,
            "user_id": log.user_id,
            "user_nama": user_nama,
            "user_nim": user_nim,
            "vehicle_id": log.vehicle_id,
            "vehicle_plat": vehicle_plat,
            "vehicle_jenis": vehicle_jenis,
            "jenis_aktivitas": log.jenis_aktivitas,
            "status_akses": status_akses_display,
            "waktu": to_jakarta_time(log.waktu).isoformat() if log.waktu else None,
        })
    return result

# ── Export Logs as PDF ──────────────────────────────────────
from core.security import get_admin, get_password_hash
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer, Image
from reportlab.lib.units import inch
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib import colors

@router.get("/reports/export-pdf")
def export_logs_pdf(
    jenis: str = "semua",
    periode: str = "semua",
    feedback: str = None,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_admin)
):
    """Export operational report as a downloadable PDF file with feedback."""
    
    # 1. Base Query for Parking Logs
    query_logs = db.query(models.ParkingLog)
    query_reqs = db.query(models.AccessRequest)
    
    # Filter by periode
    if periode != "semua":
        jakarta_tz = timezone(timedelta(hours=7))
        now_utc = datetime.now(timezone.utc)
        now_jakarta = now_utc.astimezone(jakarta_tz)
        today_start_jakarta = now_jakarta.replace(hour=0, minute=0, second=0, microsecond=0)
        
        if periode == "hari_ini":
            start_date_utc = today_start_jakarta.astimezone(timezone.utc).replace(tzinfo=None)
        elif periode == "7_hari":
            start_date_utc = (today_start_jakarta - timedelta(days=6)).astimezone(timezone.utc).replace(tzinfo=None)
        elif periode == "30_hari":
            start_date_utc = (today_start_jakarta - timedelta(days=29)).astimezone(timezone.utc).replace(tzinfo=None)
            
        query_logs = query_logs.filter(models.ParkingLog.waktu >= start_date_utc)
        query_reqs = query_reqs.filter(models.AccessRequest.waktu_request >= start_date_utc)

    if jenis != "semua":
        query_logs = query_logs.filter(models.ParkingLog.jenis_aktivitas == jenis)

    # Calculate metrics
    total_masuk = query_logs.filter(models.ParkingLog.jenis_aktivitas == "masuk").count()
    total_keluar = query_logs.filter(models.ParkingLog.jenis_aktivitas == "keluar").count()
    total_requests = query_reqs.count()
    
    # Emergency Exits (querying ParkingLog with emergency status)
    emergency_logs = query_logs.filter(models.ParkingLog.status_akses == models.AccessStatusEnum.darurat).order_by(models.ParkingLog.waktu.desc()).limit(20).all()

    # Generate PDF in memory
    buffer = io.BytesIO()
    
    def draw_footer(canvas, doc):
        canvas.saveState()
        canvas.setFont('Helvetica', 8)
        canvas.setFillColor(colors.gray)
        canvas.setStrokeColor(colors.gray)
        canvas.setLineWidth(1)
        canvas.line(40, 50, 555, 50)
        footer_text = "Unit Pengelola Parkir, Sekolah Vokasi, Universitas Harkat Negeri\nArea Parkir Sekolah Vokasi Universitas Harkat Negeri - Jl. Mataram No.9, Pesurungan Lor, Kec. Margadana, Kota Tegal, Jawa Tengah"
        y = 40
        for line in footer_text.split('\n'):
            canvas.drawString(40, y, line)
            y -= 10
        canvas.restoreState()

    doc = SimpleDocTemplate(buffer, pagesize=A4, rightMargin=40, leftMargin=40, topMargin=40, bottomMargin=70)
    elements = []
    
    styles = getSampleStyleSheet()
    normal_style = styles['Normal']
    normal_style.fontSize = 11
    normal_style.leading = 14
    normal_style.alignment = 4  # 4 is TA_JUSTIFY
    
    # 1. Header (Logo + Text)
    import os
    from reportlab.platypus import HRFlowable
    from reportlab.lib.utils import ImageReader
    logo_path = os.path.join(os.getcwd(), "univharkat.png")
    
    header_right_text = Paragraph("<font size=12 color='#808080'>Sekolah Vokasi<br/>Program Studi D-3 Teknik Komputer</font>", ParagraphStyle('HR', parent=normal_style, alignment=2))
    
    if os.path.exists(logo_path):
        img_reader = ImageReader(logo_path)
        orig_w, orig_h = img_reader.getSize()
        aspect = orig_h / float(orig_w)
        desired_width = 2.5 * inch
        desired_height = desired_width * aspect
        img = Image(logo_path, width=desired_width, height=desired_height)
        
        left_table = Table([[img]], colWidths=[desired_width])
        left_table.setStyle(TableStyle([
            ('ALIGN', (0, 0), (0, 0), 'LEFT'),
            ('VALIGN', (0, 0), (0, 0), 'CENTER'),
            ('LEFTPADDING', (0, 0), (0, 0), 0),
            ('RIGHTPADDING', (0, 0), (0, 0), 0),
        ]))
        header_table = Table([[left_table, header_right_text]], colWidths=[257, 258])
    else:
        inst_para = Paragraph("<font size=14 color='#8B0000'><b>Universitas Harkat Negeri</b></font>", normal_style)
        header_table = Table([[inst_para, header_right_text]], colWidths=[257, 258])
        
    header_table.setStyle(TableStyle([
        ('ALIGN', (0, 0), (0, 0), 'LEFT'),
        ('VALIGN', (0, 0), (0, 0), 'CENTER'),
        ('ALIGN', (1, 0), (1, 0), 'RIGHT'),
        ('VALIGN', (1, 0), (1, 0), 'CENTER'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 2),
        ('LEFTPADDING', (0, 0), (-1, -1), 0),
        ('RIGHTPADDING', (0, 0), (-1, -1), 0),
    ]))
    elements.append(header_table)
    elements.append(HRFlowable(width="100%", thickness=2, color=colors.HexColor('#8B0000'), spaceBefore=2, spaceAfter=20))
    
    # 2. Metadata (Nomor, Lampiran, Perihal)
    meta_data = [
        ['Nomor', ':', f'001/LAP-PARKIR/{datetime.now().strftime("%m/%Y")}'],
        ['Lampiran', ':', '-'],
        ['Perihal', ':', 'Laporan Operasional Smart Campus Parking']
    ]
    meta_table = Table(meta_data, colWidths=[65, 15, 435], hAlign='LEFT')
    meta_table.setStyle(TableStyle([
        ('FONTNAME', (0, 0), (-1, -1), 'Helvetica'),
        ('FONTSIZE', (0, 0), (-1, -1), 11),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 2),
        ('TOPPADDING', (0, 0), (-1, -1), 2),
        ('LEFTPADDING', (0, 0), (0, -1), 0),
        ('RIGHTPADDING', (-1, 0), (-1, -1), 0),
    ]))
    elements.append(meta_table)
    elements.append(Spacer(1, 20))
    
    # 3. Body
    elements.append(Paragraph("Kepada Yth.", normal_style))
    elements.append(Paragraph("<b>Pimpinan / Koordinator Pengelola Parkir</b>", normal_style))
    elements.append(Paragraph("Di Tempat", normal_style))
    elements.append(Spacer(1, 15))
    
    body_text = f"Dengan Hormat,<br/><br/>Sehubungan dengan operasional sistem parkir pintar kampus untuk periode <b>{periode.replace('_', ' ').title()}</b>, berikut ini kami sampaikan laporan operasional dan rekapitulasi data kendaraan yang telah tercatat di dalam sistem, beserta kendala yang dilaporkan:"
    elements.append(Paragraph(body_text, normal_style))
    elements.append(Spacer(1, 15))
    
    # Table 1: Stats
    metrics_data = [
        ['No', 'Metrik Kinerja', 'Total Jumlah'],
        ['1', 'Total Kendaraan Masuk', str(total_masuk)],
        ['2', 'Total Kendaraan Keluar', str(total_keluar)],
        ['3', 'Total Penggunaan Aplikasi (Request Akses)', str(total_requests)],
        ['4', 'Total Insiden Darurat (Emergency Gate)', str(len(emergency_logs))]
    ]
    metrics_table = Table(metrics_data, colWidths=[35, 330, 150], hAlign='LEFT')
    metrics_table.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.white),
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.black),
        ('ALIGN', (0, 0), (-1, -1), 'LEFT'),
        ('ALIGN', (0, 0), (0, -1), 'CENTER'),
        ('ALIGN', (2, 0), (2, -1), 'CENTER'),
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
        ('FONTSIZE', (0, 0), (-1, -1), 11),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 5),
        ('TOPPADDING', (0, 0), (-1, -1), 5),
        ('GRID', (0, 0), (-1, -1), 1, colors.black),
    ]))
    elements.append(metrics_table)
    elements.append(Spacer(1, 15))
    
    # Feedback
    elements.append(Paragraph("<b>Catatan Kendala & Pengaduan (Feedback):</b>", normal_style))
    elements.append(Spacer(1, 5))
    if feedback and feedback.strip():
        feedback_para = Paragraph(feedback.strip(), normal_style)
        elements.append(feedback_para)
    else:
        # Give some empty space for manual writing
        elements.append(Spacer(1, 40))
    elements.append(Spacer(1, 20))
    
    # Closing
    elements.append(Paragraph("Demikian surat laporan ini kami sampaikan. Atas perhatian dan kerjasamanya kami ucapkan terima kasih.", normal_style))
    elements.append(Spacer(1, 30))
    
    # Signature
    print_time = datetime.now(timezone(timedelta(hours=7))).strftime('%d %B %Y')
    sig_style = ParagraphStyle('SigStyle', parent=normal_style, alignment=0, spaceAfter=0, spaceBefore=0)
    sig_data = [
        ['', f'Tegal, {print_time}'],
        ['', 'Petugas Lapangan'],
        ['', ''],
        ['', ''],
        ['', ''],
        ['', Paragraph(f"<u>{current_user.nama}</u>", sig_style)],
        ['', Paragraph(f"NIP.{current_user.nim_npp}", sig_style)]
    ]
    sig_table = Table(sig_data, colWidths=[365, 150], hAlign='LEFT')
    sig_table.setStyle(TableStyle([
        ('ALIGN', (1, 0), (1, -1), 'LEFT'),
        ('LEFTPADDING', (0, 0), (-1, -1), 0),
        ('BOTTOMPADDING', (1, 5), (1, 5), 0),
        ('TOPPADDING', (1, 6), (1, 6), 0),
    ]))
    elements.append(sig_table)
    
    # Build PDF
    doc.build(elements, onFirstPage=draw_footer, onLaterPages=draw_footer)
    
    buffer.seek(0)
    filename = f"laporan_operasional_{datetime.now().strftime('%Y%m%d_%H%M%S')}.pdf"
    
    return StreamingResponse(
        buffer,
        media_type="application/pdf",
        headers={"Content-Disposition": f"attachment; filename={filename}"}
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
        "time": to_jakarta_time(announcement.created_at).isoformat()
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
