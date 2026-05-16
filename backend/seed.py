import argparse
import os
import random
from datetime import datetime, timedelta, timezone

from database import SessionLocal, engine, Base
import models
from core.security import get_password_hash


RANDOM_SEED = 20260516

DEFAULT_MAHASISWA_COUNT = 180
DEFAULT_PARKING_LOGS = 900
DEFAULT_ACCESS_REQUESTS = 120
DEFAULT_PENDING_STNK = 60
DEFAULT_LOG_DAYS = 21

PRODI_NAMES = [
    "Teknik Informatika",
    "Sistem Informasi",
    "Teknik Elektro",
    "Teknik Sipil",
    "Arsitektur",
    "Manajemen",
    "Akuntansi",
    "Ilmu Komunikasi",
    "Pendidikan Matematika",
    "Desain Komunikasi Visual",
]

FIRST_NAMES = [
    "Ahmad",
    "Aulia",
    "Bagas",
    "Citra",
    "Dewi",
    "Dimas",
    "Eka",
    "Fajar",
    "Fitri",
    "Gilang",
    "Hana",
    "Ilham",
    "Intan",
    "Joko",
    "Kartika",
    "Laras",
    "Maya",
    "Naufal",
    "Putri",
    "Rizky",
    "Salsa",
    "Taufik",
    "Vina",
    "Wahyu",
    "Yusuf",
]

LAST_NAMES = [
    "Pratama",
    "Saputra",
    "Lestari",
    "Wibowo",
    "Rahmawati",
    "Maulana",
    "Kurniawan",
    "Permatasari",
    "Hidayat",
    "Nugroho",
    "Puspitasari",
    "Wijaya",
    "Ramadhan",
    "Utami",
    "Setiawan",
    "Anggraini",
]

MOTOR_BRANDS = [
    "Honda Beat",
    "Honda Vario 160",
    "Yamaha NMAX",
    "Yamaha Aerox",
    "Suzuki Nex II",
    "Honda Scoopy",
    "Yamaha Mio",
]

CAR_BRANDS = [
    "Toyota Avanza",
    "Honda Brio",
    "Daihatsu Sigra",
    "Toyota Agya",
    "Suzuki Ertiga",
    "Mitsubishi Xpander",
]

FLAG_REASONS = [
    "Sering parkir di luar area yang ditentukan",
    "Pernah meminjamkan kartu RFID ke orang lain",
    "Belum menyelesaikan teguran parkir sebelumnya",
    "Kendaraan beberapa kali tidak sesuai data",
]


def int_env(name, default):
    try:
        return int(os.getenv(name, default))
    except (TypeError, ValueError):
        return default


def get_or_create_prodi(db, name):
    prodi = db.query(models.Prodi).filter(models.Prodi.nama == name).first()
    if prodi:
        return prodi

    prodi = models.Prodi(nama=name)
    db.add(prodi)
    db.flush()
    return prodi


def get_or_create_user(db, nim_npp, **payload):
    user = db.query(models.User).filter(models.User.nim_npp == nim_npp).first()
    if user:
        return user

    user = models.User(nim_npp=nim_npp, **payload)
    db.add(user)
    db.flush()
    return user


def get_stnk_paths():
    upload_dir = os.path.join(os.path.dirname(__file__), "uploads", "stnk")
    if not os.path.isdir(upload_dir):
        return []

    paths = []
    for filename in sorted(os.listdir(upload_dir)):
        if filename.lower().endswith((".jpg", ".jpeg", ".png", ".webp")):
            paths.append(f"/uploads/stnk/{filename}")
    return paths


def make_student_name(index):
    first = FIRST_NAMES[index % len(FIRST_NAMES)]
    last = LAST_NAMES[(index * 3) % len(LAST_NAMES)]
    if index % 4 == 0:
        middle = FIRST_NAMES[(index * 5) % len(FIRST_NAMES)]
        return f"{first} {middle} {last}"
    return f"{first} {last}"


def make_plate(index):
    prefixes = ["G", "H", "B", "K", "D", "AB", "AD", "E", "F", "L"]
    letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    prefix = prefixes[index % len(prefixes)]
    number = 1000 + ((index * 37) % 8000)
    suffix = f"{letters[(index * 7) % 26]}{letters[(index * 11) % 26]}"
    return f"{prefix} {number} {suffix}"


def seed_core_data(db):
    prodi_by_name = {name: get_or_create_prodi(db, name) for name in PRODI_NAMES}
    db.commit()

    admin_password = get_password_hash("adminpassword")
    petugas_password = get_password_hash("petugaspassword")
    mahasiswa_password = get_password_hash("mhspassword")

    admin = get_or_create_user(
        db,
        "admin123",
        nama="Super Admin",
        role=models.RoleEnum.admin,
        password_hash=admin_password,
    )

    get_or_create_user(
        db,
        "petugas123",
        nama="Budi Petugas",
        role=models.RoleEnum.petugas,
        password_hash=petugas_password,
    )

    for idx, name in enumerate(["Rani Petugas", "Agus Petugas", "Sari Petugas"], 1):
        get_or_create_user(
            db,
            f"petugas{idx:03d}",
            nama=name,
            role=models.RoleEnum.petugas,
            password_hash=petugas_password,
        )

    mhs1 = get_or_create_user(
        db,
        "11223344",
        nama="Budi Santoso",
        prodi=prodi_by_name["Teknik Informatika"],
        angkatan=2023,
        rfid_uid="RFID_BUDI_123",
        role=models.RoleEnum.mahasiswa,
        password_hash=mahasiswa_password,
        is_flagged=1,
        flag_reason="Sering parkir di luar area yang ditentukan",
    )

    mhs2 = get_or_create_user(
        db,
        "55667788",
        nama="Siti Aminah",
        prodi=prodi_by_name["Sistem Informasi"],
        angkatan=2024,
        rfid_uid="RFID_SITI_456",
        role=models.RoleEnum.mahasiswa,
        password_hash=mahasiswa_password,
    )

    db.commit()

    seed_vehicle_if_missing(
        db,
        user=mhs1,
        plat_nomor="G 1234 AB",
        jenis_kendaraan=models.VehicleTypeEnum.motor,
        merek="Honda Vario 150",
        status_validasi=models.ValidationStatusEnum.disetujui,
    )
    seed_vehicle_if_missing(
        db,
        user=mhs2,
        plat_nomor="G 5678 CD",
        jenis_kendaraan=models.VehicleTypeEnum.motor,
        merek="Yamaha NMAX",
        status_validasi=models.ValidationStatusEnum.pending,
    )

    db.commit()
    seed_announcements(db, admin)
    return prodi_by_name


def seed_vehicle_if_missing(
    db,
    user,
    plat_nomor,
    jenis_kendaraan,
    merek,
    status_validasi,
    foto_stnk=None,
):
    vehicle = (
        db.query(models.Vehicle)
        .filter(models.Vehicle.plat_nomor == plat_nomor)
        .first()
    )
    if vehicle:
        return vehicle

    vehicle = models.Vehicle(
        user_id=user.id,
        jenis_kendaraan=jenis_kendaraan,
        plat_nomor=plat_nomor,
        merek=merek,
        foto_stnk=foto_stnk,
        status_validasi=status_validasi,
    )
    db.add(vehicle)
    db.flush()
    return vehicle


def seed_announcements(db, admin_user):
    if db.query(models.Announcement).count() > 0:
        return

    messages = [
        "Mulai 1 Mei 2026, seluruh kendaraan wajib memiliki STNK yang terverifikasi untuk masuk area parkir kampus.",
        "Perbaikan jalur parkir motor gedung B akan dilakukan pada 3-5 Mei. Gunakan jalur alternatif.",
        "Petugas akan memprioritaskan permintaan akses manual untuk mahasiswa dengan kendaraan terdaftar.",
    ]
    for message in messages:
        db.add(models.Announcement(message=message, sender_id=admin_user.id))
    db.commit()


def seed_demo_students(db, prodi_by_name, mahasiswa_count, pending_stnk_count):
    password_hash = get_password_hash("mhspassword")
    stnk_paths = get_stnk_paths()
    prodi_list = list(prodi_by_name.values())
    students = []

    for index in range(1, mahasiswa_count + 1):
        nim = f"2026{index:05d}"
        prodi = prodi_list[index % len(prodi_list)]
        angkatan = 2021 + (index % 5)
        is_flagged = 1 if index % 17 == 0 else 0
        flag_reason = FLAG_REASONS[index % len(FLAG_REASONS)] if is_flagged else None

        user = get_or_create_user(
            db,
            nim,
            nama=make_student_name(index),
            prodi=prodi,
            angkatan=angkatan,
            rfid_uid=f"RFID_DEMO_{index:05d}",
            role=models.RoleEnum.mahasiswa,
            password_hash=password_hash,
            is_flagged=is_flagged,
            flag_reason=flag_reason,
        )
        students.append(user)

        if index <= pending_stnk_count:
            status = models.ValidationStatusEnum.pending
        elif index % 13 == 0:
            status = models.ValidationStatusEnum.ditolak
        else:
            status = models.ValidationStatusEnum.disetujui

        is_car = index % 9 == 0
        jenis = models.VehicleTypeEnum.mobil if is_car else models.VehicleTypeEnum.motor
        brands = CAR_BRANDS if is_car else MOTOR_BRANDS
        foto_stnk = stnk_paths[index % len(stnk_paths)] if stnk_paths else None

        seed_vehicle_if_missing(
            db,
            user=user,
            plat_nomor=make_plate(index),
            jenis_kendaraan=jenis,
            merek=brands[index % len(brands)],
            status_validasi=status,
            foto_stnk=foto_stnk,
        )

        if index % 50 == 0:
            db.commit()

    db.commit()
    return students


def approved_vehicles(db):
    return (
        db.query(models.Vehicle)
        .join(models.User, models.Vehicle.user_id == models.User.id)
        .filter(
            models.User.role == models.RoleEnum.mahasiswa,
            models.Vehicle.status_validasi == models.ValidationStatusEnum.disetujui,
        )
        .all()
    )


def seed_parking_logs(db, target_logs, days):
    current_logs = db.query(models.ParkingLog).count()
    if current_logs >= target_logs:
        return 0

    vehicles = approved_vehicles(db)
    if not vehicles:
        return 0

    rng = random.Random(RANDOM_SEED + current_logs)
    now = datetime.now(timezone.utc)
    to_create = target_logs - current_logs
    created = 0

    while created < to_create:
        vehicle = vehicles[(current_logs + created) % len(vehicles)]
        day_offset = rng.randint(0, max(days - 1, 0))

        if day_offset == 0:
            start_hour = rng.randint(6, max(now.hour, 7))
            start_minute = rng.randint(0, 59)
            masuk_time = now.replace(
                hour=min(start_hour, 23),
                minute=start_minute,
                second=rng.randint(0, 59),
                microsecond=0,
            )
            if masuk_time > now:
                masuk_time = now - timedelta(minutes=rng.randint(1, 90))
        else:
            masuk_time = (
                now
                - timedelta(days=day_offset)
            ).replace(
                hour=rng.randint(6, 18),
                minute=rng.randint(0, 59),
                second=rng.randint(0, 59),
                microsecond=0,
            )

        status_akses = (
            models.AccessStatusEnum.manual_petugas
            if rng.random() < 0.18
            else models.AccessStatusEnum.otomatis
        )

        db.add(
            models.ParkingLog(
                user_id=vehicle.user_id,
                vehicle_id=vehicle.id,
                waktu=masuk_time,
                jenis_aktivitas=models.ActivityTypeEnum.masuk,
                status_akses=status_akses,
            )
        )
        created += 1

        should_add_exit = created < to_create and rng.random() > 0.12
        if should_add_exit:
            candidate_keluar_time = masuk_time + timedelta(
                hours=rng.randint(1, 9),
                minutes=rng.randint(5, 55),
            )
            if candidate_keluar_time > now:
                minutes_until_now = int((now - masuk_time).total_seconds() // 60)
                if minutes_until_now < 5:
                    keluar_time = None
                else:
                    keluar_time = masuk_time + timedelta(
                        minutes=rng.randint(5, minutes_until_now)
                    )
            else:
                keluar_time = candidate_keluar_time

            if keluar_time:
                db.add(
                    models.ParkingLog(
                        user_id=vehicle.user_id,
                        vehicle_id=vehicle.id,
                        waktu=keluar_time,
                        jenis_aktivitas=models.ActivityTypeEnum.keluar,
                        status_akses=status_akses,
                    )
                )
                created += 1

        if created % 200 == 0:
            db.commit()

    db.commit()
    return created


def seed_access_requests(db, target_requests):
    current_requests = db.query(models.AccessRequest).count()
    if current_requests >= target_requests:
        return 0

    vehicles = approved_vehicles(db)
    if not vehicles:
        return 0

    existing_pending_user_ids = {
        row[0]
        for row in db.query(models.AccessRequest.user_id)
        .filter(models.AccessRequest.status == models.AccessRequestStatusEnum.pending)
        .all()
    }

    rng = random.Random(RANDOM_SEED + current_requests + 99)
    now = datetime.now(timezone.utc)
    to_create = target_requests - current_requests
    created = 0

    pending_quota = min(int(to_create * 0.65), len(vehicles))
    for vehicle in vehicles:
        if created >= pending_quota:
            break
        if vehicle.user_id in existing_pending_user_ids:
            continue

        db.add(
            models.AccessRequest(
                user_id=vehicle.user_id,
                vehicle_id=vehicle.id,
                jenis_aktivitas=(
                    models.ActivityTypeEnum.masuk
                    if created % 2 == 0
                    else models.ActivityTypeEnum.keluar
                ),
                status=models.AccessRequestStatusEnum.pending,
                waktu_request=now - timedelta(
                    minutes=rng.randint(0, 4),
                    seconds=rng.randint(0, 59),
                ),
            )
        )
        existing_pending_user_ids.add(vehicle.user_id)
        created += 1

    while created < to_create:
        vehicle = vehicles[(current_requests + created) % len(vehicles)]
        request_time = now - timedelta(
            days=rng.randint(0, 10),
            hours=rng.randint(1, 18),
            minutes=rng.randint(0, 59),
        )
        approved = rng.random() > 0.28
        status = (
            models.AccessRequestStatusEnum.disetujui
            if approved
            else models.AccessRequestStatusEnum.ditolak
        )

        db.add(
            models.AccessRequest(
                user_id=vehicle.user_id,
                vehicle_id=vehicle.id,
                jenis_aktivitas=(
                    models.ActivityTypeEnum.masuk
                    if rng.random() > 0.45
                    else models.ActivityTypeEnum.keluar
                ),
                status=status,
                waktu_request=request_time,
                waktu_respon=request_time + timedelta(minutes=rng.randint(1, 9)),
                catatan=None if approved else "Data akses perlu diverifikasi ulang oleh petugas",
            )
        )
        created += 1

        if created % 200 == 0:
            db.commit()

    db.commit()
    return created


def seed_data(mahasiswa_count, parking_logs, access_requests, pending_stnk, log_days):
    Base.metadata.create_all(bind=engine)

    db = SessionLocal()
    try:
        prodi_by_name = seed_core_data(db)
        seed_demo_students(
            db,
            prodi_by_name,
            mahasiswa_count=mahasiswa_count,
            pending_stnk_count=pending_stnk,
        )
        created_logs = seed_parking_logs(db, target_logs=parking_logs, days=log_days)
        created_requests = seed_access_requests(db, target_requests=access_requests)

        total_mahasiswa = (
            db.query(models.User)
            .filter(models.User.role == models.RoleEnum.mahasiswa)
            .count()
        )
        total_vehicles = db.query(models.Vehicle).count()
        total_pending_stnk = (
            db.query(models.Vehicle)
            .filter(models.Vehicle.status_validasi == models.ValidationStatusEnum.pending)
            .count()
        )
        total_logs = db.query(models.ParkingLog).count()
        total_requests = db.query(models.AccessRequest).count()
        total_pending_requests = (
            db.query(models.AccessRequest)
            .filter(models.AccessRequest.status == models.AccessRequestStatusEnum.pending)
            .count()
        )

        print("[OK] Database seeded successfully.")
        print("Akun test:")
        print("  Admin:     admin123 / adminpassword")
        print("  Petugas:   petugas123 / petugaspassword")
        print("  Mahasiswa: 11223344 / mhspassword (flagged)")
        print("  Mahasiswa: 55667788 / mhspassword")
        print("Ringkasan data:")
        print(f"  Mahasiswa total:          {total_mahasiswa}")
        print(f"  Kendaraan total:          {total_vehicles}")
        print(f"  STNK pending total:       {total_pending_stnk}")
        print(f"  Log parkir total:         {total_logs} (+{created_logs})")
        print(f"  Request akses total:      {total_requests}")
        print(f"  Request akses pending:    {total_pending_requests}")
        print(f"  Request akses baru dibuat: {created_requests}")
    finally:
        db.close()


def parse_args():
    parser = argparse.ArgumentParser(
        description="Seed demo data for Smart Campus Parking System."
    )
    parser.add_argument(
        "--mahasiswa",
        type=int,
        default=int_env("SEED_MAHASISWA", DEFAULT_MAHASISWA_COUNT),
        help="Jumlah mahasiswa demo yang ditargetkan.",
    )
    parser.add_argument(
        "--logs",
        type=int,
        default=int_env("SEED_PARKING_LOGS", DEFAULT_PARKING_LOGS),
        help="Jumlah total log keluar/masuk parkir yang ditargetkan.",
    )
    parser.add_argument(
        "--access-requests",
        type=int,
        default=int_env("SEED_ACCESS_REQUESTS", DEFAULT_ACCESS_REQUESTS),
        help="Jumlah total permintaan akses keluar/masuk yang ditargetkan.",
    )
    parser.add_argument(
        "--pending-stnk",
        type=int,
        default=int_env("SEED_PENDING_STNK", DEFAULT_PENDING_STNK),
        help="Jumlah kendaraan demo yang dibuat sebagai pending STNK.",
    )
    parser.add_argument(
        "--days",
        type=int,
        default=int_env("SEED_LOG_DAYS", DEFAULT_LOG_DAYS),
        help="Sebaran hari ke belakang untuk log parkir.",
    )
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    seed_data(
        mahasiswa_count=max(args.mahasiswa, 0),
        parking_logs=max(args.logs, 0),
        access_requests=max(args.access_requests, 0),
        pending_stnk=max(args.pending_stnk, 0),
        log_days=max(args.days, 1),
    )
