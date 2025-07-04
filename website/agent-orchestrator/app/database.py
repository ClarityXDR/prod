import os
import asyncpg
from loguru import logger

# Global connection pool
db_pool = None

async def init_db():
    """Initialize database connection pool"""
    global db_pool
    
    try:
        # Get database connection parameters from environment variables
        db_host = os.getenv("DB_HOST", "localhost")
        db_port = int(os.getenv("DB_PORT", "5432"))
        db_user = os.getenv("DB_USER", "postgres")
        db_password = os.getenv("DB_PASSWORD", "postgres")
        db_name = os.getenv("DB_NAME", "clarityxdr")
        
        # Create connection pool
        db_pool = await asyncpg.create_pool(
            host=db_host,
            port=db_port,
            user=db_user,
            password=db_password,
            database=db_name,
            min_size=5,
            max_size=20
        )
        
        logger.info(f"Database connection pool initialized for {db_user}@{db_host}:{db_port}/{db_name}")
        
        # Test connection
        async with db_pool.acquire() as conn:
            version = await conn.fetchval("SELECT version()")
            logger.info(f"Connected to PostgreSQL: {version}")
            
    except Exception as e:
        logger.error(f"Failed to initialize database connection pool: {str(e)}")
        raise

async def close_db():
    """Close database connection pool"""
    global db_pool
    
    if db_pool:
        await db_pool.close()
        logger.info("Database connection pool closed")

def get_db_pool():
    """Get the database connection pool"""
    global db_pool
    if db_pool is None:
        raise RuntimeError("Database connection pool not initialized")
    return db_pool
