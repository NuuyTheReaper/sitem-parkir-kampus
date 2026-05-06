"""
plate_validator.py — Logika Pencocokan Plat Nomor (Validasi Ganda)

Modul ini bertanggung jawab atas normalisasi dan perbandingan string plat nomor
antara data yang tersimpan di Database dan hasil deteksi ML (YOLOv8 + OCR).

Contoh:
    Database : "G 5090 DB"
    ML OCR   : "G5090DB" atau "g 5090 db" atau "G-5090-DB"
    
    Setelah normalisasi:
    Keduanya menjadi → "G5090DB"
    Hasil: COCOK ✅
"""

import re
from typing import Optional


def normalize_plate(plate: str) -> str:
    """
    Normalisasi string plat nomor untuk perbandingan yang konsisten.
    
    Langkah-langkah:
    1. Hapus semua spasi (leading, trailing, dan di tengah)
    2. Konversi seluruh karakter ke UPPERCASE
    3. Hapus karakter non-alfanumerik (tanda hubung, titik, dll.)
       → Ini mengatasi noise dari hasil OCR
    
    Args:
        plate: String plat nomor mentah (dari DB atau ML OCR)
        
    Returns:
        String plat nomor yang sudah dinormalisasi
        
    Examples:
        >>> normalize_plate("G 5090 DB")
        'G5090DB'
        >>> normalize_plate("g-5090-db")
        'G5090DB'
        >>> normalize_plate("  G  5090  DB  ")
        'G5090DB'
        >>> normalize_plate("AB 1234 CD")
        'AB1234CD'
    """
    if not plate:
        return ""
    
    # Step 1: Hapus semua spasi
    cleaned = plate.strip().replace(" ", "")
    
    # Step 2: Konversi ke UPPERCASE
    cleaned = cleaned.upper()
    
    # Step 3: Hapus karakter non-alfanumerik (-, ., _, dll.)
    # Hanya sisakan huruf dan angka
    cleaned = re.sub(r'[^A-Z0-9]', '', cleaned)
    
    return cleaned


def validate_plate_match(
    plate_from_db: str,
    plate_from_ml: str,
    confidence: Optional[float] = None,
    min_confidence: float = 0.70
) -> dict:
    """
    Melakukan validasi ganda: membandingkan plat nomor dari Database
    dengan hasil deteksi ML (OCR).
    
    Args:
        plate_from_db: Plat nomor terdaftar di database (misal: "G 5090 DB")
        plate_from_ml: Plat nomor hasil OCR dari kamera ML (misal: "G5090DB")
        confidence: Skor kepercayaan dari model ML (0.0 - 1.0), opsional
        min_confidence: Ambang batas minimum confidence yang diterima
        
    Returns:
        dict berisi:
            - match (bool): Apakah plat cocok
            - normalized_db (str): Plat DB setelah normalisasi
            - normalized_ml (str): Plat ML setelah normalisasi
            - confidence_ok (bool): Apakah confidence memenuhi ambang
            - reason (str): Alasan hasil validasi
    
    Examples:
        >>> validate_plate_match("G 5090 DB", "G5090DB")
        {'match': True, 'normalized_db': 'G5090DB', 'normalized_ml': 'G5090DB', ...}
        
        >>> validate_plate_match("G 5090 DB", "G5091DB")
        {'match': False, ...}
    """
    norm_db = normalize_plate(plate_from_db)
    norm_ml = normalize_plate(plate_from_ml)
    
    # Cek confidence ML jika tersedia
    confidence_ok = True
    if confidence is not None and confidence < min_confidence:
        confidence_ok = False
    
    # Perbandingan string yang sudah dinormalisasi
    is_match = (norm_db == norm_ml) and confidence_ok
    
    # Tentukan alasan
    if not norm_ml:
        reason = "Plat nomor tidak terdeteksi oleh ML/OCR"
    elif not confidence_ok:
        reason = f"Confidence ML terlalu rendah: {confidence:.2f} < {min_confidence:.2f}"
    elif norm_db != norm_ml:
        reason = f"Plat tidak cocok: DB='{norm_db}' vs ML='{norm_ml}'"
    else:
        reason = "Plat nomor cocok — validasi ganda berhasil"
    
    return {
        "match": is_match,
        "normalized_db": norm_db,
        "normalized_ml": norm_ml,
        "confidence_ok": confidence_ok,
        "reason": reason
    }


def find_matching_vehicle(vehicles: list, plate_from_ml: str) -> Optional[object]:
    """
    Cari kendaraan dari daftar milik user yang plat nomornya cocok
    dengan hasil deteksi ML, menggunakan normalisasi string.
    
    Args:
        vehicles: List objek Vehicle milik user
        plate_from_ml: Plat nomor hasil deteksi ML/OCR
        
    Returns:
        Objek Vehicle yang cocok, atau None jika tidak ditemukan
    """
    norm_ml = normalize_plate(plate_from_ml)
    
    for vehicle in vehicles:
        norm_db = normalize_plate(vehicle.plat_nomor)
        if norm_db == norm_ml:
            return vehicle
    
    return None
