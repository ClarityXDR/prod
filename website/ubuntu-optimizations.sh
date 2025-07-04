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
EOF

# Apply sysctl settings
sysctl -p /etc/sysctl.d/99-docker.conf

print_message "Configuring Docker daemon for production..."

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

# Reload systemd and restart Docker
systemctl daemon-reload
systemctl restart docker

print_message "Setting up firewall rules for Docker..."

# Install ufw if not present
apt-get update && apt-get install -y ufw

# Configure UFW for Docker
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp

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
print_message "System restart recommended to apply all changes."
print_message "Run 'sudo reboot' to restart the system."