from fastapi import FastAPI
from contextlib import asynccontextmanager
from backend.api.router import router as api_router
from backend.api.websockets import router as ws_router
from backend.api.auth import router as auth_router
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

from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title="PetVision AI",
    description="Backend for the PetVision AI Mobile App",
    version="0.1.0",
    lifespan=lifespan
)

# Enable CORS specifically so Flutter Web (Chrome) running on random local ports can fetch data seamlessly!
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Adjust this in production, but wildcard is vital for local Flutter Chrome!
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router, prefix="/api/auth", tags=["auth"])
app.include_router(api_router, prefix="/api")
app.include_router(ws_router)

@app.get("/health")
async def health_check():
    return {"status": "ok", "message": "PetVision AI is running (Phase 1)"}
