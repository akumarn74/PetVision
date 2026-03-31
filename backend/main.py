from fastapi import FastAPI
from contextlib import asynccontextmanager
from backend.api.router import router as api_router
from backend.api.websockets import router as ws_router
from backend.db.session import engine, Base

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Setup actions (load models etc)
    print("Starting PetVision AI backend...")
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    # Cleanup actions
    print("Shutting down...")

app = FastAPI(
    title="PetVision AI",
    description="Backend for the PetVision AI Mobile App",
    version="0.1.0",
    lifespan=lifespan
)

app.include_router(api_router, prefix="/api")
app.include_router(ws_router)

@app.get("/health")
async def health_check():
    return {"status": "ok", "message": "PetVision AI is running (Phase 1)"}
