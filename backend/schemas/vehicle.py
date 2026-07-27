from pydantic import BaseModel
from typing import Optional
from models import VehicleTypeEnum, ValidationStatusEnum

class VehicleBase(BaseModel):
    jenis_kendaraan: VehicleTypeEnum
    plat_nomor: str
    merek: Optional[str] = None
    foto_stnk: Optional[str] = None
    foto_plat_nomor: Optional[str] = None
    catatan: Optional[str] = None

class VehicleCreate(VehicleBase):
    pass

class VehicleResponse(VehicleBase):
    id: int
    user_id: int
    status_validasi: ValidationStatusEnum
    user_nama: Optional[str] = None
    user_nim: Optional[str] = None

    class Config:
        from_attributes = True
