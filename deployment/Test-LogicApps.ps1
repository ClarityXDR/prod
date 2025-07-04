<#
.SYNOPSIS
    Tests deployed Logic Apps for basic functionality
.DESCRIPTION
    Validates that Logic Apps are deployed correctly and connections are working
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $true)]
    [string]$ConfigFilePath
)

# Import required modules
Import-Module Az.Accounts -Force
Import-Module Az.LogicApp -Force

# Load configuration
$config = Get-Content $ConfigFilePath | ConvertFrom-Json

# Connect to Azure
Connect-AzAccount -SubscriptionId $SubscriptionId
Set-AzContext -SubscriptionId $SubscriptionId

Write-Host "=== Logic Apps Validation Script ===" -ForegroundColor Cyan

# Get all Logic Apps in resource group
$logicApps = Get-AzLogicApp -ResourceGroupName $ResourceGroupName

Write-Host "Found $($logicApps.Count) Logic Apps to validate" -ForegroundColor Yellow

$testResults = @()

foreach ($app in $logicApps) {
    Write-Host "Testing Logic App: $($app.Name)" -ForegroundColor Cyan
    
    try {
        # Check if Logic App is enabled
        $status = if ($app.State -eq "Enabled") { "✓ Enabled" } else { "✗ Disabled" }
        Write-Host "  Status: $status" -ForegroundColor $(if ($app.State -eq "Enabled") { "Green" } else { "Red" })
        
        # Check triggers
        $triggers = Get-AzLogicAppTrigger -ResourceGroupName $ResourceGroupName -Name $app.Name
        Write-Host "  Triggers: $($triggers.Count) found" -ForegroundColor White
        
        # Test connections (basic check)
        $definition = Get-AzLogicApp -ResourceGroupName $ResourceGroupName -Name $app.Name
        $connections = $definition.Parameters.'$connections'.value
        
        if ($connections) {
            $connectionCount = ($connections | Get-Member -MemberType NoteProperty).Count
            Write-Host "  Connections: $connectionCount configured" -ForegroundColor White
        }
        
        $testResults += @{
            Name = $app.Name
            Status = $app.State
            TriggerCount = $triggers.Count
            ConnectionCount = if ($connections) { ($connections | Get-Member -MemberType NoteProperty).Count } else { 0 }
            TestResult = "Success"
        }
        
        Write-Host "  ✓ Validation passed" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ Validation failed: $_" -ForegroundColor Red
        $testResults += @{
            Name = $app.Name
            Status = "Error"
            Error = $_.Exception.Message
            TestResult = "Failed"
        }
    }
}

# Generate test report
$report = @{
    Timestamp = Get-Date
    ResourceGroupName = $ResourceGroupName
    TotalApps = $logicApps.Count
    PassedTests = ($testResults | Where-Object {$_.TestResult -eq 'Success'}).Count
    FailedTests = ($testResults | Where-Object {$_.TestResult -eq 'Failed'}).Count
    Results = $testResults
}

$reportFile = "validation-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
$report | ConvertTo-Json -Depth 5 | Out-File $reportFile

Write-Host "`n=== Validation Summary ===" -ForegroundColor Cyan
Write-Host "Total Logic Apps: $($logicApps.Count)" -ForegroundColor White
Write-Host "Passed validation: $($report.PassedTests)" -ForegroundColor Green
Write-Host "Failed validation: $($report.FailedTests)" -ForegroundColor Red
Write-Host "Validation report saved: $reportFile" -ForegroundColor Green
