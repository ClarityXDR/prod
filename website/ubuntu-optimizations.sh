#!/bin/bash

# Ubuntu Production Optimizations for Docker
# Run with: sudo ./ubuntu-optimizations.sh

set -e

print_message() {
    echo "===> $1"
}

print_message "Applying Ubuntu kernel optimizations for Docker..."

# Create sysctl configuration for Docker
cat > /etc/sysctl.d/99-docker.conf <<EOF
# Network optimizations
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_max_syn_backlog = 8192

# File system optimizations
fs.file-max = 65535
fs.inotify.max_user_watches = 524288

# Memory optimizations
vm.swappiness = 10
vm.dirty_ratio = 15

# Additional network optimizations
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 60
net.ipv4.tcp_keepalive_probes = 3

# Disable IPv6 if not needed
# net.ipv6.conf.all.disable_ipv6 = 1
# net.ipv6.conf.default.disable_ipv6 = 1
EOF

# Apply sysctl settings without reboot
sysctl -p /etc/sysctl.d/99-docker.conf

print_message "Configuring Docker daemon for production..."

# Check if Docker daemon.json exists and backup if it does
if [ -f /etc/docker/daemon.json ]; then
    print_message "Backing up existing Docker daemon configuration"
    cp /etc/docker/daemon.json /etc/docker/daemon.json.bak.$(date +%Y%m%d%H%M%S)
fi

# Create Docker daemon configuration
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "5"
  },
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  },
  "live-restore": true,
  "userland-proxy": false,
  "experimental": false,
  "features": {
    "buildkit": true
  },
  "metrics-addr": "127.0.0.1:9323"
}
EOF

# Create systemd override for Docker
mkdir -p /etc/systemd/system/docker.service.d
cat > /etc/systemd/system/docker.service.d/override.conf <<EOF
[Service]
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
Restart=on-failure
StartLimitInterval=60s
StartLimitBurst=3
EOF

# Ask before restarting Docker
print_message "WARNING: Restarting Docker will temporarily stop all running containers"
read -p "Would you like to restart Docker now? (y/N): " RESTART_DOCKER
if [[ "$RESTART_DOCKER" =~ ^[Yy]$ ]]; then
    print_message "Restarting Docker service..."
    systemctl daemon-reload
    systemctl restart docker
else
    print_message "Docker service NOT restarted. Please restart manually when convenient:"
    print_message "sudo systemctl daemon-reload && sudo systemctl restart docker"
fi

print_message "Setting up firewall rules for Docker..."

# Install ufw if not present
apt-get update && apt-get install -y ufw

# Check for existing UFW rules
EXISTING_RULES=$(ufw status numbered | grep -c "(v6)")
if [ $EXISTING_RULES -gt 0 ]; then
    print_message "WARNING: UFW already has rules configured."
    read -p "Would you like to configure UFW for Docker? This may modify existing rules. (y/N): " CONFIGURE_UFW
    if [[ ! "$CONFIGURE_UFW" =~ ^[Yy]$ ]]; then
        print_message "Skipping UFW configuration."
        UFW_SKIP=true
    fi
fi

if [ -z "$UFW_SKIP" ]; then
    # Configure UFW for Docker
    ufw --force enable
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Add rules for Docker inter-container communication
    ufw allow in on docker0 from 172.16.0.0/12
    ufw allow in on docker0 from 192.168.0.0/16
    
    print_message "UFW configured for Docker."
fi

print_message "Installing Docker Compose v2..."

# Check if Docker Compose is already installed
if command -v docker-compose &> /dev/null; then
    CURRENT_VERSION=$(docker-compose version --short 2>/dev/null || echo "unknown")
    print_message "Docker Compose already installed: $CURRENT_VERSION"
    print_message "Skipping installation to avoid conflicts"
else
    # Install Docker Compose v2
    DOCKER_COMPOSE_VERSION="v2.24.0"
    curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    print_message "Docker Compose v2 installed successfully"
fi

print_message "Setting up log rotation..."

# Configure log rotation for Docker containers
cat > /etc/logrotate.d/docker-containers <<EOF
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    size 10M
    missingok
    delaycompress
    copytruncate
}
EOF

print_message "Creating Docker monitoring script..."

# Create monitoring script
cat > /usr/local/bin/docker-monitor.sh <<'EOF'
#!/bin/bash
# Docker monitoring script

echo "=== Docker System Info ==="
docker system df

echo -e "\n=== Running Containers ==="
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Size}}"

echo -e "\n=== Container Resource Usage ==="
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"

echo -e "\n=== Docker Events (last hour) ==="
docker events --since 1h --until now
EOF

chmod +x /usr/local/bin/docker-monitor.sh

print_message "Ubuntu optimizations completed!"
print_message "NOTE: Docker restart was handled carefully to preserve existing containers."
print_message "System restart recommended to apply all kernel changes."
print_message "Run 'sudo reboot' to restart the system when convenient."