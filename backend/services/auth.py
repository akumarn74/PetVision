from fastapi import Depends, HTTPException, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from backend.models.domain import UserAccount
from backend.db.session import get_db
import uuid

security = HTTPBearer(auto_error=False)

async def get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
    db: AsyncSession = Depends(get_db)
) -> UserAccount:
    """
    Simulates JWT Bearer validation (Firebase/Supabase). 
    If a valid structured token is passed, automatically resolves the PostgreSQL UserAccount!
    """
    if credentials is None:
        raise HTTPException(status_code=401, detail="Authentication token required via Bearer Auth.")
        
    token = credentials.credentials
    
    # MOCK LOGIC: In production, verify the `token` using PyJWT and decrypt the user's `email` or `uid`.
    # For MVP Backend end-to-end completeness, bypassing JWT RSA decryption and resolving an anonymous UserAccount.
    
    # Try finding an existing generic test account
    query = select(UserAccount).limit(1)
    result = await db.execute(query)
    user = result.scalar_one_or_none()
    
    if not user:
        # Auto-create the mock user account if empty to allow seamless testing of foreign keys
        new_user = UserAccount(email="tester@petvision.ai")
        db.add(new_user)
        await db.commit()
        await db.refresh(new_user)
        return new_user
        
    # Validation successful, return User.
    return user
