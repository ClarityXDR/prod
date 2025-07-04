# CTI Example Usage Script
# Demonstrates MDCA IP Risky Category and Entra ID Named Location blocking

# Import the CTI Module
Import-Module ".\CTI-Module.psm1" -Force

# Example configuration
$config = @{
    SentinelWorkspaceId = "12345678-1234-1234-1234-123456789012"
    LogicAppUrls = @{
        Ingestion = "https://prod-123.westus.logic.azure.com:443/workflows/.../triggers/manual/paths/invoke"
        Validation = "https://prod-456.westus.logic.azure.com:443/workflows/.../triggers/manual/paths/invoke"
    }
}

# Initialize the CTI module
Initialize-CTIModule -SentinelWorkspaceId $config.SentinelWorkspaceId -LogicAppUrls $config.LogicAppUrls

# Connect to all required services
Connect-CTIServices

Write-Host "=== CTI MDCA and Entra ID Integration Demo ===" -ForegroundColor Cyan

# Example 1: Add malicious IP to MDCA as risky category
Write-Host "`n1. Adding IP address to MDCA as risky category..." -ForegroundColor Yellow
$maliciousIP = "192.168.100.50"
$mdcaResult = Set-MDCAPolicy -IPAddress $maliciousIP -Description "Known C2 server from threat intel feed" -Severity "High"

if ($mdcaResult) {
    Write-Host "✓ Successfully added $maliciousIP to MDCA risky IP category" -ForegroundColor Green
} else {
    Write-Host "✗ Failed to add IP to MDCA" -ForegroundColor Red
}

# Example 2: Create Entra ID Named Location with sign-in blocking
Write-Host "`n2. Creating Entra ID Named Location with sign-in blocking..." -ForegroundColor Yellow
$entraResult = Add-EntraNamedLocation -IPAddress $maliciousIP -Description "CTI Malicious IP - Auto-generated blocking policy"

if ($entraResult) {
    Write-Host "✓ Successfully created Named Location and Conditional Access blocking policy" -ForegroundColor Green
    Write-Host "   - Named Location ID: $($entraResult.NamedLocation.id)" -ForegroundColor Cyan
    Write-Host "   - CA Policy ID: $($entraResult.ConditionalAccessPolicy.id)" -ForegroundColor Cyan
} else {
    Write-Host "✗ Failed to create Entra ID Named Location" -ForegroundColor Red
}

# Example 3: Demonstrate automatic deployment via CTI indicator submission
Write-Host "`n3. Submitting IP indicator for automatic MDCA + Entra ID deployment..." -ForegroundColor Yellow
$indicator = @{
    type = "IPAddress"
    value = "10.0.0.100"
    confidence = 85
    source = "ThreatIntelFeed"
    description = "Botnet command and control server"
    severity = "High"
    tlp = "Amber"
}

$submissionResult = Set-CTIIndicator @indicator

if ($submissionResult) {
    Write-Host "✓ Indicator submitted successfully - will be automatically deployed to MDCA and Entra ID" -ForegroundColor Green
}

# Example 4: Check deployment status across all security products
Write-Host "`n4. Checking deployment status across security products..." -ForegroundColor Yellow
$deploymentStatus = Get-CTIDeploymentStatus

$deploymentStatus | Where-Object { $_.Type -eq "IPAddress" } | ForEach-Object {
    Write-Host "`nIndicator: $($_.Value)" -ForegroundColor White
    Write-Host "  MDCA Deployed: $($_.MDCA_Deployed)" -ForegroundColor $(if($_.MDCA_Deployed) {"Green"} else {"Red"})
    Write-Host "  Entra ID Deployed: $($_.EntraID_Deployed)" -ForegroundColor $(if($_.EntraID_Deployed) {"Green"} else {"Red"})
    Write-Host "  Exchange Deployed: $($_.Exchange_Deployed)" -ForegroundColor $(if($_.Exchange_Deployed) {"Green"} else {"Red"})
    Write-Host "  MDE Deployed: $($_.MDE_Deployed)" -ForegroundColor $(if($_.MDE_Deployed) {"Green"} else {"Red"})
}

# Example 5: Cleanup - Remove indicators and policies
Write-Host "`n5. Demonstrating cleanup process..." -ForegroundColor Yellow

# Remove from MDCA
Write-Host "Removing from MDCA risky category..." -ForegroundColor Yellow
Remove-MDCAPolicy -IPAddress $maliciousIP

# Remove from Entra ID
Write-Host "Removing Entra ID Named Location and Conditional Access policy..." -ForegroundColor Yellow
Remove-EntraNamedLocation -IPAddress $maliciousIP

Write-Host "`n=== Demo Complete ===" -ForegroundColor Cyan
Write-Host "Key Features Demonstrated:" -ForegroundColor White
Write-Host "✓ MDCA IP address risky category management" -ForegroundColor Green
Write-Host "✓ Entra ID Named Location with complete sign-in blocking" -ForegroundColor Green
Write-Host "✓ Automatic deployment via CTI indicator submission" -ForegroundColor Green
Write-Host "✓ Cross-product deployment status monitoring" -ForegroundColor Green
Write-Host "✓ Automated cleanup and policy removal" -ForegroundColor Green