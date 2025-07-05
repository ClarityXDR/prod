<#
.SYNOPSIS
    Updates the validation status of a threat indicator
.DESCRIPTION
    This script updates the validation status of a threat indicator in the
    central SharePoint list. This will trigger appropriate Logic Apps to handle
    deployment or removal based on the new status.
.PARAMETER IndicatorValue
    The value of the indicator to update
.PARAMETER IndicatorType
    The type of indicator (required if IndicatorValue is provided)
.PARAMETER IndicatorId
    The unique ID of the indicator (alternative to specifying Value and Type)
.PARAMETER NewStatus
    The new validation status to set
.PARAMETER Reason
    Reason for the status change
.PARAMETER ReputationScore
    Updated reputation score (optional)
.PARAMETER ReputationSource
    Source of the reputation score (optional)
.EXAMPLE
    .\Update-CTIIndicatorStatus.ps1 -IndicatorValue "192.168.1.100" -IndicatorType "IPAddress" -NewStatus "FalsePositive" -Reason "Internal IP range"
.EXAMPLE
    .\Update-CTIIndicatorStatus.ps1 -IndicatorId "a1b2c3d4-e5f6-7890-abcd-1234567890ab" -NewStatus "Valid" -ReputationScore 85 -ReputationSource "VirusTotal"
.NOTES
    Requires PnP.PowerShell module and appropriate permissions to the SharePoint site
#>

[CmdletBinding(DefaultParameterSetName = "ByValue")]
param(
    [Parameter(Mandatory = $true, ParameterSetName = "ByValue")]
    [string]$IndicatorValue,
    
    [Parameter(Mandatory = $true, ParameterSetName = "ByValue")]
    [ValidateSet("FileHash", "IPAddress", "URL", "Domain", "Certificate", "Email")]
    [string]$IndicatorType,
    
    [Parameter(Mandatory = $true, ParameterSetName = "ById")]
    [string]$IndicatorId,
    
    [Parameter(Mandatory = $true)]
    [ValidateSet("Pending", "Valid", "Invalid", "Expired", "FalsePositive")]
    [string]$NewStatus,
    
    [Parameter(Mandatory = $true)]
    [string]$Reason,
    
    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 100)]
    [int]$ReputationScore = 0,
    
    [Parameter(Mandatory = $false)]
    [string]$ReputationSource = ""
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

# Find the indicator
try {
    $camlQuery = "<View><Query><Where>"
    
    if ($PSCmdlet.ParameterSetName -eq "ByValue") {
        $camlQuery += "<And><Eq><FieldRef Name='IndicatorType'/><Value Type='Choice'>$IndicatorType</Value></Eq><Eq><FieldRef Name='IndicatorValue'/><Value Type='Text'>$IndicatorValue</Value></Eq></And>"
    } else {
        $camlQuery += "<Eq><FieldRef Name='IndicatorId'/><Value Type='Text'>$IndicatorId</Value></Eq>"
    }
    
    $camlQuery += "</Where></Query></View>"
    
    $items = Get-PnPListItem -List $indicatorsListName -Query $camlQuery
    
    if (-not $items -or $items.Count -eq 0) {
        if ($PSCmdlet.ParameterSetName -eq "ByValue") {
            Write-Error "No indicator found with value '$IndicatorValue' and type '$IndicatorType'"
        } else {
            Write-Error "No indicator found with ID '$IndicatorId'"
        }
        exit 1
    }
    
    $item = $items[0]
    $now = Get-Date
    $username = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    
    # Prepare update values
    $actionHistory = $item.FieldValues.ActionHistory
    $newAction = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - Validation status changed to '$NewStatus'. Reason: $Reason. User: $username"
    $updatedActionHistory = if ($actionHistory) { 
        $actionHistory + "`n" + $newAction 
    } else { 
        $newAction 
    }
    
    $values = @{
        ValidationStatus = $NewStatus
        LastValidated = $now
        ActionHistory = $updatedActionHistory
    }
    
    if ($ReputationScore -gt 0) {
        $values.ReputationScore = $ReputationScore
    }
    
    if ($ReputationSource) {
        $values.ReputationSource = $ReputationSource
    }
    
    # Automatically set expiration for false positives
    if ($NewStatus -eq "FalsePositive" -or $NewStatus -eq "Expired") {
        $values.ValidUntil = $now
    }
    
    # Update the indicator
    Set-PnPListItem -List $indicatorsListName -Identity $item.Id -Values $values | Out-Null
    
    Write-Host "Updated indicator status to '$NewStatus'" -ForegroundColor Green
    Write-Host "The SharePoint change will trigger Logic Apps to handle the appropriate actions." -ForegroundColor Yellow
    
    # Display indicator details
    [PSCustomObject]@{
        ID = $item.Id
        IndicatorId = $item.FieldValues.IndicatorId
        Type = $item.FieldValues.IndicatorType
        Value = $item.FieldValues.IndicatorValue
        Title = $item.FieldValues.Title
        NewStatus = $NewStatus
        UpdatedBy = $username
        UpdatedAt = $now
    }
} catch {
    Write-Error "Failed to update indicator: $_"
    exit 1
} finally {
    # Disconnect from SharePoint
    Disconnect-PnPOnline
}
