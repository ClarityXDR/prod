param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$Location,
    
    [Parameter(Mandatory=$true)]
    [string]$ContainerRegistryName,
    
    [Parameter(Mandatory=$true)]
    [string]$DomainName,
    
    [Parameter(Mandatory=$false)]
    [SecureString]$DbPassword
)

# Generate secure password if not provided
if (-not $DbPassword) {
    Add-Type -AssemblyName System.Web
    $DbPassword = [System.Web.Security.Membership]::GeneratePassword(32, 8)
    Write-Host "Generated secure database password" -ForegroundColor Green
}

# Check if logged in to Azure
$context = Get-AzContext
if (-not $context) {
    Write-Host "Please login to Azure" -ForegroundColor Yellow
    Connect-AzAccount
}

# Create resource group if it doesn't exist
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) {
    Write-Host "Creating resource group: $ResourceGroupName" -ForegroundColor Green
    $rg = New-AzResourceGroup -Name $ResourceGroupName -Location $Location
}

# Create container registry if it doesn't exist
$acr = Get-AzContainerRegistry -ResourceGroupName $ResourceGroupName -Name $ContainerRegistryName -ErrorAction SilentlyContinue
if (-not $acr) {
    Write-Host "Creating container registry: $ContainerRegistryName" -ForegroundColor Green
    $acr = New-AzContainerRegistry -ResourceGroupName $ResourceGroupName -Name $ContainerRegistryName -Location $Location -Sku Basic -EnableAdminUser
}

# Get registry credentials
$acrCreds = Get-AzContainerRegistryCredential -ResourceGroupName $ResourceGroupName -Name $ContainerRegistryName

# Build and push Docker images
Write-Host "Building Docker images..." -ForegroundColor Green

# Build frontend
docker build -t "$($acr.LoginServer)/clarityxdr/frontend:latest" ../frontend
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to build frontend image"
    exit 1
}

# Build backend
docker build -t "$($acr.LoginServer)/clarityxdr/backend:latest" ../backend
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to build backend image"
    exit 1
}

# Login to ACR
Write-Host "Logging in to container registry..." -ForegroundColor Green
docker login $acr.LoginServer -u $acrCreds.Username -p $acrCreds.Password

# Push images
Write-Host "Pushing images to registry..." -ForegroundColor Green
docker push "$($acr.LoginServer)/clarityxdr/frontend:latest"
docker push "$($acr.LoginServer)/clarityxdr/backend:latest"

# Deploy to Azure Container Apps
Write-Host "Deploying to Azure Container Apps..." -ForegroundColor Green

$deploymentParams = @{
    'containerRegistryUrl' = $acr.LoginServer
    'containerRegistryUsername' = $acrCreds.Username
    'containerRegistryPassword' = $acrCreds.Password
    'domainName' = $DomainName
    'dbPassword' = $DbPassword
}

$deployment = New-AzResourceGroupDeployment `
    -ResourceGroupName $ResourceGroupName `
    -TemplateFile "../azure-deployment/azure-container-apps-secure.bicep" `
    -TemplateParameterObject $deploymentParams

if ($deployment.ProvisioningState -eq 'Succeeded') {
    Write-Host "Deployment successful!" -ForegroundColor Green
    Write-Host "Frontend URL: $($deployment.Outputs.frontendUrl.Value)" -ForegroundColor Cyan
    Write-Host "Backend URL: $($deployment.Outputs.backendUrl.Value)" -ForegroundColor Cyan
    Write-Host "Key Vault: $($deployment.Outputs.keyVaultName.Value)" -ForegroundColor Cyan
    Write-Host "Storage Account: $($deployment.Outputs.storageAccountName.Value)" -ForegroundColor Cyan
    
    # Save deployment info
    $deploymentInfo = @{
        ResourceGroup = $ResourceGroupName
        FrontendUrl = $deployment.Outputs.frontendUrl.Value
        BackendUrl = $deployment.Outputs.backendUrl.Value
        KeyVault = $deployment.Outputs.keyVaultName.Value
        StorageAccount = $deployment.Outputs.storageAccountName.Value
        DeploymentTime = Get-Date
    }
    
    $deploymentInfo | ConvertTo-Json | Out-File "deployment-info.json"
    Write-Host "Deployment information saved to deployment-info.json" -ForegroundColor Green
} else {
    Write-Error "Deployment failed: $($deployment.ProvisioningState)"
    exit 1
}
