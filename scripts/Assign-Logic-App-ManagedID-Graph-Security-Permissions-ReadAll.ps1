# Script to assign Microsoft Graph Security API read permissions to a Logic App's managed identity
# Designed to copy-paste directly into Azure Cloud Shell

# EDIT THESE VALUES BEFORE RUNNING:
$managedIdentityObjectId = "7343503f-8af0-46bb-a527-4728f35e8915"
$ResourceGroupName = "InformationSecurity"
$SubscriptionId = "b4e0a897-1c30-4c8a-950f-1117044b8298"  # Leave as $null to use current subscription, or set to "your-subscription-id"

# Set subscription context if provided
if ($SubscriptionId) {
    Set-AzContext -SubscriptionId $SubscriptionId
}

Write-Host "Managed Identity Object ID: $managedIdentityObjectId"

# Connect to Microsoft Graph (available in Cloud Shell)
Connect-MgGraph -Scopes "Application.Read.All","AppRoleAssignment.ReadWrite.All" -NoWelcome

# Microsoft Graph application ID (not Security API specific)
$graphAppId = "00000003-0000-0000-c000-000000000000"
$permissionNames = @(
    "SecurityEvents.Read.All",
    "SecurityIncident.Read.All",
    "SecurityIncident.ReadWrite.All"
)

# Get Microsoft Graph service principal
$graphSp = Get-MgServicePrincipal -Filter "appId eq '$graphAppId'"

if (-not $graphSp) {
    Write-Error "Could not find Microsoft Graph service principal"
    exit 1
}

Write-Host "Found Microsoft Graph service principal: $($graphSp.DisplayName)"

# Process each permission
foreach ($permissionName in $permissionNames) {
    Write-Host "`nProcessing permission: $permissionName" -ForegroundColor Cyan
    
    # Get the app role for the current permission
    $appRole = $graphSp.AppRoles | Where-Object { $_.Value -eq $permissionName -and $_.AllowedMemberTypes -contains "Application" }

    if (-not $appRole) {
        Write-Error "Could not find $permissionName app role in Microsoft Graph"
        continue
    }

    Write-Host "Found app role: $($appRole.Value) (ID: $($appRole.Id))"

    # Check if the role assignment already exists
    $existingAssignment = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $managedIdentityObjectId |
        Where-Object { $_.AppRoleId -eq $appRole.Id -and $_.ResourceId -eq $graphSp.Id }

    if ($existingAssignment) {
        Write-Host "Permission $permissionName already assigned to managed identity" -ForegroundColor Yellow
    } else {
        # Create new role assignment
        Write-Host "Assigning $permissionName permission to managed identity..."
        
        # Create the app role assignment using Microsoft Graph PowerShell
        $params = @{
            PrincipalId = $managedIdentityObjectId
            ResourceId = $graphSp.Id
            AppRoleId = $appRole.Id
        }
        
        try {
            New-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $managedIdentityObjectId -BodyParameter $params
            Write-Host "Successfully assigned $permissionName permission to managed identity" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to assign $permissionName permission: $($_.Exception.Message)"
        }
    }
}

Write-Host "`nPermission assignment process completed." -ForegroundColor Green

