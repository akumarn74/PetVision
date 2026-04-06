import asyncio
import os
import sys

# Add backend to path explicitly to ensure absolute imports succeed
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from backend.db.session import engine, Base
from backend.models.domain import UserAccount, PetProfile, PetScanResult

async def init_models():
    print("Initializing Database Schemas natively...")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        print("Dropped all schemas cleanly.")
        await conn.run_sync(Base.metadata.create_all)
        print("Created all schemas cleanly.")
        
if __name__ == "__main__":
    asyncio.run(init_models())
