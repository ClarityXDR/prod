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
    echo -e "${1}===> ${2}${NC}"
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
    
    # Check system resources
    local ram_gb=$(free -g | awk '/^Mem:/{print $2}')
    local cpu_cores=$(nproc)
    
    print_message $BLUE "System specs: ${ram_gb}GB RAM, ${cpu_cores} CPU cores"
    
    if [[ $ram_gb -lt 3 ]]; then
        print_message $YELLOW "Warning: Less than 4GB RAM detected. ClarityXDR may run slowly."
        echo -n "Continue anyway? (y/N): "
        read continue_low_ram
        if [[ ! "$continue_low_ram" =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    print_message $GREEN "Prerequisites check completed"
}

install_packages() {
    print_message $BLUE "Installing required packages..."
    
    # Set non-interactive mode
    export DEBIAN_FRONTEND=noninteractive
    
    # Update package list
    print_message $BLUE "Updating package list..."
    apt-get update -qq
    
    # Diagnostic information
    print_message $BLUE "Checking system state..."
    echo "Held packages:"
    dpkg --get-selections | grep hold || echo "No held packages found"
    
    echo "Broken packages:"
    dpkg --audit || echo "No broken packages found"
    
    echo "Upgradable packages:"
    apt list --upgradable
    
    echo "Docker package status:"
    apt-cache policy docker.io
    
    # Check and fix any lock files that might be preventing installation
    print_message $BLUE "Checking for lock files..."
    for lock_file in /var/lib/dpkg/lock* /var/cache/apt/archives/lock /var/lib/apt/lists/lock; do
        if [ -e "$lock_file" ]; then
            print_message $YELLOW "Found lock file: $lock_file - attempting to remove"
            rm -f "$lock_file"
        fi
    done
    
    # Fix any broken packages and held packages
    print_message $BLUE "Fixing package issues..."
    apt-get install -f -y -qq
    dpkg --configure -a
    
    # Check for held packages and release them
    if dpkg --get-selections | grep -q hold; then
        print_message $YELLOW "Found held packages, attempting to resolve..."
        dpkg --get-selections | grep hold | awk '{print $1}' | xargs apt-mark unhold
    fi
    
    # Install Docker - check if already installed first
    if command -v docker &> /dev/null; then
        print_message $GREEN "Docker already installed"
        docker --version
    else
        print_message $BLUE "Installing Docker via apt..."
        if apt-get install -y -qq docker.io; then
            print_message $GREEN "Docker installed via apt"
        else
            print_message $YELLOW "Apt failed, trying official Docker script..."
            curl -fsSL https://get.docker.com -o get-docker.sh
            # Run script non-interactively by piping 'yes' to it
            yes | sh get-docker.sh || sh get-docker.sh
            rm get-docker.sh
        fi
    fi
    
    # Install Docker Compose
    print_message $BLUE "Installing Docker Compose..."
    if command -v docker-compose &> /dev/null; then
        print_message $GREEN "Docker Compose already installed"
        docker-compose --version
    else
        # First check if Docker Compose plugin is available (modern Docker installations include this)
        print_message $BLUE "Checking for Docker Compose plugin..."
        if docker compose version &> /dev/null; then
            print_message $GREEN "Docker Compose plugin is available, creating compatibility script"
            # Create a docker-compose script that calls docker compose
            cat > /usr/local/bin/docker-compose <<EOF
#!/bin/bash
docker compose "\$@"
EOF
            chmod +x /usr/local/bin/docker-compose
            print_message $GREEN "Created docker-compose wrapper for docker compose plugin"
        else
            # Best practice: Create isolated virtual environment for Docker Compose
            print_message $BLUE "Setting up isolated virtual environment for Docker Compose..."
            
            # Install required packages
            apt-get install -y -qq python3-full
            
            # Create dedicated virtual environment
            python3 -m venv /opt/docker-compose-venv
            
            # Set secure permissions
            chown -R root:root /opt/docker-compose-venv
            chmod -R 755 /opt/docker-compose-venv
            
            # Install docker-compose in virtual environment
            print_message $BLUE "Installing Docker Compose in virtual environment..."
            /opt/docker-compose-venv/bin/pip install --no-cache-dir docker-compose
            
            # Create secure wrapper script
            print_message $BLUE "Creating secure Docker Compose wrapper..."
            cat > /usr/local/bin/docker-compose <<EOF
#!/bin/bash
# Secure wrapper for docker-compose installed in isolated virtual environment
/opt/docker-compose-venv/bin/docker-compose "\$@"
EOF
            chmod 755 /usr/local/bin/docker-compose
            
            print_message $GREEN "Docker Compose installed in isolated virtual environment (PEP 668 compliant)"
        fi
    fi
    
    # Verify Docker Compose installation
    if ! command -v docker-compose &> /dev/null; then
        print_message $RED "Docker Compose installation failed"
        exit 1
    else
        docker-compose --version
        print_message $GREEN "Docker Compose is ready"
    fi

    print_message $BLUE "Installing utilities..."
    apt-get install -y -qq curl git openssl apache2-utils
    
    # Start Docker
    print_message $BLUE "Starting Docker service..."
    systemctl start docker || true
    systemctl enable docker || true
    
    # Add user to docker group
    if [[ -n "$SUDO_USER" ]]; then
        usermod -aG docker "$SUDO_USER"
        print_message $GREEN "Added $SUDO_USER to docker group"
    fi
    
    # Verify installations
    print_message $BLUE "Verifying installations..."
    if command -v docker &> /dev/null; then
        docker --version
        print_message $GREEN "Docker is ready"
    else
        print_message $RED "Docker installation failed"
        exit 1
    fi
    
    if command -v docker-compose &> /dev/null; then
        docker-compose --version
        print_message $GREEN "Docker Compose is ready"
    else
        print_message $RED "Docker Compose installation failed"
        exit 1
    fi
    
    print_message $GREEN "Package installation completed"
}

collect_configuration() {
    print_message $BLUE "Configuration setup..."
    echo ""
    
    # Simple domain input
    echo -n "Enter your domain name (e.g., portal.clarityxdr.com): "
    read DOMAIN_NAME
    
    # Simple email input  
    echo -n "Enter your email for SSL certificates: "
    read ACME_EMAIL
    
    # Optional OpenAI key
    echo -n "Enter OpenAI API Key (optional, press Enter to skip): "
    read OPENAI_API_KEY
    
    # Generate secure values
    print_message $BLUE "Generating secure passwords..."
    POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    REDIS_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
    ENCRYPTION_KEY=$(openssl rand -base64 24 | tr -d "=+/")
    JWT_SECRET=$(openssl rand -base64 32 | tr -d "=+/")
    TRAEFIK_ADMIN_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/")
    TRAEFIK_DASHBOARD_AUTH=$(htpasswd -nb admin "$TRAEFIK_ADMIN_PASSWORD")
    
    print_message $GREEN "Configuration completed"
}

setup_application() {
    print_message $BLUE "Setting up ClarityXDR..."
    
    # Create directory
    mkdir -p /opt/clarityxdr
    cd /opt/clarityxdr
    
    # Clone repo
    print_message $BLUE "Downloading from GitHub..."
    if [[ -d ".git" ]]; then
        git pull
    else
        git clone https://github.com/ClarityXDR/prod.git .
    fi
    
    cd website
    
    # Create directories
    mkdir -p letsencrypt backups repositories uploads client-rules
    
    # Create .env file
    print_message $BLUE "Creating configuration..."
    cat > .env << EOF
DOMAIN_NAME=$DOMAIN_NAME
ACME_EMAIL=$ACME_EMAIL
TRAEFIK_DASHBOARD_AUTH=$TRAEFIK_DASHBOARD_AUTH
POSTGRES_DB=clarityxdr
POSTGRES_USER=postgres
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
REDIS_PASSWORD=$REDIS_PASSWORD
ENCRYPTION_KEY=$ENCRYPTION_KEY
JWT_SECRET=$JWT_SECRET
JWT_EXPIRES_IN=24h
REACT_APP_API_URL=https://api.$DOMAIN_NAME
OPENAI_API_KEY=$OPENAI_API_KEY
AZURE_OPENAI_ENDPOINT=
AZURE_OPENAI_API_KEY=
AZURE_OPENAI_DEPLOYMENT=
KQL_TIMEOUT=60
AGENT_QUERY_TIMEOUT=300
LOG_LEVEL=info
NODE_ENV=production
EOF
    
    print_message $GREEN "Application setup completed"
}

start_services() {
    print_message $BLUE "Starting ClarityXDR services..."
    
    # Check if compose file exists
    if [[ ! -f "docker-compose.yml" ]]; then
        print_message $RED "docker-compose.yml not found!"
        exit 1
    fi
    
    # Start services
    print_message $BLUE "Starting Docker containers..."
    docker-compose up -d
    
    # Brief wait
    print_message $BLUE "Waiting for services to start..."
    sleep 15
    
    print_message $GREEN "Services started!"
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
    echo "Important:"
    echo "  • Point your DNS records to this server's IP"
    echo "  • Open firewall ports 80 and 443"
    echo "  • SSL certificates will be generated automatically"
    echo ""
    echo "Commands:"
    echo "  • View logs: cd /opt/clarityxdr/website && docker-compose logs -f"
    echo "  • Restart: cd /opt/clarityxdr/website && docker-compose restart"
    echo ""
    
    # Save credentials
    cat > /opt/clarityxdr/CREDENTIALS.txt << EOF
ClarityXDR Credentials - $(date)

URLs:
- Main: https://$DOMAIN_NAME
- API: https://api.$DOMAIN_NAME
- Dashboard: https://traefik.$DOMAIN_NAME

Traefik Login:
- Username: admin
- Password: $TRAEFIK_ADMIN_PASSWORD

Database:
- Password: $POSTGRES_PASSWORD

Redis:
- Password: $REDIS_PASSWORD
EOF
    
    chmod 600 /opt/clarityxdr/CREDENTIALS.txt
    print_message $GREEN "Credentials saved to /opt/clarityxdr/CREDENTIALS.txt"
}

main() {
    print_banner
    check_prerequisites
    install_packages
    collect_configuration
    setup_application
    start_services
    display_results
}

# Run main function
main "$@"
- Password: $POSTGRES_PASSWORD

Redis:
- Password: $REDIS_PASSWORD
EOF
    
    chmod 600 /opt/clarityxdr/CREDENTIALS.txt
    print_message $GREEN "Credentials saved to /opt/clarityxdr/CREDENTIALS.txt"
}

main() {
    print_banner
    check_prerequisites
    install_packages
    collect_configuration
    setup_application
    start_services
    display_results
}

# Run main function
main "$@"
