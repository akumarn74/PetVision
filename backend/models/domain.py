import uuid
from pydantic import BaseModel
from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Text
from sqlalchemy.dialects.postgresql import UUID
from datetime import datetime
from backend.db.session import Base

# SQLAlchemy Models
class UserAccount(Base):
    __tablename__ = "users"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String, unique=True, index=True)
    is_pro = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

class PetProfile(Base):
    __tablename__ = "pet_profiles"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    owner_id = Column(UUID(as_uuid=True), ForeignKey("users.id"))
    name = Column(String, index=True)
    breed = Column(String)
    age_months = Column(Integer)
    baseline_weight = Column(Float)
    created_at = Column(DateTime, default=datetime.utcnow)

class PetScanResult(Base):
    __tablename__ = "pet_scan_results"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    pet_id = Column(UUID(as_uuid=True), ForeignKey("pet_profiles.id"))
    timestamp = Column(DateTime, default=datetime.utcnow, index=True)
    
    # YOLO & Classifier Features
    body_condition_score = Column(Float)
    coat_health_score = Column(Float)
    eye_clarity_score = Column(Float)
    dental_plaque_score = Column(Float)
    
    # Raw JSON detections (bounding boxes, confidence)
    raw_detections = Column(Text)
    image_url = Column(String)

# Pydantic Schemas
class PetScanResponse(BaseModel):
    id: uuid.UUID
    pet_id: uuid.UUID
    body_condition_score: float
    coat_health_score: float
    eye_clarity_score: float
    dental_plaque_score: float
    image_url: str
    message: str

    class Config:
        from_attributes = True

class PetProfileResponse(BaseModel):
    id: uuid.UUID
    owner_id: uuid.UUID | None
    name: str
    breed: str
    age_months: int
    baseline_weight: float
    
    class Config:
        from_attributes = True

