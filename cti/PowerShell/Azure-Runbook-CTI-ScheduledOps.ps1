# Azure Runbook - CTI Scheduled Operations
# This runbook performs scheduled maintenance tasks for the CTI solution
# Runs daily to sync indicators, check deployment status, and cleanup expired items

param(
    [Parameter(Mandatory = $false)]
    [string]$SentinelWorkspaceId = (Get-AutomationVariable -Name "CTI-SentinelWorkspaceId"),
    
    [Parameter(Mandatory = $false)]
    [string]$IngestionLogicAppUrl = (Get-AutomationVariable -Name "CTI-IngestionLogicAppUrl"),
    
    [Parameter(Mandatory = $false)]
    [string]$ValidationLogicAppUrl = (Get-AutomationVariable -Name "CTI-ValidationLogicAppUrl")
)

# Import required modules (these should be imported into the Automation Account)
Import-Module Az.Accounts
Import-Module Az.Profile
Import-Module Az.OperationalInsights
Import-Module ExchangeOnlineManagement
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Identity.SignIns

# Import the CTI module from the Automation Account
. .\CTI-Module.ps1

Write-Output "Starting CTI Scheduled Operations at $(Get-Date)"

try {
    # Connect to services using Managed Identity or stored credentials
    Write-Output "Connecting to Azure services..."
    
    # Connect to Azure using Managed Identity
    Connect-AzAccount -Identity
    
    # Connect to Exchange Online using stored credentials
    $ExchangeCredential = Get-AutomationPSCredential -Name "CTI-ExchangeOnlineCredential"
    Connect-ExchangeOnline -Credential $ExchangeCredential -ShowProgress $false
    
    # Connect to Microsoft Graph using stored credentials
    $GraphCredential = Get-AutomationPSCredential -Name "CTI-GraphCredential"
    Connect-MgGraph -ClientSecretCredential $GraphCredential
    
    # Initialize CTI Module
    $logicAppUrls = @{
        Ingestion = $IngestionLogicAppUrl
        Validation = $ValidationLogicAppUrl
    }
    
    Initialize-CTIModule -SentinelWorkspaceId $SentinelWorkspaceId -LogicAppUrls $logicAppUrls
    
    Write-Output "✓ All services connected successfully"
    
    # Task 1: Sync pending indicators to security products
    Write-Output "`n=== Synchronizing Pending Indicators ==="
    $pendingIndicators = Get-CTIIndicators | Where-Object { $_.DeploymentStatus -eq "Pending" -or $_.DeploymentStatus -eq "Failed" }
    
    if ($pendingIndicators.Count -gt 0) {
        Write-Output "Found $($pendingIndicators.Count) indicators requiring deployment"
        
        foreach ($indicator in $pendingIndicators) {
            try {
                Write-Output "Syncing indicator: $($indicator.Value) ($($indicator.Type))"
                
                switch ($indicator.PlacementStrategy) {
                    "MDCA_EntraID" {
                        if ($indicator.Type -eq "IPAddress") {
                            # Deploy to MDCA as risky IP
                            Set-MDCAPolicy -IPAddress $indicator.Value -Description "CTI Auto-deployment" -Severity "High"
                            
                            # Deploy to Entra ID Named Location with blocking
                            Add-EntraNamedLocation -IPAddress $indicator.Value -Description "CTI Malicious IP - Auto-deployed"
                            
                            Write-Output "✓ Deployed $($indicator.Value) to MDCA and Entra ID"
                        }
                    }
                    "Exchange_ConnectionFilter" {
                        if ($indicator.Type -eq "IPAddress") {
                            Add-ExchangeConnectionFilterIP -IPAddress $indicator.Value
                            Write-Output "✓ Deployed $($indicator.Value) to Exchange Connection Filter"
                        }
                    }
                    "Exchange_TenantAllowBlock" {
                        Add-ExchangeTenantBlockList -Value $indicator.Value -Type $indicator.Type
                        Write-Output "✓ Deployed $($indicator.Value) to Exchange Tenant Block List"
                    }
                    "MDE_Primary" {
                        Set-MDEIndicator -IndicatorValue $indicator.Value -IndicatorType $indicator.Type -Action "Block"
                        Write-Output "✓ Deployed $($indicator.Value) to Microsoft Defender for Endpoint"
                    }
                    default {
                        Write-Warning "Unknown placement strategy: $($indicator.PlacementStrategy)"
                    }
                }
                
                # Update deployment status in Sentinel
                $updateLog = @{
                    IndicatorId = $indicator.IndicatorId
                    DeploymentStatus = "Deployed"
                    DeploymentDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                    DeployedBy = "Azure-Runbook"
                } | ConvertTo-Json
                
                # Log deployment success to Sentinel
                Send-AzOperationalInsightsDataCollector -WorkspaceId $SentinelWorkspaceId -LogType "CTI_DeploymentUpdate" -JsonMessage $updateLog
                
            }
            catch {
                Write-Error "Failed to deploy indicator $($indicator.Value): $($_.Exception.Message)"
                
                # Log deployment failure
                $failureLog = @{
                    IndicatorId = $indicator.IndicatorId
                    DeploymentStatus = "Failed"
                    ErrorMessage = $_.Exception.Message
                    FailureDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
                } | ConvertTo-Json
                
                Send-AzOperationalInsightsDataCollector -WorkspaceId $SentinelWorkspaceId -LogType "CTI_DeploymentFailure" -JsonMessage $failureLog
            }
        }
    } else {
        Write-Output "No pending indicators found for deployment"
    }
    
    # Task 2: Check deployment status across all products
    Write-Output "`n=== Checking Deployment Status ==="
    $deploymentStatus = Get-CTIDeploymentStatus
    
    $statusSummary = $deploymentStatus | Group-Object Type | ForEach-Object {
        $total = $_.Count
        $mdeDeployed = ($_.Group | Where-Object { $_.MDE_Deployed }).Count
        $exchangeDeployed = ($_.Group | Where-Object { $_.Exchange_Deployed }).Count
        $mdcaDeployed = ($_.Group | Where-Object { $_.MDCA_Deployed }).Count
        $entraDeployed = ($_.Group | Where-Object { $_.EntraID_Deployed }).Count
        
        [PSCustomObject]@{
            IndicatorType = $_.Name
            TotalIndicators = $total
            MDE_DeploymentRate = [math]::Round(($mdeDeployed / $total) * 100, 2)
            Exchange_DeploymentRate = [math]::Round(($exchangeDeployed / $total) * 100, 2)
            MDCA_DeploymentRate = [math]::Round(($mdcaDeployed / $total) * 100, 2)
            EntraID_DeploymentRate = [math]::Round(($entraDeployed / $total) * 100, 2)
        }
    }
    
    $statusSummary | ForEach-Object {
        Write-Output "$($_.IndicatorType): Total=$($_.TotalIndicators), MDE=$($_.MDE_DeploymentRate)%, Exchange=$($_.Exchange_DeploymentRate)%, MDCA=$($_.MDCA_DeploymentRate)%, EntraID=$($_.EntraID_DeploymentRate)%"
    }
    
    # Log deployment status summary to Sentinel
    $statusLog = @{
        CheckDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        StatusSummary = $statusSummary
        TotalIndicators = $deploymentStatus.Count
    } | ConvertTo-Json -Depth 5
    
    Send-AzOperationalInsightsDataCollector -WorkspaceId $SentinelWorkspaceId -LogType "CTI_StatusCheck" -JsonMessage $statusLog
    
    # Task 3: Cleanup expired indicators
    Write-Output "`n=== Cleaning Up Expired Indicators ==="
    $expiredIndicators = Get-CTIIndicators | Where-Object { $_.Expires -lt (Get-Date) }
    
    if ($expiredIndicators.Count -gt 0) {
        Write-Output "Found $($expiredIndicators.Count) expired indicators for cleanup"
        
        foreach ($indicator in $expiredIndicators) {
            try {
                Write-Output "Removing expired indicator: $($indicator.Value)"
                Remove-CTIIndicator -IndicatorId $indicator.IndicatorId -Reason "Expired - Automated cleanup"
            }
            catch {
                Write-Error "Failed to remove expired indicator $($indicator.Value): $($_.Exception.Message)"
            }
        }
    } else {
        Write-Output "No expired indicators found for cleanup"
    }
    
    # Task 4: Health check - verify service connections
    Write-Output "`n=== Service Health Check ==="
    $healthStatus = @{
        Azure = $true
        ExchangeOnline = $false
        MicrosoftGraph = $false
        Timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    }
    
    try {
        # Test Exchange Online connection
        $null = Get-OrganizationConfig -ErrorAction Stop
        $healthStatus.ExchangeOnline = $true
        Write-Output "✓ Exchange Online connection healthy"
    }
    catch {
        Write-Warning "Exchange Online connection issue: $($_.Exception.Message)"
    }
    
    try {
        # Test Microsoft Graph connection
        $null = Get-MgContext -ErrorAction Stop
        $healthStatus.MicrosoftGraph = $true
        Write-Output "✓ Microsoft Graph connection healthy"
    }
    catch {
        Write-Warning "Microsoft Graph connection issue: $($_.Exception.Message)"
    }
    
    # Log health status
    $healthLog = $healthStatus | ConvertTo-Json
    Send-AzOperationalInsightsDataCollector -WorkspaceId $SentinelWorkspaceId -LogType "CTI_HealthCheck" -JsonMessage $healthLog
    
    Write-Output "`n=== CTI Scheduled Operations Completed Successfully ==="
    
    # Generate summary report
    $summary = @{
        ExecutionDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        PendingIndicatorsProcessed = $pendingIndicators.Count
        ExpiredIndicatorsRemoved = $expiredIndicators.Count
        TotalActiveIndicators = $deploymentStatus.Count
        HealthStatus = $healthStatus
        Status = "Success"
    }
    
    Write-Output "Summary: $($summary | ConvertTo-Json -Depth 3)"
    
    return $summary

}
catch {
    Write-Error "CTI Scheduled Operations failed: $($_.Exception.Message)"
    
    # Log failure
    $failureLog = @{
        ExecutionDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        ErrorMessage = $_.Exception.Message
        Status = "Failed"
    } | ConvertTo-Json
    
    Send-AzOperationalInsightsDataCollector -WorkspaceId $SentinelWorkspaceId -LogType "CTI_RunbookFailure" -JsonMessage $failureLog
    
    throw $_
}
finally {
    # Cleanup connections
    try {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
        Disconnect-MgGraph -ErrorAction SilentlyContinue
    }
    catch {
        # Ignore cleanup errors
    }
}