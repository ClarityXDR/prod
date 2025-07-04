<#
.SYNOPSIS
    Microsoft Defender for Endpoint repair and reset script for MDE Live Response
.DESCRIPTION
    Runs various MpCmdRun.exe commands to repair and reset MDE components
.NOTES
    File Name: repair-mde.ps1
    Author: Bio-Rad Security Team
    Requires: PowerShell v3.0 or later, Windows Defender/MDE installed
    Usage: Upload to Live Response Library and run on endpoints as needed
.EXAMPLE
    From MDE Live Response console:
    run repair-mde.ps1
#>

# Print banner for easier identification in console output
Write-Host "============================================================"
Write-Host "  MICROSOFT DEFENDER FOR ENDPOINT REPAIR SCRIPT"
Write-Host "============================================================"
Write-Host "Hostname: $env:COMPUTERNAME"
Write-Host "Date: $(Get-Date)"
Write-Host "User: $env:USERNAME"
Write-Host "============================================================"

# Define MpCmdRun.exe path
$mpCmdPath = "C:\Program Files\Windows Defender\MpCmdRun.exe"

# Check if MpCmdRun.exe exists
if (-not (Test-Path $mpCmdPath)) {
    Write-Host "ERROR: MpCmdRun.exe not found at $mpCmdPath"
    Write-Host "Checking alternative locations..."
    
    $altPaths = @(
        "C:\Program Files\Microsoft Security Client\MpCmdRun.exe",
        "C:\ProgramData\Microsoft\Windows Defender\Platform\*\MpCmdRun.exe"
    )
    
    foreach ($altPath in $altPaths) {
        $foundPath = Get-ChildItem $altPath -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($foundPath) {
            $mpCmdPath = $foundPath.FullName
            Write-Host "Found MpCmdRun.exe at: $mpCmdPath"
            break
        }
    }
    
    if (-not (Test-Path $mpCmdPath)) {
        Write-Host "ERROR: Could not locate MpCmdRun.exe. Exiting."
        exit 1
    }
}

Write-Host "Using MpCmdRun.exe from: $mpCmdPath"
Write-Host ""

# Function to run MpCmdRun with error handling
function Invoke-MpCmd {
    param([string]$Arguments, [string]$Description)
    
    Write-Host "Executing: $Description"
    Write-Host "Command: `"$mpCmdPath`" $Arguments"
    
    try {
        $result = & $mpCmdPath $Arguments.Split(' ') 2>&1
        Write-Host "Result: $result"
        Write-Host "Status: SUCCESS"
    }
    catch {
        Write-Host "Status: ERROR - $_"
    }
    Write-Host "----------------------------------------"
}

# Execute MDE repair commands
Write-Host "Starting MDE repair sequence..."
Write-Host ""

Invoke-MpCmd "-wdenable" "Enable Windows Defender"
Invoke-MpCmd "-wdfix" "Basic Windows Defender Fix"
Invoke-MpCmd "-wdfix -full" "Full Windows Defender Fix"
Invoke-MpCmd "-SignatureUpdate -MMPC" "Update Signatures from MMPC"
Invoke-MpCmd "-ResetPlatform" "Reset Platform Components"

Write-Host "============================================================"
Write-Host "MDE repair sequence completed at $(Get-Date)"
Write-Host "============================================================"
