# Implementation Guide - Microsoft 365 E5 Central Threat Intelligence Solution

## Prerequisites

### Required Licenses and Permissions

- Microsoft 365 E5 (includes Defender for Endpoint, Exchange Online Protection)
- Microsoft Sentinel
- Azure Logic Apps
- Global Administrator or Security Administrator roles

### Required PowerShell Modules

```powershell
Install-Module -Name Az -Force
Install-Module -Name ExchangeOnlineManagement -Force
Install-Module -Name Microsoft.Graph -Force
Install-Module -Name MicrosoftDefenderATP -Force
```

### API Permissions Required

- Microsoft Graph: ThreatIndicators.ReadWrite.OwnedBy
- Microsoft Defender: Ti.ReadWrite
- Exchange Online: Exchange.ManageAsApp
- Microsoft Sentinel: Contributor on workspace

## Phase 1: Sentinel Threat Intelligence Configuration

### 1.1 Enable Threat Intelligence Data Connector

1. Navigate to Microsoft Sentinel > Data connectors
2. Search for "Threat Intelligence - TAXII"
3. Configure the connector with your threat feeds

### 1.2 Create Custom Threat Intelligence Table

```kql
// Custom table schema for CTI_IndicatorManagement_CL
CTI_IndicatorManagement_CL
| extend 
    IndicatorId = tostring(IndicatorId_s),
    IndicatorType = tostring(IndicatorType_s),
    IndicatorValue = tostring(IndicatorValue_s),
    ConfidenceScore = toint(ConfidenceScore_d),
    Source = tostring(Source_s),
    CreatedDate = todatetime(CreatedDate_t),
    ExpirationDate = todatetime(ExpirationDate_t),
    DeploymentStatus = tostring(DeploymentStatus_s),
    ValidationStatus = tostring(ValidationStatus_s),
    LastValidated = todatetime(LastValidated_t),
    PlacementStrategy = tostring(PlacementStrategy_s)
```

## Phase 2: Logic Apps Deployment

### 2.1 IoC Ingestion Logic App

- Accepts indicators from multiple sources
- Validates format and enriches with context
- Determines placement strategy
- Deploys to appropriate M365 security products

### 2.2 Validation Logic App

- Scheduled runs (daily/weekly based on criticality)
- Queries VirusTotal and Microsoft Threat Intel
- Updates confidence scores
- Removes expired or false positive indicators

### 2.3 False Positive Management Logic App

- Processes reported false positives
- Removes from all security products
- Updates central database
- Sends notifications to security team

## Phase 3: PowerShell Module Configuration

### 3.1 Core CTI Module Functions

- `Get-CTIIndicators` - Retrieve indicators from Sentinel
- `Set-CTIIndicator` - Create/update indicators
- `Remove-CTIIndicator` - Remove indicators from all products
- `Test-CTIIndicatorValidity` - Validate indicators against threat intel services
- `Sync-CTIToSecurityProducts` - Manual sync to security products

### 3.2 Product-Specific Functions

- `Set-MDEIndicator` - Deploy to Defender for Endpoint
- `Set-ExchangeBlockList` - Deploy to Exchange Online
- `Set-MDCAPolicy` - Deploy IP addresses to Defender for Cloud Apps as **risky category**
- `Add-EntraNamedLocation` - Deploy to Entra ID Conditional Access as **Named Location with sign-in blocking**
- `Remove-MDCAPolicy` - Remove IP addresses from MDCA risky category
- `Remove-EntraNamedLocation` - Remove Named Location and associated Conditional Access blocking policy
- `Get-CTIDeploymentStatus` - Check deployment status across all security products

### 3.3 MDCA Integration Details

The CTI solution integrates with Microsoft Defender for Cloud Apps to:

- **Mark IP addresses as risky category**: Automatically categorizes malicious IPs as risky in MDCA
- **Create governance policies**: Applies appropriate governance actions for risky IP ranges
- **Monitor cloud app access**: Tracks and logs access attempts from risky IPs
- **Severity-based actions**: Applies different governance controls based on threat severity

**Key Functions:**
- `Set-MDCAPolicy -IPAddress "192.168.1.100" -Severity "High"` - Adds IP to risky category
- Policy naming convention: `CTI_RiskyIP_[IP_with_underscores]`
- Automatic logging to Sentinel for audit trail

### 3.4 Entra ID Named Location Integration

The solution creates Named Locations in Entra ID that:

- **Block all sign-ins**: Creates Conditional Access policies that completely block authentication
- **Apply to all users**: Blocks sign-ins for all users and applications
- **Immediate enforcement**: Takes effect immediately upon creation
- **Automatic cleanup**: Removes both Named Location and Conditional Access policy when indicator expires

**Key Functions:**
- `Add-EntraNamedLocation -IPAddress "192.168.1.100"` - Creates Named Location and blocking policy
- Policy naming convention: `CTI_Block_CTI_Malicious_[IP_with_underscores]`
- Supports both single IPs (/32) and CIDR ranges
- Automatic policy cleanup when indicators are removed

## Phase 4: Workbook Customization

### 4.1 New Workbook Tabs

1. **CTI Dashboard** - Overview of all indicators and their status
2. **Deployment Status** - Track deployment across security products
3. **Validation Results** - Monitor validation outcomes and false positives
4. **Performance Metrics** - Measure effectiveness and coverage

### 4.2 Key Metrics to Track

- Total indicators by type and product
- Validation success rate
- False positive rate
- Coverage gaps
- Response time metrics

## Phase 5: Deployment and Testing

### 5.1 Initial Deployment

1. Deploy Logic Apps using ARM templates
2. Import PowerShell modules
3. Configure API connections
4. Test with sample indicators
5. Import custom workbook

### 5.2 Validation Testing

1. Submit known good and bad indicators
2. Verify placement in correct products
3. Test validation workflows
4. Validate false positive handling

## Ongoing Operations

### Daily Tasks

- Monitor Logic App runs for errors
- Review validation results
- Process false positive reports

### Weekly Tasks

- Review performance metrics
- Update confidence thresholds
- Audit indicator placements

### Monthly Tasks

- Comprehensive validation of all indicators
- Review and update placement strategies
- Performance optimization

## Troubleshooting

### Common Issues

1. **API Authentication Failures** - Check service principal permissions
2. **Logic App Timeouts** - Implement batching for large indicator sets
3. **False Positive Spikes** - Review confidence score thresholds
4. **Deployment Failures** - Check product-specific limits and formats

### Monitoring Points

- Logic App execution history
- Sentinel custom logs for CTI operations
- Security product event logs
- Performance counters in workbook
