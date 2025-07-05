<#
.SYNOPSIS
    Deploys ClarityXDR SOC SharePoint Online Template
.DESCRIPTION
    Complete deployment script for Security Operations Center SharePoint site
.PARAMETER TenantUrl
    SharePoint tenant admin URL
.PARAMETER SiteUrl
    Target site URL for SOC deployment
.PARAMETER AppId
    Application ID for authentication
.PARAMETER CertificatePath
    Path to authentication certificate
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$TenantUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$SiteUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$AppId,
    
    [Parameter(Mandatory=$true)]
    [string]$CertificatePath,
    
    [string]$SOCManagerEmail = "socmanager@clarityxdr.com",
    
    [string]$LogicAppUrl = "",
    
    [string]$DefenderWorkspaceId = "",
    
    [string]$SentinelWorkspaceId = ""
)

# Import required modules
Import-Module PnP.PowerShell -ErrorAction Stop

# Function to log progress
function Write-Log {
    param($Message, $Type = "Info")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Type) {
        "Info" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        default { "White" }
    }
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

try {
    Write-Log "Starting ClarityXDR SOC Template Deployment"
    
    # Connect to SharePoint
    Write-Log "Connecting to SharePoint tenant"
    Connect-PnPOnline -Url $TenantUrl -ClientId $AppId -CertificatePath $CertificatePath
    
    # Create site scripts
    Write-Log "Creating site scripts"
    
    # Main site script
    $mainScriptContent = Get-Content "$PSScriptRoot\SiteScripts\SOC-Main-Script.json" -Raw
    $mainScriptId = Add-PnPSiteScript -Title "ClarityXDR SOC Main Script" -Content $mainScriptContent -Description "Main SOC site configuration"
    
    # Lists script
    $listsScriptContent = Get-Content "$PSScriptRoot\SiteScripts\SOC-Lists-Script.json" -Raw
    $listsScriptId = Add-PnPSiteScript -Title "ClarityXDR SOC Lists Script" -Content $listsScriptContent -Description "SOC lists and libraries"
    
    # Security script
    $securityScriptContent = Get-Content "$PSScriptRoot\SiteScripts\SOC-Security-Script.json" -Raw
    $securityScriptId = Add-PnPSiteScript -Title "ClarityXDR SOC Security Script" -Content $securityScriptContent -Description "Security configuration"
    
    # Navigation script
    $navScriptContent = Get-Content "$PSScriptRoot\SiteScripts\SOC-Navigation-Script.json" -Raw
    $navScriptId = Add-PnPSiteScript -Title "ClarityXDR SOC Navigation Script" -Content $navScriptContent -Description "Site navigation"
    
    # Create site design
    Write-Log "Creating site design"
    $scriptIds = @($mainScriptId, $listsScriptId, $securityScriptId, $navScriptId)
    $siteDesignId = Add-PnPSiteDesign -Title "ClarityXDR Security Operations Center" `
        -SiteScriptIds $scriptIds `
        -Description "Complete SOC template with security dashboards and automation" `
        -WebTemplate "TeamSite" `
        -PreviewImageUrl "https://clarityxdr.com/images/soc-preview.png"
    
    # Grant permissions to SOC team
    Write-Log "Setting site design permissions"
    Grant-PnPSiteDesignRights -Identity $siteDesignId -Principals "SOC-Team@clarityxdr.com" -Rights View
    
    # Connect to target site
    Write-Log "Connecting to target site: $SiteUrl"
    Connect-PnPOnline -Url $SiteUrl -ClientId $AppId -CertificatePath $CertificatePath
    
    # Apply site design
    Write-Log "Applying site design to target site"
    $task = Add-PnPSiteDesignTask -SiteDesignId $siteDesignId
    
    # Wait for site design application
    Write-Log "Waiting for site design application to complete..."
    $status = Get-PnPSiteDesignTask -Identity $task.ID
    while ($status.Status -ne "Completed") {
        Start-Sleep -Seconds 5
        $status = Get-PnPSiteDesignTask -Identity $task.ID
        Write-Log "Status: $($status.Status)" -Type "Info"
    }
    
    # Apply additional configurations
    Write-Log "Applying PnP template"
    Invoke-PnPSiteTemplate -Path "$PSScriptRoot\..\Templates\SOC-Site-Template.pnp" -Parameters @{
        "SOCManager" = $SOCManagerEmail
        "LogicAppUrl" = $LogicAppUrl
        "DefenderWorkspaceId" = $DefenderWorkspaceId
        "SentinelWorkspaceId" = $SentinelWorkspaceId
    }
    
    # Deploy SPFx solutions
    Write-Log "Deploying SPFx web parts"
    
    # KQL Dashboard web part
    $kqlPackage = "$PSScriptRoot\..\WebParts\KQLDashboard\sharepoint\solution\kql-dashboard.sppkg"
    if (Test-Path $kqlPackage) {
        Add-PnPApp -Path $kqlPackage -Publish -Overwrite
        Write-Log "KQL Dashboard web part deployed"
    }
    
    # MITRE Navigator web part
    $mitrePackage = "$PSScriptRoot\..\WebParts\MITRENavigator\sharepoint\solution\mitre-navigator.sppkg"
    if (Test-Path $mitrePackage) {
        Add-PnPApp -Path $mitrePackage -Publish -Overwrite
        Write-Log "MITRE Navigator web part deployed"
    }
    
    # Configure security settings
    Write-Log "Configuring security settings"
    
    # Set external sharing to disabled
    Set-PnPSite -DisableSharingForNonOwners
    
    # Configure audit settings
    Set-PnPAuditing -EnableAll
    
    # Create default KQL queries
    Write-Log "Importing default KQL queries"
    & "$PSScriptRoot\Utilities\Import-KQLQueries.ps1" -SiteUrl $SiteUrl
    
    Write-Log "SOC Template deployment completed successfully!" -Type "Info"
    
} catch {
    Write-Log "Error during deployment: $_" -Type "Error"
    throw
} finally {
    Disconnect-PnPOnline
}