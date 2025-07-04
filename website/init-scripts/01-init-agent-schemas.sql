-- ClarityXDR Agent Database Initialization

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create schema for agent management
CREATE SCHEMA IF NOT EXISTS agent_mgmt;

-- Agent Types
CREATE TABLE agent_mgmt.agent_types (
    id SERIAL PRIMARY KEY,
    type_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert base agent types
INSERT INTO agent_mgmt.agent_types (type_name, description) VALUES
('CEO', 'Executive decision making and company oversight'),
('SALES', 'Sales pipeline and customer acquisition'),
('MARKETING', 'Marketing campaigns and brand management'),
('CUSTOMER_SERVICE', 'Customer support and service management'),
('ACCOUNTING', 'Financial recording and reporting'),
('FINANCE', 'Financial planning and analysis'),
('CFO', 'Financial strategy and oversight'),
('CISO', 'Security strategy and compliance with CISSP knowledge'),
('KQL_HUNTING', 'Advanced threat hunting using KQL'),
('SECURITY_COPILOT', 'Integration with Microsoft Security Copilot'),
('PURVIEW_GRC', 'Governance, risk management, and compliance'),
('ORCHESTRATOR', 'Coordinates workflow between other agents');

-- Agent Definitions
CREATE TABLE agent_mgmt.agents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    type_id INTEGER REFERENCES agent_mgmt.agent_types(id),
    description TEXT,
    capabilities JSONB,
    config JSONB,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Agent Relationships (for orchestration)
CREATE TABLE agent_mgmt.agent_relationships (
    id SERIAL PRIMARY KEY,
    source_agent_id UUID REFERENCES agent_mgmt.agents(id),
    target_agent_id UUID REFERENCES agent_mgmt.agents(id),
    relationship_type VARCHAR(50) NOT NULL,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(source_agent_id, target_agent_id, relationship_type)
);

-- Agent Conversations
CREATE TABLE agent_mgmt.conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255),
    status VARCHAR(50) DEFAULT 'active',
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Agent Messages
CREATE TABLE agent_mgmt.messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID REFERENCES agent_mgmt.conversations(id),
    sender_agent_id UUID REFERENCES agent_mgmt.agents(id),
    receiver_agent_id UUID REFERENCES agent_mgmt.agents(id),
    content TEXT NOT NULL,
    message_type VARCHAR(50) DEFAULT 'text',
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Agent Action Logs
CREATE TABLE agent_mgmt.action_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    agent_id UUID REFERENCES agent_mgmt.agents(id),
    action_type VARCHAR(100) NOT NULL,
    status VARCHAR(50) NOT NULL,
    details JSONB,
    result JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create schema for client management
CREATE SCHEMA IF NOT EXISTS client_mgmt;

-- Clients table
CREATE TABLE client_mgmt.clients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    tenant_id VARCHAR(50) UNIQUE,
    contact_email VARCHAR(255),
    contact_name VARCHAR(255),
    status VARCHAR(50) DEFAULT 'active',
    subscription_tier VARCHAR(50) DEFAULT 'standard',
    onboarded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- App Registrations
CREATE TABLE client_mgmt.app_registrations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID REFERENCES client_mgmt.clients(id),
    app_id VARCHAR(50) NOT NULL,
    display_name VARCHAR(255) NOT NULL,
    client_secret_encrypted BYTEA,
    permissions JSONB,
    status VARCHAR(50) DEFAULT 'active',
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create schema for KQL management
CREATE SCHEMA IF NOT EXISTS kql_mgmt;

-- KQL Query Templates
CREATE TABLE kql_mgmt.query_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    query_text TEXT NOT NULL,
    category VARCHAR(100),
    tags TEXT[],
    is_public BOOLEAN DEFAULT TRUE,
    author_id UUID REFERENCES agent_mgmt.agents(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Client Specific KQL Queries
CREATE TABLE kql_mgmt.client_queries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID REFERENCES client_mgmt.clients(id),
    template_id UUID REFERENCES kql_mgmt.query_templates(id),
    name VARCHAR(255) NOT NULL,
    query_text TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- KQL Query Execution Results
CREATE TABLE kql_mgmt.query_results (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    query_id UUID REFERENCES kql_mgmt.client_queries(id),
    executed_by UUID REFERENCES agent_mgmt.agents(id),
    status VARCHAR(50) NOT NULL,
    result_count INTEGER,
    result_summary TEXT,
    execution_time_ms INTEGER,
    full_results JSONB,
    executed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create schema for MDE rules repository
CREATE SCHEMA IF NOT EXISTS mde_rules;

-- MDE Rule Categories
CREATE TABLE mde_rules.categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert base categories
INSERT INTO mde_rules.categories (name, description) VALUES
('Malware Detection', 'Rules for identifying malware activity'),
('Credential Theft', 'Rules for detecting credential theft attempts'),
('Lateral Movement', 'Rules for identifying lateral movement techniques'),
('Data Exfiltration', 'Rules for detecting data exfiltration'),
('Initial Access', 'Rules for detecting initial access vectors'),
('Persistence', 'Rules for identifying persistence mechanisms'),
('Privilege Escalation', 'Rules for detecting privilege escalation'),
('Defense Evasion', 'Rules for identifying defense evasion techniques');

-- Master MDE Detection Rules
CREATE TABLE mde_rules.master_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    rule_text TEXT NOT NULL,
    rule_type VARCHAR(50) NOT NULL,
    category_id INTEGER REFERENCES mde_rules.categories(id),
    severity VARCHAR(20) NOT NULL,
    tags TEXT[],
    author VARCHAR(100),
    version VARCHAR(20) DEFAULT '1.0',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Client-specific MDE Rules
CREATE TABLE mde_rules.client_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID REFERENCES client_mgmt.clients(id),
    master_rule_id UUID REFERENCES mde_rules.master_rules(id),
    title VARCHAR(255) NOT NULL,
    description TEXT,
    rule_text TEXT NOT NULL,
    customizations TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    deployed BOOLEAN DEFAULT FALSE,
    deployed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Rule Deployment History
CREATE TABLE mde_rules.deployment_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_rule_id UUID REFERENCES mde_rules.client_rules(id),
    deployed_by UUID REFERENCES agent_mgmt.agents(id),
    status VARCHAR(50) NOT NULL,
    version VARCHAR(20) NOT NULL,
    details TEXT,
    deployed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create views for easier data access
CREATE OR REPLACE VIEW agent_mgmt.active_agents AS
SELECT a.id, a.name, t.type_name, a.description, a.capabilities, a.config
FROM agent_mgmt.agents a
JOIN agent_mgmt.agent_types t ON a.type_id = t.id
WHERE a.is_active = TRUE;

CREATE OR REPLACE VIEW client_mgmt.active_clients AS
SELECT c.id, c.name, c.tenant_id, c.contact_email, c.subscription_tier, 
       COUNT(DISTINCT ar.id) AS app_registration_count,
       COUNT(DISTINCT cr.id) AS custom_rule_count
FROM client_mgmt.clients c
LEFT JOIN client_mgmt.app_registrations ar ON c.id = ar.client_id
LEFT JOIN mde_rules.client_rules cr ON c.id = cr.client_id
WHERE c.status = 'active'
GROUP BY c.id, c.name, c.tenant_id, c.contact_email, c.subscription_tier;

-- Create indexes for better performance
CREATE INDEX idx_agents_type_id ON agent_mgmt.agents(type_id);
CREATE INDEX idx_agents_is_active ON agent_mgmt.agents(is_active);
CREATE INDEX idx_messages_conversation_id ON agent_mgmt.messages(conversation_id);
CREATE INDEX idx_app_registrations_client_id ON client_mgmt.app_registrations(client_id);
CREATE INDEX idx_client_queries_client_id ON kql_mgmt.client_queries(client_id);
CREATE INDEX idx_client_rules_client_id ON mde_rules.client_rules(client_id);
CREATE INDEX idx_client_rules_master_rule_id ON mde_rules.client_rules(master_rule_id);
