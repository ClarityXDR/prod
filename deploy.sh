#!/bin/bash

# Production deployment script for ClarityXDR
# Usage: ./deploy-production.sh [blue|green]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to print colored output
print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Load environment variables
if [ ! -f .env ]; then
    print_message $RED "Error: .env file not found!"
    print_message $YELLOW "Please copy .env.example to .env and configure it."
    exit 1
fi

source .env

# Validate required environment variables
required_vars=("DOMAIN_NAME" "POSTGRES_PASSWORD" "ENCRYPTION_KEY" "ACME_EMAIL")
for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        print_message $RED "Error: $var is not set in .env file!"
        exit 1
    fi
done

# Generate secure passwords if not set
if [ "$POSTGRES_PASSWORD" = "CHANGE_ME_TO_SECURE_PASSWORD" ]; then
    print_message $YELLOW "Generating secure database password..."
    POSTGRES_PASSWORD=$(openssl rand -base64 32)
    sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$POSTGRES_PASSWORD/" .env
fi

if [ "$ENCRYPTION_KEY" = "CHANGE_ME_TO_32_CHAR_ENCRYPTION_KEY_HERE" ]; then
    print_message $YELLOW "Generating encryption key..."
    ENCRYPTION_KEY=$(openssl rand -base64 32 | head -c 32)
    sed -i "s/ENCRYPTION_KEY=.*/ENCRYPTION_KEY=$ENCRYPTION_KEY/" .env
fi

# Blue-Green deployment logic
DEPLOYMENT_COLOR=${1:-blue}
if [ "$DEPLOYMENT_COLOR" = "blue" ]; then
    NEW_COLOR="green"
else
    NEW_COLOR="blue"
fi

print_message $BLUE "Starting $NEW_COLOR deployment..."

# Create necessary directories
mkdir -p letsencrypt backups repositories uploads init-scripts

# Pull latest images
print_message $GREEN "Pulling latest images..."
docker-compose -f docker-compose.yml pull

# Build images with production optimizations
print_message $GREEN "Building production images..."
docker-compose -f docker-compose.yml build --no-cache

# Start new deployment
print_message $GREEN "Starting $NEW_COLOR deployment..."
docker-compose -p clarityxdr-$NEW_COLOR up -d

# Wait for health checks
print_message $YELLOW "Waiting for services to be healthy..."
sleep 30

# Check health status
healthy=true
services=("postgres" "backend" "frontend")
for service in "${services[@]}"; do
    if ! docker-compose -p clarityxdr-$NEW_COLOR ps | grep $service | grep -q "healthy"; then
        print_message $RED "Service $service is not healthy!"
        healthy=false
    fi
done

if [ "$healthy" = true ]; then
    # Switch traffic to new deployment
    print_message $GREEN "All services healthy. Switching traffic..."
    
    # Stop old deployment if exists
    if docker-compose -p clarityxdr-$DEPLOYMENT_COLOR ps 2>/dev/null | grep -q "Up"; then
        print_message $YELLOW "Stopping old $DEPLOYMENT_COLOR deployment..."
        docker-compose -p clarityxdr-$DEPLOYMENT_COLOR down
    fi
    
    print_message $GREEN "Deployment successful! Running on $NEW_COLOR."
    
    # Clean up old images
    print_message $YELLOW "Cleaning up old images..."
    docker image prune -f
    
    # Show deployment info
    print_message $BLUE "Deployment Information:"
    echo "Frontend URL: https://$DOMAIN_NAME"
    echo "Backend URL: https://api.$DOMAIN_NAME"
    echo "Deployment Color: $NEW_COLOR"
    echo "Deployment Time: $(date)"
    
    # Save deployment info
    cat > deployment-info.json <<EOF
{
    "deployment_color": "$NEW_COLOR",
    "frontend_url": "https://$DOMAIN_NAME",
    "backend_url": "https://api.$DOMAIN_NAME",
    "deployment_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "status": "success"
}
EOF
    
else
    print_message $RED "Deployment failed! Rolling back..."
    docker-compose -p clarityxdr-$NEW_COLOR down
    exit 1
fi

# One-liner deployment command for CI/CD
# docker-compose pull && docker-compose up -d --remove-orphans
