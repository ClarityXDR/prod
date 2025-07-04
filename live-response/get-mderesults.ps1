# Get MDE Results - Quick script for Live Response sessions
# Retrieves Windows Defender threats and scan results

Write-Host "=== Windows Defender Threat & Scan Results ===" -ForegroundColor Cyan
Write-Host "Timestamp: $(Get-Date)" -ForegroundColor Yellow
Write-Host ""

# Get detected threats
Write-Host "--- Detected Threats ---" -ForegroundColor Green
$threats = Get-MpThreatDetection
if ($threats) {
    $threats | Format-Table -AutoSize -Property DetectionID, ThreatName, InitialDetectionTime, ProcessName, Resources
} else {
    Write-Host "No threats detected" -ForegroundColor Gray
}

# Get threat history
Write-Host "`n--- Threat History ---" -ForegroundColor Green
$threatHistory = Get-MpThreat
if ($threatHistory) {
    $threatHistory | Format-Table -AutoSize -Property ThreatID, ThreatName, SeverityID, CategoryID, DetectionSource
} else {
    Write-Host "No threat history found" -ForegroundColor Gray
}

# Get scan history
Write-Host "`n--- Recent Scan Results ---" -ForegroundColor Green
$scanHistory = Get-MpComputerStatus
Write-Host "Last Quick Scan: $($scanHistory.QuickScanEndTime)"
Write-Host "Last Full Scan: $($scanHistory.FullScanEndTime)"
Write-Host "Real-time Protection: $($scanHistory.RealTimeProtectionEnabled)"
Write-Host "Antivirus Enabled: $($scanHistory.AntivirusEnabled)"
Write-Host "Antispyware Enabled: $($scanHistory.AntispywareEnabled)"

# Get Windows Defender status
Write-Host "`n--- Windows Defender Status ---" -ForegroundColor Green
Write-Host "Computer Name: $($scanHistory.ComputerName)"
Write-Host "Signature Version: $($scanHistory.AntivirusSignatureVersion)"
Write-Host "Last Signature Update: $($scanHistory.AntivirusSignatureLastUpdated)"
Write-Host "Engine Version: $($scanHistory.AMEngineVersion)"
Write-Host "Product Version: $($scanHistory.AMProductVersion)"

# Check for any quarantined items
Write-Host "`n--- Quarantined Items ---" -ForegroundColor Green
$quarantine = Get-MpThreatCatalog
if ($quarantine) {
    $quarantine | Format-Table -AutoSize -Property ThreatName, SeverityID, CategoryID
} else {
    Write-Host "No items in quarantine" -ForegroundColor Gray
}

Write-Host "`n=== End of Report ===" -ForegroundColor Cyan