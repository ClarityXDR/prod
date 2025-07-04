# Logic Apps Deployment Scripts

## Overview
This directory contains scripts to deploy the sanitized Logic Apps to Azure Sentinel properly.

## Files
- `Deploy-LogicApps.ps1` - Main deployment script
- `Test-LogicApps.ps1` - Validation script  
- `config.template.json` - Configuration template
- `README.md` - This documentation

## Prerequisites
1. Azure PowerShell modules installed
2. Azure subscription with appropriate permissions
3. Microsoft Sentinel workspace configured
4. Configuration file prepared

## Quick Start

### 1. Prepare Configuration
```powershell
# Copy and customize configuration template
Copy-Item "config.template.json" "config.json"
# Edit config.json with your environment values
```

### 2. Deploy Logic Apps
```powershell
.\Deploy-LogicApps.ps1 -SubscriptionId "your-sub-id" -ResourceGroupName "sentinel-rg" -ConfigFilePath ".\config.json"
```

### 3. Validate Deployment
```powershell
.\Test-LogicApps.ps1 -SubscriptionId "your-sub-id" -ResourceGroupName "sentinel-rg" -ConfigFilePath ".\config.json"
```

## Configuration Parameters
- `subscriptionId` - Azure subscription ID
- `resourceGroupName` - Target resource group
- `location` - Azure region for deployment
- `adminEmail` - Admin email address
- `securityEmail` - Security team email
- `companyName` - Your company name
- `teamsChannelId` - Teams channel for notifications
- `sentinelWorkspaceId` - Sentinel workspace ID

## Post-Deployment Steps
1. Authenticate API connections in Azure Portal
2. Test Logic Apps manually
3. Configure monitoring and alerting
4. Enable production triggers
5. Validate Sentinel integration

## Troubleshooting
- Check deployment logs in generated log files
- Verify API connection authentication
- Review resource group deployment history
- Validate configuration parameters
