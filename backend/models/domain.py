import uuid
from pydantic import BaseModel
from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Text, Boolean
from sqlalchemy.dialects.postgresql import UUID
from datetime import datetime
from backend.db.session import Base

# SQLAlchemy Models
class UserAccount(Base):
    __tablename__ = "users"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String, unique=True, index=True)
    hashed_password = Column(String)
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
    xp_points = Column(Integer, default=0)
    
    # Many-to-many Household Join Code
    join_code = Column(String, unique=True, index=True, nullable=True)
    
    # Cal AI Nutrition Tracking
    activity_level = Column(String, default="moderate") # couch_potato, moderate, active
    diet_goal = Column(String, default="maintain") # lose_weight, maintain, gain_weight
    target_calories = Column(Float, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow)

class PetHouseholdLink(Base):
    __tablename__ = "pet_household_links"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    pet_id = Column(UUID(as_uuid=True), ForeignKey("pet_profiles.id"), index=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), index=True)
    joined_at = Column(DateTime, default=datetime.utcnow)

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

class DietEntry(Base):
    __tablename__ = "diet_entries"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    pet_id = Column(UUID(as_uuid=True), ForeignKey("pet_profiles.id"))
    timestamp = Column(DateTime, default=datetime.utcnow, index=True)
    
    # Nutrition Data parsed by Cal AI Engine
    food_name = Column(String)
    calories = Column(Float)
    proteins_g = Column(Float)
    fats_g = Column(Float)
    raw_query = Column(String) # the natural language string they typed

class FoodCatalog(Base):
    __tablename__ = "food_catalog"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    name = Column(String, index=True)
    brand = Column(String)
    calories_per_serving = Column(Float)
    proteins_per_serving = Column(Float)
    fats_per_serving = Column(Float)
    serving_size_desc = Column(String) # e.g. '1 Cup', '1 Can'

# Pydantic Schemas
class UserRegister(BaseModel):
    email: str
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str
class PetScanResponse(BaseModel):
    id: uuid.UUID
    pet_id: uuid.UUID
    body_condition_score: float
    coat_health_score: float
    eye_clarity_score: float
    dental_plaque_score: float
    raw_detections: str | None = None
    image_url: str
    message: str

    class Config:
        from_attributes = True

class DietEntryResponse(BaseModel):
    id: uuid.UUID
    pet_id: uuid.UUID
    timestamp: datetime
    food_name: str
    calories: float
    proteins_g: float
    fats_g: float
    raw_query: str
    
    class Config:
        from_attributes = True

class PetProfileResponse(BaseModel):
    id: uuid.UUID
    owner_id: uuid.UUID | None
    name: str
    breed: str
    age_months: int
    baseline_weight: float
    xp_points: int
    join_code: str | None = None
    activity_level: str
    diet_goal: str
    target_calories: float | None = None
    
    class Config:
        from_attributes = True

class FoodCatalogResponse(BaseModel):
    id: uuid.UUID
    name: str
    brand: str
    calories_per_serving: float
    proteins_per_serving: float
    fats_per_serving: float
    serving_size_desc: str
    
    class Config:
        from_attributes = True
