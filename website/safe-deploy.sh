#!/bin/bash

# Ultra-safe deployment script that preserves existing containers
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_message() {
    echo -e "${1}${2}${NC}"
}

print_message $GREEN "🛡️ Safe ClarityXDR Deployment..."

# Pre-deployment checks
print_message $YELLOW "Checking existing containers..."
echo "=== Current AdGuard/Unifi Containers ==="
docker ps -a | grep -E "(adguard|unifi)" || echo "No AdGuard/Unifi containers found"

echo -e "\n=== Current ClarityXDR Containers ==="
docker ps -a | grep clarityxdr || echo "No ClarityXDR containers found"

# Ask for confirmation
read -p "Continue with deployment? This will only affect ClarityXDR containers (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_message $YELLOW "Deployment cancelled"
    exit 1
fi

# Safe cleanup - only ClarityXDR
print_message $YELLOW "Safely cleaning up ClarityXDR containers only..."
docker-compose down 2>/dev/null || true
docker rm -f $(docker ps -aq --filter "name=clarityxdr") 2>/dev/null || true

# Deploy
print_message $GREEN "Starting ClarityXDR deployment..."
docker-compose up -d

# Verify other containers are still running
print_message $GREEN "Verification - checking other containers are still running..."
echo "=== AdGuard/Unifi Status ==="
docker ps | grep -E "(adguard|unifi)" || echo "No AdGuard/Unifi containers running"

echo -e "\n=== ClarityXDR Status ==="
docker ps | grep clarityxdr || echo "No ClarityXDR containers running"

print_message $GREEN "✅ Safe deployment complete!"
