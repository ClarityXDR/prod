#Requires -Version 5.1
#Requires -Modules Az.Accounts, Az.Resources

<#
.SYNOPSIS
    One-click deployment script for ClarityXDR platform
.DESCRIPTION
    This script provides a complete automated deployment of the ClarityXDR platform including:
    - Resource group creation
    - Azure Resource Manager template deployment
    - Post-deployment configuration
    - Validation and health checks
.PARAMETER DeploymentPrefix
    Prefix for all resource names (3-10 characters)
.PARAMETER Location
    Azure region for deployment
.PARAMETER AdminEmail
    Administrator email for notifications
.PARAMETER OrganizationName
    Organization name for metadata
.PARAMETER SkipPostConfig
    Skip post-deployment configuration
.PARAMETER SkipValidation
    Skip deployment validation
.EXAMPLE
    .\deploy-clarityxdr.ps1 -DeploymentPrefix "ClarityXDR" -Location "eastus" -AdminEmail "admin@contoso.com" -OrganizationName "Contoso Ltd"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [ValidatePattern('^[a-zA-Z0-9]{3,10}$')]
    [string]$DeploymentPrefix,
    
    [Parameter(Mandatory=$true)]
    [string]$Location,
    
    [Parameter(Mandatory=$true)]
    [ValidatePattern('^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')]
    [string]$AdminEmail,
    
    [Parameter(Mandatory=$true)]
    [string]$OrganizationName,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipPostConfig,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipValidation,
    
    [Parameter(Mandatory=$false)]
    [switch]$EnableDefenderEASM,
    
    [Parameter(Mandatory=$false)]
    [string]$ExchangeServiceAccount = "",
    
    [Parameter(Mandatory=$false)]
    [securestring]$ExchangePassword,
    
    [Parameter(Mandatory=$false)]
    [securestring]$VirusTotalApiKey
)

# Script configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Deployment variables
$ResourceGroupName = "$DeploymentPrefix-RG"
$WorkspaceName = "$DeploymentPrefix-Workspace"
$ScriptPath = $PSScriptRoot
$TemplateFile = Join-Path $ScriptPath "azuredeploy.json"
$ParametersFile = Join-Path $ScriptPath "azuredeploy.parameters.json"

# Deployment tracking
$DeploymentResults = @{
    StartTime = Get-Date
    DeploymentPrefix = $DeploymentPrefix
    Location = $Location
    ResourceGroup = $ResourceGroupName
    Workspace = $WorkspaceName
    Steps = @{}
    Errors = @()
    Success = $false
}

function Write-DeploymentStep {
    param(
        [string]$Step,
        [string]$Status,
        [string]$Message,
        [string]$Details = ""
    )
    
    $Icon = switch ($Status) {
        "Success" { "✅" }
        "Warning" { "⚠️" }
        "Error" { "❌" }
        "Info" { "ℹ️" }
        "Progress" { "🔄" }
        default { "📋" }
    }
    
    $Color = switch ($Status) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        "Info" { "Cyan" }
        "Progress" { "Blue" }
        default { "White" }
    }
    
    Write-Host "$Icon $Step`: $Message" -ForegroundColor $Color
    if ($Details) {
        Write-Host "   $Details" -ForegroundColor Gray
    }
    
    # Store result
    $DeploymentResults.Steps[$Step] = @{
        Status = $Status
        Message = $Message
        Details = $Details
        Timestamp = Get-Date
    }
    
    if ($Status -eq "Error") {
        $DeploymentResults.Errors += "$Step`: $Message"
    }
}

function Test-Prerequisites {
    Write-Host "`n🔍 Checking Prerequisites..." -ForegroundColor Yellow
    
    # Check PowerShell version
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        Write-DeploymentStep "PowerShell Version" "Error" "PowerShell 5.1 or higher required. Current: $($PSVersionTable.PSVersion)"
        return $false
    }
    Write-DeploymentStep "PowerShell Version" "Success" "Version $($PSVersionTable.PSVersion) ✓"
    
    # Check required modules
    $RequiredModules = @("Az.Accounts", "Az.Resources")
    foreach ($Module in $RequiredModules) {
        if (Get-Module -ListAvailable -Name $Module) {
            Write-DeploymentStep "Module $Module" "Success" "Available ✓"
        }
        else {
            Write-DeploymentStep "Module $Module" "Progress" "Installing..."
            try {
                Install-Module -Name $Module -Force -Scope CurrentUser -AllowClobber
                Write-DeploymentStep "Module $Module" "Success" "Installed ✓"
            }
            catch {
                Write-DeploymentStep "Module $Module" "Error" "Failed to install: $($_.Exception.Message)"
                return $false
            }
        }
    }
    
    # Check template files
    if (!(Test-Path $TemplateFile)) {
        Write-DeploymentStep "Template File" "Error" "Template file not found: $TemplateFile"
        return $false
    }
    Write-DeploymentStep "Template File" "Success" "Found ✓"
    
    # Validate Azure location
    try {
        $AvailableLocations = Get-AzLocation
        if ($AvailableLocations.Location -contains $Location) {
            Write-DeploymentStep "Azure Location" "Success" "$Location is valid ✓"
        }
        else {
            Write-DeploymentStep "Azure Location" "Error" "$Location is not a valid Azure region"
            return $false
        }
    }
    catch {
        Write-DeploymentStep "Azure Location" "Warning" "Could not validate location (continuing anyway)"
    }
    
    return $true
}

function Connect-ToAzure {
    Write-Host "`n🔐 Connecting to Azure..." -ForegroundColor Yellow
    
    try {
        $Context = Get-AzContext
        if (!$Context) {
            Write-DeploymentStep "Azure Connection" "Progress" "Connecting to Azure..."
            Connect-AzAccount
            $Context = Get-AzContext
        }
        
        Write-DeploymentStep "Azure Connection" "Success" "Connected as: $($Context.Account.Id)"
        Write-DeploymentStep "Subscription" "Info" "$($Context.Subscription.Name) ($($Context.Subscription.Id))"
        
        return $true
    }
    catch {
        Write-DeploymentStep "Azure Connection" "Error" "Failed to connect: $($_.Exception.Message)"
        return $false
    }
}

function New-ResourceGroupIfNeeded {
    Write-Host "`n🏗️ Setting up Resource Group..." -ForegroundColor Yellow
    
    try {
        $RG = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
        if ($RG) {
            Write-DeploymentStep "Resource Group" "Info" "Already exists: $ResourceGroupName"
        }
        else {
            Write-DeploymentStep "Resource Group" "Progress" "Creating: $ResourceGroupName"
            $RG = New-AzResourceGroup -Name $ResourceGroupName -Location $Location
            Write-DeploymentStep "Resource Group" "Success" "Created: $($RG.ResourceGroupName)"
        }
        
        return $true
    }
    catch {
        Write-DeploymentStep "Resource Group" "Error" "Failed to create: $($_.Exception.Message)"
        return $false
    }
}

function New-ParametersFile {
    Write-Host "`n📄 Preparing deployment parameters..." -ForegroundColor Yellow
    
    try {
        # Create parameters object
        $Parameters = @{
            deploymentPrefix = @{ value = $DeploymentPrefix }
            location = @{ value = $Location }
            organizationName = @{ value = $OrganizationName }
            pricingTier = @{ value = "PerGB2018" }
            capacityReservation = @{ value = 100 }
            dataRetentionDays = @{ value = 90 }
            enableMicrosoftDefender = @{ value = $true }
            enableEntraID = @{ value = $true }
            enableOffice365 = @{ value = $true }
            enableThreatIntelligence = @{ value = $true }
            enableDefenderEASM = @{ value = $EnableDefenderEASM.IsPresent }
            enableCostOptimization = @{ value = $true }
            severityLevels = @{ value = @("High", "Medium", "Low") }
            enableSolutionsEssentials = @{ value = @("Microsoft Entra ID", "Microsoft Defender for Endpoint", "Microsoft Defender for Office 365", "Threat Intelligence") }
            enableAutomationAccount = @{ value = $true }
            exchangeCredentialUsername = @{ value = $ExchangeServiceAccount }
        }
        
        # Add secure parameters if provided
        if ($ExchangePassword) {
            $Parameters.exchangeCredentialPassword = @{ value = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ExchangePassword)) }
        }
        else {
            $Parameters.exchangeCredentialPassword = @{ value = "" }
        }
        
        if ($VirusTotalApiKey) {
            $Parameters.virusTotalApiKey = @{ value = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($VirusTotalApiKey)) }
        }
        else {
            $Parameters.virusTotalApiKey = @{ value = "" }
        }
        
        # Create parameters file
        $ParametersObj = @{
            '$schema' = "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#"
            contentVersion = "1.0.0.0"
            parameters = $Parameters
        }
        
        $TempParametersFile = Join-Path $env:TEMP "clarityxdr-parameters-$(Get-Date -Format 'yyyyMMddHHmmss').json"
        $ParametersObj | ConvertTo-Json -Depth 10 | Out-File -FilePath $TempParametersFile -Encoding UTF8
        
        Write-DeploymentStep "Parameters File" "Success" "Created temporary parameters file"
        
        return $TempParametersFile
    }
    catch {
        Write-DeploymentStep "Parameters File" "Error" "Failed to create parameters: $($_.Exception.Message)"
        return $null
    }
}

function Start-AzureDeployment {
    param([string]$ParametersFilePath)
    
    Write-Host "`n🚀 Starting Azure Deployment..." -ForegroundColor Yellow
    Write-Host "This may take 15-30 minutes..." -ForegroundColor Cyan
    
    try {
        $DeploymentName = "ClarityXDR-Deployment-$(Get-Date -Format 'yyyyMMddHHmmss')"
        
        Write-DeploymentStep "Template Deployment" "Progress" "Starting deployment: $DeploymentName"
        
        $Deployment = New-AzResourceGroupDeployment `
            -ResourceGroupName $ResourceGroupName `
            -Name $DeploymentName `
            -TemplateFile $TemplateFile `
            -TemplateParameterFile $ParametersFilePath `
            -Verbose
        
        if ($Deployment.ProvisioningState -eq "Succeeded") {
            Write-DeploymentStep "Template Deployment" "Success" "Deployment completed successfully"
            
            # Display outputs
            if ($Deployment.Outputs) {
                Write-Host "`n📊 Deployment Outputs:" -ForegroundColor Cyan
                foreach ($Output in $Deployment.Outputs.GetEnumerator()) {
                    Write-Host "   $($Output.Key): $($Output.Value.Value)" -ForegroundColor White
                }
            }
            
            return $Deployment
        }
        else {
            Write-DeploymentStep "Template Deployment" "Error" "Deployment failed with state: $($Deployment.ProvisioningState)"
            return $null
        }
    }
    catch {
        Write-DeploymentStep "Template Deployment" "Error" "Deployment failed: $($_.Exception.Message)"
        return $null
    }
    finally {
        # Clean up temporary parameters file
        if ($ParametersFilePath -and (Test-Path $ParametersFilePath)) {
            Remove-Item $ParametersFilePath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Invoke-PostDeploymentConfig {
    if ($SkipPostConfig) {
        Write-DeploymentStep "Post-Deployment Config" "Info" "Skipped by user request"
        return $true
    }
    
    Write-Host "`n⚙️ Running Post-Deployment Configuration..." -ForegroundColor Yellow
    
    try {
        $PostConfigScript = Join-Path $ScriptPath "scripts\post-deployment-config.ps1"
        if (Test-Path $PostConfigScript) {
            Write-DeploymentStep "Post-Config Script" "Progress" "Executing post-deployment configuration..."
            
            & $PostConfigScript -ResourceGroup $ResourceGroupName -WorkspaceName $WorkspaceName -Location $Location
            
            Write-DeploymentStep "Post-Config Script" "Success" "Post-deployment configuration completed"
            return $true
        }
        else {
            Write-DeploymentStep "Post-Config Script" "Warning" "Post-deployment script not found: $PostConfigScript"
            return $false
        }
    }
    catch {
        Write-DeploymentStep "Post-Config Script" "Error" "Post-deployment configuration failed: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-DeploymentValidation {
    if ($SkipValidation) {
        Write-DeploymentStep "Deployment Validation" "Info" "Skipped by user request"
        return $true
    }
    
    Write-Host "`n🔍 Validating Deployment..." -ForegroundColor Yellow
    
    try {
        $ValidationScript = Join-Path $ScriptPath "scripts\validate-deployment.ps1"
        if (Test-Path $ValidationScript) {
            Write-DeploymentStep "Validation Script" "Progress" "Running deployment validation..."
            
            & $ValidationScript -ResourceGroup $ResourceGroupName -WorkspaceName $WorkspaceName -GenerateReport
            
            Write-DeploymentStep "Validation Script" "Success" "Deployment validation completed"
            return $true
        }
        else {
            Write-DeploymentStep "Validation Script" "Warning" "Validation script not found: $ValidationScript"
            return $false
        }
    }
    catch {
        Write-DeploymentStep "Validation Script" "Error" "Deployment validation failed: $($_.Exception.Message)"
        return $false
    }
}

function Show-DeploymentSummary {
    param($Deployment)
    
    $DeploymentResults.EndTime = Get-Date
    $DeploymentResults.Duration = $DeploymentResults.EndTime - $DeploymentResults.StartTime
    
    Write-Host "`n🎉 ClarityXDR Deployment Summary" -ForegroundColor Green
    Write-Host "=================================" -ForegroundColor Green
    
    Write-Host "📊 Deployment Details:" -ForegroundColor Yellow
    Write-Host "   Prefix: $DeploymentPrefix" -ForegroundColor White
    Write-Host "   Location: $Location" -ForegroundColor White
    Write-Host "   Resource Group: $ResourceGroupName" -ForegroundColor White
    Write-Host "   Workspace: $WorkspaceName" -ForegroundColor White
    Write-Host "   Duration: $($DeploymentResults.Duration.ToString('hh\:mm\:ss'))" -ForegroundColor White
    
    if ($Deployment -and $Deployment.Outputs.resourceLinks) {
        Write-Host "`n🔗 Quick Links:" -ForegroundColor Yellow
        $Links = $Deployment.Outputs.resourceLinks.Value
        Write-Host "   Microsoft Sentinel: $($Links.sentinelWorkspace)" -ForegroundColor Cyan
        Write-Host "   Key Vault: $($Links.keyVault)" -ForegroundColor Cyan
        Write-Host "   Cost Dashboard: $($Links.costOptimization)" -ForegroundColor Cyan
        if ($Links.automationAccount) {
            Write-Host "   Automation: $($Links.automationAccount)" -ForegroundColor Cyan
        }
    }
    
    Write-Host "`n📋 Next Steps:" -ForegroundColor Yellow
    Write-Host "   1. ✅ Review detection rules in Microsoft Sentinel" -ForegroundColor White
    Write-Host "   2. 🔌 Configure additional data connectors as needed" -ForegroundColor White
    Write-Host "   3. ⚡ Set up Logic Apps API connections" -ForegroundColor White
    Write-Host "   4. 🧪 Test automation workflows" -ForegroundColor White
    Write-Host "   5. 📊 Monitor costs and optimize as needed" -ForegroundColor White
    
    Write-Host "`n📚 Resources:" -ForegroundColor Yellow
    Write-Host "   📖 Documentation: docs/" -ForegroundColor Cyan
    Write-Host "   🐛 Issues: https://github.com/ClarityXDR/ClarityXDR/issues" -ForegroundColor Cyan
    Write-Host "   💬 Community: https://discord.gg/clarityxdr" -ForegroundColor Cyan
    
    if ($DeploymentResults.Errors.Count -eq 0) {
        $DeploymentResults.Success = $true
        Write-Host "`n✨ Deployment completed successfully! ✨" -ForegroundColor Green
    }
    else {
        Write-Host "`n⚠️ Deployment completed with some issues:" -ForegroundColor Yellow
        foreach ($Error in $DeploymentResults.Errors) {
            Write-Host "   • $Error" -ForegroundColor Red
        }
    }
}

# Main execution
Write-Host "🚀 ClarityXDR One-Click Deployment" -ForegroundColor Green
Write-Host "===================================" -ForegroundColor Green
Write-Host "Organization: $OrganizationName" -ForegroundColor Cyan
Write-Host "Deployment Prefix: $DeploymentPrefix" -ForegroundColor Cyan
Write-Host "Location: $Location" -ForegroundColor Cyan
Write-Host "Admin Email: $AdminEmail" -ForegroundColor Cyan

# Step 1: Prerequisites
if (!(Test-Prerequisites)) {
    Write-Error "Prerequisites check failed. Please resolve issues and try again."
    exit 1
}

# Step 2: Azure Connection
if (!(Connect-ToAzure)) {
    Write-Error "Failed to connect to Azure. Please check your credentials and try again."
    exit 1
}

# Step 3: Resource Group
if (!(New-ResourceGroupIfNeeded)) {
    Write-Error "Failed to create or access resource group. Please check permissions."
    exit 1
}

# Step 4: Parameters
$ParametersFile = New-ParametersFile
if (!$ParametersFile) {
    Write-Error "Failed to create deployment parameters."
    exit 1
}

# Step 5: Azure Deployment
$Deployment = Start-AzureDeployment -ParametersFilePath $ParametersFile
if (!$Deployment) {
    Write-Error "Azure deployment failed. Check the Azure portal for details."
    exit 1
}

# Step 6: Post-Deployment Configuration
Invoke-PostDeploymentConfig | Out-Null

# Step 7: Validation
Invoke-DeploymentValidation | Out-Null

# Step 8: Summary
Show-DeploymentSummary -Deployment $Deployment

# Return deployment results for programmatic use
return $DeploymentResults
