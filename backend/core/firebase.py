import httpx
from core.config import settings

async def trigger_physical_servo(gate_id: str = "GATE_MASUK_1"):
    """
    Mengirimkan sinyal ke Firebase Realtime Database untuk memicu ESP32 membuka gerbang fisik.
    """
    # Set the local trigger first to ensure it's updated immediately for HTTP polling
    try:
        from routers import iot
        iot.local_servo_trigger = 1
        print(f"[Firebase Helper] [OK] local_servo_trigger set to 1 for {gate_id}")
    except Exception as e:
        print(f"[Firebase Helper] [ERROR] Error setting local_servo_trigger: {e}")

    if not settings.FIREBASE_DB_URL:
        print("[Firebase Helper] Warning: FIREBASE_DB_URL tidak diatur di backend. Menggunakan HTTP trigger saja.")
        return True
        
    url = f"{settings.FIREBASE_DB_URL.rstrip('/')}/gates/{gate_id}/servo_trigger.json"
    params = {}
    if settings.FIREBASE_DB_SECRET:
        params["auth"] = settings.FIREBASE_DB_SECRET
        
    try:
        async with httpx.AsyncClient() as client:
            # Menggunakan PUT untuk mengupdate nilai /gates/{gate_id}/servo_trigger menjadi 1
            response = await client.put(url, params=params, json=1, timeout=5)
            if response.status_code == 200:
                print(f"[Firebase Helper] [OK] Berhasil mengirim sinyal trigger servo ke Firebase untuk {gate_id}.")
                return True
            else:
                print(f"[Firebase Helper] [WARN] Gagal update Firebase: HTTP {response.status_code} - {response.text}")
    except Exception as e:
        print(f"[Firebase Helper] [ERROR] Error menghubungi Firebase: {e}")
    return False


async def reset_physical_servo(gate_id: str = "GATE_MASUK_1"):
    """
    Mengirimkan sinyal ke Firebase Realtime Database untuk mengatur kembali servo_trigger menjadi 0.
    """
    if not settings.FIREBASE_DB_URL:
        return True
        
    url = f"{settings.FIREBASE_DB_URL.rstrip('/')}/gates/{gate_id}/servo_trigger.json"
    params = {}
    if settings.FIREBASE_DB_SECRET:
        params["auth"] = settings.FIREBASE_DB_SECRET
        
    try:
        async with httpx.AsyncClient() as client:
            # Menggunakan PUT untuk mengupdate nilai /gates/{gate_id}/servo_trigger menjadi 0
            response = await client.put(url, params=params, json=0, timeout=5)
            if response.status_code == 200:
                print(f"[Firebase Helper] [OK] Berhasil mereset servo_trigger ke 0 di Firebase untuk {gate_id}.")
                return True
            else:
                print(f"[Firebase Helper] [WARN] Gagal reset Firebase: HTTP {response.status_code} - {response.text}")
    except Exception as e:
        print(f"[Firebase Helper] [ERROR] Error menghubungi Firebase saat reset: {e}")
    return False

