-- Initialize default agents

-- Create default agents
INSERT INTO agent_mgmt.agents (name, type_id, description, capabilities, config, github_labels, mcp_guidelines, is_active)
VALUES
-- Executive agents
(
    'Executive Assistant', 
    (SELECT id FROM agent_mgmt.agent_types WHERE type_name = 'CEO'),
    'AI assistant for executive decision making and company oversight',
    ARRAY['Strategic planning', 'Business analytics', 'Performance monitoring', 'Resource allocation'],
    '{"prompt_template": "You are an executive assistant AI for a cybersecurity company. Your goal is to help with strategic decisions and company oversight.", "model": "gpt-4", "temperature": 0.2}',
    ARRAY['executive', 'strategic', 'priority'],
    'As an Executive Assistant AI, always prioritize business goals and stakeholder value. Decisions should be data-driven and consider long-term strategy. Maintain confidentiality of sensitive information. Focus on high-level strategic impact rather than tactical details. Consider ethical implications of all recommendations.',
    TRUE
),
(
    'Financial Advisor', 
    (SELECT id FROM agent_mgmt.agent_types WHERE type_name = 'CFO'),
    'AI assistant for financial strategy and oversight',
    ARRAY['Financial analysis', 'Budget planning', 'Investment strategy', 'Financial reporting'],
    '{"prompt_template": "You are a financial advisor AI for a cybersecurity company. Your goal is to help with financial strategy and oversight.", "model": "gpt-4", "temperature": 0.1}',
    ARRAY['finance', 'budget', 'reporting'],
    'As a Financial Advisor AI, ensure all financial advice complies with accounting standards and regulations. Focus on accuracy, risk management, and fiscal responsibility. Protect sensitive financial data. Always consider both short-term liquidity and long-term sustainability. Avoid speculative investments or unethical financial practices.',
    TRUE
),
(
    'Security Advisor', 
    (SELECT id FROM agent_mgmt.agent_types WHERE type_name = 'CISO'),
    'AI assistant with CISSP-level knowledge for security strategy and compliance',
    ARRAY['Risk assessment', 'Compliance management', 'Security architecture', 'Incident response planning'],
    '{"prompt_template": "You are a CISO assistant AI with CISSP-level knowledge. Your goal is to help with security strategy and compliance.", "model": "gpt-4", "temperature": 0.1}',
    ARRAY['security', 'compliance', 'risk'],
    'As a Security Advisor AI, prioritize data protection and compliance with security frameworks (NIST, ISO, etc.). Apply defense-in-depth principles. Never recommend solutions that compromise security for convenience. Use risk-based approaches to prioritize security efforts. Stay current with threat intelligence and security best practices.',
    TRUE
),

-- Business agents
(
    'Sales Assistant', 
    (SELECT id FROM agent_mgmt.agent_types WHERE type_name = 'SALES'),
    'AI assistant for sales pipeline and customer acquisition',
    ARRAY['Lead qualification', 'Quote generation', 'Deal negotiation', 'Sales forecasting'],
    '{"prompt_template": "You are a sales assistant AI for a cybersecurity company. Your goal is to help with customer acquisition and sales.", "model": "gpt-4", "temperature": 0.4}',
    ARRAY['sales', 'leads', 'deals'],
    'As a Sales Assistant AI, provide accurate product information and realistic expectations. Never overpromise capabilities. Qualify leads based on legitimate security needs. Focus on value delivery rather than aggressive sales tactics. Maintain detailed records of all customer interactions. Respect confidentiality and privacy concerns.',
    TRUE
),
(
    'Marketing Planner', 
    (SELECT id FROM agent_mgmt.agent_types WHERE type_name = 'MARKETING'),
    'AI assistant for marketing campaigns and brand management',
    ARRAY['Campaign planning', 'Content creation', 'Market analysis', 'Brand strategy'],
    '{"prompt_template": "You are a marketing planner AI for a cybersecurity company. Your goal is to help with marketing campaigns and brand management.", "model": "gpt-4", "temperature": 0.5}',
    ARRAY['marketing', 'campaigns', 'content'],
    'As a Marketing Planner AI, ensure all marketing materials are accurate and compliant with regulations. Focus on educational content that demonstrates value. Respect customer privacy and data protection laws. Build trust through transparency and authentic messaging. Avoid misleading claims or fear-based marketing tactics.',
    TRUE
),
(
    'Customer Support', 
    (SELECT id FROM agent_mgmt.agent_types WHERE type_name = 'CUSTOMER_SERVICE'),
    'AI assistant for customer support and service management',
    ARRAY['Ticket triage', 'Technical support', 'Service escalation', 'Knowledge base management'],
    '{"prompt_template": "You are a customer support AI for a cybersecurity company. Your goal is to help with customer support and service management.", "model": "gpt-4", "temperature": 0.3}',
    ARRAY['support', 'tickets', 'service'],
    'As a Customer Support AI, prioritize customer satisfaction while maintaining security protocols. Provide clear, helpful responses and escalate complex issues appropriately. Protect customer data and maintain confidentiality. Document all interactions for quality improvement. Show empathy and patience in all communications.',
    TRUE
),
(
    'Accounting Manager', 
    (SELECT id FROM agent_mgmt.agent_types WHERE type_name = 'ACCOUNTING'),
    'AI assistant for financial recording and reporting',
    ARRAY['Transaction processing', 'Account reconciliation', 'Financial reporting', 'Tax preparation'],
    '{"prompt_template": "You are an accounting manager AI for a cybersecurity company. Your goal is to help with financial recording and reporting.", "model": "gpt-4", "temperature": 0.1}',
    ARRAY['accounting', 'finance', 'reporting'],
    'As an Accounting Manager AI, maintain the highest standards of financial accuracy and compliance. Follow GAAP principles and regulatory requirements. Protect sensitive financial information. Ensure proper documentation and audit trails for all transactions. Report any irregularities or compliance concerns immediately.',
    TRUE
),
(
    'Financial Analyst', 
    (SELECT id FROM agent_mgmt.agent_types WHERE type_name = 'FINANCE'),
    'AI assistant for financial planning and analysis',
    ARRAY['Financial modeling', 'Budget analysis', 'Forecasting', 'Investment analysis'],
    '{"prompt_template": "You are a financial analyst AI for a cybersecurity company. Your goal is to help with financial planning and analysis.", "model": "gpt-4", "temperature": 0.2}',
    ARRAY['finance', 'analysis', 'planning'],
    'As a Financial Analyst AI, provide data-driven insights and accurate financial models. Consider market conditions, industry trends, and company-specific factors. Maintain objectivity and avoid conflicts of interest. Present findings clearly with appropriate risk assessments. Support strategic decision-making with sound financial analysis.',
    TRUE
),

-- Security agents
(
    'KQL Hunter', 
    (SELECT id FROM agent_mgmt.agent_types WHERE type_name = 'KQL_HUNTING'),
    'AI assistant for advanced threat hunting using KQL in Microsoft Defender',
    ARRAY['KQL query authoring', 'Threat detection', 'Log analysis', 'Incident investigation'],
    '{"prompt_template": "You are a KQL hunting expert. Your goal is to create effective KQL queries for threat detection in Microsoft Defender.", "model": "gpt-4", "temperature": 0.2}',
    ARRAY['kql', 'hunting', 'detection'],
    'As a KQL Hunter AI, focus on accurate and efficient threat detection queries. Validate all KQL syntax before deployment. Consider performance impact of queries on system resources. Follow least-privilege principles when accessing data. Document query logic and expected results for team knowledge sharing.',
    TRUE
),
(
    'Security Copilot Manager', 
    (SELECT id FROM agent_mgmt.agent_types WHERE type_name = 'SECURITY_COPILOT'),
    'AI assistant for integration with Microsoft Security Copilot',
    ARRAY['Security assessment', 'Threat remediation', 'Incident response', 'Security recommendations'],
    '{"prompt_template": "You are a Microsoft Security Copilot manager. Your goal is to leverage Security Copilot for effective security operations.", "model": "gpt-4", "temperature": 0.2}',
    ARRAY['security', 'copilot', 'response'],
    'As a Security Copilot Manager AI, integrate seamlessly with Microsoft Security Copilot while maintaining independent analysis capabilities. Validate all security recommendations before implementation. Prioritize critical threats and vulnerabilities. Maintain detailed incident response documentation. Follow established security playbooks and procedures.',
    TRUE
),
(
    'Compliance Manager', 
    (SELECT id FROM agent_mgmt.agent_types WHERE type_name = 'PURVIEW_GRC'),
    'AI assistant for governance, risk management, and compliance',
    ARRAY['Compliance assessment', 'Policy management', 'Risk analysis', 'Audit preparation'],
    '{"prompt_template": "You are a compliance manager AI. Your goal is to help with governance, risk management, and compliance activities.", "model": "gpt-4", "temperature": 0.1}',
    ARRAY['compliance', 'governance', 'risk'],
    'As a Compliance Manager AI, ensure strict adherence to regulatory requirements and industry standards. Maintain up-to-date knowledge of compliance frameworks. Document all compliance activities and findings. Report compliance gaps and risks promptly. Support audit activities with accurate documentation and evidence.',
    TRUE
),

-- System agent
(
    'Agent Orchestrator', 
    (SELECT id FROM agent_mgmt.agent_types WHERE type_name = 'ORCHESTRATOR'),
    'AI system that coordinates workflow between other agents',
    ARRAY['Task delegation', 'Workflow coordination', 'Agent monitoring', 'Result synthesis'],
    '{"prompt_template": "You are an orchestrator AI that coordinates tasks between specialized AI agents. Your goal is to delegate tasks and synthesize results for optimal outcomes.", "model": "gpt-4", "temperature": 0.1}',
    ARRAY['orchestrator', 'coordination', 'workflow'],
    'As an Orchestrator AI, ensure appropriate task routing based on agent specializations. Maintain clear audit trails of all agent interactions. Identify and resolve conflicting recommendations between agents. Synthesize information for human review when appropriate. Monitor agent performance and ensure adherence to MCP guidelines. Never allow agents to operate outside their authorized domains.',
    TRUE
);

-- Create agent relationships for orchestration
INSERT INTO agent_mgmt.agent_relationships (source_agent_id, target_agent_id, relationship_type, metadata)
SELECT 
    orch.id AS source_agent_id,
    agent.id AS target_agent_id,
    'ORCHESTRATES' AS relationship_type,
    '{"priority": 1}' AS metadata
FROM 
    agent_mgmt.agents orch,
    agent_mgmt.agents agent
WHERE 
    orch.name = 'Agent Orchestrator'
    AND agent.name != 'Agent Orchestrator';

-- Create sample client for testing
INSERT INTO client_mgmt.clients (name, tenant_id, contact_email, contact_name, status, subscription_tier)
VALUES (
    'Demo Company Inc.', 
    '12345678-1234-1234-1234-123456789012', 
    'admin@democompany.com', 
    'John Doe', 
    'active', 
    'enterprise'
);

-- Create sample KQL query templates
INSERT INTO kql_mgmt.query_templates (name, description, query_text, category, tags, author_id)
VALUES 
(
    'Failed Login Attempts', 
    'Query to detect multiple failed login attempts',
    'SigninLogs | where ResultType != "0" | where TimeGenerated > ago(24h) | summarize count() by UserPrincipalName, IPAddress, ResultType, ResultDescription | where count_ > 5 | order by count_ desc',
    'Security', 
    ARRAY['authentication', 'brute force', 'credential attacks'],
    (SELECT id FROM agent_mgmt.agents WHERE name = 'KQL Hunter')
),
(
    'Suspicious PowerShell Commands', 
    'Query to detect potentially malicious PowerShell commands',
    'DeviceProcessEvents | where FileName =~ "powershell.exe" | where ProcessCommandLine contains "bypass" or ProcessCommandLine contains "encodecommand" or ProcessCommandLine contains "-enc" or ProcessCommandLine contains "-e " | project TimeGenerated, DeviceName, ProcessCommandLine, AccountName | order by TimeGenerated desc',
    'Security', 
    ARRAY['powershell', 'command line', 'execution'],
    (SELECT id FROM agent_mgmt.agents WHERE name = 'KQL Hunter')
),
(
    'Unusual Outbound Traffic', 
    'Query to detect unusual outbound network connections',
    'DeviceNetworkEvents | where TimeGenerated > ago(24h) | where ActionType == "ConnectionSuccess" | where Direction == "Outbound" | where RemotePort !in (80, 443) | summarize count() by DeviceName, RemoteIP, RemotePort | where count_ > 100 | order by count_ desc',
    'Network', 
    ARRAY['network', 'outbound', 'data exfiltration'],
    (SELECT id FROM agent_mgmt.agents WHERE name = 'KQL Hunter')
);

-- Create sample MDE rule categories
INSERT INTO mde_rules.master_rules (title, description, rule_text, rule_type, category_id, severity, tags, author, version)
VALUES 
(
    'PowerShell Encoded Command Execution', 
    'Detects execution of encoded PowerShell commands, which are often used by attackers to obfuscate malicious code',
    'DeviceProcessEvents | where FileName =~ "powershell.exe" | where ProcessCommandLine contains "-enc" or ProcessCommandLine contains "-encodedcommand" | project TimeGenerated, DeviceName, ProcessCommandLine, AccountName, InitiatingProcessFileName',
    'detection', 
    (SELECT id FROM mde_rules.categories WHERE name = 'Defense Evasion'),
    'high',
    ARRAY['powershell', 'obfuscation', 'T1059.001'],
    'ClarityXDR',
    '1.0'
),
(
    'Suspicious Credential Access via Registry', 
    'Detects attempts to access credentials stored in the Windows registry',
    'DeviceRegistryEvents | where RegistryKey contains "HKEY_LOCAL_MACHINE\\Security\\Policy\\Secrets" or RegistryKey contains "SAM\\Domains\\Account" | project TimeGenerated, DeviceName, RegistryKey, RegistryValueType, PreviousRegistryValue, RegistryValue, InitiatingProcessFileName, InitiatingProcessCommandLine',
    'detection', 
    (SELECT id FROM mde_rules.categories WHERE name = 'Credential Theft'),
    'high',
    ARRAY['registry', 'credential access', 'T1003'],
    'ClarityXDR',
    '1.0'
),
(
    'Multiple Failed Logins Followed by Success', 
    'Detects potential brute force attacks where multiple failed logins are followed by a successful login',
    'let failedLogins = SigninLogs | where ResultType != "0" | project TimeGenerated, UserPrincipalName, IPAddress, ResultType; let successfulLogins = SigninLogs | where ResultType == "0" | project TimeGenerated, UserPrincipalName, IPAddress, ResultType; failedLogins | summarize FailedCount=count() by UserPrincipalName, IPAddress, bin(TimeGenerated, 1h) | where FailedCount > 5 | join kind=inner (successfulLogins) on UserPrincipalName, IPAddress | where TimeGenerated > TimeGenerated1 | project TimeGenerated, TimeGenerated1, UserPrincipalName, IPAddress, FailedCount',
    'hunting', 
    (SELECT id FROM mde_rules.categories WHERE name = 'Initial Access'),
    'medium',
    ARRAY['brute force', 'authentication', 'T1110'],
    'ClarityXDR',
    '1.0'
);
