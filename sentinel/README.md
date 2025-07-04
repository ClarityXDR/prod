# Microsoft Sentinel Integration

This directory contains Microsoft Sentinel configurations, workbooks, playbooks, and custom analytics rules for the ClarityXDR platform integration, featuring the **Microsoft Sentinel All-In-One V3** cost-optimized deployment solution.

## 📋 Overview

The Sentinel module provides comprehensive SIEM capabilities with advanced cost optimization:

- **All-In-One V3 Deployment**: Complete Sentinel environment with cost controls
- **Multi-Tier Storage**: Standard, Auxiliary, and Basic tiers for cost optimization
- **Cost Monitoring Dashboard**: Interactive workbook for cost tracking and optimization
- **Custom Analytics Rules**: Detection rules specific to ClarityXDR
- **Data Collection Rules (DCRs)**: Optimized data ingestion with filtering
- **Industry-Specific Content**: Tailored query packs and configurations

## 📁 Directory Structure

```
sentinel/
├── 📂 v3/                    # Microsoft Sentinel All-In-One V3 deployment
│   ├── 📄 azuredeploy.json   # Main ARM deployment template
│   ├── 📄 costworkbook.json  # Interactive cost optimization workbook
│   ├── 📄 workspace.json     # Log Analytics workspace configuration
│   ├── 📄 createUIDefinition.json # Azure Portal UI definition
│   ├── 📄 tableretention.json # Table retention and tiering settings
│   ├── 📄 dcrtemplate.json   # Data Collection Rules template
│   ├── 📄 corelightDcr.json  # Corelight-specific DCR configuration
│   ├── 📂 LinkedTemplates/   # Modular deployment templates
│   │   ├── 📄 solutions.json # Content Hub solutions deployment
│   │   ├── 📄 alertRules.json # Analytics rules configuration
│   │   ├── 📄 dataConnectors.json # Data connector configurations
│   │   └── 📄 settings.json  # Sentinel settings and UEBA
│   └── 📂 Scripts/          # PowerShell automation scripts
│       ├── 📄 Create-NewSolutionAndRulesFromList.ps1
│       └── 📄 EnableRules.ps1
├── 📂 analytics-rules/       # Custom detection rules for Sentinel
│   ├── 📂 high-fidelity/    # High-confidence detection rules
│   ├── 📂 behavioral/       # Behavioral analytics rules
│   ├── 📂 correlation/      # Multi-signal correlation rules
│   └── 📂 threat-hunting/   # Threat hunting focused rules
├── 📂 workbooks/            # Interactive dashboards and reports
│   ├── 📂 executive/        # Executive summary dashboards
│   ├── 📂 operational/      # SOC operational dashboards
│   ├── 📂 investigation/    # Incident investigation workbooks
│   └── 📂 threat-intel/     # Threat intelligence visualization
├── 📂 playbooks/            # Logic Apps automation workflows
│   ├── 📂 enrichment/       # Alert enrichment playbooks
│   ├── 📂 response/         # Incident response playbooks
│   ├── 📂 notification/     # Alert notification playbooks
│   └── 📂 remediation/      # Automated remediation playbooks
├── 📂 hunting-queries/      # KQL hunting queries
│   ├── 📂 mitre-attack/     # MITRE ATT&CK mapped queries
│   ├── 📂 compromise-assessment/ # Compromise assessment queries
│   ├── 📂 threat-campaigns/ # Known threat campaign queries
│   └── 📂 behavioral/       # Behavioral analysis queries
├── 📂 data-connectors/      # Custom data connector configurations
├── 📂 watchlists/           # Threat intelligence and reference data
├── 📂 functions/            # KQL functions and saved searches
└── 📂 templates/            # ARM templates for deployment
```

## 🎯 Analytics Rules

### High-Fidelity Detection Rules

#### **ClarityXDR-HighConfidence-MalwareExecution.json**
```json
{
  "displayName": "ClarityXDR - High Confidence Malware Execution",
  "description": "Detects high-confidence malware execution based on ClarityXDR correlation engine",
  "severity": "High",
  "enabled": true,
  "query": "ClarityXDREvents | where EventType == 'MalwareDetection' and ConfidenceScore >= 90",
  "tactics": ["Execution", "Defense Evasion"],
  "techniques": ["T1059", "T1055"]
}
```

#### **ClarityXDR-CredentialTheft-Detection.json**
```json
{
  "displayName": "ClarityXDR - Credential Theft Detection",
  "description": "Detects credential theft activities using ClarityXDR behavioral analytics",
  "severity": "High", 
  "enabled": true,
  "query": "ClarityXDREvents | where EventType == 'CredentialAccess' and RiskScore > 75",
  "tactics": ["Credential Access"],
  "techniques": ["T1003", "T1555"]
}
```

### Behavioral Analytics Rules

#### **ClarityXDR-AnomalousUserBehavior.json**
```json
{
  "displayName": "ClarityXDR - Anomalous User Behavior",
  "description": "Machine learning-based detection of anomalous user behavior patterns",
  "severity": "Medium",
  "enabled": true,
  "query": "ClarityXDRBehaviorAnalytics | where AnomalyScore > 0.8 and EntityType == 'User'",
  "tactics": ["Initial Access", "Lateral Movement"],
  "techniques": ["T1078", "T1021"]
}
```

### Correlation Rules

#### **ClarityXDR-MultiVector-Attack.json**
```json
{
  "displayName": "ClarityXDR - Multi-Vector Attack Correlation",
  "description": "Correlates multiple attack vectors within a time window",
  "severity": "High",
  "enabled": true,
  "query": "ClarityXDRCorrelation | where CorrelationScore >= 85 and VectorCount >= 3",
  "tactics": ["Multiple"],
  "techniques": ["Multiple"]
}
```

## 📊 Workbooks

### Executive Dashboard
**File**: `workbooks/executive/ClarityXDR-Executive-Summary.json`

**Features**:
- Security posture overview
- Key risk indicators
- Threat landscape summary
- Compliance status
- ROI metrics

### SOC Operations Dashboard
**File**: `workbooks/operational/ClarityXDR-SOC-Operations.json`

**Features**:
- Real-time alert monitoring
- Incident status tracking
- Analyst performance metrics
- Queue management
- SLA compliance

### Threat Intelligence Workbook
**File**: `workbooks/threat-intel/ClarityXDR-ThreatIntel.json`

**Features**:
- IOC trend analysis
- Attribution tracking
- Campaign monitoring
- Feed performance
- Geographic threat distribution

## 🔍 Hunting Queries

### MITRE ATT&CK Mapped Queries

#### **T1055 - Process Injection Detection**
```kql
// Hunt for process injection techniques
DeviceProcessEvents
| where Timestamp > ago(7d)
| where ProcessCommandLine has_any ("WriteProcessMemory", "SetThreadContext", "ResumeThread")
| join kind=inner (
    ClarityXDREvents
    | where EventType == "ProcessInjection"
    | where ConfidenceScore > 70
) on DeviceId, Timestamp
| project Timestamp, DeviceId, FileName, ProcessCommandLine, ParentProcessName, ClarityXDRScore
| order by Timestamp desc
```

#### **T1071.001 - Web Protocol Command and Control**
```kql
// Hunt for web-based C2 communications
DeviceNetworkEvents
| where Timestamp > ago(24h)
| where RemotePort in (80, 443, 8080, 8443)
| summarize ConnectionCount = count(), 
            DataSent = sum(BytesSent),
            DataReceived = sum(BytesReceived),
            UniqueRemoteIPs = dcount(RemoteIP)
    by DeviceId, InitiatingProcessFileName, bin(Timestamp, 1h)
| where ConnectionCount > 100 or DataSent > 1000000 or UniqueRemoteIPs > 20
| join kind=inner (
    ClarityXDREvents
    | where EventType == "SuspiciousNetworkActivity"
) on DeviceId
```

### Compromise Assessment Queries

#### **Lateral Movement Detection**
```kql
// Hunt for lateral movement indicators
let TimeRange = 7d;
DeviceLogonEvents
| where Timestamp > ago(TimeRange)
| where LogonType in ("Network", "RemoteInteractive")
| summarize LogonCount = count(), 
            UniqueDevices = dcount(DeviceId),
            LogonHours = make_set(hourofday(Timestamp))
    by AccountName, bin(Timestamp, 1h)
| where UniqueDevices > 5 or LogonCount > 20
| join kind=inner (
    ClarityXDRBehaviorAnalytics
    | where EntityType == "User" 
    | where AnomalyScore > 0.7
) on $left.AccountName == $right.EntityName
```

#### **Data Exfiltration Hunt**
```kql
// Hunt for potential data exfiltration
DeviceFileEvents
| where Timestamp > ago(3d)
| where ActionType in ("FileCreated", "FileModified")
| where FileName has_any (".zip", ".rar", ".7z", ".tar")
| summarize FileCount = count(),
            TotalSize = sum(FileSize),
            UniqueLocations = dcount(FolderPath)
    by DeviceId, InitiatingProcessAccountName, bin(Timestamp, 1h)
| where FileCount > 10 or TotalSize > 100000000
| join kind=inner (
    DeviceNetworkEvents
    | where RemotePort in (80, 443, 21, 22)
    | where BytesSent > 10000000
) on DeviceId
```

## 🎭 Playbooks

### Alert Enrichment Playbook
**File**: `playbooks/enrichment/ClarityXDR-Alert-Enrichment.json`

**Capabilities**:
- IOC enrichment from threat intelligence
- Geolocation data addition
- User risk score calculation
- Asset criticality assessment
- Historical context gathering

### Incident Response Playbook
**File**: `playbooks/response/ClarityXDR-Incident-Response.json`

**Capabilities**:
- Automatic incident classification
- Stakeholder notification
- Evidence collection orchestration
- Containment action execution
- Timeline creation

### Automated Remediation Playbook
**File**: `playbooks/remediation/ClarityXDR-Auto-Remediation.json`

**Capabilities**:
- Malware quarantine
- User account disabling
- Network isolation
- File deletion
- Registry cleanup

## 📋 Data Connectors

### ClarityXDR Custom Connector
**File**: `data-connectors/ClarityXDR-Connector.json`

**Data Types**:
- Security alerts and incidents
- Threat intelligence indicators
- Behavioral analytics results
- Correlation engine outputs
- System health metrics

**Configuration**:
```json
{
  "connectorType": "REST API",
  "authentication": "Bearer Token",
  "endpoint": "https://api.clarity-xdr.com/sentinel",
  "polling_interval": "5 minutes",
  "data_types": [
    "SecurityAlerts",
    "ThreatIntelligence",
    "BehaviorAnalytics",
    "CorrelationResults"
  ]
}
```

## 📚 Watchlists

### Threat Intelligence Watchlists

#### **Malicious IPs** (`watchlists/MaliciousIPs.csv`)
```csv
IPAddress,ThreatType,Confidence,Source,LastSeen
192.168.1.100,Command and Control,High,ClarityXDR,2025-07-02
10.0.0.50,Malware Distribution,Medium,External Feed,2025-07-01
```

#### **Suspicious Domains** (`watchlists/SuspiciousDomains.csv`)
```csv
Domain,ThreatType,Confidence,Source,LastSeen
evil.com,Phishing,High,ClarityXDR,2025-07-02
malware-site.net,Malware,High,Threat Intel,2025-07-01
```

#### **High-Value Assets** (`watchlists/HighValueAssets.csv`)
```csv
DeviceName,AssetType,Criticality,Owner,Environment
DC01,Domain Controller,Critical,IT,Production
SQL-PROD-01,Database Server,Critical,DBA,Production
```

## 🔧 Functions and Saved Searches

### KQL Functions

#### **GetClarityXDRRisk**
```kql
// Function to calculate ClarityXDR risk score
let GetClarityXDRRisk = (entity_name: string, entity_type: string) {
    ClarityXDRBehaviorAnalytics
    | where EntityName == entity_name and EntityType == entity_type
    | where Timestamp > ago(7d)
    | summarize RiskScore = max(AnomalyScore), 
                LastSeen = max(Timestamp),
                RiskFactors = make_list(RiskFactor)
    | extend RiskLevel = case(
        RiskScore > 0.8, "Critical",
        RiskScore > 0.6, "High", 
        RiskScore > 0.4, "Medium",
        "Low"
    )
};
```

#### **CorrelateMultipleDataSources**
```kql
// Function to correlate events across multiple data sources
let CorrelateMultipleDataSources = (timewindow: timespan, entity: string) {
    let StartTime = ago(timewindow);
    let EndTime = now();
    
    union
        (SecurityEvent | where TimeGenerated between (StartTime .. EndTime) | where Account == entity),
        (DeviceLogonEvents | where Timestamp between (StartTime .. EndTime) | where AccountName == entity),
        (SigninLogs | where TimeGenerated between (StartTime .. EndTime) | where UserPrincipalName == entity),
        (ClarityXDREvents | where Timestamp between (StartTime .. EndTime) | where EntityName == entity)
    | order by TimeGenerated desc
};
```

## 🚀 Microsoft Sentinel All-In-One V3 Deployment

### Cost-Optimized Features

The V3 deployment introduces advanced cost optimization capabilities:

#### **Multi-Tier Storage Architecture**
- **Standard Tier**: Critical security data requiring frequent querying and real-time analytics
- **Auxiliary Tier**: Less critical data with reduced query frequency but important for security operations
- **Basic Tier**: Compliance data that is rarely queried but needs long-term retention

#### **Data Collection Optimization**
- **Granular DCRs**: Fine-tuned Data Collection Rules for precise data filtering
- **Entra ID Optimization**: Optimized collection of high-volume logs like NonInteractiveSignIn
- **Corelight Integration**: Specialized DCRs for network security data with value-based tiering

#### **Interactive Cost Management**
- **Real-time Cost Dashboard**: Monitor ingestion volumes and costs by data source
- **Optimization Recommendations**: Automated suggestions for cost reduction
- **Table Management Interface**: Interactive controls for adjusting tier and retention settings

### Quick Deployment

#### **Prerequisites**
- Azure subscription with Contributor access
- Microsoft Sentinel licensing
- Resource group with appropriate permissions

#### **One-Click Deployment**
```bash
# Deploy via Azure CLI
az deployment group create \
  --resource-group "ClarityXDR-Sentinel" \
  --template-file "v3/azuredeploy.json" \
  --parameters @v3/parameters.json
```

#### **Azure Portal Deployment**
1. Navigate to the [Azure Portal](https://portal.azure.com)
2. Click "Create a resource" → "Template deployment"
3. Upload `v3/azuredeploy.json`
4. Follow the guided configuration using `v3/createUIDefinition.json`

### Configuration Parameters

#### **Core Settings**
```json
{
  "workspaceName": "ClarityXDR-Workspace",
  "pricingTier": "PerGB2018",
  "dailyQuota": 100,
  "enableMultiTier": true,
  "standardTierRetention": 90,
  "auxiliaryTierRetention": 30,
  "basicTierRetention": 180
}
```

#### **Cost Optimization Settings**
```json
{
  "enableDataConnectors": [
    "AzureActiveDirectory",
    "MicrosoftDefenderAdvancedThreatProtection",
    "SecurityEvents"
  ],
  "enableSolutions1P": [
    "Microsoft Entra ID",
    "Microsoft Defender XDR",
    "Windows Security Events"
  ]
}
```

## 💰 Cost Optimization Features

### Tiering Strategy

#### **High-Value Data (Standard Tier)**
- Security alerts and incidents
- Interactive sign-in logs
- Critical network protocols (DNS, HTTP, SSL)
- Audit logs for compliance

#### **Medium-Value Data (Auxiliary Tier)**
- Non-interactive sign-in logs
- Service principal authentication
- Network connection logs
- Application logs

#### **Low-Value Data (Basic Tier)**
- Verbose protocol logs (SMB, FTP)
- Debug and trace logs
- Historical compliance data

### Automated Cost Controls

#### **Data Collection Rules (DCRs)**
```json
{
  "EntraIDOptimization": {
    "filterCriteria": [
      "Category != 'NonInteractiveUserSignInLogs' OR ResultType != '0'",
      "UserPrincipalName !startswith 'svc-'"
    ],
    "targetTier": "Auxiliary"
  },
  "CorelightOptimization": {
    "highValueProtocols": ["dns", "http", "ssl"],
    "mediumValueProtocols": ["conn"],
    "lowValueProtocols": ["smb", "ftp"]
  }
}
```

#### **Table Retention Management**
```json
{
  "retentionPolicies": {
    "SecurityAlert": 365,
    "SecurityIncident": 730,
    "SigninLogs": 90,
    "NonInteractiveUserSignInLogs": 30,
    "CoreLight_Conn": 60,
    "CoreLight_SMB": 7
  }
}
```

### Cost Monitoring Dashboard

#### **Key Metrics Tracked**
- Daily ingestion volumes by data source
- Monthly cost projections with optimization
- Growth trends and anomaly detection
- Savings opportunities by tier changes

#### **Interactive Controls**
- Real-time table tier adjustments
- Retention period modifications
- Filter rule management
- Cost impact calculations

## 📊 Deployment Options

### Standard Deployment
```powershell
# Basic deployment with default cost optimization
.\Deploy-SentinelV3.ps1 -ResourceGroup "ClarityXDR-RG" -WorkspaceName "ClarityXDR-Workspace"
```

### Government Cloud Deployment
```powershell
# Government cloud deployment with enhanced security
.\Deploy-SentinelV3.ps1 -ResourceGroup "ClarityXDR-RG" -IsGov $true -SecurityLevel "Enhanced"
```

### Custom Industry Configuration
```powershell
# Healthcare-specific deployment with compliance focus
.\Deploy-SentinelV3.ps1 -Industry "Healthcare" -ComplianceFramework "HIPAA"
```

## 🔧 Post-Deployment Configuration

### Solution Management
```powershell
# Deploy specific security solutions
.\v3\Scripts\Create-NewSolutionAndRulesFromList.ps1 `
  -ResourceGroup "ClarityXDR-RG" `
  -Workspace "ClarityXDR-Workspace" `
  -Solutions @("Microsoft Entra ID", "Microsoft Defender XDR", "Windows Security Events")
```

### Rule Enablement
```powershell
# Enable analytics rules for specific connectors
.\v3\Scripts\EnableRules.ps1 `
  -ResourceGroup "ClarityXDR-RG" `
  -Workspace "ClarityXDR-Workspace" `
  -Connectors @("AzureActiveDirectory", "MicrosoftDefenderAdvancedThreatProtection") `
  -SeveritiesToInclude @("Medium", "High")
```

### Cost Optimization Recommendations

#### **Immediate Actions**
1. **Review NonInteractive Sign-in Logs**: Move to Auxiliary tier for 60-80% cost reduction
2. **Optimize Corelight Data**: Implement protocol-specific tiering strategy
3. **Adjust Retention Periods**: Align retention with compliance requirements
4. **Enable Data Filtering**: Use DCRs to filter unnecessary data before ingestion

#### **Weekly Actions**
1. Review cost dashboard for trends and anomalies
2. Identify new high-volume data sources
3. Adjust tier assignments based on query patterns
4. Monitor growth rates and implement controls

#### **Monthly Actions**
1. Analyze month-over-month cost changes
2. Review and update filtering rules
3. Optimize retention periods based on actual usage
4. Evaluate new cost optimization opportunities

## 📚 References

- [Microsoft Sentinel Documentation](https://docs.microsoft.com/en-us/azure/sentinel/)
- [KQL Query Language Reference](https://docs.microsoft.com/en-us/azure/data-explorer/kusto/query/)
- [MITRE ATT&CK Framework](https://attack.mitre.org/)
- [Azure Logic Apps Documentation](https://docs.microsoft.com/en-us/azure/logic-apps/)
- [Sentinel REST API Reference](https://docs.microsoft.com/en-us/rest/api/securityinsights/)

---

**Last Updated**: July 2025 | **Maintained by**: SIEM Engineering Team
