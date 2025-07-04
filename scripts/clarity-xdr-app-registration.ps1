#Requires -Modules Az.Accounts, Az.Resources, Az.KeyVault, Microsoft.Graph.Applications

<#
.SYNOPSIS
    Creates an Azure AD application registration with necessary permissions for Clarity XDR threat management and indicator synchronization.
.DESCRIPTION
    This script creates an Azure AD application registration with comprehensive permissions for Clarity XDR platform:
    - Microsoft Defender for Endpoint (MDE)
    - Microsoft Threat Protection (MTP)
    - Microsoft Graph API
    - Exchange Online
    - Entra ID named locations
.PARAMETER ResourceGroup
    The name of the resource group to create or use.
.PARAMETER Location
    The Azure region where resources will be created.
.EXAMPLE
    .\clarity-xdr-app-registration.ps1 -ResourceGroup "my-resource-group" -Location "eastus"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroup = "",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = ""
)

# Define all permissions as variables for easy management
#=========================================================

# Microsoft Threat Protection API permissions
$MTP_PERMISSIONS = @(
    # ThreatIndicators.ReadWrite
    @{
        apiId = "8ee8fdad-f234-4243-8f3b-15c294843740"
        permissionId = "7734e8e5-8dde-42fc-b5ae-6eafea078693"
        permissionName = "ThreatIndicators.ReadWrite"
        type = "Role"
    }
)

# Microsoft Graph API permissions
$GRAPH_PERMISSIONS = @(
    # ThreatIndicators.ReadWrite.OwnedBy
    @{
        apiId = "00000003-0000-0000-c000-000000000000"
        permissionId = "21792b6c-c986-4ffc-85de-df9da54b52fa"
        permissionName = "ThreatIndicators.ReadWrite.OwnedBy"
        type = "Role"
    },
    # ThreatIntelligence.Read.Write
    @{
        apiId = "00000003-0000-0000-c000-000000000000"
        permissionId = "197ee4e9-b993-4066-898f-d6aecc55125b"
        permissionName = "ThreatIntelligence.ReadWrite"
        type = "Role"
    },
    # Policy.ReadWrite.ConditionalAccess - For managing named locations
    @{
        apiId = "00000003-0000-0000-c000-000000000000"
        permissionId = "01c0a623-fc9b-48e9-b794-0756f8e8f067"
        permissionName = "Policy.ReadWrite.ConditionalAccess"
        type = "Role"
    },
    # IdentityRiskyUser.Read.All - For XDR capabilities
    @{
        apiId = "00000003-0000-0000-c000-000000000000"
        permissionId = "eb79cd2f-3957-4588-9117-3756b487eeda"
        permissionName = "IdentityRiskyUser.Read.All"
        type = "Role"
    }
)

# Windows Defender ATP API permissions
$WDATP_PERMISSIONS = @(
    @{
        apiId = "fc780465-2017-40d4-a0c5-307022471b92"
        permissionId = "76767153-6b9f-4456-a270-7a8a8a1e68ea"
        permissionName = "AdvancedQuery.Read"
        type = "Role"
    }
)

# Microsoft Defender for Endpoint API permissions
$MDE_PERMISSIONS = @(
    # Ti.ReadWrite - Read and write Indicators
    @{
        apiId = "05a65629-4c1b-48c1-a78b-804c4abdd4af"
        permissionId = "41ba7d20-b411-42ca-9fee-1fbca7b4965f"
        permissionName = "Ti.ReadWrite"
        type = "Role"
    },
    # AdvancedQuery.Read - Run advanced queries
    @{
        apiId = "05a65629-4c1b-48c1-a78b-804c4abdd4af"
        permissionId = "93489bf5-0fbc-4f2d-b901-33f2fe047b58"
        permissionName = "AdvancedQuery.Read"
        type = "Role"
    },
    # Alert.ReadWrite - Read and write alerts
    @{
        apiId = "05a65629-4c1b-48c1-a78b-804c4abdd4af"
        permissionId = "0f7200fb-f9b8-4746-b100-8878cc1cae7c"
        permissionName = "Alert.ReadWrite"
        type = "Role"
    },
    # File.Read.All - Read file profiles
    @{
        apiId = "05a65629-4c1b-48c1-a78b-804c4abdd4af"
        permissionId = "818f499a-6a55-493f-b107-2401dcf0e091"
        permissionName = "File.Read.All"
        type = "Role"
    },
    # Ip.Read.All - Read IP address profiles
    @{
        apiId = "05a65629-4c1b-48c1-a78b-804c4abdd4af"
        permissionId = "b2b7f02a-98e1-445d-a87d-262ad0f8e82e"
        permissionName = "Ip.Read.All"
        type = "Role"
    },
    # Machine.ReadWrite.All - Read and write machine information
    @{
        apiId = "05a65629-4c1b-48c1-a78b-804c4abdd4af"
        permissionId = "46f5409d-9660-4585-9aa0-96e9b0c9baa1"
        permissionName = "Machine.ReadWrite.All"
        type = "Role"
    },
    # SecurityConfiguration.ReadWrite.All - Read and write security configurations
    @{
        apiId = "05a65629-4c1b-48c1-a78b-804c4abdd4af"
        permissionId = "4ac83e46-552f-4057-b63d-774c44c11d11"
        permissionName = "SecurityConfiguration.ReadWrite.All"
        type = "Role"
    },
    # Vulnerability.Read.All - Read vulnerability information
    @{
        apiId = "05a65629-4c1b-48c1-a78b-804c4abdd4af"
        permissionId = "41269fc5-d04d-4635-b70c-9b32597069ad"
        permissionName = "Vulnerability.Read.All"
        type = "Role"
    }
)

# Exchange Online permissions
$EXCHANGE_PERMISSIONS = @(
    # Exchange.ManageAsApp - Required for AntiSpam Filter Policy and Tenant Allow/Block Lists
    @{
        apiId = "00000002-0000-0ff1-ce00-000000000000"
        permissionId = "dc890d15-9560-4a4c-9b7f-a736ec74ec40"
        permissionName = "Exchange.ManageAsApp"
        type = "Role"
    }
)

# Combine all permissions for easier management
$ALL_PERMISSIONS = @() + $MTP_PERMISSIONS + $GRAPH_PERMISSIONS + $WDATP_PERMISSIONS + $MDE_PERMISSIONS + $EXCHANGE_PERMISSIONS

# Script execution starts here
#=========================================================

# Header display
Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "          Clarity XDR Application Registration Setup" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Blue
try {
    $account = Get-AzContext
    if (-not $account) {
        Write-Host "Not logged in to Azure." -ForegroundColor Yellow
        Connect-AzAccount
        $account = Get-AzContext
    }
}
catch {
    Write-Host "Not logged in to Azure." -ForegroundColor Yellow
    Connect-AzAccount
    $account = Get-AzContext
}

# Get subscription and tenant details
$subName = $account.Subscription.Name
$subId = $account.Subscription.Id
$tenantId = $account.Tenant.Id

Write-Host "Using subscription: $subName ($subId)" -ForegroundColor Green
Write-Host "Tenant ID: $tenantId" -ForegroundColor Green

# Prompt for resource group and location if not provided as arguments
if (-not $ResourceGroup) {
    $ResourceGroup = Read-Host -Prompt "Please enter a resource group name to create or use"
}

if (-not $Location) {
    $Location = Read-Host -Prompt "Please enter the Azure region (e.g., eastus, westeurope)"
}

# Check if resource group exists, create if it doesn't
$rgExists = Get-AzResourceGroup -Name $ResourceGroup -ErrorAction SilentlyContinue
if (-not $rgExists) {
    Write-Host "Creating resource group $ResourceGroup in $Location..." -ForegroundColor Blue
    New-AzResourceGroup -Name $ResourceGroup -Location $Location
}

# Create app registration
$appName = "ClarityXDR-ThreatSync-App"
Write-Host "Creating app registration: $appName..." -ForegroundColor Blue

# Check if Microsoft.Graph module is installed
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Applications)) {
    Write-Host "Installing Microsoft.Graph.Applications module..." -ForegroundColor Yellow
    Install-Module -Name Microsoft.Graph.Applications -Scope CurrentUser -Force
}

# Connect to Microsoft Graph if needed
try {
    $graphConnection = Get-MgContext
    if (-not $graphConnection) {
        Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.ReadWrite.All"
    }
} 
catch {
    Connect-MgGraph -Scopes "Application.ReadWrite.All", "Directory.ReadWrite.All"
}

# Create the application
$appProperties = @{
    DisplayName = $appName
    SignInAudience = "AzureADMyOrg"
    Notes = "Clarity XDR application for threat intelligence sync and management"
}

$app = New-MgApplication -BodyParameter $appProperties
$appId = $app.AppId
$objectId = $app.Id

if (-not $appId) {
    Write-Host "Failed to retrieve Application ID." -ForegroundColor Red
    exit 1
}

Write-Host "Application successfully created." -ForegroundColor Green
Write-Host "Application (Client) ID: $appId" -ForegroundColor Green

# Create service principal
Write-Host "Creating service principal for the application..." -ForegroundColor Blue
New-MgServicePrincipal -AppId $appId | Out-Null
Write-Host "Service principal created successfully." -ForegroundColor Green

# Save app ID and other non-sensitive info to a file
@"
CLIENT_ID=$appId
APP_OBJECT_ID=$objectId
APP_NAME=$appName
"@ | Out-File -FilePath "clarityxdr-app-credentials.env" -Encoding ascii

# Add API permissions
Write-Host "Adding required permissions..." -ForegroundColor Blue

foreach ($permission in $ALL_PERMISSIONS) {
    Write-Host "Adding permission: $($permission.permissionName) for API ID: $($permission.apiId)" -ForegroundColor Yellow
    
    $apiPermission = @{
        "resourceAppId" = $permission.apiId
        "resourceAccess" = @(
            @{
                "id" = $permission.permissionId
                "type" = $permission.type
            }
        )
    }

    # Get current permissions
    $currentApp = Get-MgApplication -ApplicationId $objectId
    $currentPermissions = $currentApp.RequiredResourceAccess
    
    # Check if permission already exists
    $permissionExists = $false
    foreach ($existingPermission in $currentPermissions) {
        if ($existingPermission.ResourceAppId -eq $permission.apiId) {
            $resourceAccessExists = $false
            foreach ($existingAccess in $existingPermission.ResourceAccess) {
                if ($existingAccess.Id -eq $permission.permissionId -and $existingAccess.Type -eq $permission.type) {
                    $permissionExists = $true
                    break
                }
            }
            if (-not $permissionExists) {
                # Add to existing ResourceAppId
                $existingPermission.ResourceAccess += @{
                    "Id" = $permission.permissionId
                    "Type" = $permission.type
                }
                $permissionExists = $true
            }
            break
        }
    }
    
    if (-not $permissionExists) {
        # Add new permission
        $currentPermissions += $apiPermission
        Update-MgApplication -ApplicationId $objectId -RequiredResourceAccess $currentPermissions
    }
}

Write-Host "API permissions added successfully." -ForegroundColor Green

# Create a Key Vault for storing the secret
Write-Host "Creating Key Vault to store client secret..." -ForegroundColor Blue
$kvNameSuffix = -join ((97..122) | Get-Random -Count 8 | ForEach-Object {[char]$_})
$kvName = "clarityxdr-kv-$kvNameSuffix"
Write-Host "Creating Key Vault: $kvName..." -ForegroundColor Blue

$keyvault = New-AzKeyVault -Name $kvName -ResourceGroupName $ResourceGroup -Location $Location -Sku Standard -EnabledForTemplateDeployment $true
if (-not $keyvault) {
    Write-Host "Failed to create Key Vault." -ForegroundColor Red
    exit 1
}

Write-Host "Key Vault created successfully: $kvName" -ForegroundColor Green
"KEYVAULT_NAME=$kvName" | Out-File -FilePath "clarityxdr-app-credentials.env" -Encoding ascii -Append

# Assign Key Vault Secrets Officer role to the current user
Write-Host "Assigning Key Vault permissions to current user..." -ForegroundColor Blue
$userId = (Get-AzADUser -SignedIn).Id
if (-not $userId) {
    Write-Host "Unable to retrieve current user ID. Make sure you are logged in with Connect-AzAccount." -ForegroundColor Red
    exit 1
}

Write-Host "Granting Key Vault Secrets Officer role to current user..." -ForegroundColor Blue
try {
    New-AzRoleAssignment -RoleDefinitionName "Key Vault Secrets Officer" -ObjectId $userId -Scope $keyvault.ResourceId
} 
catch {
    Write-Host "Failed to assign Key Vault role. You may need to manually assign permissions." -ForegroundColor Red
    Write-Host "Manual steps: Go to the Key Vault in Azure Portal, select Access Control (IAM), add yourself as 'Key Vault Secrets Officer'." -ForegroundColor Yellow
}

# Wait for permissions to propagate
Write-Host "Waiting 15 seconds for RBAC permissions to propagate..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Create client secret
Write-Host "Creating client secret and storing in Key Vault..." -ForegroundColor Blue
$secretYears = 2
Write-Host "Creating client secret with $secretYears year(s) duration..." -ForegroundColor Blue

# Create app password (secret)
$endDate = (Get-Date).AddYears($secretYears)
$passwordCred = @{
    DisplayName = "Clarity XDR Threat Sync Secret"
    EndDateTime = $endDate
}

$secret = Add-MgApplicationPassword -ApplicationId $objectId -PasswordCredential $passwordCred
if (-not $secret.SecretText) {
    Write-Host "Failed to create client secret." -ForegroundColor Red
    exit 1
}

# Store the secret in Key Vault
$secretValue = ConvertTo-SecureString -String $secret.SecretText -AsPlainText -Force
Set-AzKeyVaultSecret -VaultName $kvName -Name "ClarityXDRAppSecret" -SecretValue $secretValue

Write-Host "Client secret created and securely stored in Key Vault '$kvName' with name 'ClarityXDRAppSecret'" -ForegroundColor Green

Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "            Clarity XDR Setup Complete!" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan

Write-Host "Clarity XDR app registration has been created successfully with necessary security permissions."
Write-Host "Client secret has been securely stored in Key Vault and will be used by the Clarity XDR platform."

Write-Host "`nIMPORTANT NEXT STEPS:" -ForegroundColor Yellow
Write-Host "1. Grant admin consent for API permissions in the Azure Portal:" -ForegroundColor White
Write-Host "   - Navigate to: Microsoft Entra ID > App registrations" -ForegroundColor White
Write-Host "   - Select your app: $appName" -ForegroundColor White
Write-Host "   - Go to 'API permissions'" -ForegroundColor White
Write-Host "   - Click 'Grant admin consent for $($account.Tenant.Name)'" -ForegroundColor White

Write-Host "`n2. For using in a Runbook with a Managed Identity:" -ForegroundColor White
Write-Host "   - Create an Azure Automation account with a System-assigned Managed Identity" -ForegroundColor White
Write-Host "   - Grant the Managed Identity access to the Key Vault" -ForegroundColor White
Write-Host "   - In your runbook, use the Managed Identity to retrieve the client secret" -ForegroundColor White

Write-Host "`nYour Clarity XDR app registration and Key Vault details have been saved to: clarityxdr-app-credentials.env" -ForegroundColor White
Write-Host "NOTE: Your client secret has been securely stored in Key Vault and is NOT in the credentials file." -ForegroundColor Yellow
