# Get MDE Results - Formatted for incident posting
# Outputs formatted text ready for copy/paste to incidents

param(
    [string]$IncidentId = "Not Specified"
)

$output = @"
=== MDE Live Response Collection ===
Incident ID: $IncidentId
Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC' -AsUTC)
Hostname: $env:COMPUTERNAME
Domain: $env:USERDOMAIN

--- THREAT DETECTION STATUS ---
"@

# Active threats
$threats = Get-MpThreatDetection -ErrorAction SilentlyContinue | Select-Object -First 5
if ($threats) {
    $output += "`nACTIVE THREATS FOUND:`n"
    $threats | ForEach-Object {
        $output += "  Threat: $($_.ThreatName)`n"
        $output += "  Time: $($_.InitialDetectionTime)`n"
        $output += "  Process: $($_.ProcessName)`n`n"
    }
} else {
    $output += "No active threats detected`n"
}

# Protection status
$status = Get-MpComputerStatus -ErrorAction SilentlyContinue
$output += @"

--- PROTECTION STATUS ---
Real-time Protection: $($status.RealTimeProtectionEnabled)
Last Quick Scan: $($status.QuickScanEndTime)
Last Full Scan: $($status.FullScanEndTime)
Signature Version: $($status.AntivirusSignatureVersion)
Last Update: $($status.AntivirusSignatureLastUpdated)

--- RECENT EVENTS (48 hrs) ---
"@

# Recent events
$events = Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-Windows Defender/Operational';ID=1116,1117,1006,1007,1015;StartTime=(Get-Date).AddDays(-2)} -MaxEvents 5 -ErrorAction SilentlyContinue
if ($events) {
    $events | ForEach-Object {
        $output += "`n[$($_.TimeCreated)] Event $($_.Id): $($_.Message.Split("`n")[0])"
    }
} else {
    $output += "`nNo detection events in last 48 hours"
}

$output += @"

--- COLLECTION METADATA ---
Collected by: $env:USERNAME
Collection Method: MDE Live Response
Script Version: 1.0
=== END OF COLLECTION ===
"@

# Display for copy
Write-Host $output -ForegroundColor White
Write-Host "`n`n[Copy the above text to paste into incident]" -ForegroundColor Yellow

# Also save to clipboard if possible
$output | Set-Clipboard -ErrorAction SilentlyContinue
Write-Host "[Results copied to clipboard]" -ForegroundColor Green