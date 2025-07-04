from fastapi import APIRouter, HTTPException, Depends
from loguru import logger
from app.database import get_db_pool
import asyncpg

router = APIRouter()

@router.get("/")
async def get_agents():
    """Get all active agents"""
    try:
        pool = get_db_pool()
        async with pool.acquire() as conn:
            query = """
                SELECT a.id, a.name, t.type_name as type, a.description, 
                       a.capabilities, a.config, a.is_active
                FROM agent_mgmt.agents a
                JOIN agent_mgmt.agent_types t ON a.type_id = t.id
                ORDER BY t.type_name, a.name
            """
            records = await conn.fetch(query)
            
            # Transform database records to dict
            result = []
            for r in records:
                result.append({
                    "id": str(r["id"]),
                    "name": r["name"],
                    "type": r["type"],
                    "description": r["description"],
                    "capabilities": r["capabilities"],
                    "config": r["config"],
                    "is_active": r["is_active"]
                })
            
            return result
    except Exception as e:
        logger.error(f"Error fetching agents: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error fetching agents: {str(e)}")

@router.get("/{agent_id}")
async def get_agent(agent_id: str):
    """Get agent by ID"""
    try:
        pool = get_db_pool()
        async with pool.acquire() as conn:
            query = """
                SELECT a.id, a.name, t.type_name as type, a.description, 
                       a.capabilities, a.config, a.is_active,
                       a.created_at, a.updated_at
                FROM agent_mgmt.agents a
                JOIN agent_mgmt.agent_types t ON a.type_id = t.id
                WHERE a.id = $1
            """
            record = await conn.fetchrow(query, agent_id)
            
            if not record:
                raise HTTPException(status_code=404, detail=f"Agent with ID {agent_id} not found")
            
            return {
                "id": str(record["id"]),
                "name": record["name"],
                "type": record["type"],
                "description": record["description"],
                "capabilities": record["capabilities"],
                "config": record["config"],
                "is_active": record["is_active"],
                "created_at": record["created_at"],
                "updated_at": record["updated_at"]
            }
    except asyncpg.exceptions.PostgresError as e:
        logger.error(f"Database error fetching agent {agent_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Database error: {str(e)}")
    except Exception as e:
        logger.error(f"Error fetching agent {agent_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error fetching agent: {str(e)}")

@router.post("/{agent_id}/activate")
async def activate_agent(agent_id: str):
    """Activate an agent"""
    try:
        pool = get_db_pool()
        async with pool.acquire() as conn:
            # Start transaction
            async with conn.transaction():
                # Check if agent exists
                exists = await conn.fetchval("SELECT EXISTS(SELECT 1 FROM agent_mgmt.agents WHERE id = $1)", agent_id)
                
                if not exists:
                    raise HTTPException(status_code=404, detail=f"Agent with ID {agent_id} not found")
                
                # Update agent status
                await conn.execute(
                    "UPDATE agent_mgmt.agents SET is_active = true, updated_at = NOW() WHERE id = $1",
                    agent_id
                )
                
                # Log the activation
                await conn.execute(
                    """
                    INSERT INTO agent_mgmt.action_logs 
                    (agent_id, action_type, status, details) 
                    VALUES ($1, 'ACTIVATION', 'success', '{"source": "api"}')
                    """,
                    agent_id
                )
        
        return {"status": "success", "message": f"Agent {agent_id} activated successfully"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error activating agent {agent_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error activating agent: {str(e)}")

@router.post("/{agent_id}/deactivate")
async def deactivate_agent(agent_id: str):
    """Deactivate an agent"""
    try:
        pool = get_db_pool()
        async with pool.acquire() as conn:
            # Start transaction
            async with conn.transaction():
                # Check if agent exists
                exists = await conn.fetchval("SELECT EXISTS(SELECT 1 FROM agent_mgmt.agents WHERE id = $1)", agent_id)
                
                if not exists:
                    raise HTTPException(status_code=404, detail=f"Agent with ID {agent_id} not found")
                
                # Update agent status
                await conn.execute(
                    "UPDATE agent_mgmt.agents SET is_active = false, updated_at = NOW() WHERE id = $1",
                    agent_id
                )
                
                # Log the deactivation
                await conn.execute(
                    """
                    INSERT INTO agent_mgmt.action_logs 
                    (agent_id, action_type, status, details) 
                    VALUES ($1, 'DEACTIVATION', 'success', '{"source": "api"}')
                    """,
                    agent_id
                )
        
        return {"status": "success", "message": f"Agent {agent_id} deactivated successfully"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error deactivating agent {agent_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error deactivating agent: {str(e)}")

@router.get("/{agent_id}/logs")
async def get_agent_logs(agent_id: str, limit: int = 50):
    """Get agent action logs"""
    try:
        pool = get_db_pool()
        async with pool.acquire() as conn:
            query = """
                SELECT id, agent_id, action_type, status, details, result, created_at
                FROM agent_mgmt.action_logs
                WHERE agent_id = $1
                ORDER BY created_at DESC
                LIMIT $2
            """
            records = await conn.fetch(query, agent_id, limit)
            
            result = []
            for r in records:
                result.append({
                    "id": str(r["id"]),
                    "agent_id": str(r["agent_id"]),
                    "action_type": r["action_type"],
                    "status": r["status"],
                    "details": r["details"],
                    "result": r["result"],
                    "created_at": r["created_at"]
                })
            
            return result
    except Exception as e:
        logger.error(f"Error fetching logs for agent {agent_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error fetching agent logs: {str(e)}")
