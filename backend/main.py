import os
import asyncio
from datetime import datetime, timedelta, timezone
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from database import engine, Base, SessionLocal
import models

# Automatically create all database tables if they do not exist
try:
    Base.metadata.create_all(bind=engine)
except Exception as e:
    print(f"Warning: Could not connect to DB. Ensure MySQL is running. Details: {e}")

# ── Background task: Auto-expire old pending requests ──
REQUEST_EXPIRE_MINUTES = 10

async def expire_old_requests_task():
    """Background task that runs every 60 seconds to auto-expire old pending requests."""
    while True:
        await asyncio.sleep(60)
        try:
            db = SessionLocal()
            cutoff = datetime.now(timezone.utc) - timedelta(minutes=REQUEST_EXPIRE_MINUTES)
            old_requests = db.query(models.AccessRequest).filter(
                models.AccessRequest.status == models.AccessRequestStatusEnum.pending,
                models.AccessRequest.waktu_request < cutoff
            ).all()
            
            for req in old_requests:
                req.status = models.AccessRequestStatusEnum.ditolak
                req.waktu_respon = datetime.now(timezone.utc)
                req.catatan = f"Otomatis kadaluarsa: tidak direspons dalam {REQUEST_EXPIRE_MINUTES} menit"
            
            if old_requests:
                db.commit()
                print(f"[Timer] Auto-expired {len(old_requests)} pending request(s)")
            db.close()
        except Exception as e:
            print(f"[Timer] Error: {e}")

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: launch background timer
    task = asyncio.create_task(expire_old_requests_task())
    print("[Timer] Background request expiry task started (every 60s)")
    yield
    # Shutdown: cancel background task
    task.cancel()

app = FastAPI(title="Smart Campus Parking System API", version="1.0.0", lifespan=lifespan)

@app.exception_handler(SQLAlchemyError)
async def database_exception_handler(request: Request, exc: SQLAlchemyError):
    print(f"[DB] Error while handling {request.method} {request.url.path}: {exc}")
    return JSONResponse(
        status_code=503,
        content={
            "detail": "Database tidak bisa diakses. Cek DATABASE_URL, service MySQL, dan tabel database."
        },
    )

# Setup CORS for the Flutter application
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Serve uploaded STNK photos
UPLOAD_DIR = os.path.join(os.path.dirname(__file__), "uploads")
os.makedirs(UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

@app.get("/health/db")
def read_db_health():
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
        return {"status": "success", "database": "connected"}
    except SQLAlchemyError as exc:
        print(f"[DB] Health check failed: {exc}")
        raise HTTPException(
            status_code=503,
            detail="Database tidak bisa diakses. Cek DATABASE_URL, service MySQL, dan tabel database.",
        )

from routers import auth, admin, mahasiswa, petugas, iot

# Include all the REST API and WebSocket routers
app.include_router(auth.router)
app.include_router(admin.router)
app.include_router(mahasiswa.router)
app.include_router(petugas.router)
app.include_router(iot.router)

# Serve Flutter Web build if it exists (placed at the end as fallback)
web_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "frontend", "build", "web")
if os.path.exists(web_dir):
    print(f"[Web] Serving Flutter Web frontend from {web_dir}")
    app.mount("/", StaticFiles(directory=web_dir, html=True), name="web")
else:
    print("[Web] Web build directory not found, mounting default root response")
    @app.get("/")
    def read_root():
        return {
            "status": "success",
            "message": "Welcome to Smart Campus Parking System API (Frontend web build not found)"
        }
