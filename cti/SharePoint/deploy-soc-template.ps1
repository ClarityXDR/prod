<#
.SYNOPSIS
    Deploys ClarityXDR SOC SharePoint Online Template from GitHub
.DESCRIPTION
    Complete deployment script for Security Operations Center SharePoint site
    This version pulls all required files directly from GitHub repository
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
    
    [string]$SentinelWorkspaceId = "",
    
    [string]$GitHubBaseUrl = "https://raw.githubusercontent.com/ClarityXDR/prod/refs/heads/main/cti/SharePoint"
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

# Function to download content from GitHub
function Get-GitHubContent {
    param(
        [string]$RelativePath,
        [string]$Description = "file"
    )
    
    $url = "$GitHubBaseUrl/$RelativePath"
    Write-Log "Downloading $Description from: $url"
    
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing
        return $response.Content
    }
    catch {
        Write-Log "Failed to download $Description from GitHub: $_" -Type "Error"
        throw
    }
}

# Function to download binary file from GitHub
function Get-GitHubBinaryFile {
    param(
        [string]$RelativePath,
        [string]$LocalPath,
        [string]$Description = "file"
    )
    
    $url = "$GitHubBaseUrl/$RelativePath"
    Write-Log "Downloading $Description from: $url"
    
    try {
        Invoke-WebRequest -Uri $url -OutFile $LocalPath -UseBasicParsing
        return $LocalPath
    }
    catch {
        Write-Log "Failed to download $Description from GitHub: $_" -Type "Error"
        throw
    }
}

try {
    Write-Log "Starting ClarityXDR SOC Template Deployment from GitHub"
    
    # Create temporary directory for downloaded files
    $tempDir = Join-Path $env:TEMP "ClarityXDR-SOC-$(Get-Date -Format 'yyyyMMddHHmmss')"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Write-Log "Created temporary directory: $tempDir"
    
    # Connect to SharePoint
    Write-Log "Connecting to SharePoint tenant"
    Connect-PnPOnline -Url $TenantUrl -ClientId $AppId -CertificatePath $CertificatePath
    
    # Download and create site scripts
    Write-Log "Creating site scripts from GitHub"
    
    # Main site script
    $mainScriptContent = Get-GitHubContent -RelativePath "soc-main-script.json" -Description "Main site script"
    $mainScriptId = Add-PnPSiteScript -Title "ClarityXDR SOC Main Script" -Content $mainScriptContent -Description "Main SOC site configuration"
    Write-Log "Created main site script: $mainScriptId"
    
    # Lists script
    $listsScriptContent = Get-GitHubContent -RelativePath "soc-lists-script.json" -Description "Lists script"
    $listsScriptId = Add-PnPSiteScript -Title "ClarityXDR SOC Lists Script" -Content $listsScriptContent -Description "SOC lists and libraries"
    Write-Log "Created lists site script: $listsScriptId"
    
    # Security script
    $securityScriptContent = Get-GitHubContent -RelativePath "SOC-Security-Script.json" -Description "Security script"
    if ($securityScriptContent) {
        $securityScriptId = Add-PnPSiteScript -Title "ClarityXDR SOC Security Script" -Content $securityScriptContent -Description "Security configuration"
        Write-Log "Created security site script: $securityScriptId"
    }
    else {
        Write-Log "Security script not found, using placeholder" -Type "Warning"
        # Create a minimal security script as placeholder
        $securityScriptContent = @'
{
  "$schema": "https://developer.microsoft.com/json-schemas/sp/site-design-script-actions.schema.json",
  "actions": [
    {
      "verb": "setSiteExternalSharingCapability",
      "capability": "Disabled"
    }
  ]
}
'@
        $securityScriptId = Add-PnPSiteScript -Title "ClarityXDR SOC Security Script" -Content $securityScriptContent -Description "Security configuration"
    }
    
    # Navigation script
    $navScriptContent = Get-GitHubContent -RelativePath "SOC-Navigation-Script.json" -Description "Navigation script"
    if ($navScriptContent) {
        $navScriptId = Add-PnPSiteScript -Title "ClarityXDR SOC Navigation Script" -Content $navScriptContent -Description "Site navigation"
        Write-Log "Created navigation site script: $navScriptId"
    }
    else {
        Write-Log "Navigation script not found, continuing without it" -Type "Warning"
        $navScriptId = $null
    }
    
    # Create site design
    Write-Log "Creating site design"
    $scriptIds = @($mainScriptId, $listsScriptId, $securityScriptId) | Where-Object { $_ }
    if ($navScriptId) { $scriptIds += $navScriptId }
    
    $siteDesignId = Add-PnPSiteDesign -Title "ClarityXDR Security Operations Center" `
        -SiteScriptIds $scriptIds `
        -Description "Complete SOC template with security dashboards and automation" `
        -WebTemplate "TeamSite" `
        -PreviewImageUrl "https://clarityxdr.com/images/soc-preview.png"
    
    Write-Log "Created site design: $siteDesignId"
    
    # Grant permissions to SOC team if email exists
    if (Test-Path variable:SOCTeamEmail) {
        Write-Log "Setting site design permissions"
        Grant-PnPSiteDesignRights -Identity $siteDesignId -Principals $SOCTeamEmail -Rights View
    }
    
    # Connect to target site
    Write-Log "Connecting to target site: $SiteUrl"
    Connect-PnPOnline -Url $SiteUrl -ClientId $AppId -CertificatePath $CertificatePath
    
    # Apply site design
    Write-Log "Applying site design to target site"
    $task = Add-PnPSiteDesignTask -SiteDesignId $siteDesignId
    
    # Wait for site design application
    Write-Log "Waiting for site design application to complete..."
    $maxWaitTime = 300 # 5 minutes
    $waitTime = 0
    $checkInterval = 5
    
    do {
        Start-Sleep -Seconds $checkInterval
        $waitTime += $checkInterval
        $status = Get-PnPSiteDesignTask -Identity $task.ID
        Write-Log "Status: $($status.Status) (waited $waitTime seconds)"
    } while ($status.Status -ne "Completed" -and $waitTime -lt $maxWaitTime)
    
    if ($status.Status -ne "Completed") {
        Write-Log "Site design application timed out, continuing..." -Type "Warning"
    }
    
    # Download and apply PnP template if available
    $pnpTemplatePath = Join-Path $tempDir "SOC-Site-Template.pnp"
    try {
        Get-GitHubBinaryFile -RelativePath "../Templates/SOC-Site-Template.pnp" `
                            -LocalPath $pnpTemplatePath `
                            -Description "PnP template"
        
        Write-Log "Applying PnP template"
        Invoke-PnPSiteTemplate -Path $pnpTemplatePath -Parameters @{
            "SOCManager" = $SOCManagerEmail
            "LogicAppUrl" = $LogicAppUrl
            "DefenderWorkspaceId" = $DefenderWorkspaceId
            "SentinelWorkspaceId" = $SentinelWorkspaceId
        }
    }
    catch {
        Write-Log "PnP template not found or failed to apply, continuing..." -Type "Warning"
    }
    
    # Deploy SPFx solutions
    Write-Log "Attempting to deploy SPFx web parts"
    
    # KQL Dashboard web part
    try {
        $kqlPackagePath = Join-Path $tempDir "kql-dashboard.sppkg"
        Get-GitHubBinaryFile -RelativePath "../WebParts/KQLDashboard/sharepoint/solution/kql-dashboard.sppkg" `
                            -LocalPath $kqlPackagePath `
                            -Description "KQL Dashboard package"
        
        Add-PnPApp -Path $kqlPackagePath -Publish -Overwrite
        Write-Log "KQL Dashboard web part deployed"
    }
    catch {
        Write-Log "KQL Dashboard deployment failed or file not found" -Type "Warning"
    }
    
    # MITRE Navigator web part
    try {
        $mitrePackagePath = Join-Path $tempDir "mitre-navigator.sppkg"
        Get-GitHubBinaryFile -RelativePath "../WebParts/MITRENavigator/sharepoint/solution/mitre-navigator.sppkg" `
                            -LocalPath $mitrePackagePath `
                            -Description "MITRE Navigator package"
        
        Add-PnPApp -Path $mitrePackagePath -Publish -Overwrite
        Write-Log "MITRE Navigator web part deployed"
    }
    catch {
        Write-Log "MITRE Navigator deployment failed or file not found" -Type "Warning"
    }
    
    # Configure security settings
    Write-Log "Configuring security settings"
    
    # Set external sharing to disabled
    Set-PnPSite -DisableSharingForNonOwners
    
    # Configure audit settings
    Set-PnPAuditing -EnableAll
    
    # Download and execute KQL import script
    try {
        $kqlImportScript = Get-GitHubContent -RelativePath "Utilities/Import-KQLQueries.ps1" -Description "KQL import script"
        
        # Save script to temp file and execute
        $kqlScriptPath = Join-Path $tempDir "Import-KQLQueries.ps1"
        $kqlImportScript | Out-File -FilePath $kqlScriptPath -Encoding UTF8
        
        Write-Log "Importing default KQL queries"
        & $kqlScriptPath -SiteUrl $SiteUrl
    }
    catch {
        Write-Log "KQL import script not found or failed to execute" -Type "Warning"
    }
    
    # Create sample data structures if lists were created
    Write-Log "Verifying list creation and adding sample data"
    
    try {
        # Add sample incident
        $incidentsList = Get-PnPList -Identity "Security Incidents" -ErrorAction SilentlyContinue
        if ($incidentsList) {
            Add-PnPListItem -List "Security Incidents" -Values @{
                "Title" = "Sample Incident - Deployment Test"
                "IncidentID" = "INC-$(Get-Date -Format 'yyyyMMdd')-001"
                "Severity" = "Low"
                "Status" = "Closed"
            }
            Write-Log "Added sample incident"
        }
    }
    catch {
        Write-Log "Could not add sample data" -Type "Warning"
    }
    
    Write-Log "SOC Template deployment completed successfully!" -Type "Info"
    Write-Log "Site URL: $SiteUrl"
    Write-Log "Please verify the deployment and configure any additional settings as needed."
    
} catch {
    Write-Log "Error during deployment: $_" -Type "Error"
    throw
} finally {
    # Cleanup
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "Cleaned up temporary files"
    }
    
    Disconnect-PnPOnline
}