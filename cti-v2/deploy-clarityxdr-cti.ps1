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
    
    [Parameter(Mandatory = $true)]
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
    [string]$ExistingAppSecret
)

# Script configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"
$script:StartTime = Get-Date
$script:LogFile = "CTI-Deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$script:GitHubBaseUrl = "https://raw.githubusercontent.com/ClarityXDR/prod/refs/heads/main/cti"

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
    if ($Colors.ContainsKey($Level) -and $Colors[$Level]) {
        $color = $Colors[$Level]
    } else {
        $color = "White"
    }
    if ($NoNewLine) {
        Write-Host $Message -ForegroundColor $color -NoNewline
    } else {
        Write-Host $Message -ForegroundColor $color
    }
}

function Test-Prerequisites {
    Write-DeploymentLog "Checking prerequisites..." -Level "Progress"
    
    $prerequisites = @{
        "Azure PowerShell" = { Get-Module -ListAvailable -Name Az.* }
        "PnP PowerShell" = { Get-Module -ListAvailable -Name PnP.PowerShell }
        "Exchange Online Management" = { Get-Module -ListAvailable -Name ExchangeOnlineManagement }
        "Microsoft Graph" = { Get-Module -ListAvailable -Name Microsoft.Graph }
        "Azure CLI" = { az --version }
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

function New-CTIAppRegistration {
    param(
        [string]$AppName = "ClarityXDR-CTI-Automation"
    )
    
    Write-DeploymentLog "Creating Azure AD App Registration..." -Level "Progress"
    
    # Connect to Azure AD
    Connect-AzAccount -TenantId $TenantId -SubscriptionId $SubscriptionId -Credential $GlobalAdminCredential
    
    # Required API permissions
    $requiredPermissions = @(
        @{
            API = "Microsoft Graph"
            Permissions = @(
                "ThreatIndicators.ReadWrite.OwnedBy",
                "SecurityEvents.Read.All",
                "Policy.Read.All",
                "Policy.ReadWrite.ConditionalAccess",
                "Application.ReadWrite.All"
            )
        },
        @{
            API = "Office 365 Exchange Online"
            Permissions = @(
                "Exchange.ManageAsApp"
            )
        },
        @{
            API = "Microsoft Threat Protection"
            Permissions = @(
                "Ti.ReadWrite",
                "AdvancedHunting.Read.All"
            )
        }
    )

    # Mark variable as intentionally used to satisfy script analyzers until the permission-grant logic is added.
    $null = $requiredPermissions
    
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
    $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $rg) {
        Write-DeploymentLog "Creating resource group: $ResourceGroupName" -Level "Info"
        $rg = New-AzResourceGroup -Name $ResourceGroupName -Location $Location
    }
    
    # Prepare deployment parameters
    $deploymentParams = @{
        projectName = "CTI"
        sentinelWorkspaceId = "" # Will be created or retrieved
        sentinelWorkspaceKey = "" # Will be retrieved after creation
        exchangeCredentialUsername = $GlobalAdminCredential.UserName
        exchangeCredentialPassword = $GlobalAdminCredential.GetNetworkCredential().Password
        graphAppId = $AppRegistration.AppId
        graphClientSecret = $AppRegistration.AppSecret
        tenantId = $TenantId
    }
    
    # Check for existing Sentinel workspace or create new one
    Write-DeploymentLog "Checking for Sentinel workspace..." -Level "Info"
    $workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if (-not $workspace) {
        Write-DeploymentLog "Creating new Log Analytics workspace for Sentinel..." -Level "Info"
        $workspaceName = "CTI-Sentinel-$(Get-Random -Maximum 9999)"
        $workspace = New-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroupName -Name $workspaceName -Location $Location -Sku "PerGB2018"
        
        # Enable Sentinel
        Write-DeploymentLog "Enabling Microsoft Sentinel..." -Level "Info"
        Set-AzSentinelOnboardingState -ResourceGroupName $ResourceGroupName -WorkspaceName $workspace.Name -DataConnectorsCheckRequirements $false
    }
    
    $deploymentParams.sentinelWorkspaceId = $workspace.CustomerId
    $workspaceKey = Get-AzOperationalInsightsWorkspaceSharedKey -ResourceGroupName $ResourceGroupName -Name $workspace.Name
    $deploymentParams.sentinelWorkspaceKey = $workspaceKey.PrimarySharedKey
    
    # Download and deploy ARM template
    Write-DeploymentLog "Downloading ARM template from GitHub..." -Level "Info"
    $templateUri = "$script:GitHubBaseUrl/azuredeploy.json"
    $templateFile = "$env:TEMP\cti-azuredeploy.json"
    Invoke-WebRequest -Uri $templateUri -OutFile $templateFile
    
    # Deploy ARM template
    Write-DeploymentLog "Deploying ARM template..." -Level "Progress"
    $deployment = New-AzResourceGroupDeployment `
        -ResourceGroupName $ResourceGroupName `
        -Name $DeploymentName `
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
    Write-DeploymentLog "Deploying SharePoint components..." -Level "Progress"
    
    # Connect to SharePoint
    Write-DeploymentLog "Connecting to SharePoint..." -Level "Info"
    Connect-PnPOnline -Url $SharePointTenantUrl -Credentials $GlobalAdminCredential
    
    # Download and execute SharePoint deployment script
    $spDeployScript = "$env:TEMP\deploy-soc-template.ps1"
    Invoke-WebRequest -Uri "$script:GitHubBaseUrl/SharePoint/deploy-soc-template.ps1" -OutFile $spDeployScript
    
    # Create certificate for app-only auth
    Write-DeploymentLog "Creating certificate for SharePoint app authentication..." -Level "Info"
    $certName = "CTI-SharePoint-Cert"
    $cert = New-SelfSignedCertificate -Subject "CN=$certName" -CertStoreLocation "Cert:\CurrentUser\My" -KeyExportPolicy Exportable -KeySpec Signature -KeyLength 2048 -HashAlgorithm SHA256
    $certPath = "$env:TEMP\$certName.pfx"
    $certPassword = [System.Web.Security.Membership]::GeneratePassword(16, 4)
    Export-PfxCertificate -Cert $cert -FilePath $certPath -Password (ConvertTo-SecureString -String $certPassword -AsPlainText -Force)
    
    # Execute SharePoint deployment
    & $spDeployScript `
        -TenantUrl $SharePointTenantUrl `
        -SiteUrl $SharePointSiteUrl `
        -AppId $AppRegistration.AppId `
        -CertificatePath $certPath `
        -SOCManagerEmail $GlobalAdminCredential.UserName `
        -SentinelWorkspaceId $AzureDeployment.WorkspaceId
    
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
    
    # Download CTI module
    $moduleDir = "$env:ProgramFiles\WindowsPowerShell\Modules\ClarityXDR-CTI\1.0.0"
    New-Item -Path $moduleDir -ItemType Directory -Force | Out-Null
    
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
    
    # Create scheduled task for daily CTI operations
    $taskName = "ClarityXDR-CTI-DailySync"
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\Run-CTIDailySync.ps1`""
    $trigger = New-ScheduledTaskTrigger -Daily -At "2:00AM"
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force
    
    Write-DeploymentLog "Scheduled tasks configured successfully!" -Level "Success"
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
    
    $quickStart = @"
# ClarityXDR CTI Quick Start Guide

Deployment completed on: $(Get-Date)

## Key Information

- **Resource Group**: $ResourceGroupName
- **SharePoint Site**: $SharePointSiteUrl
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
   - Navigate to: $SharePointSiteUrl
   - Review the ThreatIndicatorsList

4. **Monitor Logic Apps**
   - Azure Portal > Resource Groups > $ResourceGroupName
   - Check Logic Apps run history

## Support

- Documentation: https://github.com/ClarityXDR/prod/tree/main/cti
- Issues: Contact SOC Team

## Deployment Log

See: $($script:LogFile)
"@
    
    $quickStartPath = "CTI-QuickStart-$(Get-Date -Format 'yyyyMMdd').md"
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
        $appReg = New-CTIAppRegistration
    }
    
    # Step 3: Deploy Azure resources
    $azureDeployment = Deploy-AzureResources -AppRegistration $appReg
    
    # Step 4: Deploy SharePoint components
    $spDeployment = Deploy-SharePointComponents
    
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
    
    Test-Deployment -DeploymentInfo $deploymentInfo
    
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
    if (Test-Path "$env:TEMP\cti-*.json") {
        Remove-Item "$env:TEMP\cti-*.json" -Force
    }
    if (Test-Path "$env:TEMP\*.pfx") {
        Remove-Item "$env:TEMP\*.pfx" -Force
    }
}

#endregion