from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks, Request
from loguru import logger
from app.database import get_db_pool
from app.redis_client import get_redis
from app.agents import agent_instances
import json
import uuid
import asyncio
import asyncpg
import hmac
import hashlib
import os

router = APIRouter()

# GitHub webhook secret for validating requests
GITHUB_WEBHOOK_SECRET = os.getenv("GITHUB_WEBHOOK_SECRET", "")

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

@router.post("/github/webhook")
async def github_webhook(request: Request, background_tasks: BackgroundTasks):
    """Handle GitHub webhook events"""
    try:
        # Validate GitHub webhook signature
        if GITHUB_WEBHOOK_SECRET:
            signature = request.headers.get("X-Hub-Signature-256")
            if not signature:
                raise HTTPException(status_code=401, detail="No signature provided")
            
            payload = await request.body()
            calculated_signature = "sha256=" + hmac.new(
                GITHUB_WEBHOOK_SECRET.encode(), 
                payload, 
                hashlib.sha256
            ).hexdigest()
            
            if not hmac.compare_digest(signature, calculated_signature):
                raise HTTPException(status_code=401, detail="Invalid signature")
        
        # Parse the webhook payload
        payload = await request.json()
        event_type = request.headers.get("X-GitHub-Event")
        
        if event_type == "issues":
            return await handle_issues_event(payload, background_tasks)
        elif event_type == "issue_comment":
            return await handle_issue_comment_event(payload, background_tasks)
        else:
            logger.info(f"Received unhandled GitHub event: {event_type}")
            return {"status": "ignored", "event": event_type}
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error processing GitHub webhook: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error processing webhook: {str(e)}")

async def handle_issues_event(payload, background_tasks):
    """Handle GitHub issues events"""
    try:
        action = payload.get("action")
        issue = payload.get("issue", {})
        repository = payload.get("repository", {})
        
        if action not in ("opened", "reopened", "labeled", "assigned"):
            return {"status": "ignored", "action": action}
        
        issue_number = issue.get("number")
        repository_full_name = repository.get("full_name")
        labels = [label.get("name") for label in issue.get("labels", [])]
        
        logger.info(f"Processing GitHub issue #{issue_number} from {repository_full_name} with labels {labels}")
        
        # Find the appropriate agent based on repository and labels
        pool = get_db_pool()
        async with pool.acquire() as conn:
            query = """
                SELECT a.id
                FROM agent_mgmt.agents a
                WHERE a.github_repository = $1
                AND a.is_active = true
                AND (
                    a.github_labels && $2::text[]
                    OR array_length(a.github_labels, 1) IS NULL
                )
                LIMIT 1
            """
            agent_id = await conn.fetchval(query, repository_full_name, labels)
            
            if not agent_id:
                logger.warning(f"No agent found for repository {repository_full_name} with labels {labels}")
                return {"status": "ignored", "reason": "no matching agent"}
            
            # Queue the issue for processing by the agent
            agent = agent_instances.get(str(agent_id))
            if agent:
                background_tasks.add_task(agent.process_github_issue, issue, None)
                return {"status": "queued", "agent": agent.name, "issue": issue_number}
            else:
                logger.warning(f"Agent {agent_id} not found in active instances")
                return {"status": "error", "reason": "agent not active"}
    
    except Exception as e:
        logger.error(f"Error handling issues event: {str(e)}")
        return {"status": "error", "error": str(e)}

async def handle_issue_comment_event(payload, background_tasks):
    """Handle GitHub issue comment events"""
    try:
        action = payload.get("action")
        if action != "created":
            return {"status": "ignored", "action": action}
        
        issue = payload.get("issue", {})
        comment = payload.get("comment", {})
        repository = payload.get("repository", {})
        
        issue_number = issue.get("number")
        repository_full_name = repository.get("full_name")
        comment_body = comment.get("body", "")
        
        # Check if comment mentions any agent
        pool = get_db_pool()
        async with pool.acquire() as conn:
            agents = await conn.fetch(
                "SELECT id, name FROM agent_mgmt.agents WHERE is_active = true"
            )
            
            mentioned_agent = None
            for agent in agents:
                if f"@{agent['name']}" in comment_body:
                    mentioned_agent = agent
                    break
            
            if not mentioned_agent:
                return {"status": "ignored", "reason": "no agent mentioned"}
            
            # Get the existing issue record
            issue_record = await conn.fetchrow(
                """
                SELECT id, agent_id, status 
                FROM agent_mgmt.github_issues 
                WHERE repository = $1 AND issue_number = $2
                """,
                repository_full_name, issue_number
            )
            
            # Process the comment with the mentioned agent
            agent = agent_instances.get(str(mentioned_agent['id']))
            if agent:
                background_tasks.add_task(
                    agent.process_github_issue, 
                    issue, 
                    issue_record
                )
                return {"status": "queued", "agent": agent.name, "issue": issue_number}
            else:
                logger.warning(f"Agent {mentioned_agent['id']} not found in active instances")
                return {"status": "error", "reason": "agent not active"}
    
    except Exception as e:
        logger.error(f"Error handling issue comment event: {str(e)}")
        return {"status": "error", "error": str(e)}

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
