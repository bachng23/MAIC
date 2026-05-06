from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1.router import api_router
from app.services.emergency_service import resume_pending_escalations
from app.services.reminder_scheduler import shutdown_scheduler, start_scheduler


@asynccontextmanager
async def lifespan(_: FastAPI):
    await start_scheduler()
    await resume_pending_escalations()
    try:
        yield
    finally:
        await shutdown_scheduler()

app = FastAPI(
    title="MediGuard API",
    description="AI Health Support for Elderly in Taiwan",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router)


@app.get("/health")
async def health_check():
    return {"status": "ok"}
