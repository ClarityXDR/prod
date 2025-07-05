# ClarityXDR CTI Pre-Deployment Checklist

## 🚀 Quick Deployment Command

```powershell
# One-line deployment (after prerequisites are met)
.\Deploy-ClarityXDR-CTI.ps1 -TenantId "YOUR_TENANT_ID" -SubscriptionId "YOUR_SUBSCRIPTION_ID" -ResourceGroupName "CTI-RG" -SharePointTenantUrl "https://yourdomain-admin.sharepoint.com" -SharePointSiteUrl "https://yourdomain.sharepoint.com/sites/CTI" -GlobalAdminCredential (Get-Credential)
```

## ✅ Prerequisites Checklist

### Required Permissions
- [ ] **Global Administrator** role in Microsoft 365
- [ ] **Owner** role on target Azure subscription
- [ ] **SharePoint Administrator** access
- [ ] **Security Administrator** role (recommended)

### Required Licenses
- [ ] Microsoft 365 E5 or equivalent including:
  - [ ] Microsoft Defender for Endpoint P2
  - [ ] Microsoft Defender for Office 365 P2
  - [ ] Azure Active Directory P2
  - [ ] Microsoft Sentinel
  - [ ] SharePoint Online Plan 2

### PowerShell Modules (Auto-installed if missing)
```powershell
# Run this to install all required modules
Install-Module -Name Az -Force -AllowClobber
Install-Module -Name PnP.PowerShell -Force
Install-Module -Name ExchangeOnlineManagement -Force
Install-Module -Name Microsoft.Graph -Force
Install-Module -Name MicrosoftDefenderATP -Force
```

### Azure Resources Budget Estimate
| Resource | Monthly Cost (Est.) |
|----------|-------------------|
| Logic Apps (3x) | ~$15 |
| Automation Account | ~$5 |
| Sentinel Data Ingestion | ~$50-200 |
| **Total** | **~$70-220/month** |

## 📋 Pre-Deployment Information Gathering

### Required Information
```yaml
Tenant Information:
  Tenant ID: ________________________
  Primary Domain: ____________________
  
Azure Details:
  Subscription ID: ___________________
  Preferred Region: __________________
  
SharePoint URLs:
  Tenant Admin URL: __________________
  CTI Site URL: ______________________
  
Contacts:
  SOC Manager Email: _________________
  Security Team DL: __________________
```

### Optional Configuration
```yaml
Existing Resources:
  Sentinel Workspace ID: _____________
  App Registration ID: _______________
  Key Vault Name: ____________________
```

## 🔐 Security Pre-Requisites

### 1. Create Service Account (Recommended)
```powershell
# Create dedicated service account for CTI automation
$password = [System.Web.Security.Membership]::GeneratePassword(16, 4)
New-MsolUser -UserPrincipalName "svc-cti@yourdomain.com" -DisplayName "CTI Service Account" -Password $password
```

### 2. Configure Conditional Access Exclusion
- Exclude service account from MFA requirements
- Create named location for automation IPs
- Document exclusion for audit purposes

### 3. Enable Audit Logging
```powershell
# Ensure audit logging is enabled
Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true
```

## 🚦 Go/No-Go Checklist

### Technical Readiness
- [ ] All PowerShell modules installed
- [ ] Azure subscription has required resource providers
- [ ] SharePoint site collection available
- [ ] Network connectivity to all required endpoints

### Organizational Readiness
- [ ] Change management approval obtained
- [ ] Maintenance window scheduled (2 hours)
- [ ] Rollback plan documented
- [ ] Security team notified

### Data Readiness
- [ ] Initial threat indicators identified for testing
- [ ] Feed sources documented
- [ ] False positive process defined
- [ ] Retention policies agreed

## 🏃 Rapid Deployment Steps

### 1. Download Deployment Package
```powershell
# Download all required files
git clone https://github.com/ClarityXDR/prod.git
cd prod/cti

# Or download just the deployment script
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/ClarityXDR/prod/refs/heads/main/cti/Deploy-ClarityXDR-CTI.ps1" -OutFile "Deploy-ClarityXDR-CTI.ps1"
```

### 2. Run Pre-Flight Check
```powershell
# Validate environment readiness
.\Deploy-ClarityXDR-CTI.ps1 -ValidateOnly
```

### 3. Execute Deployment
```powershell
# Full deployment with progress tracking
.\Deploy-ClarityXDR-CTI.ps1 @splatParams -Verbose
```

### 4. Verify Deployment
```powershell
# Run post-deployment validation
.\Test-CTIDeployment.ps1 -ResourceGroupName "CTI-RG"
```

## 📊 Success Criteria

### Immediate Validation (5 minutes)
- [ ] All Azure resources show "Succeeded" state
- [ ] Logic Apps are enabled and running
- [ ] SharePoint lists are accessible
- [ ] PowerShell module imports successfully

### Functional Validation (15 minutes)
- [ ] Test indicator can be added via PowerShell
- [ ] Indicator appears in SharePoint list
- [ ] Logic App processes the indicator
- [ ] Deployment status updates correctly

### Integration Validation (30 minutes)
- [ ] Indicator deployed to Microsoft Defender
- [ ] Named Location created in Azure AD
- [ ] MDCA policy configured
- [ ] Exchange block list updated

## 🆘 Troubleshooting Quick Reference

### Common Issues

| Issue | Solution |
|-------|----------|
| "Insufficient privileges" | Ensure Global Admin role is active |
| "Resource provider not registered" | Run `Register-AzResourceProvider -ProviderNamespace Microsoft.Logic` |
| "SharePoint site not found" | Verify URL and ensure site exists |
| "Module not found" | Run as Administrator and install modules |

### Emergency Rollback
```powershell
# Remove all CTI resources
.\Remove-CTIDeployment.ps1 -ResourceGroupName "CTI-RG" -Confirm:$false
```

## 📞 Support Contacts

- **Technical Issues**: Open issue at https://github.com/ClarityXDR/prod/issues
- **Security Concerns**: Contact SOC team immediately
- **Licensing Questions**: Contact Microsoft account team

---

**Ready to Deploy?** If all checkboxes are marked, you're ready to go from Blue to Green! 🚀