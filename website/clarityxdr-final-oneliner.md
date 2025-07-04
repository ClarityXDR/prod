## 🚀 ClarityXDR ONE-LINE DEPLOYMENT

### 🧹 COMPLETE CLEANUP & DEPLOYMENT:

If you've had previous failed deployments, use this complete cleanup and deployment command:

```bash
sudo bash -c 'docker-compose down -v 2>/dev/null || true; docker system prune -af; docker volume prune -f; rm -rf /opt/clarityxdr; curl -fsSL https://raw.githubusercontent.com/DataGuys/ClarityXDR/refs/heads/main/website/install.sh | bash'
```

### 🎯 SIMPLE STATIC DEPLOYMENT:

For a quick working demo without complex React build:

```bash
sudo bash -c 'docker run -d -p 80:80 --name clarityxdr-demo -v /tmp/clarityxdr:/usr/share/nginx/html nginx:alpine && curl -fsSL https://raw.githubusercontent.com/DataGuys/ClarityXDR/refs/heads/main/website/main.html > /tmp/clarityxdr/index.html && echo "✅ Demo at http://$(curl -s ifconfig.me || hostname -I | awk \"{print \$1}\")"'
```

### 🔧 NETWORK TROUBLESHOOTING:

If npm install fails due to network issues:

```bash
# Set npm to use different registry
sudo npm config set registry https://registry.npmjs.org/
sudo npm config set fetch-timeout 300000
sudo npm config set fetch-retries 3

# Or try with yarn
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt update && sudo apt install yarn
```

### 🎯 ULTRA-SIMPLE ONE-LINER (with cleanup):

```bash
sudo bash -c 'docker rm -f clarityxdr-simple 2>/dev/null || true && mkdir -p /tmp/clarityxdr && cd /tmp/clarityxdr && curl -fsSL https://raw.githubusercontent.com/DataGuys/ClarityXDR/refs/heads/main/website/main.html > index.html && docker run -d -p 80:80 --name clarityxdr-simple -v /tmp/clarityxdr/index.html:/usr/share/nginx/html/index.html:ro nginx:alpine && echo "✅ ClarityXDR at http://$(hostname -I | awk '\''{print $1}'\'' || ip route get 1 | awk '\''{print $7}'\'' | head -1)"'
```

### 🚨 FALLBACK MINIMAL DEPLOYMENT (with cleanup):

```bash
sudo bash -c '
# Stop and remove existing containers
docker-compose down 2>/dev/null || true
docker rm -f clarityxdr-simple clarityxdr-minimal 2>/dev/null || true

# Create minimal working directory
mkdir -p /opt/clarityxdr-minimal
cd /opt/clarityxdr-minimal

# Download the main HTML file
curl -fsSL https://raw.githubusercontent.com/DataGuys/ClarityXDR/refs/heads/main/website/main.html > index.html

# Create simple docker-compose.yml
cat > docker-compose.yml << "EOF"
version: "3.8"
services:
  frontend:
    image: nginx:alpine
    container_name: clarityxdr-minimal
    ports:
      - "80:80"
    volumes:
      - ./index.html:/usr/share/nginx/html/index.html:ro
    restart: unless-stopped
    command: ["/bin/sh", "-c", "nginx -g \"daemon off;\""]
EOF

# Start the service
docker-compose up -d

# Get LAN IP
LAN_IP=$(hostname -I | awk "{print \$1}" || ip route get 1 | awk "{print \$7}" | head -1 || echo "localhost")
echo "✅ Minimal ClarityXDR running at http://$LAN_IP"
'
```

### 🧹 CLEANUP EXISTING CONTAINERS:

If you need to clean up existing containers first:

```bash
# Remove specific ClarityXDR containers
sudo docker rm -f clarityxdr-simple clarityxdr-minimal 2>/dev/null || true

# Or remove all containers (careful!)
sudo docker rm -f $(sudo docker ps -aq) 2>/dev/null || true

# Clean up Docker system
sudo docker system prune -f
```

### 🔧 MANUAL TROUBLESHOOTING:

If the automated deployment fails, try these manual steps:

```bash
# 1. Complete cleanup
sudo docker-compose down -v 2>/dev/null || true
sudo docker system prune -af
sudo docker volume prune -f
sudo rm -rf /opt/clarityxdr

# 2. Manual installation
sudo mkdir -p /opt/clarityxdr
cd /opt/clarityxdr
sudo git clone https://github.com/DataGuys/ClarityXDR.git .
cd website

# 3. Create .env file
sudo cp .env.example .env 2>/dev/null || sudo tee .env > /dev/null <<EOF
DOMAIN_NAME=localhost
POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)
ENCRYPTION_KEY=$(openssl rand -base64 32 | tr -d '/+=' | head -c 32)
EOF

# 4. Generate frontend dependencies
cd frontend
sudo npm install --package-lock-only 2>/dev/null || true
cd ..

# 5. Start services
sudo docker-compose up -d
```

### 🚨 Common Issues & Solutions:

**Issue 1: npm ci fails**
```bash
cd /opt/clarityxdr/website/frontend
sudo npm install --package-lock-only
cd ..
sudo docker-compose build frontend
sudo docker-compose up -d
```

**Issue 2: Port conflicts**
```bash
sudo netstat -tlnp | grep :80
sudo systemctl stop apache2 nginx 2>/dev/null || true
sudo docker-compose up -d
```

**Issue 3: Permission errors**
```bash
sudo chown -R $USER:$USER /opt/clarityxdr
sudo chmod +x /opt/clarityxdr/website/*.sh
```

### 📋 Post-Installation Commands:

Check status:
```bash
docker ps | grep clarityxdr
```

View logs:
```bash
docker logs -f clarityxdr
```

Stop service:
```bash
docker stop clarityxdr
```

Remove completely:
```bash
docker rm -f clarityxdr && docker volume prune -f
```

### 🔧 Requirements:
- Ubuntu 20.04+ (or any Linux with Docker support)
- Port 80 (and 443 for SSL) available
- 2GB RAM minimum
- 10GB disk space

### 🚨 Troubleshooting:

If the deployment fails, run this diagnostic:

```bash
# Check Docker status
sudo systemctl status docker

# Check for port conflicts
sudo netstat -tlnp | grep :80

# Clean up and retry
sudo docker-compose down -v
sudo docker system prune -f
curl -fsSL https://raw.githubusercontent.com/DataGuys/ClarityXDR/refs/heads/main/website/install.sh | sudo bash
```

### 📋 Manual Cleanup Commands:

```bash
# Stop all ClarityXDR containers
sudo docker stop $(docker ps -q --filter "name=clarityxdr")

# Remove all ClarityXDR containers
sudo docker rm $(docker ps -aq --filter "name=clarityxdr")

# Remove ClarityXDR volumes
sudo docker volume ls | grep clarityxdr | awk '{print $2}' | xargs sudo docker volume rm

# Remove installation directory
sudo rm -rf /opt/clarityxdr
```

### 📖 Full Documentation:
https://github.com/DataGuys/ClarityXDR

### 📋 Get Current LAN IP:

To find your current LAN IP address, run:

```bash
# Method 1: Using hostname
hostname -I | awk '{print $1}'

# Method 2: Using ip route
ip route get 1 | awk '{print $7}' | head -1

# Method 3: Using ifconfig (if available)
ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -1

# Method 4: Using ip addr
ip addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1
```

### 🛡️ SAFE CLEANUP (preserves other containers):

Use this safer cleanup command that only affects ClarityXDR containers:

```bash
# Safe cleanup - only removes ClarityXDR related containers
sudo bash -c 'docker-compose down 2>/dev/null || true; docker rm -f $(docker ps -aq --filter "name=clarityxdr") 2>/dev/null || true; docker image prune -f --filter "label=clarityxdr" 2>/dev/null || true'
```

### 🚨 URGENT: CONTAINER RECOVERY:

If you accidentally removed all containers, you can try to recover them:

```bash
# Check if any containers still exist (stopped)
sudo docker ps -a

# Check for persistent volumes (your data should still be here)
sudo docker volume ls

# Check for any remaining images
sudo docker images

# Look for AdGuard Home and Unifi Controller volumes
sudo docker volume ls | grep -E "(adguard|unifi)"

# Check for bind mounts in common locations
ls -la /opt/adguardhome/ 2>/dev/null || echo "No /opt/adguardhome directory"
ls -la /opt/unifi/ 2>/dev/null || echo "No /opt/unifi directory"
ls -la /var/lib/unifi/ 2>/dev/null || echo "No /var/lib/unifi directory"
```

### 🔧 RECREATE ADGUARD HOME:

```bash
# Recreate the network first
sudo docker network create -d macvlan \
    --subnet=192.168.0.0/24 \
    --gateway=192.168.0.1 \
    --ip-range=192.168.0.240/28 \
    -o parent=$(ip route | grep default | awk '{print $5}' | head -1) \
    lan_bridge_macvlan

# Recreate AdGuard Home (adjust paths as needed)
sudo docker run -d \
    --name adguardhome \
    --network lan_bridge_macvlan \
    --ip 192.168.0.241 \
    --restart unless-stopped \
    -v /opt/adguardhome/work:/opt/adguardhome/work \
    -v /opt/adguardhome/conf:/opt/adguardhome/conf \
    adguard/adguardhome:latest

# Alternative if using Docker volumes
sudo docker run -d \
    --name adguardhome \
    --network lan_bridge_macvlan \
    --ip 192.168.0.241 \
    --restart unless-stopped \
    -v adguardhome_work:/opt/adguardhome/work \
    -v adguardhome_conf:/opt/adguardhome/conf \
    adguard/adguardhome:latest
```

### 🔧 RECREATE UNIFI CONTROLLER:

```bash
# Recreate Unifi Controller (adjust paths as needed)
sudo docker run -d \
    --name unifi-controller \
    --network lan_bridge_macvlan \
    --ip 192.168.0.242 \
    --restart unless-stopped \
    -v /opt/unifi:/unifi \
    -e RUNAS_UID0=false \
    -e UNIFI_UID=999 \
    -e UNIFI_GID=999 \
    linuxserver/unifi-controller:latest

# Alternative if using Docker volumes
sudo docker run -d \
    --name unifi-controller \
    --network lan_bridge_macvlan \
    --ip 192.168.0.242 \
    --restart unless-stopped \
    -v unifi_data:/unifi \
    -e RUNAS_UID0=false \
    -e UNIFI_UID=999 \
    -e UNIFI_GID=999 \
    linuxserver/unifi-controller:latest
```

### 🔍 FIND YOUR DATA:

```bash
# Find AdGuard Home data
find /var/lib/docker/volumes -name "*adguard*" -type d 2>/dev/null
find /opt -name "*adguard*" -type d 2>/dev/null
find /etc -name "*adguard*" -type d 2>/dev/null

# Find Unifi Controller data
find /var/lib/docker/volumes -name "*unifi*" -type d 2>/dev/null
find /opt -name "*unifi*" -type d 2>/dev/null
find /var/lib -name "*unifi*" -type d 2>/dev/null

# Check Docker volumes specifically
sudo docker volume inspect $(sudo docker volume ls -q) | grep -E "(adguard|unifi)" -A 5 -B 5
```

### 🔧 RECOVERY SCRIPT:

```bash
# Create recovery script
cat > /tmp/container_recovery.sh << 'EOF'
#!/bin/bash
echo "=== Container Recovery Script ==="

# Recreate network
echo "Creating lan_bridge_macvlan network..."
sudo docker network create -d macvlan \
    --subnet=192.168.0.0/24 \
    --gateway=192.168.0.1 \
    --ip-range=192.168.0.240/28 \
    -o parent=$(ip route | grep default | awk '{print $5}' | head -1) \
    lan_bridge_macvlan 2>/dev/null || echo "Network already exists"

# Check for existing volumes
echo "Checking for existing volumes..."
ADGUARD_VOLS=$(sudo docker volume ls | grep adguard)
UNIFI_VOLS=$(sudo docker volume ls | grep unifi)

if [ -n "$ADGUARD_VOLS" ]; then
    echo "Found AdGuard volumes: $ADGUARD_VOLS"
fi

if [ -n "$UNIFI_VOLS" ]; then
    echo "Found Unifi volumes: $UNIFI_VOLS"
fi

# Recreate containers (modify as needed)
echo "Recreating containers..."
echo "Please check the volume paths and modify this script as needed"
EOF

chmod +x /tmp/container_recovery.sh
```
