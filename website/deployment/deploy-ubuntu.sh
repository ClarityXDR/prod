#!/bin/bash

# ClarityXDR Ubuntu One-Line Deployment Script
# Usage: curl -sSL https://raw.githubusercontent.com/ClarityXDR/prod/refs/heads/main/website/deployment/deploy-ubuntu.sh | sudo bash

set -euo pipefail  # Enhanced error handling with undefined variable protection

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global variables
INSTALL_DIR="/opt/clarityxdr"
LOG_FILE="/var/log/clarityxdr-install.log"
REQUIRED_RAM_GB=4
REQUIRED_DISK_GB=20

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

print_message() {
    echo -e "${1}===> ${2}${NC}"
    log "$2"
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

check_prerequisites() {
    print_message $BLUE "Checking prerequisites..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_message $RED "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Check OS version
    if [[ ! -f /etc/os-release ]]; then
        print_message $RED "Cannot detect OS version"
        exit 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" ]] || [[ "${VERSION_ID%%.*}" -lt 20 ]]; then
        print_message $RED "This script requires Ubuntu 20.04 or higher"
        exit 1
    fi
    
    # Check system resources
    local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    local cpu_cores=$(nproc)
    local disk_free_gb=$(df -BG "$INSTALL_DIR" 2>/dev/null | awk 'NR==2 {print int($4)}' || df -BG / | awk 'NR==2 {print int($4)}')
    
    print_message $BLUE "System specs: ${ram_gb}GB RAM, ${cpu_cores} CPU cores, ${disk_free_gb}GB free disk"
    
    if [[ $ram_gb -lt $((REQUIRED_RAM_GB - 1)) ]]; then
        print_message $YELLOW "Warning: Less than ${REQUIRED_RAM_GB}GB RAM detected. ClarityXDR may run slowly."
        echo -n "Continue anyway? (y/N): "
        read -r continue_low_ram
        if [[ ! "$continue_low_ram" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    if [[ $disk_free_gb -lt $REQUIRED_DISK_GB ]]; then
        print_message $RED "Error: Less than ${REQUIRED_DISK_GB}GB free disk space"
        exit 1
    fi
    
    # Check network connectivity
    print_message $BLUE "Checking network connectivity..."
    if ! curl -s --head --fail https://github.com > /dev/null; then
        print_message $RED "Cannot reach GitHub. Please check your internet connection."
        exit 1
    fi
    
    print_message $GREEN "Prerequisites check completed"
}

install_packages() {
    print_message $BLUE "Installing required packages..."
    
    # Set non-interactive mode
    export DEBIAN_FRONTEND=noninteractive
    
    # Update package list with retry logic
    local max_retries=3
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        if apt-get update -qq; then
            break
        fi
        retry_count=$((retry_count + 1))
        print_message $YELLOW "Package update failed, retry $retry_count of $max_retries"
        sleep 5
    done
    
    if [[ $retry_count -eq $max_retries ]]; then
        print_message $RED "Failed to update package list after $max_retries attempts"
        exit 1
    fi
    
    # Fix any broken packages
    print_message $BLUE "Fixing package issues..."
    apt-get install -f -y -qq || true
    dpkg --configure -a || true
    
    # Install Docker
    if command -v docker &> /dev/null; then
        print_message $GREEN "Docker already installed: $(docker --version)"
    else
        print_message $BLUE "Installing Docker..."
        # Try official Docker installation method first
        curl -fsSL https://get.docker.com -o get-docker.sh
        if sh get-docker.sh; then
            print_message $GREEN "Docker installed successfully"
        else
            print_message $YELLOW "Official Docker script failed, trying apt..."
            apt-get install -y -qq docker.io || {
                print_message $RED "Failed to install Docker"
                exit 1
            }
        fi
        rm -f get-docker.sh
    fi
    
    # Install Docker Compose v2
    print_message $BLUE "Installing Docker Compose v2..."
    if docker compose version &> /dev/null; then
        print_message $GREEN "Docker Compose v2 already installed"
    else
        # Install Docker Compose plugin
        mkdir -p /usr/local/lib/docker/cli-plugins
        COMPOSE_VERSION="v2.24.0"
        curl -SL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
            -o /usr/local/lib/docker/cli-plugins/docker-compose
        chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
        
        # Create compatibility wrapper
        cat > /usr/local/bin/docker-compose <<'EOF'
#!/bin/bash
docker compose "$@"
EOF
        chmod +x /usr/local/bin/docker-compose
    fi
    
    # Install other utilities
    print_message $BLUE "Installing utilities..."
    apt-get install -y -qq curl git openssl apache2-utils jq || {
        print_message $RED "Failed to install required utilities"
        exit 1
    }
    
    # Start and enable Docker
    systemctl start docker || true
    systemctl enable docker || true
    
    # Add user to docker group
    if [[ -n "${SUDO_USER:-}" ]]; then
        usermod -aG docker "$SUDO_USER" || true
        print_message $GREEN "Added $SUDO_USER to docker group"
    fi
    
    print_message $GREEN "Package installation completed"
}

validate_input() {
    local input=$1
    local type=$2
    
    case $type in
        "domain")
            if [[ ! "$input" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                print_message $RED "Invalid domain format"
                return 1
            fi
            ;;
        "email")
            if [[ ! "$input" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                print_message $RED "Invalid email format"
                return 1
            fi
            ;;
    esac
    return 0
}

collect_configuration() {
    print_message $BLUE "Configuration setup..."
    
    # Generate secure values
    print_message $BLUE "Generating secure passwords..."
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    ENCRYPTION_KEY=$(openssl rand -base64 24 | tr -d "=+/" | head -c32)
    JWT_SECRET=$(openssl rand -base64 32 | tr -d "=+/")
    TRAEFIK_ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
    TRAEFIK_DASHBOARD_AUTH=$(htpasswd -nb admin "$TRAEFIK_ADMIN_PASSWORD" 2>/dev/null || echo "admin:$(openssl passwd -apr1 "$TRAEFIK_ADMIN_PASSWORD")")
    
    echo ""
    # Domain input with validation
    while true; do
        echo -n "Enter your domain name (e.g., portal.clarityxdr.com): "
        read -r DOMAIN_NAME < /dev/tty
        if validate_input "$DOMAIN_NAME" "domain"; then
            break
        fi
    done
    
    # Email input with validation
    while true; do
        echo -n "Enter your email for SSL certificates: "
        read -r ACME_EMAIL < /dev/tty
        if validate_input "$ACME_EMAIL" "email"; then
            break
        fi
    done
    
    # Optional OpenAI key
    echo -n "Enter OpenAI API Key (optional, press Enter to skip): "
    read -r OPENAI_API_KEY < /dev/tty
    
    # Optional Azure credentials for Logic App deployment
    echo ""
    echo "Azure credentials for Logic App deployment (optional, press Enter to skip each):"
    echo -n "Azure Tenant ID: "
    read -r AZURE_TENANT_ID < /dev/tty
    echo -n "Azure Client ID: "
    read -r AZURE_CLIENT_ID < /dev/tty
    echo -n "Azure Client Secret: "
    read -rs AZURE_CLIENT_SECRET < /dev/tty
    echo ""
    
    print_message $GREEN "Configuration completed"
}

setup_application() {
    print_message $BLUE "Setting up ClarityXDR..."
    
    # Create directory with proper permissions
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Clone or update repository
    if [[ -d ".git" ]]; then
        print_message $BLUE "Updating existing repository..."
        git fetch --all
        git reset --hard origin/main
    else
        print_message $BLUE "Cloning repository..."
        # Try multiple methods to ensure success
        if ! git clone https://github.com/ClarityXDR/prod.git . --depth 1; then
            print_message $YELLOW "Git clone failed, trying alternative method..."
            rm -rf "$INSTALL_DIR"/*
            mkdir -p "$INSTALL_DIR"
            cd "$INSTALL_DIR"
            
            # Download as archive
            curl -L https://github.com/ClarityXDR/prod/archive/refs/heads/main.tar.gz -o clarityxdr.tar.gz
            tar -xzf clarityxdr.tar.gz --strip-components=1
            rm clarityxdr.tar.gz
        fi
    fi
    
    # Verify we have the website directory
    if [[ ! -d "website" ]]; then
        print_message $RED "Website directory not found!"
        exit 1
    fi
    
    cd website
    
    # Create required directories with proper permissions
    mkdir -p letsencrypt backups repositories uploads client-rules logs
    chmod 755 letsencrypt backups repositories uploads client-rules logs
    
    # Create .env file with all configurations
    print_message $BLUE "Creating configuration file..."
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
FRONTEND_URL=https://$DOMAIN_NAME
LICENSE_API_ENDPOINT=https://api.$DOMAIN_NAME/api/licensing/validate

# AI Configuration
OPENAI_API_KEY=$OPENAI_API_KEY
AZURE_OPENAI_ENDPOINT=
AZURE_OPENAI_API_KEY=
AZURE_OPENAI_DEPLOYMENT=

# Azure Configuration for Logic App Deployment
AZURE_TENANT_ID=$AZURE_TENANT_ID
AZURE_CLIENT_ID=$AZURE_CLIENT_ID
AZURE_CLIENT_SECRET=$AZURE_CLIENT_SECRET

# KQL Configuration
KQL_TIMEOUT=60
AGENT_QUERY_TIMEOUT=300

# Logging
LOG_LEVEL=info

# Environment
NODE_ENV=production
EOF
    
    # Secure the .env file
    chmod 600 .env
    
    print_message $GREEN "Application setup completed"
}

start_services() {
    print_message $BLUE "Starting ClarityXDR services..."
    
    cd "$INSTALL_DIR/website"
    
    # Validate docker-compose file
    if [[ ! -f "docker-compose.yml" ]]; then
        print_message $RED "docker-compose.yml not found!"
        exit 1
    fi
    
    # Pull images first to avoid timeout during startup
    print_message $BLUE "Pulling Docker images..."
    docker-compose pull || print_message $YELLOW "Warning: Some images could not be pulled"
    
    # Start services
    print_message $BLUE "Starting Docker containers..."
    if docker-compose up -d; then
        print_message $GREEN "Docker containers started"
    else
        print_message $RED "Failed to start Docker containers"
        docker-compose logs
        exit 1
    fi
    
    # Wait for services to be healthy
    print_message $BLUE "Waiting for services to be healthy..."
    local max_wait=60
    local wait_time=0
    
    while [[ $wait_time -lt $max_wait ]]; do
        if docker-compose ps | grep -q "unhealthy\|starting"; then
            sleep 5
            wait_time=$((wait_time + 5))
        else
            break
        fi
    done
    
    # Check final status
    docker-compose ps
    
    print_message $GREEN "Services started!"
}

configure_firewall() {
    print_message $BLUE "Configuring firewall..."
    
    # Check if ufw is installed
    if command -v ufw &> /dev/null; then
        # Enable firewall if not already enabled
        if ! ufw status | grep -q "Status: active"; then
            ufw --force enable
        fi
        
        # Configure rules
        ufw allow 22/tcp comment "SSH"
        ufw allow 80/tcp comment "HTTP"
        ufw allow 443/tcp comment "HTTPS"
        
        print_message $GREEN "Firewall configured"
    else
        print_message $YELLOW "UFW not installed, skipping firewall configuration"
    fi
}

create_systemd_service() {
    print_message $BLUE "Creating systemd service..."
    
    cat > /etc/systemd/system/clarityxdr.service << EOF
[Unit]
Description=ClarityXDR Docker Compose Application
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=forking
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR/website
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
ExecReload=/usr/local/bin/docker-compose restart
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable clarityxdr.service
    
    print_message $GREEN "Systemd service created and enabled"
}

display_results() {
    print_message $GREEN "=========================================="
    print_message $GREEN "  ClarityXDR Deployment Complete!"
    print_message $GREEN "=========================================="
    echo ""
    echo "Application URLs:"
    echo "  • Main: https://$DOMAIN_NAME"
    echo "  • API: https://api.$DOMAIN_NAME"
    echo "  • Dashboard: https://traefik.$DOMAIN_NAME"
    echo ""
    echo "Traefik Dashboard Login:"
    echo "  • Username: admin"
    echo "  • Password: $TRAEFIK_ADMIN_PASSWORD"
    echo ""
    echo "Important next steps:"
    echo "  1. Point your DNS A records to this server's IP: $(curl -s ifconfig.me 2>/dev/null || echo "Check manually")"
    echo "  2. Ensure firewall ports 80 and 443 are open"
    echo "  3. SSL certificates will be generated automatically after DNS propagation"
    echo ""
    echo "Useful commands:"
    echo "  • View logs: cd $INSTALL_DIR/website && docker-compose logs -f"
    echo "  • Restart: systemctl restart clarityxdr"
    echo "  • Status: systemctl status clarityxdr"
    echo "  • Stop: systemctl stop clarityxdr"
    echo ""
    
    # Save credentials securely
    local creds_file="$INSTALL_DIR/CREDENTIALS.txt"
    cat > "$creds_file" << EOF
ClarityXDR Credentials - $(date)
================================

URLs:
- Main: https://$DOMAIN_NAME
- API: https://api.$DOMAIN_NAME
- Dashboard: https://traefik.$DOMAIN_NAME

Traefik Dashboard:
- Username: admin
- Password: $TRAEFIK_ADMIN_PASSWORD

Database:
- Host: postgres
- Database: clarityxdr
- Username: postgres
- Password: $POSTGRES_PASSWORD

Redis:
- Host: redis
- Password: $REDIS_PASSWORD

Security Keys:
- JWT Secret: $JWT_SECRET
- Encryption Key: $ENCRYPTION_KEY

Installation Details:
- Install Directory: $INSTALL_DIR
- Log File: $LOG_FILE
- Service: clarityxdr.service
EOF
    
    chmod 600 "$creds_file"
    print_message $GREEN "Credentials saved to $creds_file (keep this file secure!)"
    
    # Create backup of configuration
    backup_dir="$INSTALL_DIR/backups/initial-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"
    cp .env "$backup_dir/"
    cp "$creds_file" "$backup_dir/"
    print_message $GREEN "Configuration backed up to $backup_dir"
}

cleanup_on_error() {
    print_message $RED "Installation failed. Check $LOG_FILE for details."
    print_message $YELLOW "To retry, run: sudo $0"
    exit 1
}

main() {
    # Set up error handling
    trap cleanup_on_error ERR
    
    # Initialize log file
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    chmod 640 "$LOG_FILE"
    
    # Run installation steps
    print_banner
    check_prerequisites
    install_packages
    collect_configuration
    setup_application
    configure_firewall
    start_services
    create_systemd_service
    display_results
    
    log "Installation completed successfully"
}

# Run main function
main "$@"
