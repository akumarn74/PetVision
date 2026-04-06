from fastapi import APIRouter, File, UploadFile, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from backend.db.session import get_db
from backend.models.domain import PetScanResponse, PetScanResult, PetProfile, PetProfileResponse
from backend.services.inference import run_pet_inference
from backend.services.storage import upload_file_to_s3
from backend.services.trends import calculate_30_day_trends
from backend.services.llm import generate_vet_report_summary
from backend.api.websockets import manager
from backend.services.auth import get_current_user
from backend.services.billing import check_monthly_scan_quota
from backend.models.domain import UserAccount
import uuid
import json

from pydantic import BaseModel

router = APIRouter()

class PetProfileCreate(BaseModel):
    name: str
    breed: str
    age_months: int
    baseline_weight: float
    owner_id: uuid.UUID | None = None

@router.post("/pets")
async def create_pet_profile(
    profile: PetProfileCreate, 
    db: AsyncSession = Depends(get_db),
    current_user: UserAccount = Depends(get_current_user)
):
    new_pet = PetProfile(
        name=profile.name,
        breed=profile.breed,
        age_months=profile.age_months,
        baseline_weight=profile.baseline_weight,
        owner_id=current_user.id
    )
    db.add(new_pet)
    await db.commit()
    await db.refresh(new_pet)
    return {"pet_id": new_pet.id, "message": "Pet profile created"}

from sqlalchemy import select, delete

@router.get("/pets", response_model=list[PetProfileResponse])
async def list_pets(
    db: AsyncSession = Depends(get_db),
    current_user: UserAccount = Depends(get_current_user)
):
    """Fetches all pets currently matching an explicit signed-in user."""
    query = select(PetProfile).where(PetProfile.owner_id == current_user.id)
    result = await db.execute(query)
    return result.scalars().all()

@router.delete("/pets/{pet_id}")
async def delete_pet(
    pet_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: UserAccount = Depends(get_current_user)
):
    """Deletes a pet entirely securely enforcing ownership."""
    await verify_pet_ownership(pet_id, current_user.id, db)
    await db.execute(delete(PetProfile).where(PetProfile.id == pet_id))
    await db.commit()
    return {"message": "Pet deleted successfully."}

async def verify_pet_ownership(pet_id: uuid.UUID, owner_id: uuid.UUID, db: AsyncSession):
    query = select(PetProfile.id).where(PetProfile.id == pet_id, PetProfile.owner_id == owner_id)
    result = await db.execute(query)
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="Not authorized to access this pet.")

@router.get("/pets/{pet_id}/scans", response_model=list[PetScanResponse])
async def list_pet_scans(
    pet_id: uuid.UUID, 
    db: AsyncSession = Depends(get_db),
    current_user: UserAccount = Depends(get_current_user)
):
    """Fetches historic scans dynamically."""
    await verify_pet_ownership(pet_id, current_user.id, db)
    query = select(PetScanResult).where(PetScanResult.pet_id == pet_id).order_by(PetScanResult.timestamp.desc())
    result = await db.execute(query)
    return result.scalars().all()

from fastapi import File, UploadFile
from typing import List

@router.post("/sync/scans/{pet_id}")
async def sync_offline_scans(
    pet_id: uuid.UUID,
    files: List[UploadFile] = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: UserAccount = Depends(get_current_user)
):
    """
    Offline Sync Hook: Flutter devices periodically flush their cache of cached images here.
    Ingests an entire batch loop of YOLO evaluations securely.
    """
    await verify_pet_ownership(pet_id, current_user.id, db)
    
    responses = []
    for file in files:
        await check_monthly_scan_quota(db, current_user)
        try:
            file_bytes = await file.read()
            image_url = await upload_file_to_s3(file, pet_id)
            inference_results = run_pet_inference(file_bytes)
            metrics = inference_results["metrics"]
            new_scan = PetScanResult(
                pet_id=pet_id,
                body_condition_score=metrics["body_condition_score"],
                coat_health_score=metrics["coat_health_score"],
                eye_clarity_score=metrics["eye_clarity_score"],
                dental_plaque_score=metrics["dental_plaque_score"],
                raw_detections=json.dumps(inference_results["detections"]),
                image_url=image_url
            )
            db.add(new_scan)
            await db.commit()
            await db.refresh(new_scan)
            responses.append({"filename": file.filename, "status": "success", "id": new_scan.id})
        except Exception as e:
            responses.append({"filename": file.filename, "status": "error", "message": str(e)})

    return {"sync_results": responses}

@router.post("/scans/{pet_id}", response_model=PetScanResponse)
async def process_new_scan(
    pet_id: uuid.UUID,
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
    current_user: UserAccount = Depends(get_current_user)
):
    """
    Receives a 10-second burst or photo, runs YOLO, stores the metrics into Timescale.
    """
    await verify_pet_ownership(pet_id, current_user.id, db)
    await check_monthly_scan_quota(db, current_user)
    
    await manager.broadcast_status(pet_id, "ingesting", {"message": "Uploading camera burst safely..."})
    try:
        # Fetch Pet Profile to pass expected Identity Data to Vision Model
        profile_query = select(PetProfile).where(PetProfile.id == pet_id)
        profile_result = await db.execute(profile_query)
        pet = profile_result.scalar_one_or_none()
        expected_name = pet.name if pet else "Your pet"
        expected_breed = pet.breed if pet else "Unknown pet"

        # 1. Read bytes for Inference
        file_bytes = await file.read()
        
        # 2. Upload file to MinIO storage asynchronously
        image_url = await upload_file_to_s3(file, pet_id)
        
        # 3. Process with GPT-4o Vision
        await manager.broadcast_status(pet_id, "processing", {"message": "Running Multi-Modal Vision AI Pipeline..."})
        inference_results = await run_pet_inference(file_bytes, expected_name, expected_breed)
        
        # 3B. ANTI-FRAUD GATING
        detections = inference_results["detections"]
        if detections.get("is_fraud", False):
            fraud_reason = detections.get("fraud_reason", "The image does not appear to match the documented pet species or breed.")
            await manager.broadcast_status(pet_id, "error", {"message": fraud_reason})
            raise HTTPException(status_code=400, detail=f"IDENTITY MISMATCH: {fraud_reason}")
            
    except HTTPException:
        raise
    except Exception as e:
        await manager.broadcast_status(pet_id, "error", {"message": str(e)})
        raise HTTPException(status_code=500, detail=f"Pipeline Error: {str(e)}")
    
    metrics = inference_results["metrics"]

    # 4. Save to TimescaleDB
    new_scan = PetScanResult(
        pet_id=pet_id,
        body_condition_score=metrics["body_condition_score"],
        coat_health_score=metrics["coat_health_score"],
        eye_clarity_score=metrics["eye_clarity_score"],
        dental_plaque_score=metrics["dental_plaque_score"],
        raw_detections=json.dumps(inference_results["detections"]),
        image_url=image_url
    )
    db.add(new_scan)
    await db.commit()
    await db.refresh(new_scan)
    
    await manager.broadcast_status(pet_id, "completed", {"message": "Inference and database insertion verified."})
    
    # 5. Return success result
    return PetScanResponse(
        id=new_scan.id,
        pet_id=pet_id,
        body_condition_score=new_scan.body_condition_score,
        coat_health_score=new_scan.coat_health_score,
        eye_clarity_score=new_scan.eye_clarity_score,
        dental_plaque_score=new_scan.dental_plaque_score,
        raw_detections=new_scan.raw_detections,
        image_url=image_url,
        message="Scan completed and saved successfully."
    )

@router.get("/scans/{pet_id}/trends")
async def get_pet_longitudinal_trends(
    pet_id: uuid.UUID, 
    db: AsyncSession = Depends(get_db),
    current_user: UserAccount = Depends(get_current_user)
):
    """
    Returns the 30-day moving average and delta percentage trends for a pet's health.
    """
    await verify_pet_ownership(pet_id, current_user.id, db)
    trends = await calculate_30_day_trends(db, pet_id)
    return trends

@router.get("/scans/{pet_id}/vet_report")
async def get_vet_ready_report(
    pet_id: uuid.UUID, 
    db: AsyncSession = Depends(get_db),
    current_user: UserAccount = Depends(get_current_user)
):
    """
    Synthesizes the LLM Veterinary Report analyzing the latest CV metrics and historical trends.
    """
    await verify_pet_ownership(pet_id, current_user.id, db)
    
    # Grab pet info
    profile_query = select(PetProfile).where(PetProfile.id == pet_id)
    profile_result = await db.execute(profile_query)
    profile = profile_result.scalar_one_or_none()
    pet_name = profile.name if profile else "Your pet"
    
    trends_dict = await calculate_30_day_trends(db, pet_id)
    summary = await generate_vet_report_summary(pet_name, trends_dict, trends_dict.get("insights", []))
    
    return {"vet_report": summary, "pet_id": pet_id}

