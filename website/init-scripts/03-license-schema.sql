-- Create license management schema
CREATE SCHEMA IF NOT EXISTS license_mgmt;

-- Clients table
CREATE TABLE IF NOT EXISTS license_mgmt.clients (
    id SERIAL PRIMARY KEY,
    client_id UUID UNIQUE NOT NULL DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    contact_email VARCHAR(255),
    contact_phone VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Licenses table
CREATE TABLE IF NOT EXISTS license_mgmt.licenses (
    id SERIAL PRIMARY KEY,
    client_id INTEGER REFERENCES license_mgmt.clients(id) ON DELETE CASCADE,
    license_key VARCHAR(255) UNIQUE NOT NULL,
    issue_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expiration_date DATE NOT NULL,
    is_active BOOLEAN DEFAULT true,
    features JSONB DEFAULT '[]'::jsonb,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- License checks for telemetry
CREATE TABLE IF NOT EXISTS license_mgmt.license_checks (
    id SERIAL PRIMARY KEY,
    license_id INTEGER REFERENCES license_mgmt.licenses(id) ON DELETE CASCADE,
    checked_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    product VARCHAR(100),
    ip_address INET,
    result VARCHAR(50)
);

-- Logic App deployments
CREATE TABLE IF NOT EXISTS license_mgmt.logic_app_deployments (
    id SERIAL PRIMARY KEY,
    client_id INTEGER REFERENCES license_mgmt.clients(id) ON DELETE CASCADE,
    logic_app_name VARCHAR(255) NOT NULL,
    subscription_id UUID NOT NULL,
    resource_group VARCHAR(255) NOT NULL,
    template_name VARCHAR(255) NOT NULL,
    deployed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deployed_by INTEGER,
    status VARCHAR(50) NOT NULL,
    error_message TEXT
);

-- Create indexes for performance
CREATE INDEX idx_licenses_client_id ON license_mgmt.licenses(client_id);
CREATE INDEX idx_licenses_expiration ON license_mgmt.licenses(expiration_date);
CREATE INDEX idx_license_checks_license_id ON license_mgmt.license_checks(license_id);
CREATE INDEX idx_license_checks_checked_at ON license_mgmt.license_checks(checked_at);
CREATE INDEX idx_deployments_client_id ON license_mgmt.logic_app_deployments(client_id);

-- Row-level security policies
ALTER TABLE license_mgmt.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE license_mgmt.licenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE license_mgmt.license_checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE license_mgmt.logic_app_deployments ENABLE ROW LEVEL SECURITY;

-- Create function to update timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at
CREATE TRIGGER update_clients_updated_at BEFORE UPDATE ON license_mgmt.clients
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_licenses_updated_at BEFORE UPDATE ON license_mgmt.licenses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
