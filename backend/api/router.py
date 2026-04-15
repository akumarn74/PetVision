from fastapi import APIRouter, File, UploadFile, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from backend.db.session import get_db
from backend.db.session import get_db
from backend.models.domain import PetScanResponse, PetScanResult, PetProfile, PetProfileResponse, DietEntry, DietEntryResponse, PetHouseholdLink, FoodCatalog, FoodCatalogResponse
from backend.services.inference import run_pet_inference
from backend.services.storage import upload_file_to_s3
from backend.services.trends import calculate_30_day_trends
from backend.services.llm import generate_vet_report_summary
from backend.services.diet import parse_unstructured_meal_to_json, generate_dietary_recommendation, calculate_target_calories, parse_food_image_to_json
from backend.api.websockets import manager
from backend.services.auth import get_current_user
from backend.services.billing import check_monthly_ai_quota
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
    # Auto-calibrate the Baseline target calories using the default Lifestyle Goals
    target = await calculate_target_calories(
        profile.name, profile.breed, profile.baseline_weight, profile.age_months,
        "moderate", "maintain"
    )

    import random
    import string
    # Generate 6 character alphanumeric code
    join_code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))
    
    new_pet = PetProfile(
        name=profile.name,
        breed=profile.breed,
        age_months=profile.age_months,
        baseline_weight=profile.baseline_weight,
        owner_id=current_user.id,
        target_calories=target,
        join_code=join_code
    )
    db.add(new_pet)
    await db.commit()
    await db.refresh(new_pet)
    
    # Insert Household mapping
    household_link = PetHouseholdLink(pet_id=new_pet.id, user_id=current_user.id)
    db.add(household_link)
    await db.commit()
    
    return {"pet_id": new_pet.id, "message": "Pet profile created", "target_calories": target}

from backend.services.inference import run_onboarding_inference

@router.post("/pets/auto-detect")
async def auto_detect_pet(
    file: UploadFile = File(...),
    current_user: UserAccount = Depends(get_current_user)
):
    """Takes a raw photo and uses Vision AI to guess the breed and weight for form auto-filling."""
    file_bytes = await file.read()
    try:
        detection = await run_onboarding_inference(file_bytes)
        return detection
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

from sqlalchemy import select, delete, update

@router.get("/pets", response_model=list[PetProfileResponse])
async def list_pets(
    db: AsyncSession = Depends(get_db),
    current_user: UserAccount = Depends(get_current_user)
):
    """Fetches all pets tied to the user via Household logic."""
    query = select(PetProfile).join(PetHouseholdLink, PetProfile.id == PetHouseholdLink.pet_id).where(PetHouseholdLink.user_id == current_user.id)
    result = await db.execute(query)
    return result.scalars().all()

class JoinPetRequest(BaseModel):
    join_code: str

@router.post("/pets/join")
async def join_pet_household(
    req: JoinPetRequest,
    db: AsyncSession = Depends(get_db),
    current_user: UserAccount = Depends(get_current_user)
):
    code = req.join_code.strip().upper()
    query = select(PetProfile).where(PetProfile.join_code == code)
    result = await db.execute(query)
    pet = result.scalar_one_or_none()
    
    if not pet:
        raise HTTPException(status_code=404, detail="Invalid Join Code.")
        
    # check if already linked
    check_query = select(PetHouseholdLink).where(PetHouseholdLink.pet_id == pet.id, PetHouseholdLink.user_id == current_user.id)
    check_res = await db.execute(check_query)
    if check_res.scalar_one_or_none():
         raise HTTPException(status_code=400, detail="You are already mapped to this pet household.")
         
    link = PetHouseholdLink(pet_id=pet.id, user_id=current_user.id)
    db.add(link)
    await db.commit()
    return {"message": f"Successfully joined {pet.name}'s household!"}

from sqlalchemy import func

@router.delete("/pets/{pet_id}")
async def delete_pet(
    pet_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: UserAccount = Depends(get_current_user)
):
    """Safely unlinks a user from a pet household, conditionally cascading deletion if they are the last owner."""
    await verify_pet_ownership(pet_id, current_user.id, db)
    
    # 1. Unlink this specific user from the Household
    await db.execute(delete(PetHouseholdLink).where(PetHouseholdLink.pet_id == pet_id, PetHouseholdLink.user_id == current_user.id))
    await db.commit()
    
    # 2. Check remaining owners
    count_query = select(func.count(PetHouseholdLink.id)).where(PetHouseholdLink.pet_id == pet_id)
    count_result = await db.execute(count_query)
    remaining = count_result.scalar() or 0
    
    # 3. If nobody is left in the household, safely execute the master wipe
    if remaining == 0:
        await db.execute(delete(PetProfile).where(PetProfile.id == pet_id))
        await db.commit()
        return {"message": "Pet entirely deleted from system.", "remaining_owners": 0}
        
    return {"message": "You have left the pet's household successfully.", "remaining_owners": remaining}

async def verify_pet_ownership(pet_id: uuid.UUID, owner_id: uuid.UUID, db: AsyncSession):
    # Co-parenting authorization: Must exist in Household Link
    query = select(PetHouseholdLink.id).where(PetHouseholdLink.pet_id == pet_id, PetHouseholdLink.user_id == owner_id)
    result = await db.execute(query)
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=403, detail="Not authorized to access this pet household.")

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
        await check_monthly_ai_quota(db, current_user)
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
            
            # Incremental XP boost
            await db.execute(update(PetProfile).where(PetProfile.id == pet_id).values(xp_points=PetProfile.xp_points + 200))
            
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
    await check_monthly_ai_quota(db, current_user)
    
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
    
    # +200 XP Gamification Hook for health scan
    await db.execute(update(PetProfile).where(PetProfile.id == pet_id).values(xp_points=PetProfile.xp_points + 200))
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


class DietLogRequest(BaseModel):
    raw_text: str

@router.post("/nutrition/log/{pet_id}", response_model=DietEntryResponse)
async def log_pet_meal(
    pet_id: uuid.UUID,
    data: DietLogRequest,
    db: AsyncSession = Depends(get_db),
    current_user: UserAccount = Depends(get_current_user)
):
    await verify_pet_ownership(pet_id, current_user.id, db)
    await check_monthly_ai_quota(db, current_user)
    
    # 1. Fetch Profile
    profile_query = select(PetProfile).where(PetProfile.id == pet_id)
    profile = (await db.execute(profile_query)).scalar_one_or_none()
    
    # 2. Rip NLP context to JSON (Check Semantic Cache First)
    clean_query = data.raw_text.strip().lower()
    semantic_cache_query = select(DietEntry).where(DietEntry.raw_query.ilike(clean_query)).limit(1)
    cached_entry = (await db.execute(semantic_cache_query)).scalar_one_or_none()
    
    if cached_entry:
        macros = {
            "food_name": cached_entry.food_name,
            "calories": float(cached_entry.calories),
            "proteins_g": float(cached_entry.proteins_g),
            "fats_g": float(cached_entry.fats_g)
        }
    else:
        macros = await parse_unstructured_meal_to_json(data.raw_text, profile.name, profile.breed, profile.baseline_weight)
    
    # 3. Save
    entry = DietEntry(
        pet_id=pet_id,
        food_name=macros["food_name"],
        calories=macros["calories"],
        proteins_g=macros["proteins_g"],
        fats_g=macros["fats_g"],
        raw_query=data.raw_text
    )
    db.add(entry)
    # +50 XP Gamification Hook for meal log
    await db.execute(update(PetProfile).where(PetProfile.id == pet_id).values(xp_points=PetProfile.xp_points + 50))
    await db.commit()
    await db.refresh(entry)
    
    return entry

from datetime import datetime, time

@router.get("/nutrition/recommendation/{pet_id}")
async def get_dietary_recommendation(
    pet_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: UserAccount = Depends(get_current_user)
):
    await verify_pet_ownership(pet_id, current_user.id, db)
    
    # Get profile
    profile = (await db.execute(select(PetProfile).where(PetProfile.id == pet_id))).scalar_one_or_none()
    
    # Get latest Body Condition CV Score
    latest_scan_query = select(PetScanResult).where(PetScanResult.pet_id == pet_id).order_by(PetScanResult.timestamp.desc()).limit(1)
    scan = (await db.execute(latest_scan_query)).scalar_one_or_none()
    bcs = scan.body_condition_score if scan else 50.0

    # Calculate today's caloric intake via DB
    today_start = datetime.combine(datetime.utcnow().date(), time.min)
    meals_query = select(DietEntry).where(DietEntry.pet_id == pet_id, DietEntry.timestamp >= today_start)
    meals = (await db.execute(meals_query)).scalars().all()
    today_kcal = sum([m.calories for m in meals])
    
    # Query AI
    recommendation = await generate_dietary_recommendation(
        profile.name, profile.breed, profile.baseline_weight, bcs, today_kcal
    )
    
    return {
        "today_calories": today_kcal,
        "target_calories": profile.target_calories if profile.target_calories else 1000.0,
        "meals_logged": len(meals),
        "ai_recommendation": recommendation,
        "recent_meals": [{"id": str(m.id), "food_name": m.food_name, "calories": m.calories} for m in meals]
    }

class SetupDietRequest(BaseModel):
    activity_level: str
    diet_goal: str

@router.post("/nutrition/setup/{pet_id}")
async def setup_pet_diet(
    pet_id: uuid.UUID,
    data: SetupDietRequest,
    db: AsyncSession = Depends(get_db),
    current_user: UserAccount = Depends(get_current_user)
):
    await verify_pet_ownership(pet_id, current_user.id, db)
    
    profile = (await db.execute(select(PetProfile).where(PetProfile.id == pet_id))).scalar_one_or_none()
    profile.activity_level = data.activity_level
    profile.diet_goal = data.diet_goal
    
    # Calculate their new limit
    target = await calculate_target_calories(
        profile.name, profile.breed, profile.baseline_weight, profile.age_months,
        profile.activity_level, profile.diet_goal
    )
    profile.target_calories = target
    
    await db.commit()
    return {"target_calories": target}

class DietImageLogRequest(BaseModel):
    image_base64: str

@router.post("/nutrition/log_image/{pet_id}", response_model=DietEntryResponse)
async def log_pet_meal_image(
    pet_id: uuid.UUID,
    data: DietImageLogRequest,
    db: AsyncSession = Depends(get_db),
    current_user: UserAccount = Depends(get_current_user)
):
    await verify_pet_ownership(pet_id, current_user.id, db)
    await check_monthly_ai_quota(db, current_user)
    profile = (await db.execute(select(PetProfile).where(PetProfile.id == pet_id))).scalar_one_or_none()
    
    # GPT-4o Vision Pipeline
    macros = await parse_food_image_to_json(
        data.image_base64, profile.name, profile.breed, profile.baseline_weight, profile.diet_goal
    )
    
    entry = DietEntry(
        pet_id=pet_id,
        food_name=macros["food_name"],
        calories=macros["calories"],
        proteins_g=macros["proteins_g"],
        fats_g=macros["fats_g"],
        raw_query="[IMAGE SCAN]"
    )
    db.add(entry)
    # +50 XP Gamification Hook for CV meal log
    await db.execute(update(PetProfile).where(PetProfile.id == pet_id).values(xp_points=PetProfile.xp_points + 50))
    await db.commit()
    await db.refresh(entry)
    
    return entry

from backend.services.llm import generate_personalized_push

@router.get("/notifications/daily/{pet_id}")
async def get_daily_notification(
    pet_id: uuid.UUID, 
    db: AsyncSession = Depends(get_db),
    current_user: UserAccount = Depends(get_current_user)
):
    """Dynamically generates a sassy/humorous push notification banner payload using GPT-4o-mini."""
    await verify_pet_ownership(pet_id, current_user.id, db)
    
    profile = (await db.execute(select(PetProfile).where(PetProfile.id == pet_id))).scalar_one_or_none()
    if not profile:
        raise HTTPException(status_code=404, detail="Pet not found.")
    
    msg = await generate_personalized_push(profile.name, profile.breed, profile.diet_goal)
    return {"message": msg}

@router.get("/users/streak")
async def get_user_activity_streak(
    db: AsyncSession = Depends(get_db),
    current_user: UserAccount = Depends(get_current_user)
):
    """Calculates consecutive days of app usage (Diet logging or Pet scans) for DAU gamification."""
    import datetime
    
    # Needs to get all pets owned by this user
    pets_query = select(PetProfile.id).where(PetProfile.owner_id == current_user.id)
    pets = (await db.execute(pets_query)).scalars().all()
    
    if not pets:
        return {"streak": 0}
        
    dates_with_activity = set()
    
    # 1. Fetch diet entry dates
    diet_query = select(DietEntry.timestamp).where(DietEntry.pet_id.in_(pets))
    diet_results = (await db.execute(diet_query)).scalars().all()
    for ts in diet_results:
        dates_with_activity.add(ts.date())
        
    # 2. Fetch scan dates
    scan_query = select(PetScanResult.timestamp).where(PetScanResult.pet_id.in_(pets))
    scan_results = (await db.execute(scan_query)).scalars().all()
    for ts in scan_results:
        dates_with_activity.add(ts.date())
        
    if not dates_with_activity:
        return {"streak": 0}
        
    activity_dates = sorted(list(dates_with_activity), reverse=True)
    today = datetime.datetime.utcnow().date()
    yesterday = today - datetime.timedelta(days=1)
    
    streak = 0
    current_check_date = today
    
    if today in activity_dates:
        streak = 1
        idx = activity_dates.index(today)
    elif yesterday in activity_dates:
        streak = 1
        current_check_date = yesterday
        idx = activity_dates.index(yesterday)
    else:
        return {"streak": 0}
        
    for d in activity_dates[idx+1:]:
        current_check_date = current_check_date - datetime.timedelta(days=1)
        if d == current_check_date:
            streak += 1
        else:
            break
            
    return {"streak": streak}


@router.get("/leaderboard")
async def get_global_leaderboard(db: AsyncSession = Depends(get_db)):
    """Fetches the top 50 healthiest pets globally."""
    query = select(PetProfile.id, PetProfile.name, PetProfile.breed, PetProfile.xp_points).order_by(PetProfile.xp_points.desc()).limit(50)
    result = await db.execute(query)
    pets = result.all()
    return [{"id": p.id, "name": p.name, "breed": p.breed, "xp_points": p.xp_points} for p in pets]

@router.get("/nutrition/search", response_model=list[FoodCatalogResponse])
async def search_food_catalog(
    q: str = "",
    db: AsyncSession = Depends(get_db)
):
    """Lightning fast SQL ILIKE typeahead search for known dog/cat food."""
    query = select(FoodCatalog).where(FoodCatalog.name.ilike(f"%{q}%")).limit(10)
    result = await db.execute(query)
    return result.scalars().all()

class LogPredefinedRequest(BaseModel):
    food_id: str

@router.post("/nutrition/log_predefined/{pet_id}", response_model=DietEntryResponse)
async def log_predefined_food(
    pet_id: uuid.UUID,
    data: LogPredefinedRequest,
    db: AsyncSession = Depends(get_db),
    current_user: UserAccount = Depends(get_current_user)
):
    """Bypasses LLM entirely, instantly mapping a SQLite predefined macro set into the Pet's timeline +50 XP"""
    await verify_pet_ownership(pet_id, current_user.id, db)
    
    # fetch the food
    food = (await db.execute(select(FoodCatalog).where(FoodCatalog.id == uuid.UUID(data.food_id)))).scalar_one_or_none()
    if not food:
        raise HTTPException(status_code=404, detail="Food item not found in catalog.")
        
    entry = DietEntry(
        pet_id=pet_id,
        food_name=food.name,
        calories=food.calories_per_serving,
        proteins_g=food.proteins_per_serving,
        fats_g=food.fats_per_serving,
        raw_query=f"[TYPEAHEAD] {food.name}"
    )
    db.add(entry)
    from sqlalchemy import update
    await db.execute(update(PetProfile).where(PetProfile.id == pet_id).values(xp_points=PetProfile.xp_points + 50))
    await db.commit()
    await db.refresh(entry)
    
    return entry

@router.delete("/nutrition/{entry_id}")
async def delete_diet_entry(
    entry_id: uuid.UUID,
    db: AsyncSession = Depends(get_db),
    current_user: UserAccount = Depends(get_current_user)
):
    """Deletes a diet entry after validating ownership of the associated pet"""
    result = await db.execute(select(DietEntry).where(DietEntry.id == entry_id))
    entry = result.scalar_one_or_none()
    if not entry:
        raise HTTPException(status_code=404, detail="Diet entry not found.")
        
    await verify_pet_ownership(entry.pet_id, current_user.id, db)
    
    await db.delete(entry)
    
    # Optional: dock 50 XP if deleted? We'll leave XP as is for grace periods.
    await db.commit()
    return {"status": "deleted"}
