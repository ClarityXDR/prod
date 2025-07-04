#!/bin/bash
# ClarityXDR Installation Script
# This is what gets executed when someone runs the one-liner

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ASCII Art Banner
echo -e "${BLUE}"
cat << "EOF"
   _____ _            _ _         _  _______ _____  
  / ____| |          (_) |       | |/ /  __ \|  __ \ 
 | |    | | __ _ _ __ _| |_ _   _| ' /| |  | | |__) |
 | |    | |/ _` | '__| | __| | | |  < | |  | |  _  / 
 | |____| | (_| | |  | | |_| |_| | . \| |__| | | \ \ 
  \_____|_|\__,_|_|  |_|\__|\__, |_|\_\_____/|_|  \_\
                             __/ |                    
                            |___/  v1.0 - Quick Deploy
EOF
echo -e "${NC}"

# Function to print messages
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   error "This script must be run as root or with sudo"
   exit 1
fi

# Detect OS
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
else
    error "Cannot detect OS version"
    exit 1
fi

log "Detected OS: $OS $VER"

# Install Docker if not present
install_docker() {
    if command -v docker &> /dev/null; then
        log "Docker is already installed ($(docker --version))"
    else
        log "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
        
        # Start and enable Docker
        systemctl start docker
        systemctl enable docker
        
        log "Docker installed successfully"
    fi
    
    # Install Docker Compose plugin
    if ! docker compose version &> /dev/null 2>&1; then
        log "Installing Docker Compose..."
        apt-get update
        apt-get install -y docker-compose-plugin
    fi
}

# Get user inputs
get_configuration() {
    # Check for environment variables first
    if [[ -z "$DOMAIN" ]]; then
        echo
        read -p "Enter your domain name (or press Enter for localhost): " DOMAIN
        DOMAIN=${DOMAIN:-localhost}
    fi
    
    if [[ "$DOMAIN" != "localhost" ]] && [[ -z "$EMAIL" ]]; then
        read -p "Enter your email for SSL certificates: " EMAIL
    fi
    
    # Generate secure passwords
    POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)}
    ENCRYPTION_KEY=${ENCRYPTION_KEY:-$(openssl rand -base64 32 | head -c 32)}
}

# Create deployment directory and files
setup_deployment() {
    DEPLOY_DIR="/opt/clarityxdr"
    log "Setting up deployment in $DEPLOY_DIR"
    
    # Create directory
    mkdir -p $DEPLOY_DIR
    cd $DEPLOY_DIR
    
    # Create .env file
    cat > .env << EOF
# ClarityXDR Configuration
DOMAIN_NAME=$DOMAIN
ACME_EMAIL=${EMAIL:-admin@$DOMAIN}
POSTGRES_DB=clarityxdr
POSTGRES_USER=postgres
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
ENCRYPTION_KEY=$ENCRYPTION_KEY
REACT_APP_API_URL=https://api.$DOMAIN
EOF
    
    # Create docker-compose.yml
    if [[ "$DOMAIN" == "localhost" ]]; then
        # Local development version (no SSL)
        cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: clarityxdr-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - app-network

  backend:
    image: ghcr.io/dataguys/clarityxdr-backend:latest
    container_name: clarityxdr-backend
    restart: unless-stopped
    environment:
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_USER=${POSTGRES_USER}
      - DB_PASSWORD=${POSTGRES_PASSWORD}
      - DB_NAME=${POSTGRES_DB}
      - ENCRYPTION_KEY=${ENCRYPTION_KEY}
    depends_on:
      postgres:
        condition: service_healthy
    ports:
      - "8080:8080"
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - app-network

  frontend:
    image: ghcr.io/dataguys/clarityxdr-frontend:latest
    container_name: clarityxdr-frontend
    restart: unless-stopped
    environment:
      - REACT_APP_API_URL=http://localhost:8080
    depends_on:
      - backend
    ports:
      - "80:80"
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost/"]
      interval: 30s
      timeout: 10s
      retries: 3
    networks:
      - app-network

volumes:
  postgres_data:
    driver: local

networks:
  app-network:
    driver: bridge
EOF
    else
        # Production version with Traefik and SSL
        cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  traefik:
    image: traefik:v3.0
    container_name: clarityxdr-traefik
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt
    command:
      - --api.insecure=false
      - --providers.docker=true
      - --providers.docker.exposedbydefault=false
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --certificatesresolvers.letsencrypt.acme.tlschallenge=true
      - --certificatesresolvers.letsencrypt.acme.email=${ACME_EMAIL}
      - --certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json
      - --entrypoints.web.http.redirections.entryPoint.to=websecure
      - --entrypoints.web.http.redirections.entryPoint.scheme=https
      - --log.level=INFO
    networks:
      - app-network

  postgres:
    image: postgres:15-alpine
    container_name: clarityxdr-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - app-network

  backend:
    image: ghcr.io/dataguys/clarityxdr-backend:latest
    container_name: clarityxdr-backend
    restart: unless-stopped
    environment:
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_USER=${POSTGRES_USER}
      - DB_PASSWORD=${POSTGRES_PASSWORD}
      - DB_NAME=${POSTGRES_DB}
      - ENCRYPTION_KEY=${ENCRYPTION_KEY}
    depends_on:
      postgres:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.backend.rule=Host(\`api.${DOMAIN_NAME}\`)"
      - "traefik.http.routers.backend.entrypoints=websecure"
      - "traefik.http.routers.backend.tls.certresolver=letsencrypt"
      - "traefik.http.services.backend.loadbalancer.server.port=8080"
    networks:
      - app-network

  frontend:
    image: ghcr.io/dataguys/clarityxdr-frontend:latest
    container_name: clarityxdr-frontend
    restart: unless-stopped
    environment:
      - REACT_APP_API_URL=https://api.${DOMAIN_NAME}
    depends_on:
      - backend
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost/"]
      interval: 30s
      timeout: 10s
      retries: 3
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.frontend.rule=Host(\`${DOMAIN_NAME}\`)"
      - "traefik.http.routers.frontend.entrypoints=websecure"
      - "traefik.http.routers.frontend.tls.certresolver=letsencrypt"
      - "traefik.http.services.frontend.loadbalancer.server.port=80"
    networks:
      - app-network

volumes:
  postgres_data:
    driver: local

networks:
  app-network:
    driver: bridge
EOF
    fi
    
    # Create necessary directories
    mkdir -p letsencrypt
}

# Apply system optimizations
optimize_system() {
    log "Applying system optimizations..."
    
    # Kernel parameters for better Docker performance
    cat > /etc/sysctl.d/99-clarityxdr.conf << EOF
# Network optimizations
net.core.somaxconn = 65535
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
vm.swappiness = 10
fs.file-max = 65535
EOF
    
    sysctl -p /etc/sysctl.d/99-clarityxdr.conf > /dev/null 2>&1
    
    # Docker daemon configuration
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true
}
EOF
    
    systemctl restart docker
}

# Deploy the application
deploy_application() {
    log "Deploying ClarityXDR..."
    
    cd $DEPLOY_DIR
    
    # Pull images
    docker compose pull
    
    # Start services
    docker compose up -d
    
    # Wait for services to be ready
    log "Waiting for services to start..."
    sleep 20
    
    # Check if services are running
    if docker compose ps | grep -E "(running|Up)" > /dev/null; then
        log "Services started successfully"
    else
        error "Some services failed to start"
        docker compose logs
        exit 1
    fi
}

# Show deployment information
show_info() {
    echo
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ ClarityXDR has been deployed successfully!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo
    
    if [[ "$DOMAIN" == "localhost" ]]; then
        echo -e "🌐 Frontend: ${BLUE}http://$(curl -s ifconfig.me)${NC}"
        echo -e "🔧 Backend API: ${BLUE}http://$(curl -s ifconfig.me):8080${NC}"
    else
        echo -e "🌐 Frontend: ${BLUE}https://$DOMAIN${NC}"
        echo -e "🔧 Backend API: ${BLUE}https://api.$DOMAIN${NC}"
        echo
        echo -e "${YELLOW}⚠️  Make sure your DNS records point to this server:${NC}"
        echo -e "   $DOMAIN → $(curl -s ifconfig.me)"
        echo -e "   api.$DOMAIN → $(curl -s ifconfig.me)"
    fi
    
    echo
    echo -e "📁 Installation directory: ${BLUE}$DEPLOY_DIR${NC}"
    echo -e "🔑 Configuration file: ${BLUE}$DEPLOY_DIR/.env${NC}"
    echo
    echo -e "${GREEN}Useful commands:${NC}"
    echo -e "  View status:  ${BLUE}cd $DEPLOY_DIR && docker compose ps${NC}"
    echo -e "  View logs:    ${BLUE}cd $DEPLOY_DIR && docker compose logs -f${NC}"
    echo -e "  Restart:      ${BLUE}cd $DEPLOY_DIR && docker compose restart${NC}"
    echo -e "  Stop:         ${BLUE}cd $DEPLOY_DIR && docker compose down${NC}"
    echo -e "  Update:       ${BLUE}cd $DEPLOY_DIR && docker compose pull && docker compose up -d${NC}"
    echo
    
    # Save installation info
    cat > $DEPLOY_DIR/install-info.txt << EOF
ClarityXDR Installation Information
===================================
Date: $(date)
Domain: $DOMAIN
Directory: $DEPLOY_DIR
Public IP: $(curl -s ifconfig.me)

Database Password: $POSTGRES_PASSWORD
Encryption Key: $ENCRYPTION_KEY

To manage your installation:
cd $DEPLOY_DIR
docker compose [command]
EOF
    
    log "Installation information saved to $DEPLOY_DIR/install-info.txt"
}

# Main installation flow
main() {
    echo
    log "Starting ClarityXDR installation..."
    
    # Step 1: Install Docker
    install_docker
    
    # Step 2: Get configuration
    get_configuration
    
    # Step 3: Setup deployment files
    setup_deployment
    
    # Step 4: Optimize system
    optimize_system
    
    # Step 5: Deploy application
    deploy_application
    
    # Step 6: Show information
    show_info
    
    log "Installation completed!"
}

# Run main function
main
