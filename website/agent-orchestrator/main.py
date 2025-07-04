import os
import asyncio
import signal
import sys
from fastapi import FastAPI, HTTPException, Depends
from loguru import logger
import uvicorn

from app.database import init_db, close_db
from app.redis_client import init_redis, close_redis
from app.agents import init_agents
from app.routers import agent_router, orchestration_router
from app.health import HealthCheck

# Configure logging
logger.remove()
logger.add(
    sys.stdout,
    format="{time:YYYY-MM-DD HH:mm:ss} | {level} | {message}",
    level=os.getenv("LOG_LEVEL", "INFO").upper(),
)

app = FastAPI(
    title="ClarityXDR Agent Orchestrator",
    description="Orchestrates AI agents for security operations and business functions",
    version="1.0.0",
)

# Health check
health_check = HealthCheck()

@app.get("/health", tags=["Health"])
async def health():
    return await health_check.check_health()

# Include routers
app.include_router(agent_router.router, prefix="/agents", tags=["Agents"])
app.include_router(orchestration_router.router, prefix="/orchestrate", tags=["Orchestration"])

@app.on_event("startup")
async def startup_event():
    logger.info("Starting ClarityXDR Agent Orchestrator...")
    await init_db()
    await init_redis()
    await init_agents()
    health_check.register_db()
    health_check.register_redis()
    logger.info("Agent Orchestrator started successfully")

@app.on_event("shutdown")
async def shutdown_event():
    logger.info("Shutting down ClarityXDR Agent Orchestrator...")
    await close_redis()
    await close_db()
    logger.info("Agent Orchestrator shut down successfully")

def handle_sigterm(signum, frame):
    logger.info("Received SIGTERM. Shutting down gracefully...")
    sys.exit(0)

# Register signal handler
signal.signal(signal.SIGTERM, handle_sigterm)

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=9000,
        reload=False,
        log_level=os.getenv("LOG_LEVEL", "info").lower(),
    )
