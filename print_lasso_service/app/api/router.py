from fastapi import APIRouter

from app.api.handlers import router as handlers_router

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(handlers_router)
