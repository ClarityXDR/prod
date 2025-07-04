<#
.SYNOPSIS
    Enables LSA Protection (RunAsPPL) to protect the Local Security Authority process.

.DESCRIPTION
    This script sets the RunAsPPL registry value to enable LSA Protection, which runs
    the LSA process as a Protected Process Light (PPL). This hardens the system against
    credential theft attacks but may cause compatibility issues.

.NOTES
    POTENTIAL BREAKING CHANGES AND COMPATIBILITY ISSUES:
    
    WORKSTATION ISSUES:
    - Third-party security software may fail to inject into LSASS
    - Password managers that hook into LSASS may stop working
    - Some authentication modules (custom GINA/Credential Providers) may fail
    - Debugging tools cannot attach to LSASS process
    - Performance monitoring tools may lose LSASS visibility
    - Some single sign-on (SSO) solutions may break
    
    SERVER ISSUES:
    - Third-party authentication systems may fail
    - Custom security modules may not load
    - Some enterprise security suites may malfunction
    - Monitoring agents that hook LSASS may stop working
    - Legacy applications using older authentication APIs may fail
    - Some backup software that accesses security context may break
    
    GENERAL COMPATIBILITY:
    - Older Windows versions may not support PPL properly
    - Some antivirus products may trigger false positives
    - Memory dump analysis becomes more difficult
    - Some forensic tools cannot analyze LSASS
    - Custom authentication plugins may be blocked
    
    ROLLBACK PROCEDURE:
    If issues occur, set the registry value to 0 or delete it entirely:
    Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -Force
    Then restart the system.
    
    TESTING RECOMMENDATION:
    Test thoroughly in a non-production environment first, especially if using:
    - Third-party security software
    - Custom authentication solutions  
    - Legacy applications
    - Enterprise monitoring tools
#>

# Requires Administrator privileges
#Requires -RunAsAdministrator

# Registry path and value details
$registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
$valueName = "RunAsPPL"
$valueData = 1
$valueType = "DWord"

try {
    Write-Host "WARNING: Enabling LSA Protection may cause compatibility issues!" -ForegroundColor Red
    Write-Host "This may break third-party security software, password managers, and custom authentication modules." -ForegroundColor Red
    Write-Host "Ensure you have tested this change in a non-production environment first." -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "Setting LSA Protection (RunAsPPL) registry value..." -ForegroundColor Yellow
    
    # Ensure the registry path exists
    if (!(Test-Path $registryPath)) {
        Write-Host "Registry path does not exist. Creating: $registryPath" -ForegroundColor Yellow
        New-Item -Path $registryPath -Force | Out-Null
    }
    
    # Set the registry value
    Set-ItemProperty -Path $registryPath -Name $valueName -Value $valueData -Type $valueType -Force
    
    # Verify the value was set correctly
    $currentValue = Get-ItemProperty -Path $registryPath -Name $valueName -ErrorAction SilentlyContinue
    
    if ($currentValue.$valueName -eq $valueData) {
        Write-Host "SUCCESS: RunAsPPL has been set to $valueData" -ForegroundColor Green
        Write-Host "A system restart is required for this change to take effect." -ForegroundColor Cyan
        Write-Host ""
        Write-Host "IMPORTANT: Monitor system behavior after restart for:" -ForegroundColor Yellow
        Write-Host "- Authentication failures" -ForegroundColor Yellow
        Write-Host "- Third-party security software issues" -ForegroundColor Yellow
        Write-Host "- Application login problems" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "If issues occur, rollback with:" -ForegroundColor Cyan
        Write-Host "Remove-ItemProperty -Path '$registryPath' -Name '$valueName' -Force" -ForegroundColor Cyan
    } else {
        Write-Error "Failed to verify the registry value was set correctly."
    }
    
} catch {
    Write-Error "Failed to set registry value: $($_.Exception.Message)"
    exit 1
}
