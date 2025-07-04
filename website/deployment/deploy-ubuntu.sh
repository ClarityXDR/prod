#!/bin/bash

# ClarityXDR Ubuntu One-Line Deployment Script
# Usage: curl -sSL https://raw.githubusercontent.com/ClarityXDR/prod/refs/heads/main/website/deployment/deploy-ubuntu.sh | sudo bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_message() {
    local color=$1
    local message=$2
    echo -e "${color}===> ${message}${NC}"
}

print_banner() {
    clear
    echo -e "${GREEN}"
    echo "  ______ _            _ _         __   ______  _____  "
    echo " / _____) |          (_) |       /  \ (_____ \|  _  \ "
    echo "| /     | | ____ ____ _| |_     / /\ \ _____) ) |_)  )"
    echo "| |     | |/ _  |  __) |  _)   / /  \ \  __  /|  _  / "
    echo "| \_____| ( ( | | |  | | |__  / /    \ \ |  \ \| | \ \ "
    echo " \______)_|\_||_|_|  |_|\___)|_/      \_\_|  |_\_|  \_)"
    echo ""
    echo "              Architected by Humans, Operated by AI"
    echo -e "${NC}"
    echo "=================================================================="
    echo ""
}

generate_secure_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

generate_encryption_key() {
    openssl rand -base64 24 | tr -d "=+/"
}

generate_jwt_secret() {
    openssl rand -base64 32 | tr -d "=+/"
}

validate_domain() {
    local domain=$1
    if [[ ! $domain =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 1
    fi
    if [[ $domain =~ ^https?:// ]]; then
        return 1
    fi
    return 0
}

validate_email() {
    local email=$1
    if [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    fi
    return 1
}

check_prerequisites() {
    print_message $BLUE "Checking prerequisites..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_message $RED "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Check system resources
    local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    local cpu_cores=$(nproc)
    
    print_message $BLUE "System specs: ${ram_gb}GB RAM, ${cpu_cores} CPU cores"
    
    if [[ $ram_gb -lt 4 ]]; then
        print_message $YELLOW "Warning: Less than 4GB RAM detected. ClarityXDR may run slowly."
        read -p "Continue anyway? (y/N): " continue_low_ram
        if [[ ! "$continue_low_ram" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Update package list with better error handling
    print_message $BLUE "Updating package list..."
    if ! apt-get update; then
        print_message $RED "Failed to update package list. Please check your internet connection."
        exit 1
    fi
    
    # Install required packages one by one with progress
    local packages=("curl" "git" "docker.io" "docker-compose" "openssl" "apache2-utils")
    
    for package in "${packages[@]}"; do
        print_message $BLUE "Installing $package..."
        if ! apt-get install -y "$package"; then
            print_message $RED "Failed to install $package"
            exit 1
        fi
    done
    
    # Start and enable Docker
    print_message $BLUE "Starting Docker service..."
    systemctl start docker
    systemctl enable docker
    
    # Add current user to docker group if not root
    if [[ -n "$SUDO_USER" ]]; then
        usermod -aG docker "$SUDO_USER"
        print_message $GREEN "Added $SUDO_USER to docker group"
    fi
    
    # Verify Docker is working
    if ! docker --version > /dev/null 2>&1; then
        print_message $RED "Docker installation failed"
        exit 1
    fi
    
    print_message $GREEN "Prerequisites check completed successfully"
}

collect_configuration() {
    print_message $BLUE "Collecting configuration information..."
    echo ""
    
    # Domain name
    while true; do
        echo -n "Enter your domain name (e.g., portal.clarityxdr.com): "
        read DOMAIN_NAME
        if validate_domain "$DOMAIN_NAME"; then
            break
        else
            print_message $RED "Invalid domain name. Please enter a valid FQDN without http:// or https://"
        fi
    done
    
    # Email for SSL certificates
    while true; do
        echo -n "Enter your email for SSL certificates: "
        read ACME_EMAIL
        if validate_email "$ACME_EMAIL"; then
            break
        else
            print_message $RED "Invalid email address"
        fi
    done
    
    # OpenAI API Key
    echo -n "Enter your OpenAI API Key (optional, press Enter to skip): "
    read OPENAI_API_KEY
    
    # Azure OpenAI (optional)
    echo -n "Enter Azure OpenAI Endpoint (optional, press Enter to skip): "
    read AZURE_OPENAI_ENDPOINT
    if [[ -n "$AZURE_OPENAI_ENDPOINT" ]]; then
        echo -n "Enter Azure OpenAI API Key: "
        read AZURE_OPENAI_API_KEY
        echo -n "Enter Azure OpenAI Deployment Name: "
        read AZURE_OPENAI_DEPLOYMENT
    fi
    
    # Generate secure passwords and keys
    print_message $BLUE "Generating secure passwords and encryption keys..."
    POSTGRES_PASSWORD=$(generate_secure_password)
    REDIS_PASSWORD=$(generate_secure_password)
    ENCRYPTION_KEY=$(generate_encryption_key)
    JWT_SECRET=$(generate_jwt_secret)
    
    # Generate Traefik dashboard auth
    TRAEFIK_ADMIN_PASSWORD=$(generate_secure_password)
    TRAEFIK_DASHBOARD_AUTH=$(htpasswd -nb admin "$TRAEFIK_ADMIN_PASSWORD")
    
    print_message $GREEN "Configuration collected successfully"
}

setup_application() {
    print_message $BLUE "Setting up ClarityXDR application..."
    
    # Create application directory
    mkdir -p /opt/clarityxdr
    cd /opt/clarityxdr
    
    # Remove any existing installation
    if [[ -d ".git" ]]; then
        print_message $YELLOW "Existing installation found, updating..."
        git pull
    else
        # Clone repository
        print_message $BLUE "Downloading ClarityXDR from GitHub..."
        git clone https://github.com/ClarityXDR/prod.git .
    fi
    
    cd website
    
    # Create required directories
    mkdir -p letsencrypt backups repositories uploads client-rules
    mkdir -p agent-orchestrator/app/routers
    
    # Create .env file
    print_message $BLUE "Creating environment configuration..."
    cat > .env << EOF
# Domain Configuration
DOMAIN_NAME=$DOMAIN_NAME
ACME_EMAIL=$ACME_EMAIL
TRAEFIK_DASHBOARD_AUTH=$TRAEFIK_DASHBOARD_AUTH

# Database Configuration
POSTGRES_DB=clarityxdr
POSTGRES_USER=postgres
POSTGRES_PASSWORD=$POSTGRES_PASSWORD

# Redis Configuration
REDIS_PASSWORD=$REDIS_PASSWORD

# Security
ENCRYPTION_KEY=$ENCRYPTION_KEY
JWT_SECRET=$JWT_SECRET
JWT_EXPIRES_IN=24h

# API Configuration
REACT_APP_API_URL=https://api.$DOMAIN_NAME

# AI Configuration
OPENAI_API_KEY=$OPENAI_API_KEY
AZURE_OPENAI_ENDPOINT=$AZURE_OPENAI_ENDPOINT
AZURE_OPENAI_API_KEY=$AZURE_OPENAI_API_KEY
AZURE_OPENAI_DEPLOYMENT=$AZURE_OPENAI_DEPLOYMENT

# KQL Configuration
KQL_TIMEOUT=60
AGENT_QUERY_TIMEOUT=300

# Logging
LOG_LEVEL=info

# Environment
NODE_ENV=production
EOF
    
    print_message $GREEN "Application setup completed"
}

apply_optimizations() {
    print_message $BLUE "System optimizations available..."
    
    # Make optimization script executable if it exists
    if [[ -f "ubuntu-optimizations.sh" ]]; then
        chmod +x ubuntu-optimizations.sh
        
        echo -n "Apply system optimizations for Docker? (Y/n): "
        read apply_opts
        if [[ "$apply_opts" =~ ^[Nn]$ ]]; then
            print_message $YELLOW "Skipping system optimizations"
        else
            print_message $BLUE "Applying optimizations..."
            echo "y" | ./ubuntu-optimizations.sh
            print_message $GREEN "System optimizations applied"
        fi
    else
        print_message $YELLOW "Optimization script not found, skipping"
    fi
}

start_services() {
    print_message $BLUE "Starting ClarityXDR services..."
    
    # Check if docker-compose.yml exists
    if [[ ! -f "docker-compose.yml" ]]; then
        print_message $RED "docker-compose.yml not found in $(pwd)"
        print_message $RED "Please check the repository structure"
        exit 1
    fi
    
    # Pull images and start services
    print_message $BLUE "Pulling Docker images..."
    docker-compose pull
    
    print_message $BLUE "Starting services..."
    docker-compose up -d
    
    # Wait for services to start
    print_message $BLUE "Waiting for services to initialize..."
    sleep 30
    
    # Check service health
    print_message $BLUE "Checking service status..."
    docker-compose ps
    
    print_message $GREEN "Services started! Check above for status."
}

display_completion_info() {
    print_message $GREEN "=========================================="
    print_message $GREEN "  ClarityXDR Deployment Complete!"
    print_message $GREEN "=========================================="
    echo ""
    echo -e "${BLUE}Application URLs:${NC}"
    echo "  • Main Application: https://$DOMAIN_NAME"
    echo "  • API Endpoint: https://api.$DOMAIN_NAME"
    echo "  • Traefik Dashboard: https://traefik.$DOMAIN_NAME"
    echo ""
    echo -e "${BLUE}Dashboard Credentials:${NC}"
    echo "  • Username: admin"
    echo "  • Password: $TRAEFIK_ADMIN_PASSWORD"
    echo ""
    echo -e "${BLUE}Important Notes:${NC}"
    echo "  • Make sure DNS for $DOMAIN_NAME points to this server"
    echo "  • SSL certificates will be generated automatically"
    echo "  • Allow firewall access to ports 80 and 443"
    echo ""
    echo -e "${BLUE}Management Commands:${NC}"
    echo "  • View logs: cd /opt/clarityxdr/website && docker-compose logs -f"
    echo "  • Restart: cd /opt/clarityxdr/website && docker-compose restart"
    echo "  • Stop: cd /opt/clarityxdr/website && docker-compose down"
    echo ""
    
    # Save credentials to file
    cat > /opt/clarityxdr/credentials.txt << EOF
ClarityXDR Deployment Credentials
Generated: $(date)

Application URLs:
- Main Application: https://$DOMAIN_NAME
- API Endpoint: https://api.$DOMAIN_NAME
- Traefik Dashboard: https://traefik.$DOMAIN_NAME

Dashboard Credentials:
- Username: admin
- Password: $TRAEFIK_ADMIN_PASSWORD

Database Password: $POSTGRES_PASSWORD
Redis Password: $REDIS_PASSWORD
EOF
    
    chmod 600 /opt/clarityxdr/credentials.txt
    print_message $GREEN "Credentials saved to /opt/clarityxdr/credentials.txt"
}

main() {
    print_banner
    check_prerequisites
    collect_configuration
    setup_application
    apply_optimizations
    start_services
    display_completion_info
}

# Run main function
main "$@"
