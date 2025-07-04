-- Create schema for deployment management
CREATE SCHEMA IF NOT EXISTS deployment_mgmt;

-- Logic App Deployments
CREATE TABLE deployment_mgmt.logic_app_deployments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID REFERENCES client_mgmt.clients(id),
    logic_app_name VARCHAR(255) NOT NULL,
    subscription_id VARCHAR(255) NOT NULL,
    resource_group VARCHAR(255) NOT NULL,
    template_name VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    deployed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deployed_by UUID REFERENCES agent_mgmt.agents(id),
    error_message TEXT,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- MDE Rule Deployments
CREATE TABLE deployment_mgmt.mde_rule_deployments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID REFERENCES client_mgmt.clients(id),
    rule_id UUID REFERENCES mde_rules.master_rules(id),
    deployment_status VARCHAR(50) NOT NULL DEFAULT 'pending',
    enabled BOOLEAN DEFAULT TRUE,
    customizations JSONB,
    deployed_at TIMESTAMP WITH TIME ZONE,
    deployed_by UUID REFERENCES agent_mgmt.agents(id),
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Threat Intelligence Indicators
CREATE TABLE deployment_mgmt.threat_indicators (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID REFERENCES client_mgmt.clients(id),
    indicator_type VARCHAR(50) NOT NULL, -- ip, domain, url, hash, email
    indicator_value TEXT NOT NULL,
    threat_type VARCHAR(100) NOT NULL,
    confidence INTEGER CHECK (confidence >= 0 AND confidence <= 100),
    source VARCHAR(255) NOT NULL,
    description TEXT,
    tags TEXT[],
    expiration_date TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT TRUE,
    synced_to_sentinel BOOLEAN DEFAULT FALSE,
    synced_at TIMESTAMP WITH TIME ZONE,
    created_by UUID REFERENCES agent_mgmt.agents(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(client_id, indicator_type, indicator_value)
);

-- Threat Intelligence Feeds
CREATE TABLE deployment_mgmt.threat_feeds (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    feed_url VARCHAR(500),
    feed_type VARCHAR(50) NOT NULL, -- STIX, TAXII, CSV, JSON
    enabled BOOLEAN DEFAULT TRUE,
    update_frequency_hours INTEGER DEFAULT 24,
    last_update TIMESTAMP WITH TIME ZONE,
    last_sync_status VARCHAR(50),
    indicator_count INTEGER DEFAULT 0,
    sync_progress INTEGER DEFAULT 0,
    configuration JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Sentinel Deployments
CREATE TABLE deployment_mgmt.sentinel_deployments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    client_id UUID REFERENCES client_mgmt.clients(id),
    workspace_name VARCHAR(255) NOT NULL,
    workspace_id VARCHAR(255),
    subscription_id VARCHAR(255) NOT NULL,
    resource_group VARCHAR(255) NOT NULL,
    location VARCHAR(50) NOT NULL,
    deployment_status VARCHAR(50) NOT NULL DEFAULT 'pending',
    configuration JSONB NOT NULL,
    deployment_steps JSONB,
    deployed_at TIMESTAMP WITH TIME ZONE,
    deployed_by UUID REFERENCES agent_mgmt.agents(id),
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Deployment Templates
CREATE TABLE deployment_mgmt.deployment_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    template_type VARCHAR(50) NOT NULL, -- logic_app, mde_rule, sentinel, purview
    name VARCHAR(255) NOT NULL,
    display_name VARCHAR(255),
    description TEXT,
    version VARCHAR(20) NOT NULL DEFAULT '1.0',
    template_content TEXT NOT NULL,
    parameters JSONB,
    tags TEXT[],
    is_active BOOLEAN DEFAULT TRUE,
    created_by UUID REFERENCES agent_mgmt.agents(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(template_type, name, version)
);

-- Deployment Audit Log
CREATE TABLE deployment_mgmt.deployment_audit (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    deployment_type VARCHAR(50) NOT NULL,
    deployment_id UUID NOT NULL,
    client_id UUID REFERENCES client_mgmt.clients(id),
    action VARCHAR(100) NOT NULL,
    performed_by UUID REFERENCES agent_mgmt.agents(id),
    details JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_logic_app_deployments_client_id ON deployment_mgmt.logic_app_deployments(client_id);
CREATE INDEX idx_logic_app_deployments_status ON deployment_mgmt.logic_app_deployments(status);
CREATE INDEX idx_mde_rule_deployments_client_id ON deployment_mgmt.mde_rule_deployments(client_id);
CREATE INDEX idx_threat_indicators_client_id ON deployment_mgmt.threat_indicators(client_id);
CREATE INDEX idx_threat_indicators_type_value ON deployment_mgmt.threat_indicators(indicator_type, indicator_value);
CREATE INDEX idx_sentinel_deployments_client_id ON deployment_mgmt.sentinel_deployments(client_id);
CREATE INDEX idx_deployment_audit_client_id ON deployment_mgmt.deployment_audit(client_id);
CREATE INDEX idx_deployment_audit_created_at ON deployment_mgmt.deployment_audit(created_at);

-- Create views for deployment statistics
CREATE OR REPLACE VIEW deployment_mgmt.deployment_stats AS
SELECT 
    c.id AS client_id,
    c.name AS client_name,
    COUNT(DISTINCT lad.id) AS logic_apps_deployed,
    COUNT(DISTINCT mrd.id) AS mde_rules_deployed,
    COUNT(DISTINCT ti.id) AS threat_indicators,
    COUNT(DISTINCT sd.id) AS sentinel_deployments,
    MAX(GREATEST(
        COALESCE(lad.deployed_at, '1900-01-01'::timestamp with time zone),
        COALESCE(mrd.deployed_at, '1900-01-01'::timestamp with time zone),
        COALESCE(sd.deployed_at, '1900-01-01'::timestamp with time zone)
    )) AS last_deployment_date
FROM client_mgmt.clients c
LEFT JOIN deployment_mgmt.logic_app_deployments lad ON c.id = lad.client_id AND lad.status = 'Success'
LEFT JOIN deployment_mgmt.mde_rule_deployments mrd ON c.id = mrd.client_id AND mrd.deployment_status = 'deployed'
LEFT JOIN deployment_mgmt.threat_indicators ti ON c.id = ti.client_id AND ti.is_active = TRUE
LEFT JOIN deployment_mgmt.sentinel_deployments sd ON c.id = sd.client_id AND sd.deployment_status = 'completed'
GROUP BY c.id, c.name;
