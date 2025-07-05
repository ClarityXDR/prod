# Cyber Threat Intelligence (CTI)

This directory contains the Central Threat Intelligence Indicator Management, Reputation and Reporting solution for ClarityXDR platform.

## 📋 Overview

The CTI module provides a centralized indicator management system with multi-platform deployment:

- **Centralized Management**: SharePoint List-backed indicator database with Teams frontend
- **Multi-Platform Deployment**: Automated deployment to all security platforms
- **Bidirectional Sync**: Changes in any system are reflected everywhere
- **Lifecycle Management**: Complete lifecycle from ingestion to retirement
- **Reputation Tracking**: Monitor and respond to reputation changes

## 📁 Solution Architecture

```
┌─────────────────────────┐      ┌─────────────────────────────┐
│                         │      │                             │
│    Teams Interface      │◄────►│   SharePoint Indicator List │
│                         │      │                             │
└─────────────────────────┘      └───────────────┬─────────────┘
                                                 │
                                                 ▼
                                  ┌─────────────────────────────┐
                                  │                             │
                                  │      Logic Apps Layer       │
                                  │                             │
                                  └───────┬───────┬───────┬─────┘
                                          │       │       │
         ┌───────────────────────────────┐│       │       │
         ▼                               ▼│       ▼       ▼
┌──────────────────┐    ┌──────────────────┐  ┌───────┐  ┌───────────────────┐
│                  │    │                  │  │       │  │                   │
│ Microsoft 365    │    │ Azure            │  │ On-   │  │ Third-Party       │
│ Security Stack   │    │ Security Stack   │  │ Prem  │  │ Security Systems  │
│                  │    │                  │  │       │  │                   │
└──────────────────┘    └──────────────────┘  └───────┘  └───────────────────┘
```

## 🛠️ Components

### SharePoint Indicator List
Central database for all threat indicators with fields matching industry standards.

### Teams Management Interface
User-friendly interface for viewing, adding, and managing indicators.

### Logic Apps Workflows
- **Indicator Ingestion**: Add new indicators to SharePoint from feeds
- **Platform Deployment**: Deploy indicators to appropriate platforms
- **Synchronization**: Keep all platforms in sync with SharePoint
- **Reputation Monitoring**: Update indicators when reputation changes
- **Lifecycle Management**: Remove expired or false positive indicators

### Deployment Targets

**Microsoft 365 Security**
- Microsoft Defender for Endpoint (MDE)
- Entra ID Named Locations
- Microsoft Defender for Cloud Apps (MDCA)
- Exchange Online Protection
- Microsoft Sentinel

**Azure Security**
- Azure Firewall
- Azure Front Door WAF
- Azure Policy
- Defender for Cloud

**On-Premises**
- Network Security Devices
- Proxy/Firewall Systems
- EDR/Antivirus Solutions

## 🔄 Indicator Management Workflows

### Adding New Indicators
```powershell
# Add indicator via PowerShell
.\Add-CTIIndicator.ps1 -Type "IPAddress" -Value "192.168.1.100" -TLP "Amber" -PlatformTargets "MDE,EntraID,MDCA"

# Or use the Teams interface to add indicators manually
```

### Automated Deployments
Logic Apps automatically deploy indicators to appropriate security platforms:
- IP addresses → Network security, MDCA, Entra ID
- Domains → DNS filtering, Exchange, MDE
- File hashes → MDE, Antivirus
- URLs → Proxy filtering, Exchange, MDE

### Reputation Management
```powershell
# Check indicator reputation
.\Get-IndicatorReputation.ps1 -Value "192.168.1.100"

# Update indicator reputation
.\Update-IndicatorReputation.ps1 -Value "192.168.1.100" -NewStatus "Clean" -Reason "False positive"
```

### Indicator Lifecycle
1. **Ingestion**: Added to SharePoint from feeds or manual entry
2. **Validation**: Checked against reputation services
3. **Deployment**: Pushed to appropriate security platforms
4. **Monitoring**: Regular reputation checks and usage metrics
5. **Retirement**: Automatic removal when expired or reputation changes

## 📊 Reporting and Metrics

The solution provides comprehensive reporting through:
- Power BI dashboards
- Teams interface reporting tab
- Integration with security operations reporting

Key metrics tracked:
- Total indicators by type and platform
- Deployment success rates
- Reputation changes
- False positive rates
- Effectiveness in preventing attacks

## 🚀 Getting Started

### Prerequisites
- Microsoft 365 E5 subscription
- SharePoint site with admin access
- Azure subscription with Logic Apps
- Teams with app integration capabilities

### Initial Setup
1. Create the SharePoint indicator list
2. Deploy the Teams app
3. Configure Logic Apps for integration
4. Set up API connections to security platforms

For detailed setup instructions, see the [Implementation Guide](./Documentation/Implementation-Guide.md).

---

**Last Updated**: August 2023 | **Maintained by**: SOC Team
- **False Positive Filtering**: Whitelist management for known good indicators
- **Confidence Scoring**: Assigning confidence levels to indicators
- **Source Reputation**: Tracking feed reliability and accuracy
- **Duplicate Detection**: Preventing duplicate IOC entries

## 🔧 Configuration

### Feed Configuration File (`feeds-config.json`)
```json
{
  "feeds": [
    {
      "name": "Emerging Threats",
      "type": "HTTP",
      "url": "https://rules.emergingthreats.net/",
      "format": "SURICATA",
      "schedule": "hourly",
      "enabled": true
    }
  ]
}
```

### IOC Processing Rules
- **Retention Policy**: How long to keep indicators
- **Distribution Lists**: Which systems receive which IOCs
- **Priority Levels**: High, medium, low priority classification
- **Action Types**: Block, alert, monitor actions for different IOCs

## 📈 Metrics and Reporting

### Key Performance Indicators
- **IOC Volume**: Number of indicators processed daily
- **Feed Reliability**: Uptime and accuracy metrics for each feed
- **Detection Rate**: How many IOCs result in actual detections
- **False Positive Rate**: Percentage of IOCs that are false positives

### Reports Available
- **Daily IOC Summary**: New indicators added in the last 24 hours
- **Weekly Threat Landscape**: Trending threats and IOC categories
- **Monthly Attribution Report**: Threat actor activity summary
- **Quarterly Feed Performance**: Analysis of feed effectiveness

## 🔐 Security Considerations

### Access Control
- **Role-based Access**: Different permission levels for CTI analysts
- **API Security**: Secure storage and rotation of API keys
- **Data Classification**: Proper handling of sensitive threat intelligence
- **Audit Logging**: Complete audit trail of all CTI operations

### Data Protection
- **Encryption**: All CTI data encrypted at rest and in transit
- **Backup**: Regular backups of IOC databases and configurations
- **Privacy**: Ensuring compliance with data protection regulations
- **Sharing Agreements**: Respecting TLP and sharing restrictions

## 🤝 Contributing

### Adding New IOCs
1. Use the standardized IOC format
2. Include proper attribution and confidence scores
3. Validate against existing whitelists
4. Document the source and context

### Feed Integration
1. Create feed parser for new format
2. Implement quality validation rules
3. Add configuration options
4. Test with sample data before production

## 📚 References

- [STIX/TAXII Standards](https://oasis-open.github.io/cti-documentation/)
- [MISP Threat Sharing Platform](https://www.misp-project.org/)
- [Microsoft Defender for Endpoint IOC API](https://docs.microsoft.com/en-us/microsoft-365/security/defender-endpoint/ti-indicator)
- [Cyber Threat Intelligence Best Practices](https://www.sans.org/white-papers/cyber-threat-intelligence/)

---

**Last Updated**: July 2025 | **Maintained by**: SOC Team

## 🛠️ Scripts and Tools

### Core PowerShell Scripts
```powershell
# Create an indicator in the central system that will sync to all platforms
.\Add-CTIIndicator.ps1 -Type "IPAddress" -Value "192.168.1.100" -Title "Malicious C2 Server" -TLP "Amber" -DeploymentTargets "MDE,EntraID,MDCA"

# Remove an indicator from all platforms
.\Remove-CTIIndicator.ps1 -IndicatorId "a1b2c3d4-e5f6-7890-abcd-1234567890ab"

# Check indicator deployment status across all platforms
.\Get-CTIDeploymentStatus.ps1 -IndicatorValue "192.168.1.100"

# Validate indicator against reputation services
.\Test-IndicatorReputation.ps1 -Value "192.168.1.100" -Type "IPAddress"
```

### Logic App Sync Management
```powershell
# Force sync from SharePoint to security platforms
.\Sync-CTIToSecurityPlatforms.ps1 -ForceSync

# Import indicators from CSV file into SharePoint
.\Import-CTIIndicators.ps1 -CsvPath "C:\Temp\new-indicators.csv"

# Check sync status of all Logic Apps
.\Get-CTISyncStatus.ps1
```

## 📊 IOC Categories and Platform Mapping

### Indicator Types and Destinations
| Indicator Type | Microsoft 365 | Azure | On-Premises | Third-Party |
|----------------|---------------|-------|-------------|-------------|
| IP Address     | MDE, MDCA, Entra ID | Azure Firewall, Front Door WAF | Firewall, IPS | SIEM, TIP |
| Domain         | MDE, Exchange EOP | Azure DNS Firewall | DNS Filtering | SIEM, TIP |
| URL            | MDE, Exchange EOP/TABL | App Proxy | Proxy | SIEM, TIP |
| File Hash      | MDE | Defender for Cloud | EDR | SIEM, TIP |
| Certificate    | MDE | App Gateway | Network Security | SIEM, TIP |
| Email          | Exchange EOP/TABL | - | Mail Gateway | SIEM, TIP |

### Automatic Placement Logic
- **IP Addresses with "email" in description** → Exchange Connection Filter
- **IP Addresses (general)** → MDCA + Entra ID
- **URLs with "phish" in description** → Exchange Tenant Allow Block List
- **URLs (general)** → MDE + Exchange
- **Domains** → MDE + Exchange dual deployment
- **File Hashes** → MDE primary deployment
- **Certificates** → MDE primary deployment

## 🔄 Lifecycle Automation

### Indicator Creation
1. Indicator added to SharePoint (via Teams UI, PowerShell, or Logic App)
2. SharePoint trigger activates deployment Logic App
3. Logic App determines appropriate security platforms
4. Indicator is deployed to all targeted platforms
5. Deployment status is updated in SharePoint

### Indicator Validation
1. Scheduled Logic App checks indicator reputation
2. Reputation sources include VirusTotal, Microsoft Security Graph, AlienVault
3. Confidence score is updated based on validation results
4. Indicators with low confidence are flagged for review

### Indicator Removal
1. Indicator marked as expired or false positive in SharePoint
2. Removal Logic App triggered
3. Indicator removed from all security platforms
4. Record kept in SharePoint with status "Expired" or "FalsePositive"
5. Removal status logged in action history
