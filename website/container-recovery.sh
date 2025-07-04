#!/bin/bash

# Container Recovery Script for AdGuard Home and Unifi Controller
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_message() {
    echo -e "${1}${2}${NC}"
}

print_message $GREEN "🔄 Starting container recovery..."

# Recreate network
print_message $YELLOW "Recreating lan_bridge_macvlan network..."
sudo docker network create -d macvlan \
    --subnet=192.168.0.0/24 \
    --gateway=192.168.0.1 \
    --ip-range=192.168.0.240/28 \
    -o parent=$(ip route | grep default | awk '{print $5}' | head -1) \
    lan_bridge_macvlan 2>/dev/null || print_message $YELLOW "Network already exists"

# Check for existing volumes
print_message $YELLOW "Checking for persistent data..."
echo "=== Docker Volumes ==="
sudo docker volume ls | grep -E "(adguard|unifi)" || echo "No AdGuard/Unifi volumes found"

echo -e "\n=== Filesystem Directories ==="
ls -la /opt/ | grep -E "(adguard|unifi)" || echo "No AdGuard/Unifi directories in /opt"

echo -e "\n=== Data Recovery Check ==="
# Check for actual data files
if [ -f "/opt/adguardhome/conf/AdGuardHome.yaml" ]; then
    print_message $GREEN "AdGuard Home configuration found: /opt/adguardhome/conf/AdGuardHome.yaml"
fi

if [ -d "/opt/unifi/data" ]; then
    print_message $GREEN "Unifi Controller data found: /opt/unifi/data"
fi

# Create data directories if they don't exist
print_message $YELLOW "Ensuring data directories exist..."
sudo mkdir -p /opt/adguardhome/work /opt/adguardhome/conf
sudo mkdir -p /opt/unifi
sudo chown -R 999:999 /opt/adguardhome/ /opt/unifi/

# Recreate AdGuard Home
print_message $GREEN "Recreating AdGuard Home..."
sudo docker run -d \
    --name adguardhome \
    --network lan_bridge_macvlan \
    --ip 192.168.0.241 \
    --restart unless-stopped \
    -v /opt/adguardhome/work:/opt/adguardhome/work \
    -v /opt/adguardhome/conf:/opt/adguardhome/conf \
    adguard/adguardhome:latest || print_message $RED "Failed to create AdGuard Home"

# Recreate Unifi Controller
print_message $GREEN "Recreating Unifi Controller..."
sudo docker run -d \
    --name unifi-controller \
    --network lan_bridge_macvlan \
    --ip 192.168.0.242 \
    --restart unless-stopped \
    -v /opt/unifi:/unifi \
    -e RUNAS_UID0=false \
    -e UNIFI_UID=999 \
    -e UNIFI_GID=999 \
    linuxserver/unifi-controller:latest || print_message $RED "Failed to create Unifi Controller"

print_message $GREEN "✅ Recovery complete!"
print_message $YELLOW "Check container status:"
sudo docker ps | grep -E "(adguard|unifi)"
