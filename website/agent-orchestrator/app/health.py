import time
from loguru import logger

class HealthCheck:
    def __init__(self):
        self.services = {}
        self.startup_time = time.time()
    
    def register_db(self):
        from app.database import get_db_pool
        self.services["database"] = get_db_pool
    
    def register_redis(self):
        from app.redis_client import get_redis
        self.services["redis"] = get_redis
    
    async def check_health(self):
        """Check health of all registered services"""
        status = "healthy"
        checks = {}
        uptime = int(time.time() - self.startup_time)
        
        # Check database
        if "database" in self.services:
            try:
                pool = self.services["database"]()
                async with pool.acquire() as conn:
                    result = await conn.fetchval("SELECT 1")
                checks["database"] = {"status": "up" if result == 1 else "down"}
            except Exception as e:
                logger.error(f"Database health check failed: {str(e)}")
                checks["database"] = {"status": "down", "error": str(e)}
                status = "unhealthy"
        
        # Check Redis
        if "redis" in self.services:
            try:
                redis = self.services["redis"]()
                await redis.ping()
                checks["redis"] = {"status": "up"}
            except Exception as e:
                logger.error(f"Redis health check failed: {str(e)}")
                checks["redis"] = {"status": "down", "error": str(e)}
                status = "unhealthy"
        
        # Return the health check result
        return {
            "status": status,
            "uptime": uptime,
            "checks": checks,
            "service": "clarityxdr-agent-orchestrator"
        }
