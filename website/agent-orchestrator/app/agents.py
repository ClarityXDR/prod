from loguru import logger
from app.database import get_db_pool
import asyncio
import aiohttp
import os
import json
import re

# GitHub API configuration
GITHUB_API_URL = "https://api.github.com"
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
GITHUB_HEADERS = {
    "Authorization": f"token {GITHUB_TOKEN}",
    "Accept": "application/vnd.github.v3+json"
}

# Global dictionary to store agent instances
agent_instances = {}

async def init_agents():
    """Initialize agent instances from the database"""
    try:
        pool = get_db_pool()
        async with pool.acquire() as conn:
            # Get all active agents
            query = """
                SELECT a.id, a.name, t.type_name, a.description, a.capabilities, a.config,
                       a.github_username, a.github_repository, a.github_labels, a.mcp_guidelines
                FROM agent_mgmt.agents a
                JOIN agent_mgmt.agent_types t ON a.type_id = t.id
                WHERE a.is_active = true
            """
            agents = await conn.fetch(query)
            
            logger.info(f"Initializing {len(agents)} active agents")
            
            for agent in agents:
                agent_id = str(agent['id'])
                agent_type = agent['type_name']
                
                # Create agent instance based on type
                if agent_type == 'CEO':
                    agent_instances[agent_id] = ExecutiveAgent(agent)
                elif agent_type == 'CFO':
                    agent_instances[agent_id] = FinancialAgent(agent)
                elif agent_type == 'CISO':
                    agent_instances[agent_id] = SecurityAgent(agent)
                elif agent_type in ['SALES', 'MARKETING', 'CUSTOMER_SERVICE']:
                    agent_instances[agent_id] = BusinessAgent(agent)
                elif agent_type in ['ACCOUNTING', 'FINANCE']:
                    agent_instances[agent_id] = FinancialAgent(agent)
                elif agent_type in ['KQL_HUNTING', 'SECURITY_COPILOT', 'PURVIEW_GRC']:
                    agent_instances[agent_id] = SecurityAgent(agent)
                elif agent_type == 'ORCHESTRATOR':
                    agent_instances[agent_id] = OrchestratorAgent(agent)
                else:
                    agent_instances[agent_id] = BaseAgent(agent)
                
                logger.info(f"Initialized agent: {agent['name']} ({agent_type})")
            
            # Start background task to poll GitHub Issues
            asyncio.create_task(poll_github_issues())
            
            logger.info("All agents initialized successfully")
    except Exception as e:
        logger.error(f"Error initializing agents: {str(e)}")
        raise

async def poll_github_issues():
    """Background task to poll GitHub Issues for all agents"""
    while True:
        try:
            for agent_id, agent in agent_instances.items():
                if agent.github_repository:
                    await agent.check_github_issues()
        except Exception as e:
            logger.error(f"Error polling GitHub issues: {str(e)}")
        
        # Poll every 60 seconds
        await asyncio.sleep(60)

class BaseAgent:
    """Base class for all agents"""
    
    def __init__(self, agent_data):
        self.id = str(agent_data['id'])
        self.name = agent_data['name']
        self.type = agent_data['type_name']
        self.description = agent_data['description']
        self.capabilities = agent_data['capabilities'] if agent_data['capabilities'] else []
        self.config = agent_data['config'] if agent_data['config'] else {}
        self.github_username = agent_data['github_username']
        self.github_repository = agent_data['github_repository']
        self.github_labels = agent_data['github_labels'] if agent_data['github_labels'] else []
        self.mcp_guidelines = agent_data['mcp_guidelines']
        
    async def process_message(self, message):
        """Process a message directed to this agent"""
        logger.info(f"Agent {self.name} processing message: {message.get('content', '')[:50]}...")
        
        # Apply MCP guidelines to the response
        response = self.apply_mcp_guidelines(message.get('content', ''))
        
        return {
            "status": "success",
            "response": response
        }
    
    def apply_mcp_guidelines(self, content):
        """Apply MCP guidelines to ensure response follows protocol"""
        # This is a simplified implementation
        # In a real system, this would use more sophisticated NLP techniques
        
        # Basic response with agent identification
        response = f"[{self.name}] Response: "
        
        # Apply basic MCP principles based on agent type
        if self.mcp_guidelines:
            # For demo purposes, just mentioning we're following guidelines
            response += f"Following my MCP guidelines, I can assist with your request. "
        
        # Add generic response to content
        response += f"I've reviewed your request and can provide assistance."
        
        return response
    
    async def check_github_issues(self):
        """Check for GitHub issues assigned to this agent"""
        if not self.github_repository:
            return
        
        try:
            # Get issues assigned to this agent from GitHub API
            async with aiohttp.ClientSession() as session:
                # Format the query to find issues with specific labels
                labels_query = ",".join(self.github_labels) if self.github_labels else ""
                query_params = {
                    "labels": labels_query,
                    "state": "open"
                }
                
                repo_parts = self.github_repository.split('/')
                if len(repo_parts) != 2:
                    logger.error(f"Invalid repository format for agent {self.name}: {self.github_repository}")
                    return
                
                owner, repo = repo_parts
                
                url = f"{GITHUB_API_URL}/repos/{owner}/{repo}/issues"
                async with session.get(url, headers=GITHUB_HEADERS, params=query_params) as response:
                    if response.status != 200:
                        logger.error(f"Error fetching issues for {self.name}: {response.status}")
                        return
                    
                    issues = await response.json()
                    
                    for issue in issues:
                        # Check if we've already processed this issue
                        pool = get_db_pool()
                        async with pool.acquire() as conn:
                            existing = await conn.fetchrow(
                                "SELECT id, status FROM agent_mgmt.github_issues WHERE repository = $1 AND issue_number = $2",
                                self.github_repository, issue['number']
                            )
                            
                            if existing and existing['status'] == 'completed':
                                continue
                            
                            # Process the issue
                            await self.process_github_issue(issue, existing)
        
        except Exception as e:
            logger.error(f"Error checking GitHub issues for agent {self.name}: {str(e)}")
    
    async def process_github_issue(self, issue, existing_record):
        """Process a GitHub issue"""
        try:
            issue_number = issue['number']
            issue_title = issue['title']
            issue_body = issue['body'] or ""
            issue_url = issue['html_url']
            
            logger.info(f"Agent {self.name} processing GitHub issue #{issue_number}: {issue_title}")
            
            # Create or update issue record in database
            pool = get_db_pool()
            async with pool.acquire() as conn:
                if not existing_record:
                    # Create new record
                    issue_id = await conn.fetchval(
                        """
                        INSERT INTO agent_mgmt.github_issues 
                        (agent_id, issue_number, repository, title, status, url, created_at, updated_at)
                        VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
                        RETURNING id
                        """,
                        self.id, issue_number, self.github_repository, issue_title, 'processing', issue_url
                    )
                else:
                    # Update existing record
                    issue_id = existing_record['id']
                    await conn.execute(
                        """
                        UPDATE agent_mgmt.github_issues 
                        SET status = 'processing', updated_at = NOW()
                        WHERE id = $1
                        """,
                        issue_id
                    )
            
            # Log action
            await self.log_action(
                "PROCESS_GITHUB_ISSUE", 
                "processing", 
                {
                    "issue_number": issue_number, 
                    "title": issue_title
                },
                None,
                issue_id
            )
            
            # Process the issue content
            response = self.apply_mcp_guidelines(issue_body)
            
            # Post comment to GitHub
            await self.post_github_comment(issue_number, response)
            
            # Update issue status
            async with pool.acquire() as conn:
                await conn.execute(
                    """
                    UPDATE agent_mgmt.github_issues 
                    SET status = 'completed', updated_at = NOW()
                    WHERE id = $1
                    """,
                    issue_id
                )
            
            # Log completion
            await self.log_action(
                "PROCESS_GITHUB_ISSUE", 
                "success", 
                {
                    "issue_number": issue_number, 
                    "title": issue_title
                },
                {
                    "response": response[:100] + "..." if len(response) > 100 else response
                },
                issue_id
            )
            
        except Exception as e:
            logger.error(f"Error processing GitHub issue: {str(e)}")
            await self.log_action(
                "PROCESS_GITHUB_ISSUE", 
                "error", 
                {
                    "issue_number": issue.get('number'), 
                    "title": issue.get('title')
                },
                {
                    "error": str(e)
                }
            )
    
    async def post_github_comment(self, issue_number, comment):
        """Post a comment to a GitHub issue"""
        if not self.github_repository:
            return
        
        try:
            repo_parts = self.github_repository.split('/')
            owner, repo = repo_parts
            
            url = f"{GITHUB_API_URL}/repos/{owner}/{repo}/issues/{issue_number}/comments"
            
            payload = {
                "body": comment
            }
            
            async with aiohttp.ClientSession() as session:
                async with session.post(url, headers=GITHUB_HEADERS, json=payload) as response:
                    if response.status not in (201, 200):
                        error_text = await response.text()
                        logger.error(f"Error posting comment to GitHub: {response.status} - {error_text}")
                        return None
                    
                    result = await response.json()
                    return result.get('id')
        
        except Exception as e:
            logger.error(f"Error posting GitHub comment: {str(e)}")
            return None
    
    async def log_action(self, action_type, status, details=None, result=None, github_issue_id=None):
        """Log an action performed by this agent"""
        try:
            pool = get_db_pool()
            async with pool.acquire() as conn:
                await conn.execute(
                    """
                    INSERT INTO agent_mgmt.action_logs 
                    (agent_id, action_type, status, details, result, github_issue_id) 
                    VALUES ($1, $2, $3, $4, $5, $6)
                    """,
                    self.id, action_type, status, details, result, github_issue_id
                )
            logger.debug(f"Agent {self.name} logged action: {action_type} - {status}")
        except Exception as e:
            logger.error(f"Error logging agent action: {str(e)}")

class ExecutiveAgent(BaseAgent):
    """Agent for executive functions"""
    
    def apply_mcp_guidelines(self, content):
        """Apply executive-specific MCP guidelines"""
        # In a real implementation, this would use more sophisticated techniques
        response = f"[{self.name}] Executive Analysis: "
        
        # Focus on strategic impact
        response += "Based on strategic analysis and business impact assessment, "
        response += "I recommend the following course of action that aligns with our organizational goals. "
        
        # Add reference to content
        response += f"Regarding your request, I've evaluated it within our strategic framework."
        
        return response

class BusinessAgent(BaseAgent):
    """Agent for business functions"""
    
    async def process_message(self, message):
        await self.log_action("PROCESS_MESSAGE", "success", {"message_id": message.get("id")})
        # Implement business-specific logic here
        return {
            "status": "success",
            "response": f"Business agent {self.name} processed the message"
        }

class FinancialAgent(BaseAgent):
    """Agent for financial functions"""
    
    async def process_message(self, message):
        await self.log_action("PROCESS_MESSAGE", "success", {"message_id": message.get("id")})
        # Implement financial-specific logic here
        return {
            "status": "success",
            "response": f"Financial agent {self.name} processed the message"
        }

class SecurityAgent(BaseAgent):
    """Agent for security functions"""
    
    async def process_message(self, message):
        await self.log_action("PROCESS_MESSAGE", "success", {"message_id": message.get("id")})
        # Implement security-specific logic here
        return {
            "status": "success",
            "response": f"Security agent {self.name} processed the message"
        }

class OrchestratorAgent(BaseAgent):
    """Agent for orchestrating other agents"""
    
    async def process_message(self, message):
        await self.log_action("PROCESS_MESSAGE", "success", {"message_id": message.get("id")})
        # Implement orchestration logic here
        return {
            "status": "success",
            "response": f"Orchestrator agent {self.name} processed the message"
        }
    
    async def delegate_task(self, task, target_agents):
        """Delegate a task to other agents"""
        results = {}
        for agent_id in target_agents:
            if agent_id in agent_instances:
                agent = agent_instances[agent_id]
                logger.info(f"Delegating task to agent: {agent.name}")
                try:
                    result = await agent.process_message(task)
                    results[agent_id] = result
                except Exception as e:
                    logger.error(f"Error delegating task to agent {agent.name}: {str(e)}")
                    results[agent_id] = {"status": "error", "error": str(e)}
            else:
                logger.warning(f"Agent {agent_id} not found")
                results[agent_id] = {"status": "error", "error": "Agent not found"}
        
        return results
