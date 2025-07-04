#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_message() {
    echo -e "${1}${2}${NC}"
}

print_message $GREEN "🚀 Installing ClarityXDR..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    print_message $RED "Please run as root (use sudo)"
    exit 1
fi

# Update system
print_message $YELLOW "Updating system packages..."
apt-get update -y

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    print_message $YELLOW "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable docker
    systemctl start docker
    usermod -aG docker $USER || true
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    print_message $YELLOW "Installing Docker Compose..."
    curl -L "https://github.com/docker/compose/releases/download/v2.24.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
fi

# Install required packages
print_message $YELLOW "Installing required packages..."
apt-get install -y curl wget git openssl nodejs npm

# Create installation directory and clone repository
INSTALL_DIR="/opt/clarityxdr"
print_message $YELLOW "Cloning ClarityXDR repository..."
if [ -d "$INSTALL_DIR" ]; then
    rm -rf "$INSTALL_DIR"
fi
git clone https://github.com/DataGuys/ClarityXDR.git "$INSTALL_DIR"
cd "$INSTALL_DIR/website"

# Create .env file from example or create a new one
if [ ! -f ".env.example" ]; then
    print_message $YELLOW "Creating .env.example file..."
    cat > .env.example <<EOF
# Domain Configuration
DOMAIN_NAME=localhost
ACME_EMAIL=admin@localhost.com

# Database Configuration
POSTGRES_DB=clarityxdr
POSTGRES_USER=postgres
POSTGRES_PASSWORD=CHANGE_ME_TO_SECURE_PASSWORD

# Security
ENCRYPTION_KEY=CHANGE_ME_TO_32_CHAR_ENCRYPTION_KEY_HERE

# API Configuration
REACT_APP_API_URL=http://localhost:8080
EOF
fi

# Copy .env.example to .env
cp .env.example .env

# Set domain if provided
if [ -n "$DOMAIN" ]; then
    sed -i "s/DOMAIN_NAME=.*/DOMAIN_NAME=$DOMAIN/" .env
fi

# Set email if provided
if [ -n "$EMAIL" ]; then
    sed -i "s/ACME_EMAIL=.*/ACME_EMAIL=$EMAIL/" .env
fi

# Generate secure passwords
print_message $YELLOW "Generating secure passwords..."
DB_PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)
ENCRYPTION_KEY=$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)

# Update .env file with secure passwords
if grep -q "POSTGRES_PASSWORD=" .env; then
    sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$DB_PASSWORD/" .env
else
    echo "POSTGRES_PASSWORD=$DB_PASSWORD" >> .env
fi

if grep -q "ENCRYPTION_KEY=" .env; then
    sed -i "s/ENCRYPTION_KEY=.*/ENCRYPTION_KEY=$ENCRYPTION_KEY/" .env
else
    echo "ENCRYPTION_KEY=$ENCRYPTION_KEY" >> .env
fi

# Clean up any existing deployment
print_message $YELLOW "Cleaning up existing ClarityXDR deployments only..."
# Only target ClarityXDR containers specifically
docker-compose -f docker-compose.yml down 2>/dev/null || true
docker rm -f $(docker ps -aq --filter "name=clarityxdr") 2>/dev/null || true
# Remove only ClarityXDR images, not all images
docker rmi $(docker images --filter "reference=*clarityxdr*" -q) 2>/dev/null || true
# Only remove unused volumes (not forced removal of all volumes)
docker volume prune -f --filter "label=clarityxdr" 2>/dev/null || true

# Recreate the lan_bridge_macvlan network if it doesn't exist
print_message $YELLOW "Checking/creating lan_bridge_macvlan network..."
if ! docker network ls | grep -q "lan_bridge_macvlan"; then
    print_message $YELLOW "Creating lan_bridge_macvlan network..."
    # Get the primary network interface
    PRIMARY_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
    # Create macvlan network
    docker network create -d macvlan \
        --subnet=192.168.1.0/24 \
        --gateway=192.168.1.1 \
        --ip-range=192.168.1.240/28 \
        -o parent=$PRIMARY_INTERFACE \
        lan_bridge_macvlan 2>/dev/null || {
        print_message $YELLOW "Failed to create macvlan network, using default bridge"
    }
else
    print_message $GREEN "lan_bridge_macvlan network already exists - preserving existing configuration"
fi

# Create necessary directories
mkdir -p letsencrypt backups repositories uploads init-scripts

# Check if frontend directory exists and create package-lock.json if needed
if [ -d "frontend" ]; then
    print_message $YELLOW "Setting up frontend dependencies..."
    cd frontend
    
    # Install Node.js dependencies and create package-lock.json
    npm config set registry https://registry.npmjs.org/
    npm config set fetch-timeout 300000
    npm config set fetch-retries 3
    
    # Generate package-lock.json first
    if [ ! -f "package-lock.json" ]; then
        print_message $YELLOW "Installing dependencies to generate package-lock.json..."
        npm install --package-lock-only --no-audit --prefer-offline 2>/dev/null || {
            print_message $YELLOW "Fallback: Creating minimal package-lock.json..."
            npm install --no-audit --prefer-offline 2>/dev/null || true
        }
    fi
    
    # Ensure we have basic React files
    if [ ! -d "src" ]; then
        print_message $YELLOW "Creating basic React structure..."
        mkdir -p src public
        echo '<!DOCTYPE html><html><head><title>ClarityXDR</title></head><body><div id="root"></div></body></html>' > public/index.html
        echo 'import React from "react"; import ReactDOM from "react-dom/client"; const root = ReactDOM.createRoot(document.getElementById("root")); root.render(<h1>ClarityXDR</h1>);' > src/index.js
    fi
    
    cd ..
else
    print_message $YELLOW "Frontend directory not found, creating minimal static version..."
    mkdir -p frontend/build
    curl -fsSL https://raw.githubusercontent.com/DataGuys/ClarityXDR/refs/heads/main/website/main.html > frontend/build/index.html
fi

# Apply system optimizations
print_message $YELLOW "Applying system optimizations..."
if [ -f "./ubuntu-optimizations.sh" ]; then
    chmod +x ubuntu-optimizations.sh
    ./ubuntu-optimizations.sh
else
    curl -fsSL https://raw.githubusercontent.com/DataGuys/ClarityXDR/refs/heads/main/website/ubuntu-optimizations.sh > ubuntu-optimizations.sh
    chmod +x ubuntu-optimizations.sh
    ./ubuntu-optimizations.sh
fi

# Start services
print_message $GREEN "Starting ClarityXDR services..."
docker-compose up -d

# Wait for services to be ready
print_message $YELLOW "Waiting for services to initialize..."
sleep 45

# Check if services are running
if docker-compose ps | grep -q "Up"; then
    # Get local LAN IP address instead of WAN
    LAN_IP=$(hostname -I | awk '{print $1}' || ip route get 1 | awk '{print $7}' | head -1 || echo "localhost")
    print_message $GREEN "✅ ClarityXDR deployed successfully!"
    print_message $BLUE "Frontend: http://$LAN_IP"
    print_message $BLUE "Backend: http://$LAN_IP:8080"
    print_message $BLUE "Configuration: $INSTALL_DIR/website/.env"
    print_message $YELLOW "View logs: cd $INSTALL_DIR/website && docker-compose logs -f"
else
    print_message $RED "❌ Deployment failed. Check logs: docker-compose logs"
    exit 1
fi

print_message $GREEN "🎉 Installation complete!"
print_message $YELLOW "System restart recommended to apply all optimizations."
print_message $BLUE "Run 'sudo reboot' to restart the system."
