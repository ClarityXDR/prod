# 🚀 ClarityXDR CTI - One-Click Deployment Guide

**Go from Blue to Green in under 30 minutes!**

## 🎯 Quick Start - The "One-Click" Deploy

```powershell
# 1. Clone the repository
git clone https://github.com/ClarityXDR/prod.git
cd prod/cti

# 2. Fix GitHub URLs (one-time setup)
.\Fix-GitHubURLs.ps1 -RepositoryPath .

# 3. Deploy everything!
.\Deploy-ClarityXDR-CTI.ps1 `
    -TenantId "YOUR_TENANT_ID" `
    -SubscriptionId "YOUR_SUBSCRIPTION_ID" `
    -ResourceGroupName "CTI-RG" `
    -SharePointTenantUrl "https://yourdomain-admin.sharepoint.com" `
    -SharePointSiteUrl "https://yourdomain.sharepoint.com/sites/CTI" `
    -GlobalAdminCredential (Get-Credential)
```

That's it! Your CTI system will be fully deployed and operational.

## 📋 Pre-Flight Checklist (5 minutes)

### Required Information
- [ ] Azure Tenant ID
- [ ] Azure Subscription ID  
- [ ] SharePoint Admin URL
- [ ] SharePoint Site URL (can be new)
- [ ] Global Admin credentials

### Required Permissions
- [ ] Global Administrator in M365
- [ ] Owner on Azure Subscription
- [ ] SharePoint Administrator

### Quick Prerequisites Install
```powershell
# Run as Administrator
Set-ExecutionPolicy Bypass -Scope Process -Force

# Install all required modules (3-5 minutes)
@('Az','PnP.PowerShell','ExchangeOnlineManagement','Microsoft.Graph') | ForEach-Object {
    Install-Module -Name $_ -Force -AllowClobber
}
```

## 🏃‍♂️ Deployment Process

### What Happens During Deployment

1. **App Registration** (2 min)
   - Creates service principal
   - Configures API permissions
   - Generates secure credentials

2. **Azure Resources** (10 min)
   - Resource group creation
   - Logic Apps deployment
   - Automation account setup
   - Sentinel workspace configuration

3. **SharePoint Setup** (5 min)
   - Site configuration
   - List creation
   - Security settings
   - Web part deployment

4. **Integration** (5 min)
   - PowerShell module installation
   - Security platform connections
   - Scheduled task configuration

5. **Validation** (3 min)
   - Component testing
   - Smoke tests
   - Health verification

## ✅ Post-Deployment Steps

### Immediate Actions (Required)

1. **Grant Admin Consent** (2 minutes)
   ```
   Azure Portal > Azure Active Directory > App registrations
   > ClarityXDR-CTI-Automation > API permissions > Grant admin consent
   ```

2. **Test the System** (5 minutes)
   ```powershell
   # Run validation
   .\Test-CTIDeployment.ps1 -ResourceGroupName "CTI-RG" -SharePointSiteUrl "YOUR_SITE_URL" -RunSmokeTests

   # Add first indicator
   Import-Module ClarityXDR-CTI
   Set-CTIIndicator -Type "IPAddress" -Value "192.168.100.100" -Confidence 90 -Source "InitialTest"
   ```

3. **Verify Automation** (2 minutes)
   - Check Logic Apps are running in Azure Portal
   - Confirm SharePoint list shows the test indicator
   - Verify deployment status updates

## 🔧 Configuration Options

### Minimal Deployment (Fastest)
```powershell
# Uses all defaults, creates everything new
.\Deploy-ClarityXDR-CTI.ps1 -TenantId "xxx" -SubscriptionId "yyy" -ResourceGroupName "CTI-RG" -SharePointTenantUrl "https://x-admin.sharepoint.com" -SharePointSiteUrl "https://x.sharepoint.com/sites/CTI" -GlobalAdminCredential (Get-Credential)
```

### Using Existing Resources
```powershell
# Reuse existing app registration and Sentinel workspace
.\Deploy-ClarityXDR-CTI.ps1 `
    -TenantId "xxx" `
    -SubscriptionId "yyy" `
    -ResourceGroupName "CTI-RG" `
    -SharePointTenantUrl "https://x-admin.sharepoint.com" `
    -SharePointSiteUrl "https://x.sharepoint.com/sites/CTI" `
    -GlobalAdminCredential (Get-Credential) `
    -UseExistingAppRegistration `
    -ExistingAppId "YOUR_APP_ID" `
    -ExistingAppSecret "YOUR_SECRET"
```

### Custom Configuration File
```powershell
# Use custom settings from deployment-config.json
Copy-Item deployment-config.json my-config.json
# Edit my-config.json with your settings

.\Deploy-ClarityXDR-CTI.ps1 `
    -ConfigFile "my-config.json" `
    -GlobalAdminCredential (Get-Credential)
```

## 📊 What You Get

### Security Platforms Integration
- ✅ **Microsoft Defender for Endpoint** - File hashes, IPs, URLs, domains
- ✅ **Azure AD (Entra ID)** - Named Locations with sign-in blocking
- ✅ **Microsoft Defender for Cloud Apps** - Risky IP categorization
- ✅ **Exchange Online Protection** - Connection filtering and block lists
- ✅ **Microsoft Sentinel** - Central orchestration and logging

### Automation Features
- 📅 Daily synchronization of indicators
- 🔄 Automatic deployment to all platforms
- 🧹 Expired indicator cleanup
- 📈 Health monitoring and reporting
- 🚨 Failure notifications

### Management Interface
- 📝 SharePoint lists for indicator management
- 📊 Power BI ready data structure
- 🔍 KQL query templates
- 🗺️ MITRE ATT&CK mapping

## 🆘 Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| "Insufficient privileges" | Ensure you're using Global Admin account |
| "Module not found" | Run PowerShell as Administrator and reinstall modules |
| "Resource provider not registered" | Run: `Register-AzResourceProvider -ProviderNamespace Microsoft.Logic` |
| "SharePoint error" | Verify site URL and that site exists |

### Quick Diagnostics
```powershell
# Check deployment status
.\Test-CTIDeployment.ps1 -ResourceGroupName "CTI-RG" -SharePointSiteUrl "YOUR_SITE" -OutputReport

# View deployment logs
Get-Content "CTI-Deployment-*.log" -Tail 50

# Test specific component
Test-NetConnection graph.microsoft.com -Port 443
```

### Emergency Rollback
```powershell
# Remove everything if needed
Remove-AzResourceGroup -Name "CTI-RG" -Force
# Remove SharePoint lists manually if needed
```

## 📈 Daily Operations

### Automatic Daily Tasks
The system automatically:
- Syncs new indicators to all platforms
- Validates existing deployments
- Removes expired indicators
- Sends summary reports

### Manual Operations
```powershell
# Force sync all pending indicators
.\Run-CTIDailySync.ps1 -ForceSync

# Add indicators from CSV
Import-Csv "indicators.csv" | ForEach-Object {
    Set-CTIIndicator -Type $_.Type -Value $_.Value -Confidence $_.Confidence -Source "CSV Import"
}

# Generate deployment report
.\Test-CTIDeployment.ps1 -ResourceGroupName "CTI-RG" -SharePointSiteUrl "YOUR_SITE" -OutputReport
```

## 🎉 Success Indicators

You know your deployment is successful when:
- ✅ All validation tests pass (80%+ success rate)
- ✅ Test indicator appears in SharePoint within 1 minute
- ✅ Logic Apps show successful runs
- ✅ You can query indicators via PowerShell
- ✅ Deployment completes in under 30 minutes

## 📞 Need Help?

1. **Check the logs**: `CTI-Deployment-[timestamp].log`
2. **Run validation**: `.\Test-CTIDeployment.ps1`
3. **Review quick start guide**: Generated after deployment
4. **GitHub Issues**: https://github.com/ClarityXDR/prod/issues

---

**Ready to deploy?** You're just one command away from a fully operational CTI system! 🚀

```powershell
# Remember: Blue to Green in under 30 minutes!
.\Deploy-ClarityXDR-CTI.ps1 -TenantId "YOUR_TENANT" -SubscriptionId "YOUR_SUB" -ResourceGroupName "CTI-RG" -SharePointTenantUrl "https://yourdomain-admin.sharepoint.com" -SharePointSiteUrl "https://yourdomain.sharepoint.com/sites/CTI" -GlobalAdminCredential (Get-Credential)
```