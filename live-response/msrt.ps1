# Script to run MSRT in Live Response - Simplified Version
Write-Output "Starting MSRT scan at $(Get-Date)"

# Download MSRT
$msrtUrl = "https://go.microsoft.com/fwlink/?LinkId=212732"
$msrtPath = "$env:TEMP\MSRT.exe"

Write-Output "Downloading MSRT..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
(New-Object System.Net.WebClient).DownloadFile($msrtUrl, $msrtPath)

# Verify download
$fileSize = (Get-Item $msrtPath).Length
Write-Output "Downloaded MSRT: $([math]::Round($fileSize/1MB, 2)) MB"

# Run MSRT
Write-Output "Running MSRT full scan (this may take 15-30 minutes)..."
$process = Start-Process -FilePath $msrtPath -ArgumentList "/F:Y /Q" -PassThru -Wait

# Output results
Write-Output "MSRT completed with exit code: $($process.ExitCode)"

switch ($process.ExitCode) {
    0 { Write-Output "No infection found." }
    1 { Write-Output "Reboot required to remove threats." }
    2 { Write-Output "Threats found and removed." }
    3 { Write-Output "Threats found, some actions failed." }
    4 { Write-Output "MSRT already run today." }
    default { Write-Output "MSRT exit code: $($process.ExitCode)" }
}

# Show log if available
$logPath = "$env:WINDIR\debug\mrt.log"
if (Test-Path $logPath) {
    Write-Output "`n===== MSRT Log (Last 20 lines) ====="
    Get-Content $logPath | Select-Object -Last 20
}

# Cleanup
Remove-Item $msrtPath -Force -ErrorAction SilentlyContinue
Write-Output "MSRT scan completed at $(Get-Date)"