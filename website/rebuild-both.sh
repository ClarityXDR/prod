#!/bin/bash

# Rebuild Both Containers Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_message() {
    echo -e "${1}${2}${NC}"
}

print_message $GREEN "🔄 Rebuilding both AdGuard Home and Unifi Controller..."

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Run AdGuard rebuild
print_message $YELLOW "Step 1: Rebuilding AdGuard Home..."
bash "$SCRIPT_DIR/rebuild-adguard.sh"

echo ""

# Run Unifi rebuild
print_message $YELLOW "Step 2: Rebuilding Unifi Controller..."
bash "$SCRIPT_DIR/rebuild-unifi.sh"

echo ""

# Final status check
print_message $GREEN "🎉 Both containers rebuilt successfully!"
print_message $YELLOW "Container Status:"
sudo docker ps | grep -E "(adguard|unifi)" || print_message $RED "No containers found"

print_message $YELLOW "Network Information:"
sudo docker network inspect lan_bridge_macvlan | grep -A 10 "Containers" || print_message $RED "Network not found"
