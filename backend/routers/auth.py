from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from datetime import timedelta

import models
from schemas.user import Token, UserProfile
from core.security import verify_password, create_access_token, get_current_user, get_password_hash
from core.config import settings
from database import get_db

router = APIRouter(prefix="/api/auth", tags=["Authentication"])

@router.get("/me", response_model=UserProfile)
def get_me(current_user: models.User = Depends(get_current_user)):
    return UserProfile.from_orm(current_user)

@router.post("/login", response_model=Token)
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    # form_data.username will securely map to the unique nim_npp in this system
    user = db.query(models.User).filter(models.User.nim_npp == form_data.username).first()
    
    if not user or not verify_password(form_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="NIM/NPP atau password salah",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.nim_npp}, expires_delta=access_token_expires
    )
    
    return {
        "access_token": access_token, 
        "token_type": "bearer", 
        "role": user.role,
        "nama": user.nama,
        "nim_npp": user.nim_npp
    }

from pydantic import BaseModel
class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str

@router.post("/change-password")
def change_password(req: ChangePasswordRequest, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    if not verify_password(req.old_password, current_user.password_hash):
        raise HTTPException(status_code=400, detail="Password lama salah")
    current_user.password_hash = get_password_hash(req.new_password)
    db.commit()
    return {"status": "success", "message": "Password berhasil diubah"}

class ProfileUpdate(BaseModel):
    nama: str
    nim_npp: str

@router.put("/profile", response_model=UserProfile)
def update_profile(req: ProfileUpdate, current_user: models.User = Depends(get_current_user), db: Session = Depends(get_db)):
    if current_user.role != models.RoleEnum.admin:
        raise HTTPException(status_code=403, detail="Hanya admin yang dapat mengubah profil")
    
    if req.nim_npp != current_user.nim_npp:
        existing = db.query(models.User).filter(models.User.nim_npp == req.nim_npp).first()
        if existing:
            raise HTTPException(status_code=400, detail="NIP/NPP sudah digunakan")
            
    current_user.nama = req.nama
    current_user.nim_npp = req.nim_npp
    db.commit()
    db.refresh(current_user)
    return UserProfile.from_orm(current_user)
