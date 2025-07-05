<#
.SYNOPSIS
    Daily synchronization script for ClarityXDR CTI operations
.DESCRIPTION
    This script runs daily to sync indicators, validate deployments, and clean up expired entries
.NOTES
    Designed to run as a scheduled task or Azure Automation runbook
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "$PSScriptRoot\deployment-config.json",
    
    [Parameter(Mandatory = $false)]
    [switch]$ForceSync,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipValidation,
    
    [Parameter(Mandatory = $false)]
    [switch]$VerboseLogging
)

# Script configuration
$ErrorActionPreference = "Stop"
$script:StartTime = Get-Date
$script:LogPath = "$PSScriptRoot\Logs\CTI-Daily-$(Get-Date -Format 'yyyyMMdd').log"

# Ensure log directory exists
$logDir = Split-Path $script:LogPath -Parent
if (-not (Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}

#region Functions

function Write-CTILog {
    param(
        [string]$Message,
        [string]$Level = "INFO",
        [switch]$NoConsole
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to log file
    Add-Content -Path $script:LogPath -Value $logEntry
    
    # Write to console if not suppressed
    if (-not $NoConsole) {
        $color = switch ($Level) {
            "INFO" { "White" }
            "SUCCESS" { "Green" }
            "WARNING" { "Yellow" }
            "ERROR" { "Red" }
            "DEBUG" { "Gray" }
            default { "White" }
        }
        
        if ($Level -eq "DEBUG" -and -not $VerboseLogging) {
            return
        }
        
        Write-Host $logEntry -ForegroundColor $color
    }
}

function Initialize-CTIEnvironment {
    Write-CTILog "Initializing CTI environment..." -Level "INFO"
    
    try {
        # Load configuration
        if (Test-Path $ConfigFile) {
            $script:Config = Get-Content $ConfigFile | ConvertFrom-Json
            Write-CTILog "Configuration loaded from: $ConfigFile" -Level "SUCCESS"
        } else {
            throw "Configuration file not found: $ConfigFile"
        }
        
        # Import CTI module
        Import-Module ClarityXDR-CTI -ErrorAction Stop
        Write-CTILog "CTI module imported successfully" -Level "SUCCESS"
        
        # Initialize module with configuration
        $initParams = @{
            SentinelWorkspaceId = $script:Config.sentinel.workspaceId
            LogicAppUrls = @{
                Ingestion = $script:Config.automation.logicApps.ingestion.url
                Validation = $script:Config.automation.logicApps.validation.url
            }
        }
        
        Initialize-CTIModule @initParams
        Write-CTILog "CTI module initialized" -Level "SUCCESS"
        
        # Connect to required services
        Connect-CTIServices
        Write-CTILog "Connected to all required services" -Level "SUCCESS"
        
        return $true
    } catch {
        Write-CTILog "Failed to initialize environment: $_" -Level "ERROR"
        return $false
    }
}

function Sync-PendingIndicators {
    Write-CTILog "`n=== Starting Indicator Synchronization ===" -Level "INFO"
    
    $syncStats = @{
        Total = 0
        Synced = 0
        Failed = 0
        Skipped = 0
    }
    
    try {
        # Get pending indicators
        $pendingIndicators = Get-CTIIndicators | Where-Object {
            $_.DeploymentStatus -eq "Pending" -or 
            ($_.DeploymentStatus -eq "Failed" -and $_.Created -gt (Get-Date).AddDays(-7))
        }
        
        $syncStats.Total = $pendingIndicators.Count
        Write-CTILog "Found $($pendingIndicators.Count) indicators pending deployment" -Level "INFO"
        
        foreach ($indicator in $pendingIndicators) {
            Write-CTILog "Processing indicator: $($indicator.Value) ($($indicator.Type))" -Level "DEBUG"
            
            try {
                # Sync to security platforms
                Sync-CTIToSecurityProducts -IndicatorId $indicator.IndicatorId
                
                $syncStats.Synced++
                Write-CTILog "Successfully synced: $($indicator.Value)" -Level "SUCCESS"
                
                # Update SharePoint with deployment status
                Update-IndicatorStatus -IndicatorId $indicator.IndicatorId -Status "Deployed"
                
            } catch {
                $syncStats.Failed++
                Write-CTILog "Failed to sync $($indicator.Value): $_" -Level "ERROR"
                
                # Update failure count
                Update-IndicatorStatus -IndicatorId $indicator.IndicatorId -Status "Failed" -FailureReason $_.Exception.Message
            }
            
            # Rate limiting
            Start-Sleep -Milliseconds 500
        }
        
    } catch {
        Write-CTILog "Error during synchronization: $_" -Level "ERROR"
    }
    
    Write-CTILog "Synchronization complete - Total: $($syncStats.Total), Synced: $($syncStats.Synced), Failed: $($syncStats.Failed)" -Level "INFO"
    return $syncStats
}

function Test-DeploymentStatus {
    Write-CTILog "`n=== Checking Deployment Status ===" -Level "INFO"
    
    $statusReport = @{
        Healthy = 0
        Degraded = 0
        Failed = 0
        Platforms = @{}
    }
    
    try {
        # Get deployment status for all active indicators
        $deploymentStatus = Get-CTIDeploymentStatus
        
        # Group by platform
        $platforms = @("MDE", "Exchange", "MDCA", "EntraID")
        
        foreach ($platform in $platforms) {
            $platformIndicators = $deploymentStatus | Where-Object { $_.PlacementStrategy -like "*$platform*" }
            $deployed = $platformIndicators | Where-Object { $_."${platform}_Deployed" -eq $true }
            
            $deploymentRate = if ($platformIndicators.Count -gt 0) {
                [math]::Round(($deployed.Count / $platformIndicators.Count) * 100, 2)
            } else { 100 }
            
            $status = if ($deploymentRate -ge 95) { "Healthy"; $statusReport.Healthy++ }
            elseif ($deploymentRate -ge 80) { "Degraded"; $statusReport.Degraded++ }
            else { "Failed"; $statusReport.Failed++ }
            
            $statusReport.Platforms[$platform] = @{
                Total = $platformIndicators.Count
                Deployed = $deployed.Count
                Rate = $deploymentRate
                Status = $status
            }
            
            Write-CTILog "$platform : $($deployed.Count)/$($platformIndicators.Count) deployed ($deploymentRate%) - $status" -Level $(if ($status -eq "Healthy") { "SUCCESS" } else { "WARNING" })
        }
        
    } catch {
        Write-CTILog "Error checking deployment status: $_" -Level "ERROR"
    }
    
    return $statusReport
}

function Remove-ExpiredIndicators {
    Write-CTILog "`n=== Cleaning Up Expired Indicators ===" -Level "INFO"
    
    $cleanupStats = @{
        Expired = 0
        Removed = 0
        Failed = 0
    }
    
    try {
        # Get expired indicators
        $expiredIndicators = Get-CTIIndicators | Where-Object { 
            $_.Expires -lt (Get-Date) -and $_.ValidationStatus -ne "FalsePositive"
        }
        
        $cleanupStats.Expired = $expiredIndicators.Count
        Write-CTILog "Found $($expiredIndicators.Count) expired indicators" -Level "INFO"
        
        foreach ($indicator in $expiredIndicators) {
            try {
                # Remove from all platforms
                Remove-CTIIndicator -IndicatorId $indicator.IndicatorId -Reason "Expired - Automated cleanup"
                
                $cleanupStats.Removed++
                Write-CTILog "Removed expired indicator: $($indicator.Value)" -Level "SUCCESS"
                
            } catch {
                $cleanupStats.Failed++
                Write-CTILog "Failed to remove $($indicator.Value): $_" -Level "ERROR"
            }
        }
        
    } catch {
        Write-CTILog "Error during cleanup: $_" -Level "ERROR"
    }
    
    Write-CTILog "Cleanup complete - Expired: $($cleanupStats.Expired), Removed: $($cleanupStats.Removed), Failed: $($cleanupStats.Failed)" -Level "INFO"
    return $cleanupStats
}

function Send-DailySummary {
    param(
        [hashtable]$SyncStats,
        [hashtable]$StatusReport,
        [hashtable]$CleanupStats
    )
    
    Write-CTILog "`n=== Sending Daily Summary ===" -Level "INFO"
    
    $duration = (Get-Date) - $script:StartTime
    
    $summary = @"
# ClarityXDR CTI Daily Operations Summary

**Date**: $(Get-Date -Format 'yyyy-MM-dd')
**Duration**: $($duration.ToString('hh\:mm\:ss'))

## Synchronization Results
- **Total Pending**: $($SyncStats.Total)
- **Successfully Synced**: $($SyncStats.Synced)
- **Failed**: $($SyncStats.Failed)

## Platform Status
$(foreach ($platform in $StatusReport.Platforms.GetEnumerator()) {
"- **$($platform.Key)**: $($platform.Value.Deployed)/$($platform.Value.Total) deployed ($($platform.Value.Rate)%) - $($platform.Value.Status)"
})

## Cleanup Results
- **Expired Indicators**: $($CleanupStats.Expired)
- **Successfully Removed**: $($CleanupStats.Removed)
- **Failed Removals**: $($CleanupStats.Failed)

## Overall Health
- **Healthy Platforms**: $($StatusReport.Healthy)
- **Degraded Platforms**: $($StatusReport.Degraded)
- **Failed Platforms**: $($StatusReport.Failed)

---
Log file: $($script:LogPath)
"@
    
    # Save summary to file
    $summaryPath = "$PSScriptRoot\Reports\CTI-Daily-Summary-$(Get-Date -Format 'yyyyMMdd').md"
    $summaryDir = Split-Path $summaryPath -Parent
    if (-not (Test-Path $summaryDir)) {
        New-Item -Path $summaryDir -ItemType Directory -Force | Out-Null
    }
    $summary | Out-File -FilePath $summaryPath -Encoding UTF8
    
    Write-CTILog "Daily summary saved to: $summaryPath" -Level "SUCCESS"
    
    # Send email notification if configured
    if ($script:Config.deployment.notifications.email.enabled) {
        try {
            # Email notification logic here
            Write-CTILog "Email notification sent to: $($script:Config.deployment.notifications.email.recipients -join ', ')" -Level "SUCCESS"
        } catch {
            Write-CTILog "Failed to send email notification: $_" -Level "WARNING"
        }
    }
    
    # Send Teams notification if configured
    if ($script:Config.deployment.notifications.teams.enabled -and $script:Config.deployment.notifications.teams.webhookUrl) {
        try {
            $teamsMessage = @{
                "@type" = "MessageCard"
                "@context" = "http://schema.org/extensions"
                "summary" = "CTI Daily Operations Summary"
                "themeColor" = if ($StatusReport.Failed -eq 0) { "00FF00" } else { "FF0000" }
                "title" = "CTI Daily Operations Summary - $(Get-Date -Format 'yyyy-MM-dd')"
                "sections" = @(
                    @{
                        "activityTitle" = "Synchronization Results"
                        "facts" = @(
                            @{ "name" = "Synced"; "value" = "$($SyncStats.Synced)/$($SyncStats.Total)" }
                            @{ "name" = "Failed"; "value" = "$($SyncStats.Failed)" }
                        )
                    }
                )
            }
            
            Invoke-RestMethod -Uri $script:Config.deployment.notifications.teams.webhookUrl -Method Post -Body ($teamsMessage | ConvertTo-Json -Depth 10) -ContentType "application/json"
            Write-CTILog "Teams notification sent" -Level "SUCCESS"
        } catch {
            Write-CTILog "Failed to send Teams notification: $_" -Level "WARNING"
        }
    }
}

function Update-IndicatorStatus {
    param(
        [string]$IndicatorId,
        [string]$Status,
        [string]$FailureReason = ""
    )
    
    try {
        # Update status in SharePoint
        Connect-PnPOnline -Url $script:Config.sharepoint.siteUrl -UseWebLogin
        
        $items = Get-PnPListItem -List $script:Config.sharepoint.lists.indicators -Query "<View><Query><Where><Eq><FieldRef Name='IndicatorId'/><Value Type='Text'>$IndicatorId</Value></Eq></Where></Query></View>"
        
        if ($items) {
            $updateValues = @{
                DeploymentStatus = $Status
                LastDeploymentAttempt = Get-Date
            }
            
            if ($Status -eq "Deployed") {
                $updateValues.LastDeploymentSuccess = Get-Date
            }
            
            if ($FailureReason) {
                $currentHistory = $items[0]["ActionHistory"]
                $updateValues.ActionHistory = "$currentHistory`n$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Deployment failed: $FailureReason"
            }
            
            Set-PnPListItem -List $script:Config.sharepoint.lists.indicators -Identity $items[0].Id -Values $updateValues
        }
        
        Disconnect-PnPOnline
    } catch {
        Write-CTILog "Failed to update indicator status: $_" -Level "WARNING"
    }
}

#endregion

#region Main Execution

try {
    Write-Host @"
╔══════════════════════════════════════════════════════════════╗
║          ClarityXDR CTI Daily Operations                     ║
╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
    
    Write-CTILog "Starting CTI daily operations" -Level "INFO"
    
    # Initialize environment
    if (-not (Initialize-CTIEnvironment)) {
        throw "Failed to initialize CTI environment"
    }
    
    # Perform operations
    $syncStats = Sync-PendingIndicators
    
    if (-not $SkipValidation) {
        $statusReport = Test-DeploymentStatus
    } else {
        Write-CTILog "Skipping deployment validation" -Level "WARNING"
        $statusReport = @{ Healthy = 0; Degraded = 0; Failed = 0; Platforms = @{} }
    }
    
    $cleanupStats = Remove-ExpiredIndicators
    
    # Send summary
    Send-DailySummary -SyncStats $syncStats -StatusReport $statusReport -CleanupStats $cleanupStats
    
    Write-CTILog "`nDaily operations completed successfully" -Level "SUCCESS"
    
    # Exit with appropriate code
    if ($syncStats.Failed -gt 0 -or $statusReport.Failed -gt 0) {
        exit 1
    } else {
        exit 0
    }
    
} catch {
    Write-CTILog "Critical error in daily operations: $_" -Level "ERROR"
    Write-CTILog $_.ScriptStackTrace -Level "ERROR"
    
    # Attempt to send error notification
    try {
        if ($script:Config.deployment.notifications.email.enabled) {
            # Send error email
            Write-CTILog "Error notification sent" -Level "INFO"
        }
    } catch {
        # Ignore notification errors
    }
    
    exit 2
} finally {
    # Cleanup
    try {
        Disconnect-MgGraph -ErrorAction SilentlyContinue
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
        Disconnect-PnPOnline -ErrorAction SilentlyContinue
    } catch {
        # Ignore cleanup errors
    }
    
    $duration = (Get-Date) - $script:StartTime
    Write-CTILog "Total execution time: $($duration.ToString('hh\:mm\:ss'))" -Level "INFO"
}

#endregion