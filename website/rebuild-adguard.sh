#!/bin/bash

# AdGuard Home Rebuild Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_message() {
    echo -e "${1}${2}${NC}"
}

print_message $GREEN "🔄 Rebuilding AdGuard Home..."

# Recreate network if it doesn't exist
print_message $YELLOW "Ensuring lan_bridge_macvlan network exists..."
sudo docker network create -d macvlan \
    --subnet=192.168.0.0/24 \
    --gateway=192.168.0.1 \
    --ip-range=192.168.0.240/28 \
    -o parent=$(ip route | grep default | awk '{print $5}' | head -1) \
    lan_bridge_macvlan 2>/dev/null || print_message $YELLOW "Network already exists"

# Stop and remove existing AdGuard container if it exists
print_message $YELLOW "Cleaning up existing AdGuard container..."
sudo docker stop adguardhome 2>/dev/null || true
sudo docker rm adguardhome 2>/dev/null || true

# Create data directories
print_message $YELLOW "Creating data directories..."
sudo mkdir -p /opt/adguardhome/work
sudo mkdir -p /opt/adguardhome/conf

# Set proper permissions
sudo chown -R 999:999 /opt/adguardhome/

# Create AdGuard Home container
print_message $GREEN "Creating AdGuard Home container..."
sudo docker run -d \
    --name adguardhome \
    --network lan_bridge_macvlan \
    --ip 192.168.0.241 \
    --restart unless-stopped \
    -v /opt/adguardhome/work:/opt/adguardhome/work \
    -v /opt/adguardhome/conf:/opt/adguardhome/conf \
    adguard/adguardhome:latest

# Wait for container to start
sleep 5

# Check if container is running
if sudo docker ps | grep -q "adguardhome"; then
    print_message $GREEN "✅ AdGuard Home successfully created!"
    print_message $GREEN "   Web Interface: http://192.168.0.241:3000"
    print_message $GREEN "   DNS Server: 192.168.0.241:53"
    print_message $YELLOW "   First time setup required at web interface"
else
    print_message $RED "❌ Failed to start AdGuard Home"
    print_message $YELLOW "Check logs: sudo docker logs adguardhome"
    exit 1
fi

print_message $GREEN "🎉 AdGuard Home rebuild complete!"
