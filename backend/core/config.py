from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    PROJECT_NAME: str = "Smart Campus Parking System"
    # Password dihapus, tersisa root:
    DATABASE_URL: str = "mysql+pymysql://root:@localhost:3306/smart_parking_db"
    
    # Secret keys for JWT
    SECRET_KEY: str = "super_secret_jwt_key_here"  # In production, use env variables
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 1440 # 24 hours

    # ANPR service runs in a separate container/process.
    # Backend calls this service only when a gate request needs camera OCR.
    ANPR_SERVICE_URL: str = "http://127.0.0.1:5000"
    ANPR_SCAN_TIMEOUT_SECONDS: float = 15.0

    # Firebase Realtime Database Settings for physical servo integration
    FIREBASE_DB_URL: str = "https://parking-system-2546df-default-rtdb.firebaseio.com"
    FIREBASE_DB_SECRET: str = "lwFhrCtxQwicVlNIuitXN98Dup4ESSdYSXKSKMdn"

    class Config:
        env_file = ".env"

settings = Settings()
