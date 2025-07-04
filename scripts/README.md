# Scripts - PowerShell Automation and Utilities

This directory contains PowerShell scripts, utilities, and automation tools for the ClarityXDR platform, including setup scripts, maintenance utilities, and operational tools.

## 📋 Overview

The Scripts module provides essential automation capabilities:

- **Platform Setup**: Initial deployment and configuration scripts
- **Maintenance Tools**: Regular maintenance and housekeeping scripts
- **Operational Utilities**: Day-to-day operational support tools
- **Integration Scripts**: API integrations and data synchronization
- **Reporting Tools**: Automated report generation and metrics collection

## 📁 Directory Structure

```
scripts/
├── 📂 setup/                 # Initial platform setup and configuration
├── 📂 maintenance/           # Regular maintenance and cleanup scripts
├── 📂 utilities/             # General purpose utility scripts
├── 📂 integrations/          # API integrations and connectors
├── 📂 reporting/             # Report generation and metrics
├── 📂 testing/               # Testing and validation scripts
├── 📂 backup/                # Backup and recovery scripts
└── 📂 templates/             # Script templates and examples
```

## 🚀 Key Scripts

### Setup and Configuration

#### **clarity-xdr-app-registration.ps1**
**Purpose**: Creates Azure AD application registration with comprehensive permissions for ClarityXDR platform

**Features**:
- Microsoft Defender for Endpoint API permissions
- Microsoft Graph API access
- Exchange Online integration
- Entra ID named locations management
- Key Vault secrets management

**Usage**:
```powershell
# Basic setup with prompts
.\clarity-xdr-app-registration.ps1

# Automated setup with parameters
.\clarity-xdr-app-registration.ps1 -ResourceGroup "ClarityXDR-RG" -Location "eastus"

# Custom configuration
.\clarity-xdr-app-registration.ps1 -ResourceGroup "MyRG" -Location "westus2" -AppName "ClarityXDR-Custom"
```

**Required Permissions**:
- Azure AD Application Administrator
- Key Vault Contributor
- Resource Group Contributor

**Output**:
- Application ID and secret stored in Key Vault
- Service principal with required permissions
- Configuration file for downstream scripts

### Maintenance Scripts

#### **Update-ThreatIntelligence.ps1**
```powershell
# Update all threat intelligence feeds
.\Update-ThreatIntelligence.ps1 -FeedType "All" -LogLevel "Detailed"

# Update specific feed with custom interval
.\Update-ThreatIntelligence.ps1 -FeedType "MISP" -UpdateInterval "4h"
```

#### **Cleanup-OldLogs.ps1**
```powershell
# Clean up logs older than 90 days
.\Cleanup-OldLogs.ps1 -RetentionDays 90 -LogPath "C:\ClarityXDR\Logs"

# Dry run to preview cleanup
.\Cleanup-OldLogs.ps1 -RetentionDays 30 -WhatIf
```

#### **Sync-DetectionRules.ps1**
```powershell
# Sync all detection rules to Defender XDR
.\Sync-DetectionRules.ps1 -RulesPath "C:\ClarityXDR\rules" -Environment "Production"

# Sync specific rule category
.\Sync-DetectionRules.ps1 -Category "execution" -ValidateOnly
```

### Utility Scripts

#### **Test-ClarityXDRConnectivity.ps1**
```powershell
# Test all API connections
.\Test-ClarityXDRConnectivity.ps1 -TestAll

# Test specific service
.\Test-ClarityXDRConnectivity.ps1 -Service "DefenderAPI" -Detailed
```

#### **Generate-SecurityReport.ps1**
```powershell
# Generate weekly security report
.\Generate-SecurityReport.ps1 -ReportType "Weekly" -OutputPath "C:\Reports"

# Custom report with specific metrics
.\Generate-SecurityReport.ps1 -Metrics @("Alerts", "IOCs", "Coverage") -Format "HTML"
```

#### **Backup-ClarityXDRConfig.ps1**
```powershell
# Backup all configurations
.\Backup-ClarityXDRConfig.ps1 -BackupPath "C:\Backups" -IncludeSecrets

# Incremental backup
.\Backup-ClarityXDRConfig.ps1 -BackupType "Incremental" -Compress
```

## 📊 Configuration Management

### Configuration Files

#### **config.json**
```json
{
  "platform": {
    "name": "ClarityXDR",
    "version": "2.0",
    "environment": "Production"
  },
  "api": {
    "defenderEndpoint": "https://api.securitycenter.microsoft.com",
    "graphEndpoint": "https://graph.microsoft.com",
    "keyVault": "https://clarity-xdr-kv.vault.azure.net"
  },
  "settings": {
    "logLevel": "Information",
    "retentionDays": 90,
    "maxConcurrentJobs": 10
  }
}
```

#### **credentials.json** (Template)
```json
{
  "azure": {
    "tenantId": "{{TENANT_ID}}",
    "clientId": "{{CLIENT_ID}}",
    "keyVaultName": "{{KEY_VAULT_NAME}}"
  },
  "apis": {
    "defenderEndpoint": "{{DEFENDER_API_KEY}}",
    "threatIntelligence": "{{CTI_API_KEY}}"
  }
}
```

### Environment Variables
```powershell
# Set up environment variables
$env:CLARITY_XDR_TENANT_ID = "your-tenant-id"
$env:CLARITY_XDR_CLIENT_ID = "your-client-id"
$env:CLARITY_XDR_KEY_VAULT = "your-key-vault-name"
$env:CLARITY_XDR_LOG_LEVEL = "Information"
```

## 🔧 Script Development Standards

### PowerShell Best Practices

#### **Error Handling**
```powershell
# Comprehensive error handling template
try {
    # Main script logic
    Write-Host "Executing main operation..."
    
} catch [System.Net.WebException] {
    Write-Error "Network error occurred: $($_.Exception.Message)"
    exit 1
} catch [System.UnauthorizedAccessException] {
    Write-Error "Access denied: $($_.Exception.Message)"
    exit 2
} catch {
    Write-Error "Unexpected error: $($_.Exception.Message)"
    exit 99
} finally {
    # Cleanup operations
    Write-Host "Cleaning up resources..."
}
```

#### **Logging Framework**
```powershell
# Standardized logging function
function Write-ClarityLog {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [ValidateSet("Info", "Warning", "Error", "Debug")]
        [string]$Level = "Info",
        
        [string]$LogPath = $script:LogPath
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Console output
    switch ($Level) {
        "Info" { Write-Host $logEntry -ForegroundColor Green }
        "Warning" { Write-Warning $logEntry }
        "Error" { Write-Error $logEntry }
        "Debug" { Write-Debug $logEntry }
    }
    
    # File output
    if ($LogPath) {
        Add-Content -Path $LogPath -Value $logEntry
    }
}
```

#### **Parameter Validation**
```powershell
# Parameter validation template
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, HelpMessage="Azure resource group name")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("eastus", "westus2", "northeurope", "westeurope")]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 365)]
    [int]$RetentionDays = 90,
    
    [Parameter(Mandatory=$false)]
    [ValidateScript({Test-Path $_ -PathType Container})]
    [string]$OutputPath = "C:\ClarityXDR\Output"
)
```

### Code Quality Standards

#### **Script Header Template**
```powershell
<#
.SYNOPSIS
    Brief description of what the script does.

.DESCRIPTION
    Detailed description of the script functionality, including any important
    notes about usage, dependencies, or limitations.

.PARAMETER ParameterName
    Description of the parameter and its purpose.

.EXAMPLE
    PS> .\ScriptName.ps1 -ParameterName "Value"
    Description of what this example does.

.NOTES
    File Name      : ScriptName.ps1
    Author         : SOC Team
    Prerequisite   : PowerShell 5.1, Azure PowerShell modules
    Creation Date  : YYYY-MM-DD
    Last Modified  : YYYY-MM-DD
    Version        : 1.0

.LINK
    https://github.com/your-org/ClarityXDR
#>
```

#### **Function Documentation**
```powershell
function Get-ClarityXDRStatus {
    <#
    .SYNOPSIS
        Gets the current status of ClarityXDR platform components.
    
    .DESCRIPTION
        This function checks the health and status of all ClarityXDR platform
        components including APIs, databases, and services.
    
    .PARAMETER Component
        Specific component to check. If not specified, all components are checked.
    
    .PARAMETER Detailed
        Returns detailed status information including performance metrics.
    
    .EXAMPLE
        Get-ClarityXDRStatus -Component "DefenderAPI"
        Checks only the Defender API status.
    
    .OUTPUTS
        PSCustomObject with status information for each component.
    #>
    [CmdletBinding()]
    param(
        [string]$Component,
        [switch]$Detailed
    )
    
    # Function implementation
}
```

## 🔍 Testing and Validation

### Unit Testing
```powershell
# Pester test example
Describe "ClarityXDR Script Tests" {
    Context "Configuration Validation" {
        It "Should load configuration file successfully" {
            { Get-Content "config.json" | ConvertFrom-Json } | Should -Not -Throw
        }
        
        It "Should have all required configuration keys" {
            $config = Get-Content "config.json" | ConvertFrom-Json
            $config.platform | Should -Not -BeNullOrEmpty
            $config.api | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "API Connectivity" {
        It "Should connect to Defender API successfully" {
            { Test-DefenderAPIConnection } | Should -Not -Throw
        }
    }
}
```

### Integration Testing
```powershell
# Integration test script
.\Test-ClarityXDRIntegration.ps1 -TestSuite "Full" -Environment "Staging"
```

### Performance Testing
```powershell
# Performance benchmarking
Measure-Command { .\Sync-DetectionRules.ps1 -RulesPath "C:\ClarityXDR\rules" }
```

## 📋 Deployment and Operations

### Automated Deployment
```yaml
# Azure DevOps Pipeline for script deployment
trigger:
  branches:
    include:
    - main
  paths:
    include:
    - scripts/*

variables:
  scriptPath: '$(Build.SourcesDirectory)/scripts'
  targetPath: '$(Agent.TempDirectory)/ClarityXDR'

steps:
- task: PowerShell@2
  displayName: 'Validate PowerShell Scripts'
  inputs:
    targetType: 'inline'
    script: |
      Get-ChildItem -Path $(scriptPath) -Filter "*.ps1" | ForEach-Object {
        $result = Invoke-ScriptAnalyzer -Path $_.FullName
        if ($result) {
          Write-Error "Script analysis failed for $($_.Name)"
          exit 1
        }
      }

- task: CopyFiles@2
  displayName: 'Copy Scripts to Artifact Directory'
  inputs:
    SourceFolder: '$(scriptPath)'
    Contents: '**/*.ps1'
    TargetFolder: '$(targetPath)'
```

### Scheduled Operations
```powershell
# Register scheduled tasks for maintenance scripts
Register-ScheduledTask -TaskName "ClarityXDR-DailyMaintenance" -Trigger (New-ScheduledTaskTrigger -Daily -At "02:00") -Action (New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\ClarityXDR\scripts\maintenance\Daily-Maintenance.ps1")
```

### Monitoring and Alerting
```powershell
# Monitor script execution and send alerts on failure
try {
    .\Critical-Security-Script.ps1
} catch {
    Send-AlertNotification -Message "Critical script failed: $($_.Exception.Message)" -Severity "High"
    throw
}
```

## 🔐 Security Considerations

### Credential Management
- **Never hardcode credentials** in scripts
- Use **Azure Key Vault** for secret storage
- Implement **certificate-based authentication** where possible
- **Rotate secrets** regularly using automated processes

### Access Control
- Scripts require **appropriate RBAC permissions**
- Use **least privilege principle**
- Implement **approval workflows** for critical scripts
- **Audit all script executions**

### Code Security
```powershell
# Secure coding practices
# 1. Input validation
if (-not (Test-Path $InputPath)) {
    throw "Invalid input path: $InputPath"
}

# 2. SQL injection prevention
$query = "SELECT * FROM Users WHERE ID = @UserID"
$parameters = @{ UserID = $UserId }

# 3. Path traversal prevention
$safePath = [System.IO.Path]::GetFullPath($UserProvidedPath)
if (-not $safePath.StartsWith($AllowedBasePath)) {
    throw "Invalid path detected"
}
```

## 📊 Metrics and Monitoring

### Performance Metrics
- **Execution Time**: Script runtime duration
- **Success Rate**: Percentage of successful executions
- **Resource Usage**: CPU, memory, and disk usage
- **Error Rate**: Number and types of errors

### Operational Metrics
- **Schedule Adherence**: Adherence to scheduled execution times
- **Dependency Health**: Status of external dependencies
- **Data Quality**: Quality of processed data
- **User Satisfaction**: Feedback from script users

### Reporting
```powershell
# Generate script performance report
.\Generate-ScriptMetricsReport.ps1 -TimeRange "30d" -Format "HTML" -EmailReport
```

## 🤝 Contributing

### Script Development Process
1. **Requirements Analysis**: Define script requirements and scope
2. **Design Review**: Technical design review with team
3. **Implementation**: Follow coding standards and best practices
4. **Testing**: Comprehensive testing including edge cases
5. **Documentation**: Complete documentation and examples
6. **Code Review**: Peer review before merging
7. **Deployment**: Staged deployment with monitoring

### Contribution Guidelines
- Follow PowerShell best practices and style guide
- Include comprehensive error handling and logging
- Write complete documentation and examples
- Add appropriate unit and integration tests
- Ensure security best practices are followed

## 📚 References

- [PowerShell Best Practices](https://docs.microsoft.com/en-us/powershell/scripting/dev-cross-plat/writing-portable-modules)
- [Azure PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/azure/)
- [PowerShell Script Analyzer](https://github.com/PowerShell/PSScriptAnalyzer)
- [Pester Testing Framework](https://pester.dev/)
- [Azure Key Vault PowerShell](https://docs.microsoft.com/en-us/azure/key-vault/general/quick-create-powershell)

---

**Last Updated**: July 2025 | **Maintained by**: Platform Engineering Team
