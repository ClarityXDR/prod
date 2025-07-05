<#
.SYNOPSIS
    Updates all GitHub URLs in CTI solution files to point to ClarityXDR repository
.DESCRIPTION
    This script updates all template files, scripts, and configurations to use the correct
    GitHub repository URLs for the ClarityXDR CTI solution
.PARAMETER RepositoryPath
    Path to the local CTI repository folder
.EXAMPLE
    .\Fix-GitHubURLs.ps1 -RepositoryPath "C:\repos\prod\cti"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath
)

$ErrorActionPreference = "Stop"

# Define the correct GitHub base URL
$correctBaseUrl = "https://raw.githubusercontent.com/ClarityXDR/prod/refs/heads/main/cti"

# Files that need URL updates
$filesToUpdate = @(
    "azuredeploy.json",
    "Deploy-ClarityXDR-CTI.ps1",
    "PowerShell\Azure-Runbook-CTI-ScheduledOps.ps1",
    "Templates\Azure-Automation-CTI.json",
    "deployment-config.json"
)

Write-Host "Updating GitHub URLs in CTI solution files..." -ForegroundColor Cyan

foreach ($file in $filesToUpdate) {
    $filePath = Join-Path $RepositoryPath $file
    
    if (Test-Path $filePath) {
        Write-Host "Processing: $file" -ForegroundColor Yellow
        
        # Read file content
        $content = Get-Content $filePath -Raw
        
        # Replace various URL patterns
        $patterns = @(
            'https://raw\.githubusercontent\.com/[^/]+/[^/]+/[^/]+/[^/]+/[^/]+/cti',
            'https://github\.com/[^/]+/[^/]+/blob/main/cti',
            'https://github\.com/[^/]+/[^/]+/tree/main/cti'
        )
        
        $updated = $false
        foreach ($pattern in $patterns) {
            if ($content -match $pattern) {
                $content = $content -replace $pattern, $correctBaseUrl
                $updated = $true
            }
        }
        
        # Update specific references
        $specificReplacements = @{
            "DataGuys/cti/refs/heads/main" = "ClarityXDR/prod/refs/heads/main/cti"
            "/DataGuys/cti" = "/ClarityXDR/prod"
            "github.com/DataGuys" = "github.com/ClarityXDR"
        }
        
        foreach ($old in $specificReplacements.Keys) {
            if ($content -match [regex]::Escape($old)) {
                $content = $content -replace [regex]::Escape($old), $specificReplacements[$old]
                $updated = $true
            }
        }
        
        if ($updated) {
            # Save updated content
            Set-Content -Path $filePath -Value $content -Encoding UTF8
            Write-Host "  ✓ Updated URLs in $file" -ForegroundColor Green
        } else {
            Write-Host "  - No URLs to update in $file" -ForegroundColor Gray
        }
    } else {
        Write-Host "  ✗ File not found: $file" -ForegroundColor Red
    }
}

# Update the main deployment script with correct repository URL
$deployScript = Join-Path $RepositoryPath "Deploy-ClarityXDR-CTI.ps1"
if (Test-Path $deployScript) {
    $content = Get-Content $deployScript -Raw
    $content = $content -replace '\$script:GitHubBaseUrl = ".*"', "`$script:GitHubBaseUrl = `"$correctBaseUrl`""
    Set-Content -Path $deployScript -Value $content -Encoding UTF8
    Write-Host "Updated GitHubBaseUrl in deployment script" -ForegroundColor Green
}

# Create a quick test script
$testScript = @'
# Quick test to verify URLs are accessible
$testUrl = "' + $correctBaseUrl + '/azuredeploy.json"
try {
    $response = Invoke-WebRequest -Uri $testUrl -UseBasicParsing -Method Head
    if ($response.StatusCode -eq 200) {
        Write-Host "✓ GitHub URLs are correctly configured and accessible!" -ForegroundColor Green
    }
} catch {
    Write-Host "✗ Failed to access GitHub URL. Please check repository settings." -ForegroundColor Red
}
'@

$testScriptPath = Join-Path $RepositoryPath "Test-GitHubAccess.ps1"
$testScript | Out-File -FilePath $testScriptPath -Encoding UTF8

Write-Host "`n✅ URL update complete!" -ForegroundColor Green
Write-Host "Run .\Test-GitHubAccess.ps1 to verify the URLs are accessible" -ForegroundColor Cyan