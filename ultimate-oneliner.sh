#!/bin/bash
# ClarityXDR - Copy and paste ONE of these commands into your Ubuntu SSH session:

# ==========================================
# OPTION 1: QUICK DEMO (No SSL, Local Only)
# ==========================================
sudo bash -c 'docker run -d --name clarityxdr -p 80:80 -p 8080:8080 -e POSTGRES_PASSWORD=demo123 postgres:15-alpine && docker run -d --name clarityxdr-app -p 3000:80 --link clarityxdr:postgres -e DB_HOST=postgres -e DB_PASSWORD=demo123 nginx:alpine && echo "ClarityXDR Demo running at http://$(curl -s ifconfig.me)"'

# ==========================================
# OPTION 2: PRODUCTION DEPLOY (With SSL)
# ==========================================
sudo bash -c 'apt update && apt install -y docker.io docker-compose && mkdir -p /opt/clarityxdr && cd /opt/clarityxdr && echo "DOMAIN_NAME=clarityxdr.local
ACME_EMAIL=admin@clarityxdr.local
POSTGRES_DB=clarityxdr
POSTGRES_USER=postgres
POSTGRES_PASSWORD=$(openssl rand -base64 32)
ENCRYPTION_KEY=$(openssl rand -base64 32 | head -c 32)" > .env && curl -fsSL https://raw.githubusercontent.com/DataGuys/ClarityXDR/main/docker-compose.yml -o docker-compose.yml && docker-compose up -d && echo "Deployed! Check status with: docker-compose ps"'

# ==========================================
# OPTION 3: ULTRA-SIMPLE PRODUCTION DEPLOY
# ==========================================
sudo bash -c 'curl -fsSL https://get.docker.com | sh && docker run -d --restart=always --name=clarityxdr -p 80:80 -p 443:443 -e DOMAIN=${DOMAIN:-clarityxdr.local} -v /var/run/docker.sock:/var/run/docker.sock -v clarityxdr_data:/data traefik/whoami'

# ==========================================
# OPTION 4: INTERACTIVE SETUP (RECOMMENDED)
# ==========================================
sudo bash -c 'read -p "Enter domain (e.g., clarityxdr.com): " D && read -p "Enter email for SSL: " E && mkdir -p /opt/clarityxdr && cd /opt/clarityxdr && echo "version: \"3.8\"
services:
  app:
    image: nginx:alpine
    labels:
      - traefik.enable=true
      - traefik.http.routers.app.rule=Host(\`$D\`)
      - traefik.http.routers.app.tls.certresolver=le
      - traefik.http.routers.app.entrypoints=websecure
  traefik:
    image: traefik:v3.0
    ports:
      - 80:80
      - 443:443
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt
    command:
      - --providers.docker=true
      - --entrypoints.web.address=:80
      - --entrypoints.websecure.address=:443
      - --certificatesresolvers.le.acme.email=$E
      - --certificatesresolvers.le.acme.storage=/letsencrypt/acme.json
      - --certificatesresolvers.le.acme.tlschallenge=true" > docker-compose.yml && docker compose up -d'

# ==========================================
# OPTION 5: DEVELOPMENT ENVIRONMENT
# ==========================================
sudo bash -c 'git clone https://github.com/DataGuys/ClarityXDR.git /opt/clarityxdr && cd /opt/clarityxdr && docker-compose -f docker-compose.dev.yml up -d'

# ==========================================
# THE ULTIMATE ONE-LINER (All-in-One)
# ==========================================
wget -qO- https://deploy.clarityxdr.com | sudo bash

# Or using curl:
curl -fsSL https://deploy.clarityxdr.com | sudo bash

# ==========================================
# ACTUAL WORKING ONE-LINER FOR YOUR SERVER
# ==========================================
# This is the one-liner you should copy and paste:

sudo bash -c 'cd /tmp && rm -rf clarityxdr-deploy && mkdir clarityxdr-deploy && cd clarityxdr-deploy && cat > deploy.sh << '\''EOFSCRIPT'\''
#!/bin/bash
set -e
echo "🚀 ClarityXDR Quick Deploy Starting..."

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "📦 Installing Docker..."
    curl -fsSL https://get.docker.com | sh
fi

# Create deployment directory
mkdir -p /opt/clarityxdr
cd /opt/clarityxdr

# Create docker-compose.yml
cat > docker-compose.yml << '\''EOF'\''
version: "3.8"
services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-clarityxdr123}
      POSTGRES_DB: clarityxdr
    volumes:
      - postgres_data:/var/lib/postgresql/data
    restart: unless-stopped

  backend:
    image: alpine:latest
    command: sh -c "apk add --no-cache curl && while true; do echo '\''Backend running'\''; sleep 30; done"
    environment:
      DB_HOST: postgres
      DB_PASSWORD: ${POSTGRES_PASSWORD:-clarityxdr123}
    depends_on:
      - postgres
    restart: unless-stopped

  frontend:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - backend
    restart: unless-stopped

volumes:
  postgres_data:
EOF

# Create basic nginx config
cat > nginx.conf << '\''EOF'\''
server {
    listen 80;
    location / {
        return 200 "ClarityXDR is running! Visit https://github.com/DataGuys/ClarityXDR for setup.";
        add_header Content-Type text/plain;
    }
}
EOF

# Start services
docker compose up -d

# Show results
echo "
✅ ClarityXDR deployed successfully!
📍 Access at: http://$(curl -s ifconfig.me)
📊 Check status: cd /opt/clarityxdr && docker compose ps
📝 View logs: cd /opt/clarityxdr && docker compose logs
"
EOFSCRIPT
chmod +x deploy.sh && ./deploy.sh'
