from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_
from backend.models.domain import UserAccount, PetProfile, PetScanResult
from fastapi import HTTPException
from datetime import datetime
import calendar

# Standard limits (would be fetched from Stripe or DB configs)
FREE_TIER_SCAN_LIMIT = 3

async def check_monthly_scan_quota(db: AsyncSession, user: UserAccount) -> bool:
    """
    Validates if an authenticated user has exceeded their free monthly scans across all pets.
    Returns True if allowed. Raises an HTTPException if blocked!
    """
    
    # In production, check `user.is_pro` status first:
    if getattr(user, "is_pro", False): 
        return True
    
    now = datetime.utcnow()
    # First day of the current month
    start_of_month = datetime(now.year, now.month, 1)
    
    # 1. Gather all Pet IDs owned by this user
    pet_query = select(PetProfile.id).where(PetProfile.owner_id == user.id)
    pet_results = await db.execute(pet_query)
    owned_pet_ids = [row for row in pet_results.scalars().all()]
    
    if not owned_pet_ids:
        # You can't scan a pet you don't own!
        return True

    # 2. Count all scans made this month linked to these specific pets
    scan_count_query = select(func.count(PetScanResult.id)).where(
        and_(
            PetScanResult.pet_id.in_(owned_pet_ids),
            PetScanResult.timestamp >= start_of_month
        )
    )
    result = await db.execute(scan_count_query)
    monthly_scans = result.scalar_one()

    if monthly_scans >= FREE_TIER_SCAN_LIMIT:
        raise HTTPException(
            status_code=402, 
            detail=f"Payment Required: You have reached the Free Tier limit of {FREE_TIER_SCAN_LIMIT} scans per month. Please upgrade to Pro."
        )
    
    return True
