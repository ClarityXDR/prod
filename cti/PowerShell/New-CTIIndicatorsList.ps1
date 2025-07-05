<#
.SYNOPSIS
    Creates a new SharePoint list for threat intelligence indicators
.DESCRIPTION
    This script creates a new SharePoint list with all the required columns
    for the CTI management solution
.PARAMETER SiteUrl
    URL of the SharePoint site where the list should be created
.PARAMETER ListName
    Name for the new list (default: ThreatIndicatorsList)
.EXAMPLE
    .\New-CTIIndicatorsList.ps1 -SiteUrl "https://contoso.sharepoint.com/sites/ThreatIntel"
.NOTES
    Requires PnP.PowerShell module and appropriate permissions to the SharePoint site
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SiteUrl,
    
    [Parameter(Mandatory = $false)]
    [string]$ListName = "ThreatIndicatorsList"
)

# Import required modules
Import-Module PnP.PowerShell -ErrorAction Stop

# Connect to SharePoint
try {
    Write-Host "Connecting to SharePoint..." -ForegroundColor Yellow
    Connect-PnPOnline -Url $SiteUrl -Interactive -ErrorAction Stop
    Write-Host "Connected to SharePoint successfully" -ForegroundColor Green
} catch {
    Write-Error "Failed to connect to SharePoint: $_"
    exit 1
}

# Check if list already exists
$existingList = Get-PnPList -Identity $ListName -ErrorAction SilentlyContinue
if ($existingList) {
    Write-Warning "A list with the name '$ListName' already exists. Please choose a different name or remove the existing list."
    exit 1
}

# Create the list
try {
    Write-Host "Creating new list '$ListName'..." -ForegroundColor Yellow
    $list = New-PnPList -Title $ListName -Template GenericList -EnableVersioning
    
    # Add required columns
    Write-Host "Adding columns to the list..." -ForegroundColor Yellow
    
    # Text fields
    Add-PnPField -List $ListName -DisplayName "Indicator ID" -InternalName "IndicatorId" -Type Text -AddToDefaultView
    Add-PnPField -List $ListName -DisplayName "Indicator Value" -InternalName "IndicatorValue" -Type Text -AddToDefaultView
    Add-PnPField -List $ListName -DisplayName "Source" -InternalName "Source" -Type Text -AddToDefaultView
    Add-PnPField -List $ListName -DisplayName "Reputation Source" -InternalName "ReputationSource" -Type Text
    Add-PnPField -List $ListName -DisplayName "Tags" -InternalName "Tags" -Type Text
    
    # Choice fields
    $indicatorTypeField = Add-PnPField -List $ListName -DisplayName "Indicator Type" -InternalName "IndicatorType" -Type Choice -AddToDefaultView
    Set-PnPField -List $ListName -Identity $indicatorTypeField -Values @{
        Choices = "FileHash","IPAddress","URL","Domain","Certificate","Email"
    }
    
    $tlpField = Add-PnPField -List $ListName -DisplayName "TLP" -InternalName "TLP" -Type Choice -AddToDefaultView
    Set-PnPField -List $ListName -Identity $tlpField -Values @{
        Choices = "White","Green","Amber","Red"
    }
    
    $severityField = Add-PnPField -List $ListName -DisplayName "Severity" -InternalName "Severity" -Type Choice -AddToDefaultView
    Set-PnPField -List $ListName -Identity $severityField -Values @{
        Choices = "Low","Medium","High","Critical"
    }
    
    $validationStatusField = Add-PnPField -List $ListName -DisplayName "Validation Status" -InternalName "ValidationStatus" -Type Choice -AddToDefaultView
    Set-PnPField -List $ListName -Identity $validationStatusField -Values @{
        Choices = "Pending","Valid","Invalid","Expired","FalsePositive"
    }
    
    # Multi-choice fields
    $deploymentTargetsField = Add-PnPFieldFromXml -List $ListName -FieldXml "<Field Type='MultiChoice' DisplayName='Deployment Targets' ID='$(New-Guid)' StaticName='DeploymentTargets' Name='DeploymentTargets'><CHOICES><CHOICE>MDE</CHOICE><CHOICE>EntraID</CHOICE><CHOICE>MDCA</CHOICE><CHOICE>ExchangeEOP</CHOICE><CHOICE>ExchangeTABL</CHOICE><CHOICE>AzureFirewall</CHOICE><CHOICE>AzurePolicy</CHOICE><CHOICE>AzureFrontDoor</CHOICE><CHOICE>OnPremFirewall</CHOICE><CHOICE>OnPremProxy</CHOICE><CHOICE>ThirdParty</CHOICE></CHOICES></Field>"
    
    # Number fields
    Add-PnPField -List $ListName -DisplayName "Confidence" -InternalName "Confidence" -Type Number -AddToDefaultView
    Add-PnPField -List $ListName -DisplayName "Reputation Score" -InternalName "ReputationScore" -Type Number
    
    # Date fields
    Add-PnPField -List $ListName -DisplayName "Valid From" -InternalName "ValidFrom" -Type DateTime -AddToDefaultView
    Add-PnPField -List $ListName -DisplayName "Valid Until" -InternalName "ValidUntil" -Type DateTime -AddToDefaultView
    Add-PnPField -List $ListName -DisplayName "Last Validated" -InternalName "LastValidated" -Type DateTime
    Add-PnPField -List $ListName -DisplayName "Last Deployment Attempt" -InternalName "LastDeploymentAttempt" -Type DateTime
    Add-PnPField -List $ListName -DisplayName "Last Deployment Success" -InternalName "LastDeploymentSuccess" -Type DateTime
    
    # Note fields
    Add-PnPField -List $ListName -DisplayName "Description" -InternalName "Description" -Type Note
    Add-PnPField -List $ListName -DisplayName "Action History" -InternalName "ActionHistory" -Type Note
    Add-PnPField -List $ListName -DisplayName "Comments" -InternalName "Comments" -Type Note
    
    # Multi-line text for JSON fields
    Add-PnPField -List $ListName -DisplayName "Deployment Status" -InternalName "DeploymentStatus" -Type Note
    
    # Create views
    Write-Host "Creating list views..." -ForegroundColor Yellow
    
    # All Indicators View
    Add-PnPView -List $ListName -Title "All Indicators" -Fields "Title","IndicatorType","IndicatorValue","Severity","Confidence","TLP","ValidUntil","ValidationStatus" -SetAsDefault
    
    # Deployment Status View
    Add-PnPView -List $ListName -Title "Deployment Status" -Fields "Title","IndicatorType","IndicatorValue","DeploymentTargets","LastDeploymentAttempt","LastDeploymentSuccess"
    
    # Validation Status View
    Add-PnPView -List $ListName -Title "Validation Status" -Fields "Title","IndicatorType","IndicatorValue","ValidationStatus","ReputationScore","ReputationSource","LastValidated"
    
    # Expiring Soon View (with filter)
    $view = Add-PnPView -List $ListName -Title "Expiring Soon" -Fields "Title","IndicatorType","IndicatorValue","Severity","ValidUntil","ValidationStatus"
    $viewXml = Get-PnPView -List $ListName -Identity $view.Id -Includes SchemaXml
    $schemaXml = [xml]$viewXml.SchemaXml
    $query = $schemaXml.View.Query
    
    $whereNode = $schemaXml.CreateElement("Where")
    $andNode = $schemaXml.CreateElement("And")
    
    $leqNode = $schemaXml.CreateElement("Leq")
    $fieldRefNode1 = $schemaXml.CreateElement("FieldRef")
    $fieldRefNode1.SetAttribute("Name", "ValidUntil")
    $valueNode1 = $schemaXml.CreateElement("Value")
    $valueNode1.SetAttribute("Type", "DateTime")
    $valueNode1.InnerText = "<Today OffsetDays='30' />"
    $leqNode.AppendChild($fieldRefNode1)
    $leqNode.AppendChild($valueNode1)
    
    $neqNode = $schemaXml.CreateElement("Neq")
    $fieldRefNode2 = $schemaXml.CreateElement("FieldRef")
    $fieldRefNode2.SetAttribute("Name", "ValidationStatus")
    $valueNode2 = $schemaXml.CreateElement("Value")
    $valueNode2.SetAttribute("Type", "Text")
    $valueNode2.InnerText = "Expired"
    $neqNode.AppendChild($fieldRefNode2)
    $neqNode.AppendChild($valueNode2)
    
    $andNode.AppendChild($leqNode)
    $andNode.AppendChild($neqNode)
    $whereNode.AppendChild($andNode)
    $query.AppendChild($whereNode)
    
    $schemaXml.View.Query = $query
    Set-PnPView -List $ListName -Identity $view.Id -Values @{SchemaXml = $schemaXml.OuterXml}
    
    # Indexed fields for performance
    Set-PnPField -List $ListName -Identity "IndicatorId" -Values @{Indexed = $true}
    Set-PnPField -List $ListName -Identity "IndicatorValue" -Values @{Indexed = $true}
    Set-PnPField -List $ListName -Identity "IndicatorType" -Values @{Indexed = $true}
    
    Write-Host "List creation completed successfully!" -ForegroundColor Green
    Write-Host "SharePoint list URL: $($SiteUrl)/Lists/$($ListName)" -ForegroundColor Cyan
    
    # Save configuration
    $configPath = Join-Path $PSScriptRoot "CTI-Config.json"
    if (Test-Path $configPath) {
        $config = Get-Content $configPath | ConvertFrom-Json
        $config.SharePointSiteUrl = $SiteUrl
        $config.IndicatorsListName = $ListName
        $config | ConvertTo-Json -Depth 10 | Set-Content $configPath
        Write-Host "Updated configuration file with new list details" -ForegroundColor Green
    } else {
        $config = @{
            SharePointSiteUrl = $SiteUrl
            IndicatorsListName = $ListName
        }
        $config | ConvertTo-Json -Depth 10 | Set-Content $configPath
        Write-Host "Created new configuration file with list details" -ForegroundColor Green
    }
    
    return $list
} catch {
    Write-Error "Failed to create list: $_"
    exit 1
} finally {
    # Disconnect from SharePoint
    Disconnect-PnPOnline
}
