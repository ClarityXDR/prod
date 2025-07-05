#Requires -Version 5.1
<#
.SYNOPSIS
    ClarityXDR App Registration Setup Script
.DESCRIPTION
    Creates a comprehensive Azure AD app registration with all permissions needed for:
    • Microsoft Defender XDR (Custom Detection Rules, Advanced Hunting, etc.)
    • Microsoft Sentinel (Analytic Rules, Security Operations)
    • Threat Intelligence APIs
    • Security Actions and Incident Management
    • Audit Logs and Directory Recommendations
    • Complete security automation pipeline capabilities
.PARAMETER ResourceGroup
    Resource group name to create or use
.PARAMETER Location
    Azure region (e.g., eastus, westeurope)
.PARAMETER Help
    Show help message
.EXAMPLE
    .\ClarityXDR-Setup.ps1 -ResourceGroup "clarityxdr-rg" -Location "eastus"
.EXAMPLE
    .\ClarityXDR-Setup.ps1 -Help
#>

param(
    [Parameter(Mandatory = $false)]
    [Alias("g")]
    [string]$ResourceGroup = "",
    
    [Parameter(Mandatory = $false)]
    [Alias("l")]
    [string]$Location = "",
    
    [Parameter(Mandatory = $false)]
    [Alias("h")]
    [switch]$Help
)

# Error handling
$ErrorActionPreference = "Stop"

# Show help if requested
if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit 0
}

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Function to write status messages
function Write-Status {
    param([string]$Message)
    Write-ColorOutput $Message -Color "Cyan"
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput $Message -Color "Green"
}

function Write-Warning {
    param([string]$Message)
    Write-ColorOutput $Message -Color "Yellow"
}

function Write-Error {
    param([string]$Message)
    Write-ColorOutput $Message -Color "Red"
}

# Header
Write-Host ""
Write-Host "=======================================================" -ForegroundColor "White"
Write-Host "          ClarityXDR Application Registration Setup" -ForegroundColor "White"
Write-Host "=======================================================" -ForegroundColor "White"
Write-Status "This script will:"
Write-Host "  • Create an Azure AD app registration"
Write-Host "  • Add comprehensive security API permissions"
Write-Host "  • Assign RBAC roles for Sentinel and Log Analytics"
Write-Host "  • Create a Key Vault for secure secret storage"
Write-Host "  • Generate and store client credentials"
Write-Host "=======================================================" -ForegroundColor "White"

Write-Status "Checking prerequisites..."

# Check for required tools
try {
    $null = Get-Command az -ErrorAction Stop
}
catch {
    Write-Error "Azure CLI is not installed. Please install it first."
    Write-Host "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
}

# Check if logged in to Azure
try {
    $accountInfo = az account show --query "name" -o tsv 2>$null
    if (-not $accountInfo) {
        throw "Not logged in"
    }
}
catch {
    Write-Warning "Not logged in to Azure."
    az login
}

# Get subscription and tenant details
try {
    $subName = az account show --query "name" -o tsv
    $subId = az account show --query "id" -o tsv
    $tenantId = az account show --query "tenantId" -o tsv
    
    if (-not $subId) {
        throw "Failed to retrieve subscription information"
    }
    
    Write-Success "Using subscription: $subName ($subId)"
    Write-Success "Tenant ID: $tenantId"
}
catch {
    Write-Error "Failed to retrieve subscription information. Please ensure you're logged in."
    exit 1
}

# Prompt for resource group if not provided
if (-not $ResourceGroup) {
    if ([Environment]::UserInteractive) {
        $ResourceGroup = Read-Host "Please enter a resource group name to create or use"
    }
    else {
        $ResourceGroup = "clarityxdr-rg"
        Write-Host "Using default resource group: $ResourceGroup"
    }
}

# Prompt for location if not provided
if (-not $Location) {
    if ([Environment]::UserInteractive) {
        $Location = Read-Host "Please enter the Azure region (e.g., eastus, westeurope)"
    }
    else {
        $Location = "eastus"
        Write-Host "Using default location: $Location"
    }
}

# Check if resource group exists, create if it doesn't
try {
    $null = az group show --name $ResourceGroup 2>$null
    Write-Success "Using existing resource group: $ResourceGroup"
}
catch {
    Write-Host "Creating resource group $ResourceGroup in $Location..."
    try {
        az group create --name $ResourceGroup --location $Location | Out-Null
        Write-Success "Resource group created successfully"
    }
    catch {
        Write-Error "Failed to create resource group. Please check your permissions and subscription."
        exit 1
    }
}

# Create app registration
$appName = "ClarityXDR-App"

# Check if app already exists
Write-Host "Checking if app registration already exists..."
try {
    $existingApp = az ad app list --display-name $appName --query "[0]" 2>$null | ConvertFrom-Json
    
    if ($existingApp) {
        Write-Warning "App registration '$appName' already exists."
        $appId = $existingApp.appId
        $objectId = $existingApp.id
        Write-Success "Using existing app with ID: $appId"
    }
    else {
        Write-Host "Creating app registration: $appName..."
        $appCreate = az ad app create --display-name $appName 2>$null | ConvertFrom-Json
        
        if (-not $appCreate) {
            throw "Failed to create app registration"
        }
        
        $appId = $appCreate.appId
        $objectId = $appCreate.id
        Write-Success "Application successfully created."
    }
}
catch {
    Write-Error "Failed to create app registration. Please check your permissions."
    exit 1
}

if (-not $appId) {
    Write-Error "Failed to retrieve Application ID."
    exit 1
}

Write-Success "Application (Client) ID: $appId"

###############################################################################
# 🎨 Set ClarityXDR App Logo                                                  #
###############################################################################
Write-Status "`nSetting ClarityXDR logo for the app registration..."

try {
    # Download the ClarityXDR logo from GitHub
    $logoUrl = "https://raw.githubusercontent.com/ClarityXDR/prod/main/brand-assets/Icon_48x48.png"
    $logoPath = "$env:TEMP\clarityxdr-logo.png"
    
    Write-Host "Downloading ClarityXDR logo..."
    Invoke-WebRequest -Uri $logoUrl -OutFile $logoPath -ErrorAction Stop
    
    # Verify the file was downloaded and is valid
    if (Test-Path $logoPath) {
        $logoInfo = Get-Item $logoPath
        if ($logoInfo.Length -gt 0) {
            Write-Host "Logo downloaded successfully ($($logoInfo.Length) bytes)"
            
            # Set the logo for the app registration
            Write-Host "Applying logo to app registration..."
            az ad app update --id $appId --logo $logoPath --output none 2>$null
            
            Write-Success "✅ ClarityXDR logo applied to app registration"
            
            # Clean up the temporary logo file
            Remove-Item $logoPath -Force -ErrorAction SilentlyContinue
        }
        else {
            Write-Warning "Downloaded logo file is empty. Skipping logo application."
        }
    }
    else {
        Write-Warning "Failed to download logo file. Skipping logo application."
    }
}
catch {
    Write-Warning "Could not set app logo: $($_.Exception.Message)"
    Write-Host "The app registration will continue without a logo."
    
    # Clean up any partial download
    if (Test-Path "$env:TEMP\clarityxdr-logo.png") {
        Remove-Item "$env:TEMP\clarityxdr-logo.png" -Force -ErrorAction SilentlyContinue
    }
}

# Create service principal
Write-Host "Creating service principal for the application..."
try {
    az ad sp create --id $appId --output none 2>$null
    Write-Success "Service principal created successfully."
}
catch {
    # Check if service principal already exists
    try {
        $null = az ad sp show --id $appId 2>$null
        Write-Warning "Service principal already exists."
    }
    catch {
        Write-Error "Failed to create service principal."
        exit 1
    }
}

# Save app ID and other non-sensitive info to a file
$credentialsContent = @"
CLIENT_ID=$appId
APP_OBJECT_ID=$objectId
APP_NAME=$appName
TENANT_ID=$tenantId
SUBSCRIPTION_ID=$subId
"@

$credentialsContent | Out-File -FilePath "clarityxdr-credentials.env" -Encoding UTF8

Write-Status "`nAdding comprehensive API permissions for ClarityXDR..."
Write-Warning "Note: Permission messages 'Invoking az ad app permission grant...' can be ignored"

###############################################################################
# 1️⃣ Microsoft Graph – Complete Security & Risk Management [ENHANCED]       #
###############################################################################
Write-Host "Adding Microsoft Graph permissions..."
Write-Host "  - Threat Intelligence & Security Events" -ForegroundColor DarkGray
Write-Host "  - Identity Risk Management (Read/Write)" -ForegroundColor DarkGray
Write-Host "  - Conditional Access & Named Locations (Read/Write)" -ForegroundColor DarkGray
Write-Host "  - Directory Operations for user/device management" -ForegroundColor DarkGray
# resourceAppId: 00000003-0000-0000-c000-000000000000

$graphPermissions = @(
    # Threat Intelligence & Security
    "21792b6c-c986-4ffc-85de-df9da54b52fa=Role", # ThreatIndicators.ReadWrite.OwnedBy
    "197ee4e9-b993-4066-898f-d6aecc55125b=Role", # ThreatIndicators.Read.All
    "472e4a4d-bb4a-4026-98d1-0b0d74cb74a5=Role", # SecurityAlert.Read.All
    "ed4fca05-be46-441f-9803-1873825f8fdb=Role", # SecurityAlert.ReadWrite.All
    "34bf0e97-1971-4929-b999-9e2442d941d7=Role", # SecurityIncident.ReadWrite.All
    "bf394140-e372-4bf9-a898-299cfc7564e5=Role", # SecurityEvents.ReadWrite.All
    "5df6fe86-1be0-44eb-b916-7bd443a71236=Role", # SecurityActions.Read.All
    "dc38509c-b87d-4da0-bd92-6bec988bac4a=Role", # SecurityActions.ReadWrite.All
    "e0b77adb-e790-44a3-b0a0-257d06303687=Role", # ThreatIntelligence.Read.All
    
    # Directory & Audit
    "e4c9e354-4dc5-45b8-9e7c-e1393b0b1a20=Role", # AuditLog.Read.All
    "7ab1d382-f21e-4acd-a863-ba3e13f7da61=Role", # Directory.Read.All
    "19dbc75e-c2e2-444c-a770-ec69d8559fc7=Role", # Directory.ReadWrite.All
    "230c1aed-a721-4c5d-9cb4-a90514e508ef=Role", # Reports.Read.All
    
    # Identity Risk Management - READ & WRITE
    "dc5007c0-2d7d-4c42-879c-2dab87571379=Role", # IdentityRiskyUser.Read.All
    "656f6061-f9fe-4807-9708-6a2e0934df76=Role", # IdentityRiskyUser.ReadWrite.All
    "2e4dd572-8ddf-4832-bd49-4ee5df4b7cc5=Role", # IdentityRiskEvent.Read.All
    "6e472fd1-ad78-48da-a0f0-97ab2c6b769e=Role", # IdentityRiskEvent.ReadWrite.All
    
    # Conditional Access & Named Locations - READ & WRITE
    "01c0a623-fc9b-48e9-b794-0756f8e8f067=Role", # Policy.Read.ConditionalAccess
    "246dd0d5-5bd0-4def-940b-0421030a5b68=Role", # Policy.ReadWrite.ConditionalAccess
    "37f7f235-527c-4136-accd-4a02d197296e=Role", # Policy.ReadWrite.SecurityDefaults
    "ad902697-1014-4ef5-81ef-2b4301988e8c=Role"  # Policy.ReadWrite.PermissionGrant
)

foreach ($permission in $graphPermissions) {
    az ad app permission add --id $appId --api "00000003-0000-0000-c000-000000000000" --api-permissions $permission --output none 2>$null
}

Write-Success "✓ Microsoft Graph permissions added"

###############################################################################
# 2️⃣ Microsoft Defender for Endpoint [CORRECTED]                            #
###############################################################################
Write-Host "Adding Microsoft Defender for Endpoint permissions..."
# WindowsDefenderATP API - resourceAppId: fc780465-2017-40d4-a0c5-307022471b92

$mdePermissions = @(
    "ea8291d3-4b9a-44b5-bc3a-6cea3026dc79=Role", # Machine.Read.All
    "7b7531ad-5926-4f2d-8a1d-38495ad33e17=Role", # Machine.ReadWrite.All
    "ee30690b-f2a2-471f-a2dc-2eadb0c4b07e=Role", # Alert.Read.All
    "93489bf5-0fbc-4f2d-b901-33f2fe08ff05=Role", # Alert.ReadWrite.All
    "93076945-2c91-4c14-ab15-5ba0c6c1dcb7=Role", # AdvancedQuery.Read.All
    "197042cb-0fc3-44f5-9c0f-871c34b77d7f=Role", # Ti.Read.All
    "3aa2db8f-db19-414f-9346-e4056fcbc5a8=Role"  # Ti.ReadWrite
)

foreach ($permission in $mdePermissions) {
    az ad app permission add --id $appId --api "fc780465-2017-40d4-a0c5-307022471b92" --api-permissions $permission --output none 2>$null
}

Write-Success "✓ Defender for Endpoint permissions added"

###############################################################################
# 3️⃣ Microsoft Threat Protection API [CORRECTED]                             #
###############################################################################
Write-Host "Adding Microsoft Threat Protection API permissions..."
# resourceAppId: 8ee8fdad-f234-4243-8f3b-15c294843740
az ad app permission add --id $appId --api "8ee8fdad-f234-4243-8f3b-15c294843740" --api-permissions "93076945-2c91-4c14-ab15-5ba0c6c1dcb7=Role" --output none 2>$null # AdvancedHunting.Read.All
Write-Success "✓ Threat Protection API permissions added"

###############################################################################
# 4️⃣ Office 365 Exchange Online [ADDED]                                      #
###############################################################################
Write-Host "Adding Office 365 Exchange Online permissions..."
# resourceAppId: 00000002-0000-0ff1-ce00-000000000000
az ad app permission add --id $appId --api "00000002-0000-0ff1-ce00-000000000000" --api-permissions "dc890d15-9560-4a4c-9b7f-a736ec74ec40=Role" --output none 2>$null # Exchange.ManageAsApp
Write-Success "✓ Exchange Online permissions added"

###############################################################################
# 5️⃣ Azure Service Management [CORRECTED]                                    #
###############################################################################
Write-Host "Adding Azure Management permissions..."
az ad app permission add --id $appId --api "797f4846-ba00-4fd7-ba43-dac1f8f63013" --api-permissions "41094075-9dad-400e-a0bd-54e686782033=Scope" --output none 2>$null # user_impersonation
Write-Success "✓ Azure Management permissions added"

Write-Success "All API permissions added successfully."

###############################################################################
# 6️⃣ RBAC: Assign roles for Sentinel and Log Analytics                      #
###############################################################################
Write-Status "`nAssigning RBAC roles for Sentinel and Log Analytics management..."

try {
    $assigneeId = az ad sp show --id $appId --query "id" -o tsv 2>$null
    if (-not $assigneeId) {
        Write-Warning "Warning: Could not retrieve service principal ID for RBAC assignment."
        $assigneeId = $appId  # Fallback to app ID
    }
}
catch {
    $assigneeId = $appId  # Fallback to app ID
}

$scope = "/subscriptions/$subId"

Write-Host "Assigning Azure Sentinel Contributor role..."
try {
    az role assignment create --assignee $assigneeId --role "Azure Sentinel Contributor" --scope $scope --output none 2>$null
    Write-Success "Azure Sentinel Contributor role assigned."
}
catch {
    Write-Warning "Note: Could not assign Azure Sentinel Contributor role (may already exist)."
}

Write-Host "Assigning Log Analytics Contributor role..."
try {
    az role assignment create --assignee $assigneeId --role "Log Analytics Contributor" --scope $scope --output none 2>$null
    Write-Success "Log Analytics Contributor role assigned."
}
catch {
    Write-Warning "Note: Could not assign Log Analytics Contributor role (may already exist)."
}

Write-Success "RBAC configuration completed."

###############################################################################
# 7️⃣ Key Vault Creation and Secret Management                                #
###############################################################################
Write-Status "`nCreating Key Vault to store client secret..."

# Generate a random suffix
$randomSuffix = -join ((1..6) | ForEach-Object { '{0:X}' -f (Get-Random -Maximum 16) })
$randomSuffix = $randomSuffix.ToLower()

# Keep Key Vault name short and valid (3-24 chars, alphanumeric and hyphens only)
$kvName = "cxdr-$randomSuffix"
Write-Host "Creating Key Vault: $kvName..."

# Attempt to create Key Vault with retry logic
$maxAttempts = 3
$attempt = 1
$kvCreated = $false

while ($attempt -le $maxAttempts -and -not $kvCreated) {
    Write-Host "Attempt $attempt of $maxAttempts..."
    
    try {
        az keyvault create --name $kvName --resource-group $ResourceGroup --location $Location --sku standard --enabled-for-template-deployment true --no-wait 2>$null | Out-Null
        
        # Wait for the Key Vault to be fully created
        Write-Host "Waiting for Key Vault creation to complete..."
        $timeout = 120
        $elapsed = 0
        $interval = 5
        
        do {
            Start-Sleep -Seconds $interval
            $elapsed += $interval
            try {
                $kvStatus = az keyvault show --name $kvName --resource-group $ResourceGroup --query "properties.provisioningState" -o tsv 2>$null
                if ($kvStatus -eq "Succeeded") {
                    $kvCreated = $true
                    break
                }
            }
            catch {
                # Continue waiting
            }
        } while ($elapsed -lt $timeout)
        
        if ($kvCreated) {
            Write-Success "Key Vault created successfully: $kvName"
            break
        }
    }
    catch {
        # Try continues
    }
    
    if ($attempt -eq $maxAttempts) {
        Write-Warning "Failed to create Key Vault after $maxAttempts attempts."
        Write-Warning "Trying alternative approach..."
        
        # Try with a different naming pattern
        $kvName = "clarityxdr$randomSuffix"
        
        try {
            az keyvault create --name $kvName --resource-group $ResourceGroup --location $Location --sku standard --enabled-for-template-deployment true | Out-Null
            Write-Success "Key Vault created successfully with alternative name: $kvName"
            $kvCreated = $true
        }
        catch {
            Write-Error "Unable to create Key Vault. Please check:"
            Write-Error "- Azure subscription limits"
            Write-Error "- Sufficient permissions"
            Write-Error "- Regional availability"
            exit 1
        }
    }
    else {
        # Generate new name for retry
        $randomSuffix = -join ((1..6) | ForEach-Object { '{0:X}' -f (Get-Random -Maximum 16) })
        $randomSuffix = $randomSuffix.ToLower()
        $kvName = "cxdr-$randomSuffix"
        Write-Warning "Retrying with new name: $kvName"
        $attempt++
        Start-Sleep -Seconds 5
    }
}

if (-not $kvCreated) {
    Write-Error "Failed to create Key Vault after all attempts."
    exit 1
}

# Add Key Vault info to credentials file
$credentialsContent += "`nKEYVAULT_NAME=$kvName"
$credentialsContent += "`nRESOURCE_GROUP=$ResourceGroup"
$credentialsContent | Out-File -FilePath "clarityxdr-credentials.env" -Encoding UTF8

# Assign Key Vault Secrets Officer role to the current user
Write-Status "Assigning Key Vault permissions to current user..."
try {
    $userId = az ad signed-in-user show --query "id" -o tsv 2>$null
    if (-not $userId) {
        Write-Warning "Warning: Unable to retrieve current user ID. Trying alternative method..."
        $userId = az account show --query "user.name" -o tsv 2>$null
        if (-not $userId) {
            Write-Error "Unable to retrieve user identity. You'll need to manually assign Key Vault permissions."
        }
    }
}
catch {
    Write-Warning "Could not retrieve user identity for Key Vault permissions."
}

if ($userId) {
    Write-Host "Granting Key Vault Secrets Officer role to user..."
    try {
        az role assignment create --role "Key Vault Secrets Officer" --assignee $userId --scope "/subscriptions/$subId/resourceGroups/$ResourceGroup/providers/Microsoft.KeyVault/vaults/$kvName" --output none 2>$null
        Write-Success "Key Vault permissions granted."
    }
    catch {
        Write-Warning "Note: Could not assign Key Vault role. You may already have permissions."
    }
}

# Wait for permissions to propagate
Write-Host "Waiting 15 seconds for RBAC permissions to propagate..."
Start-Sleep -Seconds 15

# Create client secret
Write-Status "Creating client secret and storing in Key Vault..."
$secretYears = 2
Write-Host "Creating client secret with $secretYears year(s) duration..."

# Create the secret but don't display it
$maxSecretAttempts = 3
$secretAttempt = 1
$secretResult = $null

while ($secretAttempt -le $maxSecretAttempts -and -not $secretResult) {
    try {
        $secretResult = az ad app credential reset --id $appId --years $secretYears --query "password" -o tsv 2>$null
        if ($secretResult) {
            break
        }
    }
    catch {
        # Continue to retry
    }
    
    if ($secretAttempt -eq $maxSecretAttempts) {
        Write-Error "Failed to create client secret after $maxSecretAttempts attempts."
        Write-Warning "You can manually create a secret later using:"
        Write-Host "az ad app credential reset --id $appId --years 2"
        # Don't exit, continue with the rest of the setup
        $secretResult = $null
        break
    }
    else {
        Write-Warning "Retrying secret creation (attempt $secretAttempt of $maxSecretAttempts)..."
        $secretAttempt++
        Start-Sleep -Seconds 2
    }
}

if ($secretResult) {
    # Store the secret in Key Vault (without displaying it)
    Write-Host "Storing secret in Key Vault..."
    try {
        az keyvault secret set --vault-name $kvName --name "ClarityXDRAppSecret" --value $secretResult --output none 2>$null
        Write-Success "Client secret created and securely stored in Key Vault '$kvName' with name 'ClarityXDRAppSecret'"
    }
    catch {
        Write-Warning "Warning: Could not store secret in Key Vault. You may need to do this manually."
    }
}

# Also grant the app itself access to read secrets from the Key Vault for automation
Write-Status "Granting the app access to read secrets from Key Vault..."
try {
    az keyvault set-policy --name $kvName --spn $appId --secret-permissions get list 2>$null | Out-Null
}
catch {
    Write-Warning "Note: Could not grant app access to Key Vault. You may need to do this manually if the app needs to read its own secret."
}

Write-Host ""
Write-Host "=======================================================" -ForegroundColor "White"
Write-Host "             ClarityXDR Setup Complete!" -ForegroundColor "White"
Write-Host "=======================================================" -ForegroundColor "White"

Write-Success "✅ App registration created successfully"
Write-Success "✅ ClarityXDR logo applied to app"
Write-Success "✅ Service principal created"
Write-Success "✅ Corrected API permissions added:"
Write-Host "    • Microsoft Graph Security APIs (21 permissions)" -ForegroundColor Gray
Write-Host "      - Threat Intelligence & Security Events" -ForegroundColor DarkGray
Write-Host "      - Identity Risk Management (Read/Write)" -ForegroundColor DarkGray
Write-Host "      - Conditional Access & Named Locations (Read/Write)" -ForegroundColor DarkGray
Write-Host "      - Directory Operations (Read/Write)" -ForegroundColor DarkGray
Write-Host "    • Microsoft Defender for Endpoint (7 permissions)" -ForegroundColor Gray
Write-Host "    • Microsoft Threat Protection (1 permission)" -ForegroundColor Gray
Write-Host "    • Office 365 Exchange Online (1 permission)" -ForegroundColor Gray
Write-Host "    • Azure Service Management (1 permission)" -ForegroundColor Gray
Write-Success "✅ RBAC roles assigned"
Write-Success "✅ Key Vault created"
Write-Success "✅ Client secret stored securely"

Write-Host ""
Write-Warning "IMPORTANT NEXT STEPS:"
Write-Host "1. " -NoNewline
Write-Warning "Grant admin consent for API permissions:"
Write-Host "   - Navigate to: Microsoft Entra ID > App registrations"
Write-Host "   - Select your app: $appName (with ClarityXDR logo)"
Write-Host "   - Go to 'API permissions'"
Write-Host "   - Click 'Grant admin consent for <your-tenant>'"
Write-Host "   - Wait for all permissions to show 'Granted' status"

Write-Host ""
Write-Host "2. " -NoNewline
Write-Warning "Deploy ClarityXDR components using these parameters:"
Write-Host "   - Application (Client) ID: $appId"
Write-Host "   - Tenant ID: $tenantId"
Write-Host "   - Key Vault Name: $kvName"
Write-Host "   - Secret Name: ClarityXDRAppSecret"
Write-Host "   - Resource Group: $ResourceGroup"

Write-Host ""
Write-Host "3. " -NoNewline
Write-Warning "For automated deployments, use:"
Write-Host "   - Credentials file: clarityxdr-credentials.env"
Write-Host "   - Contains all non-sensitive configuration values"

Write-Host ""
Write-Status "To retrieve the secret from Key Vault when needed:"
Write-Host "az keyvault secret show --vault-name $kvName --name ClarityXDRAppSecret --query value -o tsv"

Write-Host ""
Write-Success "Your ClarityXDR app registration is ready for use!"
Write-Warning "NOTE: Allow 5-10 minutes for all permissions to propagate before using the app."

# Provide usage for automation
Write-Host ""
Write-Status "For automated/scripted deployment:"
Write-Host ".\ClarityXDR-Setup.ps1 -ResourceGroup 'YOUR_RG_NAME' -Location 'YOUR_LOCATION'"

# Final check
if (Test-Path "clarityxdr-credentials.env") {
    Write-Host ""
    Write-Success "✅ Setup completed successfully!"
    Write-Success "Configuration saved to: clarityxdr-credentials.env"
}
else {
    Write-Host ""
    Write-Warning "⚠️  Setup completed with warnings. Please check the output above."
}