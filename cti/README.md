# Cyber Threat Intelligence (CTI)

This directory contains cyber threat intelligence feeds, indicators of compromise (IOCs), and threat intelligence integration scripts for ClarityXDR platform.

## 📋 Overview

The CTI module provides automated threat intelligence collection, processing, and integration capabilities:

- **IOC Management**: Automated import and synchronization of threat indicators
- **Feed Integration**: Support for multiple threat intelligence feeds
- **Enrichment**: Automatic enrichment of alerts with threat context
- **Attribution**: Threat actor and campaign attribution data

## 📁 Directory Structure

```
cti/
├── 📂 feeds/                  # Threat intelligence feed configurations
├── 📂 iocs/                   # Indicators of Compromise
│   ├── 📂 hashes/            # File hashes (MD5, SHA1, SHA256)
│   ├── 📂 domains/           # Malicious domains and URLs
│   ├── 📂 ips/               # Malicious IP addresses
│   └── 📂 registry/          # Registry-based IOCs
├── 📂 scripts/               # CTI automation scripts
├── 📂 reports/               # Threat intelligence reports
└── 📂 attribution/           # Threat actor and campaign data
```

## 🔄 Feed Sources

### Supported Feed Types
- **Commercial Feeds**: Integration with premium CTI providers
- **Open Source**: MISP, AlienVault OTX, Abuse.ch feeds
- **Government**: US-CERT, NCSC, and other government sources
- **Industry**: Information sharing groups and consortiums
- **Internal**: Organization-specific IOCs and hunting results

### Feed Formats
- **STIX/TAXII**: Industry standard format support
- **JSON**: Custom JSON feed parsing
- **CSV**: Simple comma-separated value files
- **XML**: Legacy XML-based feeds
- **API**: RESTful API integrations

## 🛠️ Scripts and Tools

### IOC Processing Scripts
```powershell
# Import IOCs from various feed formats
.\Import-ThreatIntelligence.ps1 -FeedType "STIX" -SourcePath "feeds/apt29-indicators.json"

# Sync IOCs with Microsoft Defender
.\Sync-DefenderIOCs.ps1 -IOCFile "iocs/latest-malware-hashes.csv"

# Enrich alerts with threat context
.\Enrich-AlertsWithCTI.ps1 -TimeRange "7d"
```

### Feed Management
```powershell
# Configure new threat intelligence feed
.\Add-CTIFeed.ps1 -FeedName "Emerging Threats" -URL "https://rules.emergingthreats.net/fwrules/"

# Update all configured feeds
.\Update-AllFeeds.ps1 -Schedule "Hourly"

# Validate IOC quality and remove false positives
.\Validate-IOCs.ps1 -IOCSet "domains" -Whitelist "corporate-domains.txt"
```

## 📊 IOC Categories

### File-based Indicators
- **Malware Hashes**: MD5, SHA1, SHA256 hashes of known malicious files
- **File Names**: Suspicious file names and patterns
- **File Paths**: Common malware installation locations
- **Digital Signatures**: Revoked or suspicious code signing certificates

### Network Indicators
- **Malicious IPs**: Command and control server addresses
- **Suspicious Domains**: Malicious and phishing domains
- **URLs**: Specific malicious URLs and patterns
- **Network Protocols**: Unusual protocol usage patterns

### Host-based Indicators
- **Registry Keys**: Malicious registry modifications
- **Service Names**: Suspicious service installations
- **Process Names**: Known malicious process names
- **Mutex Names**: Malware-specific mutex identifiers

## 🔍 Threat Actor Attribution

### Tracking Groups
- **APT Groups**: Advanced Persistent Threat organizations
- **Cybercriminal Groups**: Financially motivated threat actors
- **Hacktivists**: Ideologically motivated groups
- **Nation-State**: Government-sponsored threat actors

### Campaign Tracking
- **Operation Names**: Specific campaign identifiers
- **TTPs**: Tactics, Techniques, and Procedures mapping
- **Infrastructure**: Shared infrastructure indicators
- **Timeline**: Campaign activity timelines

## 🚀 Getting Started

### Prerequisites
- PowerShell 5.1 or later
- Microsoft Graph PowerShell module
- Microsoft Defender for Endpoint API access
- Appropriate CTI feed subscriptions

### Initial Setup
1. **Configure API Access**:
   ```powershell
   # Set up Microsoft Defender API connection
   Connect-MgGraph -Scopes "ThreatIndicators.ReadWrite.OwnedBy"
   ```

2. **Import Initial IOC Set**:
   ```powershell
   # Import baseline malware hashes
   .\Import-ThreatIntelligence.ps1 -IOCType "Hash" -SourceFile "baseline-malware.csv"
   ```

3. **Configure Automated Feeds**:
   ```powershell
   # Set up automated feed updates
   .\Configure-AutomatedFeeds.ps1 -Schedule "Daily" -FeedList "premium-feeds.json"
   ```

## 📋 IOC Management

### IOC Lifecycle
1. **Collection**: Automated collection from configured feeds
2. **Validation**: Quality checks and false positive filtering
3. **Enrichment**: Adding context and attribution data
4. **Distribution**: Pushing to security tools and platforms
5. **Aging**: Removing stale or outdated indicators

### Quality Control
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
