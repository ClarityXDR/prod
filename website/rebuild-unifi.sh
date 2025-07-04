#!/bin/bash

# Unifi Controller Rebuild Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_message() {
    echo -e "${1}${2}${NC}"
}

print_message $GREEN "🔄 Rebuilding Unifi Controller..."

# Recreate network if it doesn't exist
print_message $YELLOW "Ensuring lan_bridge_macvlan network exists..."
sudo docker network create -d macvlan \
    --subnet=192.168.0.0/24 \
    --gateway=192.168.0.1 \
    --ip-range=192.168.0.240/28 \
    -o parent=$(ip route | grep default | awk '{print $5}' | head -1) \
    lan_bridge_macvlan 2>/dev/null || print_message $YELLOW "Network already exists"

# Stop and remove existing Unifi container if it exists
print_message $YELLOW "Cleaning up existing Unifi container..."
sudo docker stop unifi-controller 2>/dev/null || true
sudo docker rm unifi-controller 2>/dev/null || true

# Create data directory
print_message $YELLOW "Creating data directory..."
sudo mkdir -p /opt/unifi

# Set proper permissions
sudo chown -R 999:999 /opt/unifi/

# Create Unifi Controller container
print_message $GREEN "Creating Unifi Controller container..."
sudo docker run -d \
    --name unifi-controller \
    --network lan_bridge_macvlan \
    --ip 192.168.0.242 \
    --restart unless-stopped \
    -v /opt/unifi:/unifi \
    -e RUNAS_UID0=false \
    -e UNIFI_UID=999 \
    -e UNIFI_GID=999 \
    -e TZ=America/New_York \
    linuxserver/unifi-controller:latest

# Wait for container to start
sleep 10

# Check if container is running
if sudo docker ps | grep -q "unifi-controller"; then
    print_message $GREEN "✅ Unifi Controller successfully created!"
    print_message $GREEN "   Web Interface: https://192.168.0.242:8443"
    print_message $GREEN "   Device Communication: 192.168.0.242:8080"
    print_message $YELLOW "   Allow up to 2 minutes for full startup"
    print_message $YELLOW "   Accept SSL certificate warning in browser"
else
    print_message $RED "❌ Failed to start Unifi Controller"
    print_message $YELLOW "Check logs: sudo docker logs unifi-controller"
    exit 1
fi

print_message $GREEN "🎉 Unifi Controller rebuild complete!"
