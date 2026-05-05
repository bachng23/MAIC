from fastapi import APIRouter

from app.api.v1.auth import router as auth_router
from app.api.v1.emergency import router as emergency_router
from app.api.v1.health import router as health_router
from app.api.v1.medications import (
    logs_router,
    router as medications_router,
    schedules_router,
)

api_router = APIRouter(prefix="/api/v1")

api_router.include_router(auth_router)
api_router.include_router(medications_router)
api_router.include_router(schedules_router)
api_router.include_router(logs_router)
api_router.include_router(health_router)
api_router.include_router(emergency_router)
