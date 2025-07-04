# Reset-MDESignatures.ps1
# Script to repair Microsoft Defender after drive-by attacks
# For use in MDE Live Response

# Start transcript for reporting
$transcriptPath = "$env:TEMP\MDERepair_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
Start-Transcript -Path $transcriptPath -Force

Write-Host "Starting Microsoft Defender repair process..." -ForegroundColor Cyan

# Change to the Windows Defender directory
$defenderPath = "$env:ProgramFiles\Windows Defender"
Set-Location -Path $defenderPath
Write-Host "Changed directory to: $defenderPath" -ForegroundColor Green

# Remove dynamic signatures
Write-Host "Removing dynamic signatures..." -ForegroundColor Yellow
& "$defenderPath\MpCmdRun.exe" -removedefinitions -dynamicsignatures
    
# Update signatures
Write-Host "Updating signatures..." -ForegroundColor Yellow
& "$defenderPath\MpCmdRun.exe" -SignatureUpdate
    
Write-Host "Microsoft Defender repair completed successfully." -ForegroundColor Green

# Stop and display transcript information
Stop-Transcript

Write-Host "---------------------------------------" -ForegroundColor Yellow
Write-Host "ACTION REQUIRED: Upload Report to Incident" -ForegroundColor Red
Write-Host "---------------------------------------" -ForegroundColor Yellow
Write-Host "Transcript saved to: $transcriptPath" -ForegroundColor Cyan
Write-Host "To upload to an incident, use the MDE portal:" -ForegroundColor Cyan
Write-Host "1. Navigate to https://security.microsoft.com/incidents" -ForegroundColor White
Write-Host "2. Select the relevant incident" -ForegroundColor White
Write-Host "3. Click 'Add Evidence'" -ForegroundColor White
Write-Host "4. Upload the transcript file from $transcriptPath" -ForegroundColor White
Write-Host "---------------------------------------" -ForegroundColor Yellow