from loguru import logger
from app.database import get_db_pool
import asyncio

# Global dictionary to store agent instances
agent_instances = {}

async def init_agents():
    """Initialize agent instances from the database"""
    try:
        pool = get_db_pool()
        async with pool.acquire() as conn:
            # Get all active agents
            query = """
                SELECT a.id, a.name, t.type_name, a.description, a.capabilities, a.config
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
            
            logger.info("All agents initialized successfully")
    except Exception as e:
        logger.error(f"Error initializing agents: {str(e)}")
        raise

class BaseAgent:
    """Base class for all agents"""
    
    def __init__(self, agent_data):
        self.id = str(agent_data['id'])
        self.name = agent_data['name']
        self.type = agent_data['type_name']
        self.description = agent_data['description']
        self.capabilities = agent_data['capabilities'] if agent_data['capabilities'] else []
        self.config = agent_data['config'] if agent_data['config'] else {}
        
    async def process_message(self, message):
        """Process a message directed to this agent"""
        logger.info(f"Agent {self.name} processing message: {message.get('content', '')[:50]}...")
        # Base implementation just logs the message
        return {
            "status": "success",
            "response": f"Message received by {self.name}"
        }
    
    async def log_action(self, action_type, status, details=None, result=None):
        """Log an action performed by this agent"""
        try:
            pool = get_db_pool()
            async with pool.acquire() as conn:
                await conn.execute(
                    """
                    INSERT INTO agent_mgmt.action_logs 
                    (agent_id, action_type, status, details, result) 
                    VALUES ($1, $2, $3, $4, $5)
                    """,
                    self.id, action_type, status, details, result
                )
            logger.debug(f"Agent {self.name} logged action: {action_type} - {status}")
        except Exception as e:
            logger.error(f"Error logging agent action: {str(e)}")

class ExecutiveAgent(BaseAgent):
    """Agent for executive functions"""
    
    async def process_message(self, message):
        await self.log_action("PROCESS_MESSAGE", "success", {"message_id": message.get("id")})
        # Implement executive-specific logic here
        return {
            "status": "success",
            "response": f"Executive agent {self.name} processed the message"
        }

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
