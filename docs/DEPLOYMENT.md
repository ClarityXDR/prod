# ClarityXDR Deployment Guide

This guide provides comprehensive instructions for deploying and configuring the ClarityXDR platform.

## Prerequisites

### Required Azure Permissions
- **Subscription Contributor**: Required for resource creation
- **Security Admin**: Required for Microsoft Sentinel configuration
- **Global Administrator**: Required for app registration (can be delegated)

### Required Licenses
- **Microsoft 365 E5** or **Microsoft Defender for Business Premium**
- **Azure subscription** with sufficient credit/billing
- **Microsoft Sentinel** (consumption-based pricing)

### Technical Requirements
- **PowerShell 5.1+** with the following modules:
  - Az.Accounts
  - Az.Resources
  - Az.KeyVault
  - Microsoft.Graph.Applications
  - ExchangeOnlineManagement (optional)

## Deployment Options

### Option 1: One-Click Deployment (Recommended)

1. **Click Deploy to Azure**:
   [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FClarityXDR%2FClarityXDR%2Fmain%2Fazuredeploy.json)

2. **Fill Required Parameters**:
   - **Deployment Prefix**: Unique identifier (e.g., "ClarityXDR")
   - **Organization Name**: Your company name
   - **Administrator Email**: Primary contact for alerts
   - **Location**: Azure region (recommend East US or West Europe)

3. **Configure Optional Settings**:
   - **Pricing Tier**: Choose between Pay-as-you-go or Capacity Reservation
   - **Data Retention**: Set retention period (30-730 days)
   - **Integrations**: Enable/disable specific Microsoft services
   - **Advanced**: Configure optional API keys and service accounts

4. **Review and Deploy**:
   - Review all settings
   - Click "Create" to start deployment
   - Deployment takes 15-30 minutes

### Option 2: Manual Deployment

```powershell
# Clone repository
git clone https://github.com/ClarityXDR/ClarityXDR.git
cd ClarityXDR

# Create resource group
az group create --name "ClarityXDR-RG" --location "eastus"

# Deploy template
az deployment group create \
  --resource-group "ClarityXDR-RG" \
  --template-file "azuredeploy.json" \
  --parameters "@azuredeploy.parameters.json"
```

## Post-Deployment Configuration

### Step 1: App Registration Setup

```powershell
# Run the app registration script
.\scripts\clarity-xdr-app-registration.ps1 -ResourceGroup "ClarityXDR-RG" -Location "eastus"

# Note the output - you'll need these values:
# - Application ID
# - Client Secret
# - Tenant ID
```

### Step 2: Configure Data Connectors

1. Navigate to **Microsoft Sentinel** in Azure Portal
2. Go to **Configuration > Data connectors**
3. Enable the following connectors:
   - Microsoft Defender for Endpoint
   - Microsoft Entra ID (Azure AD)
   - Microsoft Defender for Office 365
   - Azure Activity (if enabled)

### Step 3: Import Detection Rules

```powershell
# Import all detection rules
$WorkspaceId = "your-workspace-id"
$ResourceGroup = "ClarityXDR-RG"

# Run rule import script
.\scripts\import-detection-rules.ps1 -WorkspaceId $WorkspaceId -ResourceGroup $ResourceGroup
```

### Step 4: Configure Logic Apps

1. Navigate to **Logic Apps** in Azure Portal
2. For each deployed Logic App:
   - Open the Logic App
   - Configure API connections
   - Test the workflow
   - Enable the Logic App

### Step 5: Set Up Automation

```powershell
# Configure Azure Automation
$AutomationAccount = "ClarityXDR-Automation"
$ResourceGroup = "ClarityXDR-RG"

# Import required modules
Import-AzAutomationModule -AutomationAccountName $AutomationAccount -ResourceGroupName $ResourceGroup -ModuleUri "https://www.powershellgallery.com/packages/Az.Accounts"
Import-AzAutomationModule -AutomationAccountName $AutomationAccount -ResourceGroupName $ResourceGroup -ModuleUri "https://www.powershellgallery.com/packages/Microsoft.Graph"
```

## Validation & Testing

### Verify Deployment

```powershell
# Check resource deployment
az resource list --resource-group "ClarityXDR-RG" --output table

# Verify Sentinel workspace
az monitor log-analytics workspace show --resource-group "ClarityXDR-RG" --workspace-name "ClarityXDR-Workspace"

# Test connectivity
Test-NetConnection portal.azure.com -Port 443
```

### Test Detection Rules

1. **Navigate to Microsoft Sentinel**
2. **Go to Analytics > Active rules**
3. **Verify rules are enabled and running**
4. **Check for any configuration errors**

### Test Automation

1. **Navigate to Logic Apps**
2. **Run test workflows**
3. **Verify automation account runbooks**
4. **Check Key Vault access**

## Troubleshooting

### Common Issues

**Deployment Fails**:
- Check Azure subscription limits
- Verify required permissions
- Review deployment logs in Azure Portal

**Data Connectors Not Working**:
- Verify licensing requirements
- Check API permissions
- Review connector configuration

**High Costs**:
- Review data ingestion volumes
- Configure data collection rules
- Adjust retention settings
- Use cost optimization features

### Support Resources

- **Documentation**: Complete guides in `/docs` directory
- **GitHub Issues**: Report problems and get community help
- **Enterprise Support**: Available for commercial customers

## Security Hardening

### Recommended Security Settings

```powershell
# Enable diagnostic logging
az monitor diagnostic-settings create \
  --resource "/subscriptions/{subscription-id}/resourceGroups/ClarityXDR-RG/providers/Microsoft.KeyVault/vaults/ClarityXDR-KeyVault" \
  --name "SecurityLogs" \
  --workspace "/subscriptions/{subscription-id}/resourceGroups/ClarityXDR-RG/providers/Microsoft.OperationalInsights/workspaces/ClarityXDR-Workspace" \
  --logs '[{"category":"AuditEvent","enabled":true}]'

# Configure network restrictions
az keyvault update --name "ClarityXDR-KeyVault" --resource-group "ClarityXDR-RG" --default-action Deny
```

### Access Control

1. **Use Azure AD groups** for role assignments
2. **Implement just-in-time access** for administrative operations
3. **Enable multi-factor authentication** for all admin accounts
4. **Review and audit permissions** regularly

## Maintenance

### Regular Maintenance Tasks

1. **Weekly**:
   - Review alert volumes and false positives
   - Check platform health and performance
   - Update threat intelligence feeds

2. **Monthly**:
   - Review and optimize costs
   - Update detection rules
   - Review access permissions
   - Test backup and recovery procedures

3. **Quarterly**:
   - Update platform components
   - Review security configuration
   - Conduct security assessments
   - Update documentation

## Next Steps

After successful deployment:

1. **[Configure Advanced Features](ADVANCED_CONFIGURATION.md)**
2. **[Set Up Monitoring](MONITORING.md)**
3. **[Cost Optimization](COST_OPTIMIZATION.md)**
4. **[Best Practices](BEST_PRACTICES.md)**

---

For additional help, see our [Troubleshooting Guide](TROUBLESHOOTING.md) or contact support.
