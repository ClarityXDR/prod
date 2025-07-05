<#
.SYNOPSIS
    Adds a new threat intelligence indicator to the central SharePoint list
.DESCRIPTION
    This script adds a new threat indicator to the central CTI management system
    based on SharePoint, which will then be deployed to the appropriate security
    platforms via Logic Apps.
.PARAMETER Type
    Type of indicator (FileHash, IPAddress, URL, Domain, Certificate, Email)
.PARAMETER Value
    The actual indicator value
.PARAMETER Title
    A title or name for the indicator
.PARAMETER Description
    Detailed description of the threat
.PARAMETER TLP
    Traffic Light Protocol classification (White, Green, Amber, Red)
.PARAMETER Confidence
    Confidence score from 1-100
.PARAMETER Severity
    Severity level (Low, Medium, High, Critical)
.PARAMETER Source
    Source of the indicator
.PARAMETER DeploymentTargets
    Comma-separated list of platforms to deploy to
.PARAMETER ValidUntil
    Date until which the indicator is valid
.PARAMETER Tags
    Optional tags for the indicator
.EXAMPLE
    .\Add-CTIIndicator.ps1 -Type "IPAddress" -Value "192.168.1.100" -Title "Malicious C2 Server" -TLP "Amber" -DeploymentTargets "MDE,EntraID,MDCA"
.NOTES
    Requires PnP.PowerShell module and appropriate permissions to the SharePoint site
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("FileHash", "IPAddress", "URL", "Domain", "Certificate", "Email")]
    [string]$Type,
    
    [Parameter(Mandatory = $true)]
    [string]$Value,
    
    [Parameter(Mandatory = $true)]
    [string]$Title,
    
    [string]$Description = "",
    
    [ValidateSet("White", "Green", "Amber", "Red")]
    [string]$TLP = "Amber",
    
    [ValidateRange(1, 100)]
    [int]$Confidence = 70,
    
    [ValidateSet("Low", "Medium", "High", "Critical")]
    [string]$Severity = "Medium",
    
    [string]$Source = "Manual",
    
    [string]$DeploymentTargets = "",
    
    [datetime]$ValidUntil = (Get-Date).AddDays(90),
    
    [string]$Tags = ""
)

# Import required modules
Import-Module PnP.PowerShell -ErrorAction Stop

# Configuration - Update these values for your environment
$configPath = Join-Path $PSScriptRoot "CTI-Config.json"
if (Test-Path $configPath) {
    $config = Get-Content $configPath | ConvertFrom-Json
    $sharePointSiteUrl = $config.SharePointSiteUrl
    $indicatorsListName = $config.IndicatorsListName
} else {
    # Default values if no config file exists
    $sharePointSiteUrl = "https://contoso.sharepoint.com/sites/ThreatIntel"
    $indicatorsListName = "ThreatIndicatorsList"
    Write-Warning "Config file not found. Using default values."
}

# Connect to SharePoint
try {
    Write-Host "Connecting to SharePoint..." -ForegroundColor Yellow
    Connect-PnPOnline -Url $sharePointSiteUrl -Interactive -ErrorAction Stop
    Write-Host "Connected to SharePoint successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to connect to SharePoint: $_"
    exit 1
}

# Validate indicator value based on type
$isValid = $true
$validationMessage = ""

switch ($Type) {
    "IPAddress" {
        if (-not ($Value -match "^(\d{1,3}\.){3}\d{1,3}(\/\d{1,2})?$")) {
            $isValid = $false
            $validationMessage = "Invalid IP address format. Use IPv4 format with optional CIDR notation."
        }
    }
    "FileHash" {
        if (-not ($Value -match "^[A-Fa-f0-9]{32}$|^[A-Fa-f0-9]{40}$|^[A-Fa-f0-9]{64}$")) {
            $isValid = $false
            $validationMessage = "Invalid hash format. Use MD5 (32 chars), SHA1 (40 chars), or SHA256 (64 chars)."
        }
    }
    "Domain" {
        if (-not ($Value -match "^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$")) {
            $isValid = $false
            $validationMessage = "Invalid domain format."
        }
    }
    "URL" {
        if (-not ($Value -match "^https?://")) {
            $isValid = $false
            $validationMessage = "Invalid URL format. URLs must start with http:// or https://"
        }
    }
}

if (-not $isValid) {
    Write-Error "Indicator validation failed: $validationMessage"
    exit 1
}

# Check if indicator already exists
$existingItems = Get-PnPListItem -List $indicatorsListName -Query "<View><Query><Where><And><Eq><FieldRef Name='IndicatorType'/><Value Type='Choice'>$Type</Value></Eq><Eq><FieldRef Name='IndicatorValue'/><Value Type='Text'>$Value</Value></Eq></And></Where></Query></View>"

# Parse deployment targets
$deploymentTargetsArray = @()
if ($DeploymentTargets) {
    $deploymentTargetsArray = $DeploymentTargets.Split(',')
} else {
    # Auto-determine targets based on indicator type
    switch ($Type) {
        "IPAddress" { 
            if ($Description -like "*email*") {
                $deploymentTargetsArray = @("ExchangeEOP")
            } else {
                $deploymentTargetsArray = @("MDE", "EntraID", "MDCA") 
            }
        }
        "FileHash" { $deploymentTargetsArray = @("MDE") }
        "URL" { 
            if ($Description -like "*phish*") {
                $deploymentTargetsArray = @("ExchangeTABL")
            } else {
                $deploymentTargetsArray = @("MDE", "ExchangeTABL") 
            }
        }
        "Domain" { $deploymentTargetsArray = @("MDE", "ExchangeTABL") }
        "Certificate" { $deploymentTargetsArray = @("MDE") }
        "Email" { $deploymentTargetsArray = @("ExchangeTABL") }
    }
}

# Prepare item values
$indicatorId = if ($existingItems -and $existingItems.Count -gt 0) { 
    $existingItems[0].FieldValues.IndicatorId 
} else { 
    [guid]::NewGuid().ToString() 
}

$username = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$now = Get-Date

$itemValues = @{
    IndicatorId = $indicatorId
    IndicatorType = $Type
    IndicatorValue = $Value
    Title = $Title
    Description = $Description
    TLP = $TLP
    Confidence = $Confidence
    Severity = $Severity
    Source = $Source
    ValidFrom = $now
    ValidUntil = $ValidUntil
    ValidationStatus = "Pending"
    DeploymentTargets = $deploymentTargetsArray
    ActionHistory = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Indicator created/updated via PowerShell by $username"
}

if ($Tags) {
    $itemValues.Tags = $Tags
}

try {
    if ($existingItems -and $existingItems.Count -gt 0) {
        # Update existing item
        $existingItem = $existingItems[0]
        $actionHistory = $existingItem.FieldValues.ActionHistory
        $itemValues.ActionHistory = if ($actionHistory) { 
            $actionHistory + "`n" + $itemValues.ActionHistory 
        } else { 
            $itemValues.ActionHistory 
        }
        
        Set-PnPListItem -List $indicatorsListName -Identity $existingItem.Id -Values $itemValues | Out-Null
        Write-Host "Updated existing indicator: $Value" -ForegroundColor Green
        $result = $existingItem.Id
    } else {
        # Create new item
        $newItem = Add-PnPListItem -List $indicatorsListName -Values $itemValues
        Write-Host "Created new indicator: $Value" -ForegroundColor Green
        $result = $newItem.Id
    }
    
    Write-Host "Indicator will be deployed to: $($deploymentTargetsArray -join ', ')" -ForegroundColor Cyan
    Write-Host "SharePoint will trigger Logic Apps to deploy the indicator to the target platforms." -ForegroundColor Yellow
    
    return $result
} catch {
    Write-Error "Failed to add indicator to SharePoint: $_"
    exit 1
} finally {
    # Disconnect from SharePoint
    Disconnect-PnPOnline
}
