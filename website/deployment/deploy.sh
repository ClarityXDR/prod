#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Check required parameters
if [ $# -lt 4 ]; then
    print_message $RED "Usage: $0 <resource-group> <location> <container-registry> <domain-name> [db-password]"
    exit 1
fi

RESOURCE_GROUP=$1
LOCATION=$2
CONTAINER_REGISTRY=$3
DOMAIN_NAME=$4
DB_PASSWORD=$5

# Generate secure password if not provided
if [ -z "$DB_PASSWORD" ]; then
    DB_PASSWORD=$(openssl rand -base64 32)
    print_message $GREEN "Generated secure database password"
fi

# Check if logged in to Azure
if ! az account show > /dev/null 2>&1; then
    print_message $YELLOW "Please login to Azure"
    az login
fi

# Create resource group if it doesn't exist
if ! az group show --name $RESOURCE_GROUP > /dev/null 2>&1; then
    print_message $GREEN "Creating resource group: $RESOURCE_GROUP"
    az group create --name $RESOURCE_GROUP --location $LOCATION
fi

# Create container registry if it doesn't exist
if ! az acr show --name $CONTAINER_REGISTRY --resource-group $RESOURCE_GROUP > /dev/null 2>&1; then
    print_message $GREEN "Creating container registry: $CONTAINER_REGISTRY"
    az acr create --resource-group $RESOURCE_GROUP --name $CONTAINER_REGISTRY --location $LOCATION --sku Basic --admin-enabled true
fi

# Get registry credentials
ACR_USERNAME=$(az acr credential show --name $CONTAINER_REGISTRY --query username -o tsv)
ACR_PASSWORD=$(az acr credential show --name $CONTAINER_REGISTRY --query passwords[0].value -o tsv)
ACR_LOGIN_SERVER=$(az acr show --name $CONTAINER_REGISTRY --query loginServer -o tsv)

# Build Docker images
print_message $GREEN "Building Docker images..."

# Build frontend
docker build -t "$ACR_LOGIN_SERVER/clarityxdr/frontend:latest" ../frontend
if [ $? -ne 0 ]; then
    print_message $RED "Failed to build frontend image"
    exit 1
fi

# Build backend
docker build -t "$ACR_LOGIN_SERVER/clarityxdr/backend:latest" ../backend
if [ $? -ne 0 ]; then
    print_message $RED "Failed to build backend image"
    exit 1
fi

# Login to ACR
print_message $GREEN "Logging in to container registry..."
docker login $ACR_LOGIN_SERVER -u $ACR_USERNAME -p $ACR_PASSWORD

# Push images
print_message $GREEN "Pushing images to registry..."
docker push "$ACR_LOGIN_SERVER/clarityxdr/frontend:latest"
docker push "$ACR_LOGIN_SERVER/clarityxdr/backend:latest"

# Deploy to Azure Container Apps
print_message $GREEN "Deploying to Azure Container Apps..."

az deployment group create \
    --resource-group $RESOURCE_GROUP \
    --template-file ../azure-deployment/azure-container-apps-secure.bicep \
    --parameters \
        containerRegistryUrl=$ACR_LOGIN_SERVER \
        containerRegistryUsername=$ACR_USERNAME \
        containerRegistryPassword=$ACR_PASSWORD \
        domainName=$DOMAIN_NAME \
        dbPassword=$DB_PASSWORD

if [ $? -eq 0 ]; then
    print_message $GREEN "Deployment successful!"
    
    # Get deployment outputs
    FRONTEND_URL=$(az deployment group show --resource-group $RESOURCE_GROUP --name azure-container-apps-secure --query properties.outputs.frontendUrl.value -o tsv)
    BACKEND_URL=$(az deployment group show --resource-group $RESOURCE_GROUP --name azure-container-apps-secure --query properties.outputs.backendUrl.value -o tsv)
    KEY_VAULT=$(az deployment group show --resource-group $RESOURCE_GROUP --name azure-container-apps-secure --query properties.outputs.keyVaultName.value -o tsv)
    STORAGE_ACCOUNT=$(az deployment group show --resource-group $RESOURCE_GROUP --name azure-container-apps-secure --query properties.outputs.storageAccountName.value -o tsv)
    
    print_message $GREEN "Frontend URL: $FRONTEND_URL"
    print_message $GREEN "Backend URL: $BACKEND_URL"
    print_message $GREEN "Key Vault: $KEY_VAULT"
    print_message $GREEN "Storage Account: $STORAGE_ACCOUNT"
    
    # Save deployment info
    cat > deployment-info.json <<EOF
{
    "resourceGroup": "$RESOURCE_GROUP",
    "frontendUrl": "$FRONTEND_URL",
    "backendUrl": "$BACKEND_URL",
    "keyVault": "$KEY_VAULT",
    "storageAccount": "$STORAGE_ACCOUNT",
    "deploymentTime": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
}
EOF
    
    print_message $GREEN "Deployment information saved to deployment-info.json"
else
    print_message $RED "Deployment failed"
    exit 1
fi
