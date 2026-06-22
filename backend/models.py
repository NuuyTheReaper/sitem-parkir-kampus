from sqlalchemy import Column, Integer, String, ForeignKey, Enum as SQLEnum, DateTime
from sqlalchemy.orm import relationship
import enum
from datetime import datetime, timezone
from database import Base

# --- Enums ---
class RoleEnum(str, enum.Enum):
    admin = "admin"
    petugas = "petugas"
    mahasiswa = "mahasiswa"

class VehicleTypeEnum(str, enum.Enum):
    motor = "Motor"
    mobil = "Mobil"

class ValidationStatusEnum(str, enum.Enum):
    pending = "pending"
    disetujui = "disetujui"
    ditolak = "ditolak"

class ActivityTypeEnum(str, enum.Enum):
    masuk = "masuk"
    keluar = "keluar"

class AccessStatusEnum(str, enum.Enum):
    otomatis = "otomatis"
    manual_petugas = "manual_petugas"

# --- Models ---
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    role = Column(SQLEnum(RoleEnum), nullable=False)
    nim_npp = Column(String(50), unique=True, index=True, nullable=False) # For login
    nama = Column(String(100), nullable=False)
    prodi_id = Column(Integer, ForeignKey("prodi.id"), nullable=True)
    angkatan = Column(Integer, nullable=True) # e.g. 2023
    rfid_uid = Column(String(100), unique=True, index=True, nullable=True)
    password_hash = Column(String(255), nullable=False)
    is_flagged = Column(Integer, default=0) # 0: No, 1: Yes
    flag_reason = Column(String(255), nullable=True)

    # Relationships
    prodi = relationship("Prodi", back_populates="users")
    rfid_cards = relationship("RFIDCard", back_populates="user", cascade="all, delete-orphan")
    vehicles = relationship("Vehicle", back_populates="user", cascade="all, delete-orphan")
    parking_logs = relationship("ParkingLog", back_populates="user")

    @property
    def prodi_nama(self):
        return self.prodi.nama if self.prodi else None

    @property
    def semester(self):
        if self.angkatan:
            now = datetime.now()
            # Simplistic 2 sem/year logic starting from Sept
            months = (now.year - self.angkatan) * 12 + (now.month - 9)
            return max(1, (months // 6) + 1)
        return None

class Prodi(Base):
    __tablename__ = "prodi"

    id = Column(Integer, primary_key=True, index=True)
    nama = Column(String(100), unique=True, index=True, nullable=False)

    users = relationship("User", back_populates="prodi")

class RFIDCard(Base):
    __tablename__ = "rfid_cards"

    rfid_uid = Column(String(100), primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)

    user = relationship("User", back_populates="rfid_cards")

class Vehicle(Base):
    __tablename__ = "vehicles"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    jenis_kendaraan = Column(SQLEnum(VehicleTypeEnum), nullable=False)
    plat_nomor = Column(String(20), index=True, nullable=False)
    merek = Column(String(50), nullable=True)
    foto_stnk = Column(String(255), nullable=True) # URL or path to STNK
    status_validasi = Column(SQLEnum(ValidationStatusEnum), default=ValidationStatusEnum.pending)

    user = relationship("User", back_populates="vehicles")
    parking_logs = relationship("ParkingLog", back_populates="vehicle")

class AccessRequestStatusEnum(str, enum.Enum):
    pending = "pending"
    disetujui = "disetujui"
    ditolak = "ditolak"

class ParkingLog(Base):
    __tablename__ = "parking_logs"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    vehicle_id = Column(Integer, ForeignKey("vehicles.id"), nullable=False)
    emergency_guest_id = Column(Integer, ForeignKey("emergency_guests.id"), nullable=True)
    waktu = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    jenis_aktivitas = Column(SQLEnum(ActivityTypeEnum), nullable=False)
    status_akses = Column(SQLEnum(AccessStatusEnum), nullable=False)

    user = relationship("User", back_populates="parking_logs")
    vehicle = relationship("Vehicle", back_populates="parking_logs")
    emergency_guest = relationship("EmergencyGuest")

class AccessRequest(Base):
    __tablename__ = "access_requests"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    vehicle_id = Column(Integer, ForeignKey("vehicles.id"), nullable=True)
    emergency_guest_id = Column(Integer, ForeignKey("emergency_guests.id"), nullable=True)
    jenis_aktivitas = Column(SQLEnum(ActivityTypeEnum), nullable=False)
    status = Column(SQLEnum(AccessRequestStatusEnum), default=AccessRequestStatusEnum.pending)
    waktu_request = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    waktu_respon = Column(DateTime, nullable=True)
    catatan = Column(String(255), nullable=True)  # Optional rejection reason

    user = relationship("User")
    vehicle = relationship("Vehicle")

class Announcement(Base):
    __tablename__ = "announcements"

    id = Column(Integer, primary_key=True, index=True)
    message = Column(String(500), nullable=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    expires_at = Column(DateTime, nullable=True) # Automatic deletion time
    sender_id = Column(Integer, ForeignKey("users.id"), nullable=False) # Petugas/Admin who sent it

    sender = relationship("User")

class EmergencyGuest(Base):
    __tablename__ = "emergency_guests"

    id = Column(Integer, primary_key=True, index=True)
    nama = Column(String(100), nullable=False)
    plat_nomor = Column(String(50), nullable=False)
    alasan = Column(String(255), nullable=False)
    waktu_masuk = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    waktu_keluar = Column(DateTime, nullable=True)
    petugas_masuk_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    petugas_keluar_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    status = Column(String(20), default="di_dalam") # di_dalam, sudah_keluar

    petugas_masuk = relationship("User", foreign_keys=[petugas_masuk_id])
    petugas_keluar = relationship("User", foreign_keys=[petugas_keluar_id])
