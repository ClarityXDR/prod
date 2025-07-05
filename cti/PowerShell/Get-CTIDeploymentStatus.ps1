<#
.SYNOPSIS
    Retrieves the deployment status of threat indicators across all security platforms
.DESCRIPTION
    This script queries the central SharePoint list to get the deployment status of 
    threat indicators across all configured security platforms. It can filter by
    indicator value or type.
.PARAMETER IndicatorValue
    The value of the indicator to check (optional)
.PARAMETER IndicatorType
    The type of indicator to filter by (optional)
.PARAMETER Platform
    Filter by specific deployment platform (optional)
.PARAMETER LastDays
    Number of days to look back for indicators
.EXAMPLE
    .\Get-CTIDeploymentStatus.ps1 -IndicatorValue "192.168.1.100"
.EXAMPLE
    .\Get-CTIDeploymentStatus.ps1 -IndicatorType "IPAddress" -Platform "EntraID"
.NOTES
    Requires PnP.PowerShell module and appropriate permissions to the SharePoint site
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$IndicatorValue,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("FileHash", "IPAddress", "URL", "Domain", "Certificate", "Email", "All")]
    [string]$IndicatorType = "All",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("MDE", "EntraID", "MDCA", "ExchangeEOP", "ExchangeTABL", "AzureFirewall", "AzurePolicy", "OnPremFirewall", "ThirdParty", "All")]
    [string]$Platform = "All",
    
    [Parameter(Mandatory = $false)]
    [int]$LastDays = 30
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

# Build query
$camlQuery = "<View><Query>"
$whereClause = @()

if ($IndicatorValue) {
    $whereClause += "<Eq><FieldRef Name='IndicatorValue'/><Value Type='Text'>$IndicatorValue</Value></Eq>"
}

if ($IndicatorType -ne "All") {
    $whereClause += "<Eq><FieldRef Name='IndicatorType'/><Value Type='Choice'>$IndicatorType</Value></Eq>"
}

if ($LastDays -gt 0) {
    $dateThreshold = (Get-Date).AddDays(-$LastDays).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $whereClause += "<Geq><FieldRef Name='Created'/><Value Type='DateTime'>$dateThreshold</Value></Geq>"
}

if ($whereClause.Count -gt 0) {
    $camlQuery += "<Where>"
    if ($whereClause.Count -eq 1) {
        $camlQuery += $whereClause[0]
    } else {
        $camlQuery += "<And>$($whereClause[0])"
        for ($i = 1; $i -lt $whereClause.Count; $i++) {
            if ($i -eq $whereClause.Count - 1) {
                $camlQuery += $whereClause[$i]
            } else {
                $camlQuery += "<And>$($whereClause[$i])"
            }
        }
        for ($i = 1; $i -lt $whereClause.Count; $i++) {
            $camlQuery += "</And>"
        }
    }
    $camlQuery += "</Where>"
}

$camlQuery += "<OrderBy><FieldRef Name='Modified' Ascending='False'/></OrderBy></Query>"
$camlQuery += "<RowLimit>500</RowLimit></View>"

# Get items from SharePoint
try {
    $items = Get-PnPListItem -List $indicatorsListName -Query $camlQuery
    
    if (-not $items -or $items.Count -eq 0) {
        Write-Host "No indicators found matching the criteria" -ForegroundColor Yellow
        return
    }
    
    Write-Host "Found $($items.Count) indicators matching the criteria" -ForegroundColor Green
    
    # Process items
    $results = @()
    foreach ($item in $items) {
        $deploymentStatus = if ($item.FieldValues.DeploymentStatus) { 
            try {
                ConvertFrom-Json $item.FieldValues.DeploymentStatus -AsHashtable
            } catch {
                @{}
            }
        } else { 
            @{} 
        }
        
        $deploymentTargets = if ($item.FieldValues.DeploymentTargets -is [array]) {
            $item.FieldValues.DeploymentTargets
        } elseif ($item.FieldValues.DeploymentTargets) {
            @($item.FieldValues.DeploymentTargets)
        } else {
            @()
        }
        
        # Filter by platform if specified
        if ($Platform -ne "All") {
            if (-not ($deploymentTargets -contains $Platform)) {
                continue
            }
        }
        
        $result = [PSCustomObject]@{
            ID = $item.Id
            IndicatorId = $item.FieldValues.IndicatorId
            Type = $item.FieldValues.IndicatorType
            Value = $item.FieldValues.IndicatorValue
            Title = $item.FieldValues.Title
            Severity = $item.FieldValues.Severity
            ValidationStatus = $item.FieldValues.ValidationStatus
            DeploymentTargets = $deploymentTargets -join ", "
            LastDeploymentAttempt = $item.FieldValues.LastDeploymentAttempt
            LastDeploymentSuccess = $item.FieldValues.LastDeploymentSuccess
            MDE_Deployed = if ($deploymentStatus.ContainsKey("MDE")) { $deploymentStatus.MDE.Deployed } else { "N/A" }
            EntraID_Deployed = if ($deploymentStatus.ContainsKey("EntraID")) { $deploymentStatus.EntraID.Deployed } else { "N/A" }
            MDCA_Deployed = if ($deploymentStatus.ContainsKey("MDCA")) { $deploymentStatus.MDCA.Deployed } else { "N/A" }
            ExchangeEOP_Deployed = if ($deploymentStatus.ContainsKey("ExchangeEOP")) { $deploymentStatus.ExchangeEOP.Deployed } else { "N/A" }
            ExchangeTABL_Deployed = if ($deploymentStatus.ContainsKey("ExchangeTABL")) { $deploymentStatus.ExchangeTABL.Deployed } else { "N/A" }
            AzureFirewall_Deployed = if ($deploymentStatus.ContainsKey("AzureFirewall")) { $deploymentStatus.AzureFirewall.Deployed } else { "N/A" }
            AzurePolicy_Deployed = if ($deploymentStatus.ContainsKey("AzurePolicy")) { $deploymentStatus.AzurePolicy.Deployed } else { "N/A" }
            OnPremFirewall_Deployed = if ($deploymentStatus.ContainsKey("OnPremFirewall")) { $deploymentStatus.OnPremFirewall.Deployed } else { "N/A" }
            ThirdParty_Deployed = if ($deploymentStatus.ContainsKey("ThirdParty")) { $deploymentStatus.ThirdParty.Deployed } else { "N/A" }
            ValidUntil = $item.FieldValues.ValidUntil
        }
        
        $results += $result
    }
    
    return $results
} catch {
    Write-Error "Error retrieving indicators: $_"
    exit 1
} finally {
    # Disconnect from SharePoint
    Disconnect-PnPOnline
}
