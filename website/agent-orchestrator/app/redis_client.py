import os
import redis.asyncio as redis
from loguru import logger

# Global Redis client
redis_client = None

async def init_redis():
    """Initialize Redis client"""
    global redis_client
    
    try:
        # Get Redis connection parameters from environment variables
        redis_host = os.getenv("REDIS_HOST", "localhost")
        redis_port = int(os.getenv("REDIS_PORT", "6379"))
        redis_password = os.getenv("REDIS_PASSWORD", "")
        
        # Create Redis client
        redis_client = redis.Redis(
            host=redis_host,
            port=redis_port,
            password=redis_password,
            decode_responses=True
        )
        
        # Test connection
        await redis_client.ping()
        logger.info(f"Redis connection established to {redis_host}:{redis_port}")
        
    except Exception as e:
        logger.error(f"Failed to initialize Redis client: {str(e)}")
        raise

async def close_redis():
    """Close Redis client"""
    global redis_client
    
    if redis_client:
        await redis_client.close()
        logger.info("Redis connection closed")

def get_redis():
    """Get the Redis client"""
    global redis_client
    if redis_client is None:
        raise RuntimeError("Redis client not initialized")
    return redis_client
