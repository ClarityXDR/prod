# Logic Apps Deployment Guide

## Overview
This document provides instructions for deploying the sanitized Logic App JSON files to your Azure environment.

## Prerequisites
- Azure subscription with appropriate permissions
- Azure Logic Apps resource group
- Required Azure service connections (Sentinel, Office 365, Teams, etc.)
- Key Vault for storing sensitive information

## Sanitization Summary
The following PII and sensitive information has been removed/replaced:

### Email Addresses
- `gregory_hall@bio-rad.com` → `admin@company.com`
- `global_infosec@bio-rad.com` → `security@company.com`
- `SecurityTeam@bio-rad.com` → `securityteam@company.com`
- `@global.bio-rad.com` → `@company.com`

### Company References
- `Bio-Rad` → `YourCompany`
- `bio-rad.com` → `company.com`
- `Bio-Rad Laboratories` → `Your Company`
- `Bio-Rad Global Information Security` → `Your Company Information Security`

### Azure Resources
- Subscription ID: `b4e0a897-1c30-4c8a-950f-1117044b8298` → `00000000-0000-0000-0000-000000000000`
- Resource Group: `InformationSecurity` → `YourResourceGroup`
- Teams Channel ID: `19:4fbae423f8a8450e939b43cb777183ff@thread.tacv2` → `19:00000000000000000000000000000000@thread.tacv2`

### Connection Names
- `office365-12` → `office365-connection`
- `teams-3` → `teams-connection`
- `azuresentinel-10` → `azuresentinel-connection`
- `azuremonitorlogs-5` → `azuremonitorlogs-connection`

## Required Pre-Deployment Steps

### 1. Create Azure Connections
Before deploying Logic Apps, create the following API connections in your Azure resource group:

#### Microsoft Sentinel Connection
```powershell
# Create Sentinel connection
az resource create --resource-group YourResourceGroup \
  --resource-type Microsoft.Web/connections \
  --name azuresentinel-connection \
  --properties @sentinel-connection.json
```

#### Office 365 Connection
```powershell
# Create Office 365 connection
az resource create --resource-group YourResourceGroup \
  --resource-type Microsoft.Web/connections \
  --name office365-connection \
  --properties @office365-connection.json
```

#### Teams Connection
```powershell
# Create Teams connection
az resource create --resource-group YourResourceGroup \
  --resource-type Microsoft.Web/connections \
  --name teams-connection \
  --properties @teams-connection.json
```

#### Azure Monitor Logs Connection
```powershell
# Create Azure Monitor Logs connection
az resource create --resource-group YourResourceGroup \
  --resource-type Microsoft.Web/connections \
  --name azuremonitorlogs-connection \
  --properties @azuremonitorlogs-connection.json
```

### 2. Update Configuration Files
Replace the following placeholders in all JSON files:

1. **Subscription ID**: Replace `00000000-0000-0000-0000-000000000000` with your actual Azure subscription ID
2. **Resource Group**: Replace `YourResourceGroup` with your actual resource group name
3. **Email Addresses**: Replace placeholder emails with your actual security team contacts
4. **Company Name**: Replace `YourCompany` with your actual company name
5. **Teams Channel ID**: Replace `19:00000000000000000000000000000000@thread.tacv2` with your actual Teams channel ID

### 3. Configure Key Vault (Recommended)
Store sensitive information in Azure Key Vault:

```json
{
  "security-team-email": "security@yourcompany.com",
  "admin-email": "admin@yourcompany.com",
  "teams-channel-id": "your-actual-channel-id"
}
```

## Deployment Process

### Option 1: Azure CLI Deployment
```powershell
# Deploy Logic App
az logicapp create --resource-group YourResourceGroup \
  --name YourLogicAppName \
  --definition @path/to/sanitized/logicapp.json
```

### Option 2: ARM Template Deployment
```powershell
# Deploy using ARM template
az deployment group create --resource-group YourResourceGroup \
  --template-file logicapp-template.json \
  --parameters @logicapp-parameters.json
```

### Option 3: Azure Portal Deployment
1. Navigate to Azure Portal
2. Create new Logic App
3. Use "Code View" to paste the sanitized JSON
4. Configure connections and parameters
5. Test the Logic App

## Post-Deployment Configuration

### 1. Connection Authentication
After deployment, authenticate all API connections:
- Office 365: Sign in with service account
- Teams: Authorize with Teams admin account
- Sentinel: Configure with appropriate permissions

### 2. Test Logic Apps
Before enabling production triggers:
1. Test each Logic App manually
2. Verify email notifications work correctly
3. Check Teams integrations
4. Validate Sentinel integration

### 3. Enable Triggers
Once testing is complete:
1. Enable recurrence triggers
2. Configure webhook endpoints
3. Set up monitoring and alerting

## Security Considerations

### 1. Managed Identity
Use Managed Identity for authentication where possible:
```json
"authentication": {
  "type": "ManagedServiceIdentity"
}
```

### 2. Key Vault Integration
Reference Key Vault secrets instead of hardcoded values:
```json
"emailAddress": "@parameters('$connections')['keyvault']['connectionId']"
```

### 3. Network Security
- Configure private endpoints if required
- Implement network access restrictions
- Use VNet integration for sensitive operations

## Monitoring and Maintenance

### 1. Logic App Monitoring
- Enable Application Insights
- Configure run history retention
- Set up failure alerts

### 2. Connection Monitoring
- Monitor connection health
- Set up renewal alerts for OAuth tokens
- Implement connection testing workflows

### 3. Performance Optimization
- Review execution patterns
- Optimize trigger frequency
- Implement retry policies

## Troubleshooting

### Common Issues
1. **Connection Authentication Failures**
   - Verify service account permissions
   - Check OAuth token expiration
   - Validate API permissions

2. **Email Delivery Issues**
   - Verify SMTP settings
   - Check spam filters
   - Validate recipient addresses

3. **Teams Integration Problems**
   - Verify channel permissions
   - Check Teams app registrations
   - Validate webhook URLs

### Logs and Diagnostics
- Check Logic App run history
- Review connection diagnostics
- Monitor Azure Activity Log

## Support and Documentation
- Azure Logic Apps Documentation: https://docs.microsoft.com/en-us/azure/logic-apps/
- Troubleshooting Guide: https://docs.microsoft.com/en-us/azure/logic-apps/logic-apps-diagnosing-failures
- Best Practices: https://docs.microsoft.com/en-us/azure/logic-apps/logic-apps-best-practices

## File Inventory
The following Logic App files have been sanitized and are ready for deployment:

$(Get-ChildItem "C:\ClarityXDR\logicapps_sanitized_final\*.json" | Where-Object {$_.Name -ne "sanitization_report.txt"} | ForEach-Object {"- $($_.Name)"} | Out-String)

**Note**: Each file requires individual review for environment-specific configurations before deployment.
