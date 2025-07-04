# Microsoft Sentinel All-In-One V3 Deployment Guide

## Quick Deployment Options

### Option 1: Azure CLI with Parameters File
```bash
# Development deployment
az deployment sub create \
  --location "East US" \
  --template-file azuredeploy.json \
  --parameters @azuredeploy.parameters.json

# Production deployment
az deployment sub create \
  --location "East US" \
  --template-file azuredeploy.json \
  --parameters @azuredeploy.parameters.prod.json
```

### Option 2: PowerShell with Parameters File
```powershell
# Development deployment
New-AzSubscriptionDeployment `
  -Location "East US" `
  -TemplateFile "azuredeploy.json" `
  -TemplateParameterFile "azuredeploy.parameters.json"

# Production deployment
New-AzSubscriptionDeployment `
  -Location "East US" `
  -TemplateFile "azuredeploy.json" `
  -TemplateParameterFile "azuredeploy.parameters.prod.json"
```

### Option 3: Azure Portal
1. Navigate to Azure Portal
2. Create a new Template Deployment (subscription level)
3. Upload `azuredeploy.json`
4. Upload corresponding parameter file
5. Review and deploy

## Parameter Files

### azuredeploy.parameters.json
- Development/test environment configuration
- Smaller daily quota (10 GB)
- Basic set of data connectors
- Standard retention periods

### azuredeploy.parameters.prod.json
- Production environment configuration
- Higher daily quota (50 GB)
- Complete set of data connectors
- Extended retention periods
- Capacity reservation pricing

## Post-Deployment

After deployment completes:

1. **Verify Workspace**: Check that the Log Analytics workspace is created
2. **Validate Data Connectors**: Ensure data connectors are properly configured
3. **Review Cost Dashboard**: Access the cost optimization workbook
4. **Configure Analytics Rules**: Enable appropriate detection rules
5. **Set Up Automation**: Configure playbooks and automation rules

## Troubleshooting

### Common Issues

**Template Validation Errors**
- Ensure all parameter files have valid JSON syntax
- Verify parameter values match allowed values
- Check that required parameters have values

**Deployment Failures**
- Verify subscription permissions
- Check resource provider registrations
- Ensure quota limits are not exceeded

**Linked Template Errors**
- Verify internet connectivity for GitHub-hosted templates
- Check that LinkedTemplates directory exists if using local deployment

### Validation

To validate templates before deployment:
```bash
# Validate main template
az deployment sub validate \
  --location "East US" \
  --template-file azuredeploy.json \
  --parameters @azuredeploy.parameters.json
```

## Cost Optimization

The V3 deployment includes several cost optimization features:

1. **Multi-tier Storage**: Automatically configures different storage tiers
2. **Data Filtering**: Uses DCRs to filter unnecessary data
3. **Cost Dashboard**: Provides real-time cost monitoring
4. **Retention Management**: Configurable retention periods by data type

Monitor costs regularly using the deployed cost optimization workbook.
