import httpx
from core.config import settings

async def trigger_physical_servo():
    """
    Mengirimkan sinyal ke Firebase Realtime Database untuk memicu ESP32 membuka gerbang fisik.
    """
    # Set the local trigger first to ensure it's updated immediately for HTTP polling
    try:
        from routers import iot
        iot.local_servo_trigger = 1
        print("[Firebase Helper] ✅ local_servo_trigger set to 1")
    except Exception as e:
        print(f"[Firebase Helper] ❌ Error setting local_servo_trigger: {e}")

    if not settings.FIREBASE_DB_URL:
        print("[Firebase Helper] Warning: FIREBASE_DB_URL tidak diatur di backend. Menggunakan HTTP trigger saja.")
        return True
        
    url = f"{settings.FIREBASE_DB_URL.rstrip('/')}/gate/servo_trigger.json"
    params = {}
    if settings.FIREBASE_DB_SECRET:
        params["auth"] = settings.FIREBASE_DB_SECRET
        
    try:
        async with httpx.AsyncClient() as client:
            # Menggunakan PUT untuk mengupdate nilai /gate/servo_trigger menjadi 1
            response = await client.put(url, params=params, json=1, timeout=5)
            if response.status_code == 200:
                print("[Firebase Helper] ✅ Berhasil mengirim sinyal trigger servo ke Firebase.")
                return True
            else:
                print(f"[Firebase Helper] ⚠️ Gagal update Firebase: HTTP {response.status_code} - {response.text}")
    except Exception as e:
        print(f"[Firebase Helper] ❌ Error menghubungi Firebase: {e}")
    return False
