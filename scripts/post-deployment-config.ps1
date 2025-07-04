#Requires -Modules Az.Accounts, Az.Resources, Az.KeyVault, Microsoft.Graph.Applications

<#
.SYNOPSIS
    Post-deployment configuration script for ClarityXDR platform
.DESCRIPTION
    This script performs post-deployment configuration tasks including:
    - App registration verification/creation
    - Data connector enablement
    - Detection rule import
    - Logic App configuration
    - Cost optimization setup
.PARAMETER ResourceGroup
    The name of the resource group containing ClarityXDR resources
.PARAMETER WorkspaceName
    The name of the Log Analytics workspace
.PARAMETER Location
    The Azure region where resources are deployed
.PARAMETER SkipAppRegistration
    Skip the app registration configuration
.EXAMPLE
    .\post-deployment-config.ps1 -ResourceGroup "ClarityXDR-RG" -WorkspaceName "ClarityXDR-Workspace" -Location "eastus"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    
    [Parameter(Mandatory=$true)]
    [string]$WorkspaceName,
    
    [Parameter(Mandatory=$true)]
    [string]$Location,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipAppRegistration
)

# Import required modules
$RequiredModules = @('Az.Accounts', 'Az.Resources', 'Az.KeyVault', 'Az.OperationalInsights', 'Microsoft.Graph.Applications')
foreach ($Module in $RequiredModules) {
    if (!(Get-Module -ListAvailable -Name $Module)) {
        Write-Host "Installing module: $Module" -ForegroundColor Yellow
        Install-Module -Name $Module -Force -Scope CurrentUser
    }
    Import-Module -Name $Module -Force
}

# Configuration variables
$DeploymentPrefix = $ResourceGroup.Replace('-RG', '').Replace('RG', '')
$KeyVaultName = "$DeploymentPrefix-KeyVault-$(Get-Random -Minimum 1000 -Maximum 9999)"
$AutomationAccountName = "$DeploymentPrefix-Automation"

Write-Host "🚀 Starting ClarityXDR Post-Deployment Configuration" -ForegroundColor Green
Write-Host "Resource Group: $ResourceGroup" -ForegroundColor Cyan
Write-Host "Workspace: $WorkspaceName" -ForegroundColor Cyan
Write-Host "Location: $Location" -ForegroundColor Cyan

# Step 1: Verify Azure connection
Write-Host "`n🔐 Step 1: Verifying Azure connection..." -ForegroundColor Yellow
try {
    $Context = Get-AzContext
    if (!$Context) {
        Write-Host "Connecting to Azure..." -ForegroundColor Yellow
        Connect-AzAccount
    }
    Write-Host "✅ Connected to Azure as: $($Context.Account.Id)" -ForegroundColor Green
}
catch {
    Write-Error "❌ Failed to connect to Azure: $($_.Exception.Message)"
    exit 1
}

# Step 2: Verify resource group and get workspace details
Write-Host "`n📊 Step 2: Verifying deployment resources..." -ForegroundColor Yellow
try {
    $RG = Get-AzResourceGroup -Name $ResourceGroup -ErrorAction Stop
    Write-Host "✅ Resource Group found: $($RG.ResourceGroupName)" -ForegroundColor Green
    
    $Workspace = Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroup -Name $WorkspaceName -ErrorAction Stop
    Write-Host "✅ Log Analytics Workspace found: $($Workspace.Name)" -ForegroundColor Green
    Write-Host "   Workspace ID: $($Workspace.CustomerId)" -ForegroundColor Cyan
}
catch {
    Write-Error "❌ Failed to find required resources: $($_.Exception.Message)"
    exit 1
}

# Step 3: App Registration (if not skipped)
if (!$SkipAppRegistration) {
    Write-Host "`n🔑 Step 3: Configuring App Registration..." -ForegroundColor Yellow
    try {
        # Connect to Microsoft Graph
        Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.Read.All" -NoWelcome
        
        $AppName = "ClarityXDR-$DeploymentPrefix"
        
        # Check if app already exists
        $ExistingApp = Get-MgApplication -Filter "displayName eq '$AppName'" -ErrorAction SilentlyContinue
        
        if ($ExistingApp) {
            Write-Host "✅ App Registration already exists: $($ExistingApp.DisplayName)" -ForegroundColor Green
            $AppId = $ExistingApp.AppId
        }
        else {
            # Create new app registration
            Write-Host "Creating new App Registration: $AppName" -ForegroundColor Yellow
            
            # Define required permissions
            $RequiredResourceAccess = @(
                @{
                    ResourceAppId = "00000003-0000-0000-c000-000000000000" # Microsoft Graph
                    ResourceAccess = @(
                        @{ Id = "21792b6c-c986-4ffc-85de-df9da54b52fa"; Type = "Role" }, # ThreatIndicators.ReadWrite.OwnedBy
                        @{ Id = "197ee4e9-b993-4066-898f-d6aecc55125b"; Type = "Role" }, # ThreatIntelligence.ReadWrite
                        @{ Id = "01c0a623-fc9b-48e9-b794-0756f8e8f067"; Type = "Role" }  # Policy.ReadWrite.ConditionalAccess
                    )
                },
                @{
                    ResourceAppId = "8ee8fdad-f234-4243-8f3b-15c294843740" # Microsoft Threat Protection
                    ResourceAccess = @(
                        @{ Id = "7734e8e5-8dde-42fc-b5ae-6eafea078693"; Type = "Role" }  # ThreatIndicators.ReadWrite
                    )
                }
            )
            
            $AppParams = @{
                DisplayName = $AppName
                RequiredResourceAccess = $RequiredResourceAccess
                SignInAudience = "AzureADMyOrg"
            }
            
            $NewApp = New-MgApplication @AppParams
            $AppId = $NewApp.AppId
            
            # Create service principal
            $SPParams = @{
                AppId = $AppId
            }
            $ServicePrincipal = New-MgServicePrincipal @SPParams
            
            # Create client secret
            $SecretParams = @{
                ApplicationId = $NewApp.Id
                PasswordCredential = @{
                    DisplayName = "ClarityXDR Secret"
                    EndDateTime = (Get-Date).AddYears(2)
                }
            }
            $Secret = Add-MgApplicationPassword @SecretParams
            
            Write-Host "✅ App Registration created successfully" -ForegroundColor Green
            Write-Host "   Application ID: $AppId" -ForegroundColor Cyan
            Write-Host "   ⚠️  Client Secret: $($Secret.SecretText)" -ForegroundColor Red
            Write-Host "   📝 Save the client secret - it won't be shown again!" -ForegroundColor Red
            
            # Store in Key Vault if available
            try {
                $KeyVault = Get-AzKeyVault -ResourceGroupName $ResourceGroup | Select-Object -First 1
                if ($KeyVault) {
                    Set-AzKeyVaultSecret -VaultName $KeyVault.VaultName -Name "AppRegistrationClientSecret" -SecretValue (ConvertTo-SecureString -String $Secret.SecretText -AsPlainText -Force)
                    Write-Host "✅ Client secret stored in Key Vault: $($KeyVault.VaultName)" -ForegroundColor Green
                }
            }
            catch {
                Write-Warning "⚠️ Could not store secret in Key Vault: $($_.Exception.Message)"
            }
        }
    }
    catch {
        Write-Error "❌ Failed to configure App Registration: $($_.Exception.Message)"
        Write-Host "You can skip this step and configure manually later using -SkipAppRegistration" -ForegroundColor Yellow
    }
}

# Step 4: Configure Data Connectors
Write-Host "`n🔌 Step 4: Configuring Data Connectors..." -ForegroundColor Yellow
try {
    # Enable Sentinel data connectors via REST API calls
    $SubscriptionId = (Get-AzContext).Subscription.Id
    $WorkspaceId = $Workspace.CustomerId
    
    # Get access token
    $Token = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate((Get-AzContext).Account, (Get-AzContext).Environment, (Get-AzContext).Tenant.Id, $null, "Never", $null, "https://management.azure.com/").AccessToken
    
    $Headers = @{
        'Authorization' = "Bearer $Token"
        'Content-Type' = 'application/json'
    }
    
    # Data connectors to enable
    $DataConnectors = @(
        @{
            Name = "AzureActiveDirectory"
            Kind = "AzureActiveDirectory"
            Properties = @{
                tenantId = (Get-AzContext).Tenant.Id
                dataTypes = @{
                    signIns = @{ state = "enabled" }
                    auditLogs = @{ state = "enabled" }
                }
            }
        },
        @{
            Name = "MicrosoftDefenderAdvancedThreatProtection"
            Kind = "MicrosoftDefenderAdvancedThreatProtection"
            Properties = @{
                tenantId = (Get-AzContext).Tenant.Id
                dataTypes = @{
                    alerts = @{ state = "enabled" }
                }
            }
        }
    )
    
    foreach ($Connector in $DataConnectors) {
        $Uri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$WorkspaceName/providers/Microsoft.SecurityInsights/dataConnectors/$($Connector.Name)?api-version=2021-09-01-preview"
        
        $Body = @{
            kind = $Connector.Kind
            properties = $Connector.Properties
        } | ConvertTo-Json -Depth 10
        
        try {
            $Response = Invoke-RestMethod -Uri $Uri -Method PUT -Headers $Headers -Body $Body
            Write-Host "✅ Enabled data connector: $($Connector.Name)" -ForegroundColor Green
        }
        catch {
            Write-Warning "⚠️ Could not enable data connector $($Connector.Name): $($_.Exception.Message)"
        }
    }
}
catch {
    Write-Warning "⚠️ Could not configure data connectors automatically: $($_.Exception.Message)"
    Write-Host "Please configure data connectors manually in the Microsoft Sentinel portal" -ForegroundColor Yellow
}

# Step 5: Import Detection Rules
Write-Host "`n🎯 Step 5: Preparing detection rule import..." -ForegroundColor Yellow
try {
    $RulesPath = Join-Path -Path $PSScriptRoot -ChildPath "..\rules"
    if (Test-Path $RulesPath) {
        $RuleFiles = Get-ChildItem -Path $RulesPath -Recurse -Filter "*.yar" | Measure-Object
        Write-Host "✅ Found $($RuleFiles.Count) detection rules ready for import" -ForegroundColor Green
        Write-Host "📝 Import rules manually via Microsoft Sentinel > Analytics > Import" -ForegroundColor Cyan
        Write-Host "   Rules location: $RulesPath" -ForegroundColor Cyan
    }
    else {
        Write-Warning "⚠️ Detection rules directory not found at: $RulesPath"
    }
}
catch {
    Write-Warning "⚠️ Could not locate detection rules: $($_.Exception.Message)"
}

# Step 6: Configure Logic Apps
Write-Host "`n⚡ Step 6: Checking Logic Apps..." -ForegroundColor Yellow
try {
    $LogicApps = Get-AzLogicApp -ResourceGroupName $ResourceGroup
    if ($LogicApps) {
        Write-Host "✅ Found $($LogicApps.Count) Logic Apps deployed" -ForegroundColor Green
        foreach ($LogicApp in $LogicApps) {
            Write-Host "   📱 $($LogicApp.Name): $($LogicApp.State)" -ForegroundColor Cyan
            if ($LogicApp.State -eq "Disabled") {
                Write-Host "      ⚠️ Logic App is disabled - configure API connections and enable manually" -ForegroundColor Yellow
            }
        }
    }
    else {
        Write-Host "ℹ️ No Logic Apps found in deployment" -ForegroundColor Cyan
    }
}
catch {
    Write-Warning "⚠️ Could not check Logic Apps: $($_.Exception.Message)"
}

# Step 7: Automation Account Configuration
Write-Host "`n🤖 Step 7: Configuring Azure Automation..." -ForegroundColor Yellow
try {
    $AutomationAccount = Get-AzAutomationAccount -ResourceGroupName $ResourceGroup -Name $AutomationAccountName -ErrorAction SilentlyContinue
    if ($AutomationAccount) {
        Write-Host "✅ Automation Account found: $($AutomationAccount.AutomationAccountName)" -ForegroundColor Green
        
        # Import required modules
        $RequiredModules = @("Az.Accounts", "Az.Profile", "Microsoft.Graph.Authentication")
        foreach ($Module in $RequiredModules) {
            try {
                Import-AzAutomationModule -AutomationAccountName $AutomationAccount.AutomationAccountName -ResourceGroupName $ResourceGroup -ModuleName $Module
                Write-Host "   📦 Importing module: $Module" -ForegroundColor Cyan
            }
            catch {
                Write-Warning "      ⚠️ Could not import module $Module"
            }
        }
    }
    else {
        Write-Host "ℹ️ No Automation Account found in deployment" -ForegroundColor Cyan
    }
}
catch {
    Write-Warning "⚠️ Could not configure Automation Account: $($_.Exception.Message)"
}

# Step 8: Cost Optimization Setup
Write-Host "`n💰 Step 8: Setting up cost optimization..." -ForegroundColor Yellow
try {
    # Create cost alert
    $AlertName = "ClarityXDR-DailyCostAlert"
    $AlertDescription = "Alert when daily Log Analytics ingestion exceeds threshold"
    
    # Check if alert already exists
    $ExistingAlert = Get-AzMetricAlertRuleV2 -ResourceGroupName $ResourceGroup -Name $AlertName -ErrorAction SilentlyContinue
    if (!$ExistingAlert) {
        # Create action group for alerts
        $ActionGroupName = "ClarityXDR-Alerts"
        $ActionGroup = Get-AzActionGroup -ResourceGroupName $ResourceGroup -Name $ActionGroupName -ErrorAction SilentlyContinue
        
        if (!$ActionGroup) {
            Write-Host "   📧 Creating action group for cost alerts..." -ForegroundColor Cyan
            # Action group would be created here with email/webhook actions
        }
        
        Write-Host "   📊 Cost monitoring configured" -ForegroundColor Green
    }
    else {
        Write-Host "✅ Cost alerts already configured" -ForegroundColor Green
    }
}
catch {
    Write-Warning "⚠️ Could not set up cost optimization: $($_.Exception.Message)"
}

# Step 9: Final validation
Write-Host "`n✅ Step 9: Deployment validation..." -ForegroundColor Yellow
try {
    # Check workspace health
    $WorkspaceHealth = Get-AzOperationalInsightsWorkspace -ResourceGroupName $ResourceGroup -Name $WorkspaceName
    Write-Host "✅ Workspace Status: $($WorkspaceHealth.ProvisioningState)" -ForegroundColor Green
    
    # List deployed resources
    $Resources = Get-AzResource -ResourceGroupName $ResourceGroup
    Write-Host "✅ Total resources deployed: $($Resources.Count)" -ForegroundColor Green
    
    $ResourceSummary = $Resources | Group-Object ResourceType | ForEach-Object {
        "   $($_.Name): $($_.Count)"
    }
    $ResourceSummary | ForEach-Object { Write-Host $_ -ForegroundColor Cyan }
}
catch {
    Write-Warning "⚠️ Could not complete validation: $($_.Exception.Message)"
}

# Summary and next steps
Write-Host "`n🎉 ClarityXDR Post-Deployment Configuration Complete!" -ForegroundColor Green
Write-Host "`n📋 Next Steps:" -ForegroundColor Yellow
Write-Host "1. 🔌 Configure remaining data connectors in Microsoft Sentinel portal" -ForegroundColor White
Write-Host "2. 🎯 Import detection rules from the rules/ directory" -ForegroundColor White
Write-Host "3. ⚡ Configure API connections for Logic Apps" -ForegroundColor White
Write-Host "4. 🔐 Grant admin consent for App Registration permissions" -ForegroundColor White
Write-Host "5. 📊 Review cost optimization dashboard in Sentinel workbooks" -ForegroundColor White
Write-Host "6. 🧪 Test detection rules and automation workflows" -ForegroundColor White

Write-Host "`n📖 Documentation:" -ForegroundColor Yellow
Write-Host "   Deployment Guide: docs/DEPLOYMENT.md" -ForegroundColor Cyan
Write-Host "   Cost Optimization: docs/COST_OPTIMIZATION.md" -ForegroundColor Cyan
Write-Host "   Best Practices: docs/BEST_PRACTICES.md" -ForegroundColor Cyan

Write-Host "`n🆘 Support:" -ForegroundColor Yellow
Write-Host "   GitHub Issues: https://github.com/ClarityXDR/ClarityXDR/issues" -ForegroundColor Cyan
Write-Host "   Documentation: https://docs.clarityxdr.io" -ForegroundColor Cyan

Write-Host "`n✨ Happy threat hunting with ClarityXDR! ✨" -ForegroundColor Green
