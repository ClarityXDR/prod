# Sanitized Logic Apps - ClarityXDR

## Overview
This folder contains 43 sanitized Logic App JSON files that have been cleaned of all Personally Identifiable Information (PII) and company-specific data, making them ready for deployment in any Azure environment.

## What Was Sanitized
- **Email addresses**: All specific email addresses replaced with generic placeholders
- **Company names**: Bio-Rad references replaced with "YourCompany"
- **Azure subscription IDs**: Replaced with placeholder GUID
- **Resource group names**: Replaced with "YourResourceGroup"
- **Teams channel IDs**: Replaced with placeholder
- **Connection names**: Standardized connection naming

## File Structure
```
logicapps_sanitized_final/
├── DEPLOYMENT_GUIDE.md          # Complete deployment instructions
├── README.md                    # This file
├── sanitization_report.txt      # Detailed sanitization log
├── compose.json                 # Email template compositions
├── EmergencyNotification-LogicApp.json
├── http-*.json                  # Various HTTP-triggered Logic Apps
├── MDE-Indicators-Get.json
├── run-mde-offline.json
├── SecurityAlertLogicApp.json
├── send-isolation-release-notification.json
└── virustotalenrichment.json
```

## Logic App Categories

### 🚨 Security Response Automation
- `http-block-entraid-user-entity-with-teams-card.json` - Block user accounts with Teams notification
- `http-mde-isolatemachine.json` - Isolate machines via Microsoft Defender
- `http-reset-user-password-graphapi.json` - Reset user passwords
- `http-revoke-user-session-graphapi.json` - Revoke user sessions
- `http-run-mde-offline-*.json` - Run MDE offline scans

### 📧 Email Notifications
- `http-send-*-courtesy-email.json` - Various courtesy notification emails
- `EmergencyNotification-LogicApp.json` - Emergency notifications
- `HTTP-Send-Suspicious-Activity-Feedback-Email.json` - Suspicious activity reports

### 🔍 Threat Intelligence & Enrichment
- `http-criminalIP-Enrichment.json` - Criminal IP enrichment
- `http-ms-ti-enrichment.json` - Microsoft Threat Intelligence
- `http-virustotal-*.json` - VirusTotal integrations
- `virustotalenrichment.json` - Additional VirusTotal enrichment

### 📊 Monitoring & Alerting
- `http-alert-email-fedramp-kql.json` - FedRAMP compliance alerts
- `http-send-securescore-daily-briefing.json` - Security score reporting
- `SecurityAlertLogicApp.json` - General security alerting

### 🔗 Teams Integration
- `http-entraid-alert-response-using-teams.json` - Entra ID alerts via Teams
- `http-high-incident-post-teams-adaptivecard.json` - High-priority incident cards
- `http-pass-*-teams-*.json` - Teams notification workflows

### 🌐 Network Security
- `http-entra-ip-block-namedlocation-entity.json` - Block IPs in Entra ID
- `http-exo-ipv4-block-connectionfilter.json` - Exchange Online IP blocking

### 📈 Data Export & Timeline
- `http-device-timeline-export-30days.json` - Device timeline exports
- `MDE-Indicators-Get.json` - Microsoft Defender indicators

## Prerequisites for Deployment
1. **Azure Subscription** with Logic Apps enabled
2. **Microsoft Sentinel** workspace (for security-related Logic Apps)
3. **Office 365** license and admin permissions
4. **Microsoft Teams** admin access (for Teams integrations)
5. **Microsoft Defender for Endpoint** (for MDE-related Logic Apps)

## Quick Start
1. Read the `DEPLOYMENT_GUIDE.md` for detailed instructions
2. Update placeholder values with your environment-specific information
3. Create required Azure API connections
4. Deploy Logic Apps to your Azure resource group
5. Test functionality before enabling production triggers

## Configuration Required
Each Logic App will need the following updated:

### Global Replacements Needed
```json
{
  "subscriptionId": "00000000-0000-0000-0000-000000000000",
  "resourceGroup": "YourResourceGroup",
  "adminEmail": "admin@company.com",
  "securityEmail": "security@company.com",
  "companyName": "YourCompany",
  "teamsChannelId": "19:00000000000000000000000000000000@thread.tacv2"
}
```

### Connection Names to Update
- `office365-connection` → Your Office 365 connection name
- `teams-connection` → Your Teams connection name
- `azuresentinel-connection` → Your Sentinel connection name
- `azuremonitorlogs-connection` → Your Monitor Logs connection name

## Security Recommendations
1. **Use Managed Identity** for authentication where possible
2. **Store secrets in Key Vault** instead of hardcoding
3. **Enable diagnostic logging** for all Logic Apps
4. **Implement proper RBAC** for Logic App access
5. **Regular security reviews** of Logic App permissions

## Support
- Refer to `DEPLOYMENT_GUIDE.md` for detailed deployment instructions
- Check `sanitization_report.txt` for complete list of changes made
- Azure Logic Apps documentation: https://docs.microsoft.com/en-us/azure/logic-apps/

## Version Information
- **Sanitization Date**: $(Get-Date -Format "yyyy-MM-dd")
- **Source**: ClarityXDR project
- **Files Processed**: 43 Logic App JSON files
- **Sanitization Script**: `sanitize_logicapps_fixed.ps1`

---
**⚠️ Important**: All Logic Apps require environment-specific configuration before deployment. Do not deploy without proper testing in a development environment first.
