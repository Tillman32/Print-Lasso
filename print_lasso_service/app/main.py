import logging

from fastapi import FastAPI

from app.api.middleware import register_middleware
from app.api.router import api_router
from app.db.init_db import create_db_and_tables
from app.discovery.mdns import register_mdns_service, unregister_mdns_service

logging.basicConfig(level=logging.INFO)

app = FastAPI(title="Print Lasso Service", version="0.1.0")
register_middleware(app)
app.include_router(api_router)


@app.on_event("startup")
async def on_startup() -> None:
    create_db_and_tables()
    await register_mdns_service()


@app.on_event("shutdown")
async def on_shutdown() -> None:
    await unregister_mdns_service()
