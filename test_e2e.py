import asyncio
import httpx
import uuid
from sqlalchemy.orm import sessionmaker
from backend.models.domain import UserAccount, PetProfile
from backend.services.auth import create_access_token, get_password_hash
from backend.db.session import AsyncSessionLocal

async def test():
    email = f"test_{uuid.uuid4().hex[:6]}@petvision.ai"
    async with AsyncSessionLocal() as db:
        u = UserAccount(id=uuid.uuid4(), email=email, hashed_password=get_password_hash("pass"))
        db.add(u)
        await db.flush()
        pet_id = uuid.uuid4()
        p = PetProfile(id=pet_id, owner_id=u.id, name="B", breed="Pug", age_months=2, baseline_weight=1.0, xp_points=100)
        db.add(p)
        await db.commit()

    token = create_access_token(data={"sub": email})
    headers = {"Authorization": f"Bearer {token}"}
    async with httpx.AsyncClient(base_url="http://127.0.0.1:8000", headers=headers, timeout=30.0) as client:
        r1 = await client.post(f"/nutrition/log/{pet_id}", json={"raw_text": "1 scoop"})
        print(f"Cold hit status: {r1.status_code}")
        r2 = await client.post(f"/nutrition/log/{pet_id}", json={"raw_text": "1 scoop"})
        print(f"Cache hit status: {r2.status_code}")

if __name__ == "__main__":
    asyncio.run(test())
