<#
.SYNOPSIS
    Configures security settings for SOC SharePoint site
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$SiteUrl,
    
    [Parameter(Mandatory=$true)]
    [string]$AppId,
    
    [Parameter(Mandatory=$true)]
    [string]$CertificatePath
)

Connect-PnPOnline -Url $SiteUrl -ClientId $AppId -CertificatePath $CertificatePath

# Configure Information Barriers
Write-Host "Configuring Information Barriers"
$segments = @(
    @{Name="SOC-Analysts"; GroupId="00000000-0000-0000-0000-000000000001"},
    @{Name="SOC-Managers"; GroupId="00000000-0000-0000-0000-000000000002"},
    @{Name="Incident-Response"; GroupId="00000000-0000-0000-0000-000000000003"}
)

# Configure Sensitivity Labels
Write-Host "Applying Sensitivity Labels"
Set-PnPTenantSite -Url $SiteUrl -SensitivityLabel "Confidential - SOC Operations"

# Configure DLP Policies
Write-Host "Configuring DLP Policies"
$dlpPolicy = @{
    "Name" = "SOC Data Protection"
    "Rules" = @(
        @{
            "Name" = "Block External Sharing of IOCs"
            "Conditions" = @("Content contains threat indicators")
            "Actions" = @("Block external sharing")
        }
    )
}

# Configure Retention Policies
Write-Host "Setting Retention Policies"
Set-PnPListItemAsRecord -List "Security Incidents" -Identity * -DeclarationDate (Get-Date)

# Configure Audit Settings
Write-Host "Enabling Comprehensive Auditing"
Set-PnPAuditing -EnableAll -RetentionTime 365

Write-Host "Security configuration completed"