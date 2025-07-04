# Live Response

This directory contains live response scripts, playbooks, and tools for remote investigation and incident response using Microsoft Defender for Endpoint's live response capabilities.

## 📋 Overview

The Live Response module provides automated and manual incident response capabilities:

- **Remote Investigation**: Gather forensic artifacts from compromised endpoints
- **Threat Containment**: Isolate infected systems and stop malicious processes
- **Evidence Collection**: Secure collection of files and memory artifacts
- **Automated Remediation**: Scripted response actions for common incidents

## 📁 Directory Structure

```
liveresponse/
├── 📂 playbooks/             # Incident response playbooks
│   ├── 📂 malware/          # Malware investigation and removal
│   ├── 📂 lateral-movement/ # Lateral movement investigation
│   ├── 📂 data-exfiltration/# Data theft investigation
│   └── 📂 privilege-escalation/ # Privilege escalation response
├── 📂 scripts/              # PowerShell and batch scripts
│   ├── 📂 collection/       # Evidence collection scripts
│   ├── 📂 analysis/         # On-host analysis tools
│   ├── 📂 remediation/      # Cleanup and remediation scripts
│   └── 📂 utilities/        # General purpose utilities
├── 📂 templates/            # Response plan templates
├── 📂 artifacts/            # Common artifact locations
└── 📂 tools/                # Third-party investigation tools
```

## 🚨 Incident Response Playbooks

### Malware Investigation
```powershell
# Initial triage and evidence collection
.\playbooks\malware\Initial-MalwareTriage.ps1 -DeviceId "device-id-here"

# Memory dump collection
.\playbooks\malware\Collect-MemoryDump.ps1 -ProcessName "suspicious.exe"

# File system analysis
.\playbooks\malware\Analyze-FileSystem.ps1 -SuspiciousPath "C:\temp\"
```

### Lateral Movement Response
```powershell
# Investigate RDP sessions
.\playbooks\lateral-movement\Investigate-RDPSessions.ps1 -TimeRange "24h"

# Check for credential dumping
.\playbooks\lateral-movement\Check-CredentialDumping.ps1

# Network connection analysis
.\playbooks\lateral-movement\Analyze-NetworkConnections.ps1
```

### Data Exfiltration Investigation
```powershell
# Monitor file access patterns
.\playbooks\data-exfiltration\Monitor-FileAccess.ps1 -SensitivePaths @("C:\Finance", "C:\HR")

# Network traffic analysis
.\playbooks\data-exfiltration\Analyze-NetworkTraffic.ps1 -SuspiciousIPs @("192.168.1.100")

# Cloud upload detection
.\playbooks\data-exfiltration\Detect-CloudUploads.ps1
```

## 🔧 Live Response Scripts

### Evidence Collection
- **`Collect-ProcessMemory.ps1`**: Dump memory of specific processes
- **`Collect-RegistryHives.ps1`**: Extract registry hives for analysis
- **`Collect-EventLogs.ps1`**: Gather relevant Windows event logs
- **`Collect-NetworkArtifacts.ps1`**: Network configuration and connections
- **`Collect-FileMetadata.ps1`**: File system metadata and timestamps

### System Analysis
- **`Analyze-RunningProcesses.ps1`**: Comprehensive process analysis
- **`Analyze-NetworkConnections.ps1`**: Active network connections review
- **`Analyze-Persistence.ps1`**: Check for persistence mechanisms
- **`Analyze-UserAccounts.ps1`**: User account and logon analysis
- **`Analyze-ScheduledTasks.ps1`**: Review scheduled tasks for malicious entries

### Threat Containment
- **`Isolate-Device.ps1`**: Network isolation of compromised systems
- **`Stop-MaliciousProcess.ps1`**: Terminate malicious processes
- **`Block-NetworkTraffic.ps1`**: Block specific network communications
- **`Quarantine-Files.ps1`**: Quarantine suspicious files
- **`Disable-UserAccount.ps1`**: Disable compromised user accounts

### Remediation Actions
- **`Remove-Malware.ps1`**: Automated malware removal
- **`Reset-UserCredentials.ps1`**: Force password resets
- **`Restore-SystemIntegrity.ps1`**: System integrity restoration
- **`Update-SecurityBaseline.ps1`**: Apply security hardening measures
- **`Clean-Artifacts.ps1`**: Remove attacker artifacts

## 📊 Response Templates

### Incident Classification
- **Category 1**: Automated response for low-severity incidents
- **Category 2**: Semi-automated response requiring analyst approval
- **Category 3**: Manual response for complex investigations
- **Category 4**: Emergency response for critical incidents

### Response Timelines
- **Immediate (0-15 minutes)**: Automated containment actions
- **Short-term (15 minutes - 2 hours)**: Evidence collection and analysis
- **Medium-term (2-24 hours)**: Detailed investigation and remediation
- **Long-term (1-7 days)**: Recovery and lessons learned

## 🚀 Getting Started

### Prerequisites
- Microsoft Defender for Endpoint P2 license
- Live Response enabled in tenant settings
- Appropriate RBAC roles (Security Administrator or above)
- PowerShell 5.1 or later with required modules

### Initial Setup
1. **Enable Live Response**:
   ```powershell
   # Enable live response in Defender settings
   Set-MpPreference -EnableLiveResponse $true
   ```

2. **Deploy Scripts to Library**:
   ```powershell
   # Upload scripts to live response library
   .\Deploy-LiveResponseScripts.ps1 -ScriptPath "scripts\" -LibraryPath "defender-library"
   ```

3. **Test Response Capabilities**:
   ```powershell
   # Run basic connectivity test
   .\Test-LiveResponseConnection.ps1 -DeviceId "test-device-id"
   ```

## 🔍 Investigation Workflows

### Initial Response (First 15 minutes)
1. **Assess Scope**: Determine number of affected systems
2. **Contain Threat**: Isolate infected systems if necessary
3. **Preserve Evidence**: Take memory snapshots and critical files
4. **Document Actions**: Log all response actions taken

### Deep Investigation (15 minutes - 2 hours)
1. **Collect Artifacts**: Comprehensive evidence collection
2. **Timeline Analysis**: Reconstruct attack timeline
3. **Lateral Movement**: Check for lateral movement indicators
4. **Data Impact**: Assess potential data exposure

### Remediation (2-24 hours)
1. **Remove Threats**: Clean infected systems
2. **Patch Vulnerabilities**: Address attack vectors
3. **Restore Services**: Bring systems back online
4. **Validate Security**: Confirm threat elimination

### Recovery (1-7 days)
1. **Monitor Systems**: Continuous monitoring for reinfection
2. **Update Defenses**: Strengthen security controls
3. **Lessons Learned**: Document improvements needed
4. **Report Generation**: Executive and technical reports

## 📋 Standard Operating Procedures

### Evidence Handling
- **Chain of Custody**: Maintain forensic integrity
- **Encryption**: Encrypt all collected evidence
- **Storage**: Secure evidence storage requirements
- **Retention**: Evidence retention policies

### Communication Protocols
- **Incident Declaration**: When and how to declare incidents
- **Stakeholder Notification**: Who needs to be informed
- **Status Updates**: Regular status update requirements
- **External Communication**: Media and customer communication

### Legal Considerations
- **Data Privacy**: GDPR and other privacy regulation compliance
- **Law Enforcement**: When to involve law enforcement
- **Legal Hold**: Litigation hold procedures
- **Documentation**: Legal documentation requirements

## 🔧 Configuration

### Live Response Settings
```json
{
  "liveResponse": {
    "enabled": true,
    "allowUnsignedScripts": false,
    "maxSessionDuration": "8h",
    "autoIsolation": {
      "enabled": true,
      "severity": "High"
    }
  }
}
```

### Script Library Management
- **Version Control**: All scripts under version control
- **Testing**: Mandatory testing before deployment
- **Approval Process**: Change approval workflows
- **Distribution**: Automated deployment to endpoints

## 📈 Metrics and KPIs

### Response Time Metrics
- **Time to Detection**: How quickly threats are identified
- **Time to Containment**: Speed of threat containment
- **Time to Resolution**: Complete incident resolution time
- **Recovery Time**: Time to restore normal operations

### Effectiveness Metrics
- **Containment Success Rate**: Percentage of successful containments
- **False Positive Rate**: Rate of false positive incidents
- **Recurring Incidents**: Rate of incident recurrence
- **Automation Rate**: Percentage of automated responses

## 🔐 Security Considerations

### Access Control
- **Role-based Access**: Restrict live response access by role
- **Device Groups**: Limit access to specific device groups
- **Action Approval**: Require approval for destructive actions
- **Session Monitoring**: Monitor all live response sessions

### Audit and Compliance
- **Action Logging**: Log all response actions taken
- **Session Recording**: Record live response sessions
- **Compliance Reporting**: Generate compliance reports
- **Regular Audits**: Periodic access reviews

## 🤝 Contributing

### Adding New Scripts
1. Follow PowerShell best practices and coding standards
2. Include comprehensive error handling and logging
3. Test thoroughly in lab environment
4. Document all parameters and usage examples
5. Include appropriate security warnings

### Playbook Development
1. Follow incident response best practices
2. Include decision trees and escalation procedures
3. Test with simulated incidents
4. Document all dependencies and requirements
5. Include metrics and success criteria

## 📚 References

- [Microsoft Defender Live Response](https://docs.microsoft.com/en-us/microsoft-365/security/defender-endpoint/live-response)
- [NIST Incident Response Guide](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-61r2.pdf)
- [SANS Incident Response Process](https://www.sans.org/white-papers/incident-response-process/)
- [Digital Forensics Best Practices](https://www.sans.org/white-papers/digital-forensics-best-practices/)

---

**Last Updated**: July 2025 | **Maintained by**: Incident Response Team
