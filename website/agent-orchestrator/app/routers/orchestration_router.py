from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks
from loguru import logger
from app.database import get_db_pool
from app.redis_client import get_redis
import json
import uuid
import asyncio
import asyncpg

router = APIRouter()

@router.post("/task")
async def create_task(task: dict, background_tasks: BackgroundTasks):
    """Create a new orchestration task"""
    try:
        task_id = str(uuid.uuid4())
        redis = get_redis()
        
        # Add task_id to the task
        task["id"] = task_id
        task["status"] = "pending"
        
        # Store task in Redis
        await redis.setex(f"task:{task_id}", 3600, json.dumps(task))
        
        # Add task to processing queue
        await redis.lpush("task_queue", task_id)
        
        # Start background processing
        background_tasks.add_task(process_task, task_id)
        
        return {"task_id": task_id, "status": "pending"}
    except Exception as e:
        logger.error(f"Error creating task: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error creating task: {str(e)}")

@router.get("/task/{task_id}")
async def get_task(task_id: str):
    """Get task status and result"""
    try:
        redis = get_redis()
        task_data = await redis.get(f"task:{task_id}")
        
        if not task_data:
            raise HTTPException(status_code=404, detail=f"Task {task_id} not found")
        
        task = json.loads(task_data)
        return task
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting task {task_id}: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error getting task: {str(e)}")

@router.get("/agents/relationships")
async def get_agent_relationships():
    """Get agent relationship graph"""
    try:
        pool = get_db_pool()
        async with pool.acquire() as conn:
            query = """
                SELECT 
                    r.id, 
                    r.source_agent_id, 
                    sa.name as source_agent_name,
                    sat.type_name as source_agent_type,
                    r.target_agent_id, 
                    ta.name as target_agent_name,
                    tat.type_name as target_agent_type,
                    r.relationship_type, 
                    r.metadata
                FROM agent_mgmt.agent_relationships r
                JOIN agent_mgmt.agents sa ON r.source_agent_id = sa.id
                JOIN agent_mgmt.agent_types sat ON sa.type_id = sat.id
                JOIN agent_mgmt.agents ta ON r.target_agent_id = ta.id
                JOIN agent_mgmt.agent_types tat ON ta.type_id = tat.id
            """
            records = await conn.fetch(query)
            
            result = []
            for r in records:
                result.append({
                    "id": r["id"],
                    "source": {
                        "id": str(r["source_agent_id"]),
                        "name": r["source_agent_name"],
                        "type": r["source_agent_type"]
                    },
                    "target": {
                        "id": str(r["target_agent_id"]),
                        "name": r["target_agent_name"],
                        "type": r["target_agent_type"]
                    },
                    "relationship_type": r["relationship_type"],
                    "metadata": r["metadata"]
                })
            
            return result
    except Exception as e:
        logger.error(f"Error fetching agent relationships: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error fetching agent relationships: {str(e)}")

async def process_task(task_id: str):
    """Process a task in the background"""
    try:
        redis = get_redis()
        task_data = await redis.get(f"task:{task_id}")
        
        if not task_data:
            logger.error(f"Task {task_id} not found")
            return
        
        task = json.loads(task_data)
        
        # Update task status
        task["status"] = "processing"
        await redis.setex(f"task:{task_id}", 3600, json.dumps(task))
        
        # Implement orchestration logic based on task type
        task_type = task.get("type")
        
        if task_type == "agent_conversation":
            await handle_agent_conversation(task)
        elif task_type == "security_alert":
            await handle_security_alert(task)
        elif task_type == "kql_query":
            await handle_kql_query(task)
        else:
            logger.warning(f"Unknown task type: {task_type}")
            task["status"] = "failed"
            task["error"] = f"Unknown task type: {task_type}"
            await redis.setex(f"task:{task_id}", 3600, json.dumps(task))
            return
        
        # Update task status to completed
        task["status"] = "completed"
        await redis.setex(f"task:{task_id}", 3600, json.dumps(task))
        
    except Exception as e:
        logger.error(f"Error processing task {task_id}: {str(e)}")
        try:
            task["status"] = "failed"
            task["error"] = str(e)
            await redis.setex(f"task:{task_id}", 3600, json.dumps(task))
        except:
            pass

async def handle_agent_conversation(task):
    """Handle agent conversation task"""
    # This is a placeholder for the actual implementation
    logger.info(f"Handling agent conversation task: {task['id']}")
    await asyncio.sleep(2)  # Simulate processing time

async def handle_security_alert(task):
    """Handle security alert task"""
    # This is a placeholder for the actual implementation
    logger.info(f"Handling security alert task: {task['id']}")
    await asyncio.sleep(3)  # Simulate processing time

async def handle_kql_query(task):
    """Handle KQL query task"""
    # This is a placeholder for the actual implementation
    logger.info(f"Handling KQL query task: {task['id']}")
    await asyncio.sleep(4)  # Simulate processing time
