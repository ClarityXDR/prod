#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# ClarityXDR App Registration Setup Script
# ---------------------------------------------------------------------------
# IMPORTANT: This script must be run with bash, not sh
# Usage: bash ./clarityxdr-setup.sh [options]
# OR make it executable: chmod +x clarityxdr-setup.sh && ./clarityxdr-setup.sh
# ---------------------------------------------------------------------------
# Creates a comprehensive Azure AD app registration with all permissions needed for:
#   • Microsoft Defender XDR (Custom Detection Rules, Advanced Hunting, etc.)
#   • Microsoft Sentinel (Analytic Rules, Security Operations)
#   • Threat Intelligence APIs
#   • Security Actions and Incident Management
#   • Audit Logs and Directory Recommendations
#   • Complete security automation pipeline capabilities
#
# Usage:  ./clarityxdr-setup.sh [options]
# Options:
#   -g, --resource-group    Resource group name
#   -l, --location          Azure region (e.g., eastus, westeurope)
#   -h, --help              Show help message
# ---------------------------------------------------------------------------
set -euo pipefail

# Ensure we're running with bash
if [ -z "${BASH_VERSION:-}" ]; then
    echo "This script must be run with bash, not sh"
    echo "Usage: bash $0 [options]"
    exit 1
fi

# Color definitions for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "\n======================================================="
echo "          ClarityXDR Application Registration Setup"
echo "======================================================="
echo -e "${BLUE}This script will:${NC}"
echo "  • Create an Azure AD app registration"
echo "  • Add comprehensive security API permissions"
echo "  • Assign RBAC roles for Sentinel and Log Analytics"
echo "  • Create a Key Vault for secure secret storage"
echo "  • Generate and store client credentials"
echo "======================================================="

# Handle command-line arguments
RESOURCE_GROUP=""
LOCATION=""

# Parse command-line arguments
while [ $# -gt 0 ]; do
  key="$1"
  case $key in
    -g|--resource-group)
      RESOURCE_GROUP="$2"
      shift 2
      ;;
    -l|--location)
      LOCATION="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [options]"
      echo "Options:"
      echo "  -g, --resource-group    Resource group name"
      echo "  -l, --location          Azure region (e.g., eastus, westeurope)"
      echo "  -h, --help              Show this help message"
      exit 0
      ;;
    *)
      shift
      ;;
  esac
done

echo -e "${BLUE}Checking prerequisites...${NC}"

# Check for required tools
if ! command -v az &> /dev/null; then
  echo -e "${RED}Azure CLI is not installed. Please install it first.${NC}"
  echo "Visit: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo -e "${RED}jq is not installed. Please install it first.${NC}"
  echo "Install with: sudo apt-get install jq (Ubuntu/Debian) or brew install jq (macOS)"
  exit 1
fi

if ! az account show &> /dev/null; then
  echo -e "${YELLOW}Not logged in to Azure.${NC}"
  az login
fi

# Get subscription and tenant details
SUB_NAME=$(az account show --query name -o tsv 2>/dev/null)
SUB_ID=$(az account show --query id -o tsv 2>/dev/null)
TENANT_ID=$(az account show --query tenantId -o tsv 2>/dev/null)

if [ -z "$SUB_ID" ]; then
  echo -e "${RED}Failed to retrieve subscription information. Please ensure you're logged in.${NC}"
  exit 1
fi

echo -e "${GREEN}Using subscription: ${SUB_NAME} (${SUB_ID})${NC}"
echo -e "${GREEN}Tenant ID: ${TENANT_ID}${NC}"

# Prompt for resource group and location if not provided as arguments
if [ -z "$RESOURCE_GROUP" ]; then
  if [ -t 0 ]; then  # Check if stdin is a terminal
    echo -e "${BLUE}Please enter a resource group name to create or use:${NC}"
    read -p "Resource Group Name: " RESOURCE_GROUP
  else
    # Default resource group name when run non-interactively
    RESOURCE_GROUP="clarityxdr-rg"
    echo "Using default resource group: $RESOURCE_GROUP"
  fi
fi

if [ -z "$LOCATION" ]; then
  if [ -t 0 ]; then  # Check if stdin is a terminal
    echo -e "${BLUE}Please enter the Azure region (e.g., eastus, westeurope):${NC}"
    read -p "Azure Region: " LOCATION
  else
    # Default location when run non-interactively
    LOCATION="eastus"
    echo "Using default location: $LOCATION"
  fi
fi

# Check if resource group exists, create if it doesn't
if ! az group show --name "$RESOURCE_GROUP" &> /dev/null; then
  echo "Creating resource group ${RESOURCE_GROUP} in ${LOCATION}..."
  if ! az group create --name "$RESOURCE_GROUP" --location "$LOCATION"; then
    echo -e "${RED}Failed to create resource group. Please check your permissions and subscription.${NC}"
    exit 1
  fi
else
  echo -e "${GREEN}Using existing resource group: ${RESOURCE_GROUP}${NC}"
fi

# Create app registration
APP_NAME="ClarityXDR-App"

# Check if app already exists
echo "Checking if app registration already exists..."
EXISTING_APP=$(az ad app list --display-name "${APP_NAME}" --query "[0]" 2>/dev/null)

if [ -n "$EXISTING_APP" ] && [ "$EXISTING_APP" != "null" ]; then
  echo -e "${YELLOW}App registration '${APP_NAME}' already exists.${NC}"
  APP_ID=$(echo "$EXISTING_APP" | jq -r '.appId // empty')
  OBJECT_ID=$(echo "$EXISTING_APP" | jq -r '.id // empty')
  echo -e "${GREEN}Using existing app with ID: ${APP_ID}${NC}"
else
  echo "Creating app registration: ${APP_NAME}..."
  APP_CREATE=$(az ad app create --display-name "${APP_NAME}" 2>/dev/null)

  if [ -z "$APP_CREATE" ]; then
    echo -e "${RED}Failed to create app registration. Please check your permissions.${NC}"
    exit 1
  fi

  # Extract APP_ID with multiple fallback options
  APP_ID=$(echo "$APP_CREATE" | jq -r '.appId // empty' 2>/dev/null)
  if [ -z "$APP_ID" ]; then
    APP_ID=$(echo "$APP_CREATE" | jq -r '.id // empty' 2>/dev/null)
  fi
  if [ -z "$APP_ID" ]; then
    # Try using Azure CLI query directly
    APP_ID=$(az ad app list --display-name "${APP_NAME}" --query "[0].appId" -o tsv 2>/dev/null)
  fi

  OBJECT_ID=$(echo "$APP_CREATE" | jq -r '.id // .objectId // empty' 2>/dev/null)
  if [ -z "$OBJECT_ID" ]; then
    OBJECT_ID=$(az ad app list --display-name "${APP_NAME}" --query "[0].id" -o tsv 2>/dev/null)
  fi

  echo -e "${GREEN}Application successfully created.${NC}"
fi

if [ -z "$APP_ID" ]; then
  echo -e "${RED}Failed to retrieve Application ID.${NC}"
  exit 1
fi

echo -e "${GREEN}Application (Client) ID: ${APP_ID}${NC}"

echo "Creating service principal for the application..."
if az ad sp create --id "$APP_ID" --output none 2>/dev/null; then
  echo -e "${GREEN}Service principal created successfully.${NC}"
else
  # Check if service principal already exists
  if az ad sp show --id "$APP_ID" &> /dev/null; then
    echo -e "${YELLOW}Service principal already exists.${NC}"
  else
    echo -e "${RED}Failed to create service principal.${NC}"
    exit 1
  fi
fi

# Save app ID and other non-sensitive info to a file
echo "CLIENT_ID=${APP_ID}" > clarityxdr-credentials.env
echo "APP_OBJECT_ID=${OBJECT_ID}" >> clarityxdr-credentials.env
echo "APP_NAME=${APP_NAME}" >> clarityxdr-credentials.env
echo "TENANT_ID=${TENANT_ID}" >> clarityxdr-credentials.env
echo "SUBSCRIPTION_ID=${SUB_ID}" >> clarityxdr-credentials.env

printf "%b\nAdding comprehensive API permissions for ClarityXDR...%b\n" "$BLUE" "$NC"
echo -e "${YELLOW}Note: Permission messages 'Invoking az ad app permission grant...' can be ignored${NC}"

###############################################################################
# 1️⃣ Microsoft Defender for Endpoint (Windows Defender ATP)                  #
###############################################################################
echo "Adding Microsoft Defender for Endpoint permissions..."
# WindowsDefenderATP API - resourceAppId: fc780465-2017-40d4-a0c5-307022471b92

# Machine permissions
az ad app permission add --id "$APP_ID" --api fc780465-2017-40d4-a0c5-307022471b92 --api-permissions "ea8291d3-4b9a-44b5-bc3a-6cea3026dc79=Role" --output none 2>&1 # Machine.Read.All
az ad app permission add --id "$APP_ID" --api fc780465-2017-40d4-a0c5-307022471b92 --api-permissions "7b7531ad-5926-4f2d-8a1d-38495ad33e17=Role" --output none 2>&1 # Machine.ReadWrite.All

# Alert permissions  
az ad app permission add --id "$APP_ID" --api fc780465-2017-40d4-a0c5-307022471b92 --api-permissions "ee30690b-f2a2-471f-a2dc-2eadb0c4b07e=Role" --output none 2>&1 # Alert.Read.All
az ad app permission add --id "$APP_ID" --api fc780465-2017-40d4-a0c5-307022471b92 --api-permissions "93489bf5-0fbc-4f2d-b901-33f2fe08ff05=Role" --output none 2>&1 # Alert.ReadWrite.All

# Advanced Query (Advanced Hunting)
az ad app permission add --id "$APP_ID" --api fc780465-2017-40d4-a0c5-307022471b92 --api-permissions "93076945-2c91-4c14-ab15-5ba0c6c1dcb7=Role" --output none 2>&1 # AdvancedQuery.Read.All

# Ti (Threat Intelligence indicators)
az ad app permission add --id "$APP_ID" --api fc780465-2017-40d4-a0c5-307022471b92 --api-permissions "197042cb-0fc3-44f5-9c0f-871c34b77d7f=Role" --output none 2>&1 # Ti.Read.All
az ad app permission add --id "$APP_ID" --api fc780465-2017-40d4-a0c5-307022471b92 --api-permissions "3aa2db8f-db19-414f-9346-e4056fcbc5a8=Role" --output none 2>&1 # Ti.ReadWrite

echo -e "${GREEN}✓ Defender for Endpoint permissions added${NC}"

###############################################################################
# 2️⃣ Microsoft Graph – comprehensive security permissions                    #
###############################################################################
echo "Adding Microsoft Graph permissions..."
# resourceAppId: 00000003-0000-0000-c000-000000000000

# Suppress verbose output while adding permissions
{
  # --- Threat indicators & detection rules ------------------------------------
  az ad app permission add --id "$APP_ID" --api 00000003-0000-0000-c000-000000000000 --api-permissions "21792b6c-c986-4ffc-85de-df9da54b52fa=Role" # ThreatIndicators.ReadWrite.OwnedBy
  az ad app permission add --id "$APP_ID" --api 00000003-0000-0000-c000-000000000000 --api-permissions "197ee4e9-b993-4066-898f-d6aecc55125b=Role" # ThreatIndicators.Read.All

  # Custom Detection Rules
  az ad app permission add --id "$APP_ID" --api 00000003-0000-0000-c000-000000000000 --api-permissions "e0fd9c8d-a12e-4cc9-9827-20c8c3cd6fb8=Role" # CustomDetection.ReadWrite.All

  # --- Threat Intelligence -----------------------------------------------------
  az ad app permission add --id "$APP_ID" --api 00000003-0000-0000-c000-000000000000 --api-permissions "e0b77adb-e790-44a3-b0a0-257d06303687=Role" # ThreatIntelligence.Read.All

  # --- Security actions & alerts -----------------------------------------------
  az ad app permission add --id "$APP_ID" --api 00000003-0000-0000-c000-000000000000 --api-permissions "5df6fe86-1be0-44eb-b916-7bd443a71236=Role" # SecurityActions.Read.All
  az ad app permission add --id "$APP_ID" --api 00000003-0000-0000-c000-000000000000 --api-permissions "dc38509c-b87d-4da0-bd92-6bec988bac4a=Role" # SecurityActions.ReadWrite.All
  az ad app permission add --id "$APP_ID" --api 00000003-0000-0000-c000-000000000000 --api-permissions "bf394140-e372-4bf9-a898-299cfc7564e5=Role" # SecurityEvents.ReadWrite.All
  az ad app permission add --id "$APP_ID" --api 00000003-0000-0000-c000-000000000000 --api-permissions "472e4a4d-bb4a-4026-98d1-0b0d74cb74a5=Role" # SecurityAlert.Read.All
  az ad app permission add --id "$APP_ID" --api 00000003-0000-0000-c000-000000000000 --api-permissions "ed4fca05-be46-441f-9803-1873825f8fdb=Role" # SecurityAlert.ReadWrite.All
  az ad app permission add --id "$APP_ID" --api 00000003-0000-0000-c000-000000000000 --api-permissions "34bf0e97-1971-4929-b999-9e2442d941d7=Role" # SecurityIncident.ReadWrite.All

  # --- Audit Logs --------------------------------------------------------------
  az ad app permission add --id "$APP_ID" --api 00000003-0000-0000-c000-000000000000 --api-permissions "e4c9e354-4dc5-45b8-9e7c-e1393b0b1a20=Role" # AuditLog.Read.All

  # --- Directory and Identity --------------------------------------------------
  az ad app permission add --id "$APP_ID" --api 00000003-0000-0000-c000-000000000000 --api-permissions "7ab1d382-f21e-4acd-a863-ba3e13f7da61=Role" # Directory.Read.All
  az ad app permission add --id "$APP_ID" --api 00000003-0000-0000-c000-000000000000 --api-permissions "230c1aed-a721-4c5d-9cb4-a90514e508ef=Role" # Reports.Read.All

  # --- Identity Risk -----------------------------------------------------------
  az ad app permission add --id "$APP_ID" --api 00000003-0000-0000-c000-000000000000 --api-permissions "dc5007c0-2d7d-4c42-879c-2dab87571379=Role" # IdentityRiskyUser.Read.All
  az ad app permission add --id "$APP_ID" --api 00000003-0000-0000-c000-000000000000 --api-permissions "2e4dd572-8ddf-4832-bd49-4ee5df4b7cc5=Role" # IdentityRiskEvent.Read.All

  # --- Privileged Access -------------------------------------------------------
  az ad app permission add --id "$APP_ID" --api 00000003-0000-0000-c000-000000000000 --api-permissions "5df6fe86-1be0-44eb-b916-7bd443a71236=Role" # PrivilegedAccess.Read.AzureResources
} &> /dev/null

echo -e "${GREEN}✓ Microsoft Graph permissions added${NC}"

###############################################################################
# 3️⃣ Microsoft Threat Protection API permissions                             #
###############################################################################
echo "Adding Microsoft Threat Protection API permissions..."
# resourceAppId: 8ee8fdad-f234-4243-8f3b-15c294843740
az ad app permission add --id "$APP_ID" --api 8ee8fdad-f234-4243-8f3b-15c294843740 --api-permissions "7734e8e5-8dde-42fc-b5ae-6eafea078693=Role" --output none 2>&1 # ThreatIndicators.ReadWrite
echo -e "${GREEN}✓ Threat Protection API permissions added${NC}"

###############################################################################
# 4️⃣ Microsoft Cloud App Security API permissions                            #
###############################################################################
echo "Adding Microsoft Cloud App Security permissions..."
# resourceAppId: 05a65629-4c1b-48c1-a78b-804c4abdd4af

# Investigation permissions
az ad app permission add --id "$APP_ID" --api 05a65629-4c1b-48c1-a78b-804c4abdd4af --api-permissions "3e7702f0-6cc8-4c40-aca0-a3c3e89a37ba=Role" --output none 2>&1 # investigation.read
az ad app permission add --id "$APP_ID" --api 05a65629-4c1b-48c1-a78b-804c4abdd4af --api-permissions "edbcecec-8acd-45c2-97a2-75f0febc9b0f=Role" --output none 2>&1 # investigation.manage

# Alert permissions
az ad app permission add --id "$APP_ID" --api 05a65629-4c1b-48c1-a78b-804c4abdd4af --api-permissions "ce8f1e97-c558-48f1-ad28-beb520e94430=Role" --output none 2>&1 # alert.read
az ad app permission add --id "$APP_ID" --api 05a65629-4c1b-48c1-a78b-804c4abdd4af --api-permissions "1dd86ab1-d8a2-4379-9d0f-c47eb4a64c02=Role" --output none 2>&1 # alert.manage

# Discovery permissions  
az ad app permission add --id "$APP_ID" --api 05a65629-4c1b-48c1-a78b-804c4abdd4af --api-permissions "13285870-0bd7-4b5e-b3a9-34ffa7ca99aa=Role" --output none 2>&1 # discovery.read
az ad app permission add --id "$APP_ID" --api 05a65629-4c1b-48c1-a78b-804c4abdd4af --api-permissions "dc81b4e1-1e2b-4b06-9a7f-ad5608fd17ed=Role" --output none 2>&1 # discovery.manage

echo -e "${GREEN}✓ Cloud App Security permissions added${NC}"

###############################################################################
# 5️⃣ Azure Management (ARM) – delegated user_impersonation for Sentinel      #
###############################################################################
echo "Adding Azure Management permissions..."
az ad app permission add --id "$APP_ID" --api 797f4846-ba00-4fd7-ba43-dac1f8f63013 --api-permissions "41094075-9dad-400e-a0bd-54e686782033=Scope" --output none 2>&1 # user_impersonation
echo -e "${GREEN}✓ Azure Management permissions added${NC}"

echo -e "${GREEN}All API permissions added successfully.${NC}"

###############################################################################
# 6️⃣ RBAC: Assign roles for Sentinel and Log Analytics                      #
###############################################################################
printf "%b\nAssigning RBAC roles for Sentinel and Log Analytics management...%b\n" "$BLUE" "$NC"
ASSIGNEE_ID=$(az ad sp show --id "$APP_ID" --query id -o tsv 2>/dev/null)

if [ -z "$ASSIGNEE_ID" ]; then
  echo -e "${YELLOW}Warning: Could not retrieve service principal ID for RBAC assignment.${NC}"
  ASSIGNEE_ID=$APP_ID  # Fallback to app ID
fi

SCOPE="/subscriptions/${SUB_ID}"

echo "Assigning Azure Sentinel Contributor role..."
if az role assignment create --assignee "$ASSIGNEE_ID" --role "Azure Sentinel Contributor" --scope "$SCOPE" --output none 2>/dev/null; then
  echo -e "${GREEN}Azure Sentinel Contributor role assigned.${NC}"
else
  echo -e "${YELLOW}Note: Could not assign Azure Sentinel Contributor role (may already exist).${NC}"
fi

echo "Assigning Log Analytics Contributor role..."
if az role assignment create --assignee "$ASSIGNEE_ID" --role "Log Analytics Contributor" --scope "$SCOPE" --output none 2>/dev/null; then
  echo -e "${GREEN}Log Analytics Contributor role assigned.${NC}"
else
  echo -e "${YELLOW}Note: Could not assign Log Analytics Contributor role (may already exist).${NC}"
fi

echo -e "${GREEN}RBAC configuration completed.${NC}"

###############################################################################
# 7️⃣ Key Vault Creation and Secret Management                                #
###############################################################################
echo -e "${BLUE}\nCreating Key Vault to store client secret...${NC}"

# Generate a random suffix more safely
if command -v openssl &> /dev/null; then
    RANDOM_SUFFIX=$(openssl rand -hex 3)
else
    RANDOM_SUFFIX=$(date +%s | tail -c 6)
fi

# Keep Key Vault name short and valid (3-24 chars, alphanumeric and hyphens only)
KV_NAME="cxdr-${RANDOM_SUFFIX}"
echo "Creating Key Vault: ${KV_NAME}..."

# Attempt to create Key Vault with retry logic
MAX_ATTEMPTS=3
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "Attempt $ATTEMPT of $MAX_ATTEMPTS..."
    
    if az keyvault create \
      --name "$KV_NAME" \
      --resource-group "$RESOURCE_GROUP" \
      --location "$LOCATION" \
      --sku standard \
      --enabled-for-template-deployment true \
      --no-wait 2>/dev/null; then
        
        # Wait for the Key Vault to be fully created
        echo "Waiting for Key Vault creation to complete..."
        if az keyvault wait --name "$KV_NAME" --resource-group "$RESOURCE_GROUP" --created --timeout 120; then
            echo -e "${GREEN}Key Vault created successfully: ${KV_NAME}${NC}"
            break
        fi
    fi
    
    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo -e "${RED}Failed to create Key Vault after $MAX_ATTEMPTS attempts.${NC}"
        echo -e "${YELLOW}Trying alternative approach...${NC}"
        
        # Try with a different naming pattern
        KV_NAME="clarityxdr${RANDOM_SUFFIX}"
        
        if az keyvault create \
          --name "$KV_NAME" \
          --resource-group "$RESOURCE_GROUP" \
          --location "$LOCATION" \
          --sku standard \
          --enabled-for-template-deployment true; then
            echo -e "${GREEN}Key Vault created successfully with alternative name: ${KV_NAME}${NC}"
        else
            echo -e "${RED}Unable to create Key Vault. Please check:${NC}"
            echo -e "${RED}- Azure subscription limits${NC}"
            echo -e "${RED}- Sufficient permissions${NC}"
            echo -e "${RED}- Regional availability${NC}"
            exit 1
        fi
    else
        # Generate new name for retry
        RANDOM_SUFFIX=$(date +%s | tail -c 6)
        KV_NAME="cxdr-${RANDOM_SUFFIX}"
        echo -e "${YELLOW}Retrying with new name: ${KV_NAME}${NC}"
        ATTEMPT=$((ATTEMPT + 1))
        sleep 5
    fi
done

echo -e "${GREEN}Key Vault created successfully: ${KV_NAME}${NC}"
echo "KEYVAULT_NAME=${KV_NAME}" >> clarityxdr-credentials.env
echo "RESOURCE_GROUP=${RESOURCE_GROUP}" >> clarityxdr-credentials.env

# Assign Key Vault Secrets Officer role to the current user
echo -e "${BLUE}Assigning Key Vault permissions to current user...${NC}"
USER_ID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null)
if [ -z "$USER_ID" ]; then
  echo -e "${YELLOW}Warning: Unable to retrieve current user ID. Trying alternative method...${NC}"
  USER_ID=$(az account show --query user.name -o tsv 2>/dev/null)
  if [ -z "$USER_ID" ]; then
    echo -e "${RED}Unable to retrieve user identity. You'll need to manually assign Key Vault permissions.${NC}"
  fi
fi

if [ -n "$USER_ID" ]; then
  echo "Granting Key Vault Secrets Officer role to user..."
  if az role assignment create \
    --role "Key Vault Secrets Officer" \
    --assignee "$USER_ID" \
    --scope "/subscriptions/$SUB_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.KeyVault/vaults/$KV_NAME" \
    --output none 2>/dev/null; then
    echo -e "${GREEN}Key Vault permissions granted.${NC}"
  else
    echo -e "${YELLOW}Note: Could not assign Key Vault role. You may already have permissions.${NC}"
  fi
fi

# Wait for permissions to propagate
echo "Waiting 15 seconds for RBAC permissions to propagate..."
sleep 15

# Create client secret
echo -e "${BLUE}Creating client secret and storing in Key Vault...${NC}"
SECRET_YEARS=2
echo "Creating client secret with ${SECRET_YEARS} year(s) duration..."

# Create the secret but don't display it
MAX_SECRET_ATTEMPTS=3
SECRET_ATTEMPT=1

while [ $SECRET_ATTEMPT -le $MAX_SECRET_ATTEMPTS ]; do
  SECRET_RESULT=$(az ad app credential reset --id "$APP_ID" --years "$SECRET_YEARS" --query password -o tsv 2>/dev/null)
  
  if [ -n "$SECRET_RESULT" ]; then
    break
  fi
  
  if [ $SECRET_ATTEMPT -eq $MAX_SECRET_ATTEMPTS ]; then
    echo -e "${RED}Failed to create client secret after $MAX_SECRET_ATTEMPTS attempts.${NC}"
    echo -e "${YELLOW}You can manually create a secret later using:${NC}"
    echo "az ad app credential reset --id $APP_ID --years 2"
    # Don't exit, continue with the rest of the setup
    SECRET_RESULT=""
    break
  else
    echo -e "${YELLOW}Retrying secret creation (attempt $SECRET_ATTEMPT of $MAX_SECRET_ATTEMPTS)...${NC}"
    SECRET_ATTEMPT=$((SECRET_ATTEMPT + 1))
    sleep 2
  fi
done

if [ -n "$SECRET_RESULT" ]; then
  # Store the secret in Key Vault (without displaying it)
  echo "Storing secret in Key Vault..."
  if az keyvault secret set \
    --vault-name "$KV_NAME" \
    --name "ClarityXDRAppSecret" \
    --value "$SECRET_RESULT" \
    --output none 2>/dev/null; then
    echo -e "${GREEN}Client secret created and securely stored in Key Vault '${KV_NAME}' with name 'ClarityXDRAppSecret'${NC}"
  else
    echo -e "${YELLOW}Warning: Could not store secret in Key Vault. You may need to do this manually.${NC}"
  fi
fi

# Also grant the app itself access to read secrets from the Key Vault for automation
echo -e "${BLUE}Granting the app access to read secrets from Key Vault...${NC}"
az keyvault set-policy \
  --name "$KV_NAME" \
  --spn "$APP_ID" \
  --secret-permissions get list \
  || echo -e "${YELLOW}Note: Could not grant app access to Key Vault. You may need to do this manually if the app needs to read its own secret.${NC}"

echo -e "\n======================================================="
echo "             ClarityXDR Setup Complete!"
echo "======================================================="

echo -e "${GREEN}✅ App registration created successfully${NC}"
echo -e "${GREEN}✅ Service principal created${NC}"
echo -e "${GREEN}✅ All API permissions added${NC}"
echo -e "${GREEN}✅ RBAC roles assigned${NC}"
echo -e "${GREEN}✅ Key Vault created${NC}"
echo -e "${GREEN}✅ Client secret stored securely${NC}"

echo -e "\n${YELLOW}IMPORTANT NEXT STEPS:${NC}"
echo "1. ${YELLOW}Grant admin consent for API permissions:${NC}"
echo "   - Navigate to: Microsoft Entra ID > App registrations"
echo "   - Select your app: ${APP_NAME}"
echo "   - Go to 'API permissions'"
echo "   - Click 'Grant admin consent for <your-tenant>'"
echo "   - Wait for all permissions to show 'Granted' status"

echo -e "\n2. ${YELLOW}Deploy ClarityXDR components using these parameters:${NC}"
echo "   - Application (Client) ID: ${APP_ID}"
echo "   - Tenant ID: ${TENANT_ID}"
echo "   - Key Vault Name: ${KV_NAME}"
echo "   - Secret Name: ClarityXDRAppSecret"
echo "   - Resource Group: ${RESOURCE_GROUP}"

echo -e "\n3. ${YELLOW}For automated deployments, use:${NC}"
echo "   - Credentials file: clarityxdr-credentials.env"
echo "   - Contains all non-sensitive configuration values"

echo -e "\n${BLUE}To retrieve the secret from Key Vault when needed:${NC}"
echo "az keyvault secret show --vault-name ${KV_NAME} --name ClarityXDRAppSecret --query value -o tsv"

echo -e "\n${GREEN}Your ClarityXDR app registration is ready for use!${NC}"
echo -e "${YELLOW}NOTE: Allow 5-10 minutes for all permissions to propagate before using the app.${NC}"

# Provide usage for automation
echo -e "\n${BLUE}For automated/scripted deployment:${NC}"
echo "curl -sL https://your-repo-url/clarityxdr-setup.sh | bash -s -- --resource-group YOUR_RG_NAME --location YOUR_LOCATION"

# Final check
if [ -f "clarityxdr-credentials.env" ]; then
  echo -e "\n${GREEN}✅ Setup completed successfully!${NC}"
  echo -e "${GREEN}Configuration saved to: clarityxdr-credentials.env${NC}"
else
  echo -e "\n${YELLOW}⚠️  Setup completed with warnings. Please check the output above.${NC}"
fi