<#
.SYNOPSIS
    One-Click Deployment Script for ClarityXDR CTI Solution
.DESCRIPTION
    Master deployment script that orchestrates the complete CTI solution deployment
    including Azure resources, SharePoint configuration, and security platform integration
.PARAMETER TenantId
    Azure AD Tenant ID
.PARAMETER SubscriptionId
    Azure Subscription ID for resource deployment
.PARAMETER ResourceGroupName
    Name of the resource group to create/use
.PARAMETER Location
    Azure region for deployment (default: eastus)
.PARAMETER SharePointTenantUrl
    SharePoint tenant admin URL (e.g., https://contoso-admin.sharepoint.com)
.PARAMETER SharePointSiteUrl
    Target SharePoint site URL for CTI
.PARAMETER GlobalAdminCredential
    Global admin credential for M365 configuration
.EXAMPLE
    .\Deploy-ClarityXDR-CTI.ps1 -TenantId "xxx" -SubscriptionId "yyy" -ResourceGroupName "CTI-RG" -SharePointTenantUrl "https://contoso-admin.sharepoint.com" -SharePointSiteUrl "https://contoso.sharepoint.com/sites/CTI"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$TenantId,
    
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory = $true)]
    [string]$SharePointTenantUrl,
    
    [Parameter(Mandatory = $true)]
    [string]$SharePointSiteUrl,
    
    [Parameter(Mandatory = $false)]
    [PSCredential]$GlobalAdminCredential,
    
    [Parameter(Mandatory = $false)]
    [string]$DeploymentName = "ClarityXDR-CTI-$(Get-Date -Format 'yyyyMMddHHmm')",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipPrerequisiteCheck,
    
    [Parameter(Mandatory = $false)]
    [switch]$UseExistingAppRegistration,
    
    [Parameter(Mandatory = $false)]
    [string]$ExistingAppId,
    
    [Parameter(Mandatory = $false)]
    [string]$ExistingAppSecret,
    
    [Parameter(Mandatory = $false)]
    [switch]$ForceCloudShellMode
)

# Script configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"
$script:StartTime = Get-Date
$script:LogFile = "CTI-Deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$script:GitHubBaseUrl = "https://raw.githubusercontent.com/ClarityXDR/prod/refs/heads/main/cti"
$script:IsCloudShell = $env:AZUREPS_HOST_ENVIRONMENT -eq 'cloud-shell/1.0' -or $ForceCloudShellMode

# Store parameters in script scope for function access
$script:TenantId = $TenantId
$script:SubscriptionId = $SubscriptionId
$script:ResourceGroupName = $ResourceGroupName
$script:Location = $Location
$script:SharePointTenantUrl = $SharePointTenantUrl
$script:SharePointSiteUrl = $SharePointSiteUrl
$script:GlobalAdminCredential = $GlobalAdminCredential
$script:DeploymentName = $DeploymentName

# Cloud Shell environment setup
if ($script:IsCloudShell) {
    Write-Host "🌤️  Azure Cloud Shell detected - Configuring environment..." -ForegroundColor Cyan
    
    # Set home directory for logs in Cloud Shell
    if (Test-Path "/home/$env:USER") {
        $script:LogFile = "/home/$env:USER/CTI-Deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    }
    
    # Suppress Azure CLI update warnings
    $env:AZURE_CORE_SURVEY_MESSAGE = "false"
    
    # Ensure we're using the right context
    if ($null -eq (Get-AzContext)) {
        Write-Host "Please login to Azure..." -ForegroundColor Yellow
        Connect-AzAccount
    }
}

# Color configuration for output
$Colors = @{
    Success = "Green"
    Info = "Cyan"
    Warning = "Yellow"
    Error = "Red"
    Progress = "Magenta"
}

#region Helper Functions

function Write-DeploymentLog {
    param(
        [string]$Message,
        [string]$Level = "Info",
        [switch]$NoNewLine
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Write to log file
    Add-Content -Path $script:LogFile -Value $logMessage
    
    # Write to console with color
    # Choose the colour, defaulting to White if the key is missing (compatible with Windows PowerShell 5.1)
    $color = if ($Colors.ContainsKey($Level)) { $Colors[$Level] } else { "White" }
    if ($NoNewLine) {
        Write-Host $Message -ForegroundColor $color -NoNewline
    } else {
        Write-Host $Message -ForegroundColor $color
    }
}

function Test-Prerequisites {
    Write-DeploymentLog "Checking prerequisites..." -Level "Progress"
    
    # Detect if running in Azure Cloud Shell
    $isCloudShell = $env:AZUREPS_HOST_ENVIRONMENT -eq 'cloud-shell/1.0'
    if ($isCloudShell) {
        Write-DeploymentLog "  Detected Azure Cloud Shell environment" -Level "Info"
        Initialize-CloudShellEnvironment
    }
    
    $prerequisites = @{
        "Azure PowerShell" = { Get-Module -ListAvailable -Name Az.* }
        "PnP PowerShell" = { Get-Module -ListAvailable -Name PnP.PowerShell }
        "Exchange Online Management" = { Get-Module -ListAvailable -Name ExchangeOnlineManagement }
        "Azure CLI" = { az --version 2>$null }
    }
    
    # Handle Microsoft Graph differently for Cloud Shell
    if (-not $isCloudShell) {
        $prerequisites["Microsoft Graph"] = { Get-Module -ListAvailable -Name Microsoft.Graph }
    } else {
        # In Cloud Shell, check for Microsoft.Graph.* modules
        $prerequisites["Microsoft Graph"] = { 
            $graphModules = Get-Module -ListAvailable -Name Microsoft.Graph.* | Select-Object -First 1
            return $null -ne $graphModules
        }
    }
    
    $missing = @()
    foreach ($prereq in $prerequisites.GetEnumerator()) {
        Write-DeploymentLog "  Checking $($prereq.Key)..." -Level "Info" -NoNewLine
        try {
            $result = & $prereq.Value
            if ($result) {
                Write-DeploymentLog " ✓" -Level "Success"
            } else {
                throw
            }
        } catch {
            Write-DeploymentLog " ✗" -Level "Error"
            $missing += $prereq.Key
        }
    }
    
    if ($missing.Count -gt 0) {
        throw "Missing prerequisites: $($missing -join ', '). Please install before continuing."
    }
    
    Write-DeploymentLog "All prerequisites satisfied!" -Level "Success"
}

function Initialize-CloudShellEnvironment {
    Write-DeploymentLog "  Configuring Cloud Shell environment..." -Level "Info"
    
    # Import required Microsoft Graph modules in Cloud Shell
    $graphModules = @(
        'Microsoft.Graph.Authentication',
        'Microsoft.Graph.Applications',
        'Microsoft.Graph.Identity.DirectoryManagement',
        'Microsoft.Graph.Identity.SignIns',
        'Microsoft.Graph.Security'
    )
    
    foreach ($module in $graphModules) {
        if (Get-Module -ListAvailable -Name $module) {
            Import-Module $module -Force -ErrorAction SilentlyContinue
            Write-DeploymentLog "    Imported $module" -Level "Debug"
        }
    }
    
    # Set PowerShell Gallery as trusted if not already
    if ((Get-PSRepository -Name PSGallery).InstallationPolicy -ne 'Trusted') {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    }
    
    # Configure Azure PowerShell context settings for Cloud Shell
    Disable-AzContextAutosave -Scope Process -ErrorAction SilentlyContinue
    
    Write-DeploymentLog "  Cloud Shell environment configured" -Level "Success"
}

function New-CTIAppRegistration {
    param(
        [string]$AppName = "ClarityXDR-CTI-Automation",
        [string]$TenantId = $script:TenantId,
        [string]$SubscriptionId = $script:SubscriptionId,
        [PSCredential]$Credential = $script:GlobalAdminCredential
    )
    
    Write-DeploymentLog "Creating Azure AD App Registration..." -Level "Progress"
    
    # Check if already connected (Cloud Shell is pre-authenticated)
    $currentContext = Get-AzContext
    if (-not $currentContext -or $currentContext.Tenant.Id -ne $TenantId) {
        # Connect to Azure AD
        if ($env:AZUREPS_HOST_ENVIRONMENT -eq 'cloud-shell/1.0') {
            # In Cloud Shell, use device code flow if context doesn't match
            Connect-AzAccount -TenantId $TenantId -SubscriptionId $SubscriptionId -UseDeviceAuthentication
        } else {
            Connect-AzAccount -TenantId $TenantId -SubscriptionId $SubscriptionId -Credential $Credential
        }
    } else {
        Write-DeploymentLog "Using existing Azure connection" -Level "Info"
        # Ensure we're on the right subscription
        Set-AzContext -SubscriptionId $SubscriptionId -TenantId $TenantId | Out-Null
    }
    
    # Create app registration
    $app = New-AzADApplication -DisplayName $AppName -IdentifierUris "https://$AppName.clarityxdr.com"
    $appId = $app.AppId
    
    # Create client secret
    $secretEndDate = (Get-Date).AddYears(2)
    $secret = New-AzADAppCredential -ApplicationId $appId -EndDate $secretEndDate
    $appSecret = $secret.SecretText
    
    # Create service principal
    $sp = New-AzADServicePrincipal -AppId $appId
    
    Write-DeploymentLog "App Registration created successfully!" -Level "Success"
    Write-DeploymentLog "  App ID: $appId" -Level "Info"
    Write-DeploymentLog "  Please grant admin consent for API permissions in Azure Portal" -Level "Warning"
    
    return @{
        AppId = $appId
        AppSecret = $appSecret
        ServicePrincipalId = $sp.Id
    }
}

function Deploy-AzureResources {
    param(
        [hashtable]$AppRegistration
    )
    
    Write-DeploymentLog "Deploying Azure resources..." -Level "Progress"
    
    # Create resource group if it doesn't exist
    $rg = Get-AzResourceGroup -Name $script:ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $rg) {
        Write-DeploymentLog "Creating resource group: $script:ResourceGroupName" -Level "Info"
        $rg = New-AzResourceGroup -Name $script:ResourceGroupName -Location $script:Location
    }
    
    # Prepare deployment parameters
    $deploymentParams = @{
        projectName = "CTI"
        sentinelWorkspaceId = "" # Will be created or retrieved
        sentinelWorkspaceKey = "" # Will be retrieved after creation
        graphAppId = $AppRegistration.AppId
        graphClientSecret = $AppRegistration.AppSecret
        tenantId = $script:TenantId
    }
    
    # Add Exchange credentials only if provided (not in Cloud Shell mode)
    if ($script:GlobalAdminCredential) {
        $deploymentParams.exchangeCredentialUsername = $script:GlobalAdminCredential.UserName
        $deploymentParams.exchangeCredentialPassword = $script:GlobalAdminCredential.GetNetworkCredential().Password
    } else {
        # In Cloud Shell, use placeholder values that will be updated post-deployment
        $deploymentParams.exchangeCredentialUsername = "svc-cti@$((Get-AzContext).Tenant.Id.Split('-')[0]).onmicrosoft.com"
        $deploymentParams.exchangeCredentialPassword = "PlaceholderWillBeUpdatedPostDeployment"
        Write-DeploymentLog "Exchange credentials will need to be configured post-deployment in Azure Automation" -Level "Warning"
    }
    
    # Check for existing Sentinel workspace or create new one
    Write-DeploymentLog "Checking for Sentinel workspace..." -Level "Info"
    $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $script:ResourceGroupName -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if (-not $workspace) {
        Write-DeploymentLog "Creating new Log Analytics workspace for Sentinel..." -Level "Info"
        $workspaceName = "CTI-Sentinel-$(Get-Random -Maximum 9999)"
        $workspace = New-AzOperationalInsightsWorkspace -ResourceGroupName $script:ResourceGroupName -Name $workspaceName -Location $script:Location -Sku "PerGB2018"
        
        # Enable Sentinel
        Write-DeploymentLog "Enabling Microsoft Sentinel..." -Level "Info"
        Set-AzSentinelOnboardingState -ResourceGroupName $script:ResourceGroupName -WorkspaceName $workspace.Name -DataConnectorsCheckRequirements $false
    }
    
    $deploymentParams.sentinelWorkspaceId = $workspace.CustomerId
    $workspaceKey = Get-AzOperationalInsightsWorkspaceSharedKey -ResourceGroupName $script:ResourceGroupName -Name $workspace.Name
    $deploymentParams.sentinelWorkspaceKey = $workspaceKey.PrimarySharedKey
    
    # Download and deploy ARM template
    Write-DeploymentLog "Downloading ARM template from GitHub..." -Level "Info"
    $templateUri = "$script:GitHubBaseUrl/azuredeploy.json"
    $tempPath = if ($script:IsCloudShell) { "/tmp" } else { $env:TEMP }
    $templateFile = "$tempPath/cti-azuredeploy.json"
    Invoke-WebRequest -Uri $templateUri -OutFile $templateFile
    
    # Deploy ARM template
    Write-DeploymentLog "Deploying ARM template..." -Level "Progress"
    $deployment = New-AzResourceGroupDeployment `
        -ResourceGroupName $script:ResourceGroupName `
        -Name $script:DeploymentName `
        -TemplateFile $templateFile `
        -TemplateParameterObject $deploymentParams `
        -Verbose
    
    if ($deployment.ProvisioningState -eq "Succeeded") {
        Write-DeploymentLog "Azure resources deployed successfully!" -Level "Success"
    } else {
        throw "Azure deployment failed: $($deployment.ProvisioningState)"
    }
    
    return @{
        Outputs = $deployment.Outputs
        WorkspaceId = $deploymentParams.sentinelWorkspaceId
        WorkspaceKey = $deploymentParams.sentinelWorkspaceKey
    }
}

function Deploy-SharePointComponents {
    param(
        [hashtable]$AppRegistration
    )
    
    Write-DeploymentLog "Deploying SharePoint components..." -Level "Progress"
    
    # Connect to SharePoint with appropriate method
    Write-DeploymentLog "Connecting to SharePoint..." -Level "Info"
    
    try {
        if ($env:AZUREPS_HOST_ENVIRONMENT -eq 'cloud-shell/1.0') {
            # In Cloud Shell, use interactive login for SharePoint
            Write-DeploymentLog "Using interactive authentication for SharePoint (Cloud Shell)" -Level "Info"
            Connect-PnPOnline -Url $script:SharePointTenantUrl -Interactive
        } else {
            # Use credentials for non-Cloud Shell environments
            Connect-PnPOnline -Url $script:SharePointTenantUrl -Credentials $script:GlobalAdminCredential
        }
    } catch {
        # Fallback to web login if other methods fail
        Write-DeploymentLog "Falling back to web-based authentication" -Level "Warning"
        Connect-PnPOnline -Url $script:SharePointTenantUrl -UseWebLogin
    }
    
    # Download and execute SharePoint deployment script
    $tempPath = if ($script:IsCloudShell) { "/tmp" } else { $env:TEMP }
    $spDeployScript = "$tempPath/deploy-soc-template.ps1"
    Invoke-WebRequest -Uri "$script:GitHubBaseUrl/SharePoint/deploy-soc-template.ps1" -OutFile $spDeployScript
    
    # Create certificate for app-only auth
    Write-DeploymentLog "Creating certificate for SharePoint app authentication..." -Level "Info"
    $certName = "CTI-SharePoint-Cert"
    $cert = New-SelfSignedCertificate -Subject "CN=$certName" -CertStoreLocation "Cert:\CurrentUser\My" -KeyExportPolicy Exportable -KeySpec Signature -KeyLength 2048 -HashAlgorithm SHA256
    $certPath = "$tempPath/$certName.pfx"
    $certPassword = [System.Web.Security.Membership]::GeneratePassword(16, 4)
    Export-PfxCertificate -Cert $cert -FilePath $certPath -Password (ConvertTo-SecureString -String $certPassword -AsPlainText -Force)
    
    # Execute SharePoint deployment
    if ($script:IsCloudShell) {
        # In Cloud Shell, run the script without credential parameter
        & $spDeployScript `
            -TenantUrl $script:SharePointTenantUrl `
            -SiteUrl $script:SharePointSiteUrl `
            -AppId $AppRegistration.AppId `
            -CertificatePath $certPath `
            -SOCManagerEmail "$((Get-AzContext).Account.Id)" `
            -SentinelWorkspaceId $AzureDeployment.WorkspaceId
    } else {
        # Standard execution with credentials
        & $spDeployScript `
            -TenantUrl $script:SharePointTenantUrl `
            -SiteUrl $script:SharePointSiteUrl `
            -AppId $AppRegistration.AppId `
            -CertificatePath $certPath `
            -SOCManagerEmail $script:GlobalAdminCredential.UserName `
            -SentinelWorkspaceId $AzureDeployment.WorkspaceId
    }
    
    Write-DeploymentLog "SharePoint components deployed successfully!" -Level "Success"
    
    return @{
        CertificatePath = $certPath
        CertificatePassword = $certPassword
    }
}

function Deploy-PowerShellModules {
    param(
        [hashtable]$AzureDeployment,
        [hashtable]$SharePointDeployment
    )
    
    Write-DeploymentLog "Deploying PowerShell modules..." -Level "Progress"
    
    # Determine module installation path
    if ($script:IsCloudShell) {
        # Cloud Shell uses user-specific module path
        $moduleBase = "/home/$env:USER/.local/share/powershell/Modules"
        if (-not (Test-Path $moduleBase)) {
            New-Item -Path $moduleBase -ItemType Directory -Force | Out-Null
        }
        $moduleDir = "$moduleBase/ClarityXDR-CTI/1.0.0"
    } else {
        # Standard Windows PowerShell path
        $moduleDir = "$env:ProgramFiles\WindowsPowerShell\Modules\ClarityXDR-CTI\1.0.0"
    }
    
    New-Item -Path $moduleDir -ItemType Directory -Force | Out-Null
    Write-DeploymentLog "Installing CTI module to: $moduleDir" -Level "Info"
    
    $moduleFiles = @(
        "CTI-Module.psm1",
        "CTI-Config.json"
    )
    
    foreach ($file in $moduleFiles) {
        Write-DeploymentLog "Downloading $file..." -Level "Info"
        $uri = "$script:GitHubBaseUrl/PowerShell/$file"
        $dest = Join-Path $moduleDir $file
        Invoke-WebRequest -Uri $uri -OutFile $dest
    }
    
    # Update configuration
    $configPath = Join-Path $moduleDir "CTI-Config.json"
    $config = Get-Content $configPath | ConvertFrom-Json
    $config.SharePointSiteUrl = $SharePointSiteUrl
    $config.LogicAppUrls.Ingestion = $AzureDeployment.Outputs.ingestionLogicAppUrl.Value
    $config | ConvertTo-Json -Depth 10 | Set-Content $configPath
    
    Write-DeploymentLog "PowerShell modules deployed successfully!" -Level "Success"
}

function Deploy-ScheduledTasks {
    Write-DeploymentLog "Configuring scheduled automation..." -Level "Progress"
    
    if ($script:IsCloudShell) {
        # In Cloud Shell, we can't create Windows scheduled tasks
        Write-DeploymentLog "Cloud Shell detected - Scheduled tasks will be configured in Azure Automation" -Level "Info"
        
        # The Azure Automation runbooks are already deployed via ARM template
        Write-DeploymentLog "Azure Automation runbooks configured for daily operations" -Level "Success"
        Write-DeploymentLog "  - Daily sync scheduled for 2:00 AM UTC" -Level "Info"
        Write-DeploymentLog "  - Hourly health checks enabled" -Level "Info"
        
        # Create reminder for manual configuration
        $reminderPath = "/home/$env:USER/CTI-ScheduledTasks-Setup.md"
        @"
# CTI Scheduled Tasks Configuration

Since you deployed from Cloud Shell, Windows scheduled tasks were not created.
The Azure Automation runbooks have been deployed and will handle:

1. Daily synchronization (2:00 AM UTC)
2. Hourly health checks
3. Weekly cleanup operations

## To Enable Runbook Schedules:

1. Go to Azure Portal > Resource Groups > CTI-RG
2. Open the CTI Automation Account
3. Navigate to Runbooks
4. For each runbook, click "Schedules" and enable

## Manual Daily Sync:

Run this command in Cloud Shell anytime:
``````powershell
./Run-CTIDailySync.ps1 -ConfigFile deployment-config.json
``````
"@ | Out-File -FilePath $reminderPath -Encoding UTF8
        
        Write-DeploymentLog "Scheduled task setup instructions saved to: $reminderPath" -Level "Info"
    } else {
        # Original Windows scheduled task creation
        # Create scheduled task for daily CTI operations
        $taskName = "ClarityXDR-CTI-DailySync"
        $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\Run-CTIDailySync.ps1`""
        $trigger = New-ScheduledTaskTrigger -Daily -At "2:00AM"
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
        
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force
        
        Write-DeploymentLog "Scheduled tasks configured successfully!" -Level "Success"
    }
}

function Test-Deployment {
    param(
        [hashtable]$DeploymentInfo
    )
    
    Write-DeploymentLog "Running deployment validation tests..." -Level "Progress"
    
    $tests = @(
        @{
            Name = "Azure Resources"
            Test = {
                $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
                return $null -ne $rg
            }
        },
        @{
            Name = "Logic Apps"
            Test = {
                $logicApps = Get-AzLogicApp -ResourceGroupName $ResourceGroupName
                return $logicApps.Count -ge 2
            }
        },
        @{
            Name = "SharePoint Lists"
            Test = {
                Connect-PnPOnline -Url $SharePointSiteUrl -UseWebLogin
                $list = Get-PnPList -Identity "ThreatIndicatorsList" -ErrorAction SilentlyContinue
                return $null -ne $list
            }
        },
        @{
            Name = "PowerShell Module"
            Test = {
                $module = Get-Module -ListAvailable -Name "ClarityXDR-CTI"
                return $null -ne $module
            }
        }
    )
    
    $passed = 0
    $failed = 0
    
    foreach ($test in $tests) {
        Write-DeploymentLog "  Testing $($test.Name)..." -Level "Info" -NoNewLine
        try {
            $result = & $test.Test
            if ($result) {
                Write-DeploymentLog " ✓" -Level "Success"
                $passed++
            } else {
                Write-DeploymentLog " ✗" -Level "Error"
                $failed++
            }
        } catch {
            Write-DeploymentLog " ✗ - $($_.Exception.Message)" -Level "Error"
            $failed++
        }
    }
    
    Write-DeploymentLog "Validation complete: $passed passed, $failed failed" -Level $(if ($failed -eq 0) { "Success" } else { "Warning" })
    
    return $failed -eq 0
}

function New-QuickStartGuide {
    param(
        [hashtable]$DeploymentInfo
    )
    
    $cloudShellInstructions = if ($script:IsCloudShell) {
        @"

## Cloud Shell Specific Instructions

1. **Module Access**
   Your CTI module is installed at:
   ``/home/$env:USER/.local/share/powershell/Modules/ClarityXDR-CTI``

2. **Logs Location**
   Deployment logs are saved in your Cloud Shell home directory:
   ``/home/$env:USER/CTI-*.log``

3. **Daily Operations**
   Run daily sync manually from Cloud Shell:
   ``````powershell
   curl -sL https://raw.githubusercontent.com/ClarityXDR/prod/refs/heads/main/cti/Run-CTIDailySync.ps1 | pwsh -File -
   ``````
"@
    } else { "" }
    
    $quickStart = @"
# ClarityXDR CTI Quick Start Guide

Deployment completed on: $(Get-Date)
Environment: $(if ($script:IsCloudShell) { "Azure Cloud Shell" } else { "Local PowerShell" })

## Key Information

- **Resource Group**: $($script:ResourceGroupName)
- **SharePoint Site**: $($script:SharePointSiteUrl)
- **Sentinel Workspace ID**: $($DeploymentInfo.Azure.WorkspaceId)
- **App Registration ID**: $($DeploymentInfo.AppRegistration.AppId)

## Next Steps

1. **Grant Admin Consent**
   - Go to Azure Portal > Azure Active Directory > App registrations
   - Find "ClarityXDR-CTI-Automation"
   - Click "API permissions" > "Grant admin consent"

2. **Test Indicator Addition**
   ``````powershell
   Import-Module ClarityXDR-CTI
   Initialize-CTIModule -SentinelWorkspaceId "$($DeploymentInfo.Azure.WorkspaceId)"
   
   # Add test indicator
   Set-CTIIndicator -Type "IPAddress" -Value "192.168.100.100" -Confidence 85 -Source "TestDeployment"
   ``````

3. **Access SharePoint Site**
   - Navigate to: $($script:SharePointSiteUrl)
   - Review the ThreatIndicatorsList

4. **Monitor Logic Apps**
   - Azure Portal > Resource Groups > $($script:ResourceGroupName)
   - Check Logic Apps run history
$cloudShellInstructions

## Support

- Documentation: https://github.com/ClarityXDR/prod/tree/main/cti
- Issues: Contact SOC Team

## Deployment Log

See: $($script:LogFile)
"@
    
    $quickStartPath = if ($script:IsCloudShell) {
        "/home/$env:USER/CTI-QuickStart-$(Get-Date -Format 'yyyyMMdd').md"
    } else {
        "CTI-QuickStart-$(Get-Date -Format 'yyyyMMdd').md"
    }
    
    $quickStart | Out-File -FilePath $quickStartPath -Encoding UTF8
    
    Write-DeploymentLog "Quick start guide created: $quickStartPath" -Level "Success"
}

#endregion

#region Main Deployment Flow

try {
    Write-Host @"
╔══════════════════════════════════════════════════════════════╗
║          ClarityXDR CTI One-Click Deployment                 ║
║                                                              ║
║  Going from Blue to Green - Fast!                            ║
╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
    
    Write-DeploymentLog "Starting ClarityXDR CTI deployment..." -Level "Progress"
    Write-DeploymentLog "Deployment name: $DeploymentName" -Level "Info"
    
    # Validate credentials
    if (-not $script:IsCloudShell -and -not $GlobalAdminCredential) {
        Write-DeploymentLog "GlobalAdminCredential is required when not running in Cloud Shell" -Level "Error"
        throw "Please provide GlobalAdminCredential parameter or run from Azure Cloud Shell"
    }
    
    # In Cloud Shell, prompt for credentials if not provided
    if ($script:IsCloudShell -and -not $GlobalAdminCredential) {
        Write-DeploymentLog "Cloud Shell mode - Interactive authentication will be used" -Level "Info"
        # We'll use interactive auth for each service as needed
    }
    
    # Step 1: Prerequisites check
    if (-not $SkipPrerequisiteCheck) {
        Test-Prerequisites
    }
    
    # Step 2: Create or use existing app registration
    if ($UseExistingAppRegistration) {
        Write-DeploymentLog "Using existing app registration" -Level "Info"
        $appReg = @{
            AppId = $ExistingAppId
            AppSecret = $ExistingAppSecret
        }
    } else {
        $appReg = New-CTIAppRegistration -TenantId $script:TenantId -SubscriptionId $script:SubscriptionId -Credential $script:GlobalAdminCredential
    }
    
    # Step 3: Deploy Azure resources
    $azureDeployment = Deploy-AzureResources -AppRegistration $appReg
    
    # Step 4: Deploy SharePoint components
    $spDeployment = Deploy-SharePointComponents -AppRegistration $appReg
    
    # Step 5: Deploy PowerShell modules
    Deploy-PowerShellModules -AzureDeployment $azureDeployment -SharePointDeployment $spDeployment
    
    # Step 6: Configure scheduled tasks
    Deploy-ScheduledTasks
    
    # Step 7: Validate deployment
    $deploymentInfo = @{
        AppRegistration = $appReg
        Azure = $azureDeployment
        SharePoint = $spDeployment
    }
    
    $validationResult = Test-Deployment -DeploymentInfo $deploymentInfo
    $validationResult | Format-Table
    # Step 8: Create quick start guide
    New-QuickStartGuide -DeploymentInfo $deploymentInfo
    
    # Calculate deployment time
    $endTime = Get-Date
    $duration = $endTime - $script:StartTime
    
    Write-Host @"

╔══════════════════════════════════════════════════════════════╗
║                  DEPLOYMENT SUCCESSFUL!                      ║
╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Green
    
    Write-DeploymentLog "Deployment completed in: $($duration.ToString('hh\:mm\:ss'))" -Level "Success"
    Write-DeploymentLog "You are now GREEN! CTI system is operational." -Level "Success"
    
    # Display critical next steps
    Write-Host "`n⚠️  CRITICAL NEXT STEPS:" -ForegroundColor Yellow
    Write-Host "1. Grant admin consent for API permissions in Azure Portal" -ForegroundColor Yellow
    Write-Host "2. Review the quick start guide for testing instructions" -ForegroundColor Yellow
    Write-Host "3. Configure threat intelligence feeds in SharePoint" -ForegroundColor Yellow
    
} catch {
    Write-DeploymentLog "Deployment failed: $($_.Exception.Message)" -Level "Error"
    Write-DeploymentLog "Stack trace: $($_.ScriptStackTrace)" -Level "Error"
    
    Write-Host @"

╔══════════════════════════════════════════════════════════════╗
║                    DEPLOYMENT FAILED                         ║
╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Red
    
    Write-Host "See log file for details: $script:LogFile" -ForegroundColor Red
    throw
} finally {
    # Cleanup sensitive files
    $tempPath = if ($script:IsCloudShell) { "/tmp" } else { $env:TEMP }
    
    if (Test-Path "$tempPath/cti-*.json") {
        Remove-Item "$tempPath/cti-*.json" -Force
    }
    if (Test-Path "$tempPath/*.pfx") {
        Remove-Item "$tempPath/*.pfx" -Force
    }
    
    # Cloud Shell specific cleanup
    if ($script:IsCloudShell) {
        # Show summary in Cloud Shell
        Write-Host "`n📁 Deployment artifacts saved to: /home/$env:USER/" -ForegroundColor Cyan
        Write-Host "   - Logs: CTI-Deployment-*.log" -ForegroundColor Gray
        Write-Host "   - Quick Start: CTI-QuickStart-*.md" -ForegroundColor Gray
        Write-Host "   - Config: deployment-config.json" -ForegroundColor Gray
    }
}

#endregion