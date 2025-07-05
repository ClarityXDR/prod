#!/bin/bash

# Quick fix script to resolve SSL connection issues
# This script will disable SSL mode temporarily to get the system running

echo "🔧 ClarityXDR SSL Quick Fix"
echo "================================"

# Find the deployment directory
DEPLOY_DIR="/opt/clarityxdr"
if [ ! -d "$DEPLOY_DIR" ]; then
    echo "❌ Deployment directory not found at $DEPLOY_DIR"
    echo "Trying current directory..."
    DEPLOY_DIR="$(pwd)"
fi

echo "📁 Working in directory: $DEPLOY_DIR"
cd "$DEPLOY_DIR"

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "❌ .env file not found. Creating one..."
    cat > .env << EOF
# ClarityXDR Configuration - Quick Fix
DOMAIN_NAME=portal.clarityxdr.com
ACME_EMAIL=gregory.hall@clarityxdr.com
POSTGRES_DB=clarityxdr
POSTGRES_USER=postgres
POSTGRES_PASSWORD=clarityxdr2024
ENCRYPTION_KEY=clarityxdr_encryption_key_32_chars
DB_SSL_MODE=disable
REDIS_PASSWORD=clarityxdr_redis_2024
JWT_SECRET=clarityxdr_jwt_secret_key_here
APP_ENV=production
LOG_LEVEL=info
REACT_APP_API_URL=https://api.portal.clarityxdr.com
CORS_ORIGINS=https://portal.clarityxdr.com
BACKUP_SCHEDULE=0 2 * * *
BACKUP_RETENTION_DAYS=7
EOF
    echo "✅ Created .env file with SSL disabled"
else
    echo "📝 Found existing .env file"
    
    # Check if DB_SSL_MODE is set
    if grep -q "DB_SSL_MODE" .env; then
        # Update existing DB_SSL_MODE to disable
        sed -i 's/DB_SSL_MODE=.*/DB_SSL_MODE=disable/' .env
        echo "✅ Updated DB_SSL_MODE to disable in .env"
    else
        # Add DB_SSL_MODE=disable
        echo "DB_SSL_MODE=disable" >> .env
        echo "✅ Added DB_SSL_MODE=disable to .env"
    fi
fi

# Stop the services
echo "🛑 Stopping ClarityXDR services..."
docker-compose down

# Wait a moment
sleep 3

# Start the services
echo "🚀 Starting ClarityXDR services with SSL disabled..."
docker-compose up -d

# Wait for services to start
echo "⏳ Waiting for services to start..."
sleep 15

# Check status
echo "📊 Checking service status..."
docker-compose ps

echo ""
echo "🔍 Checking backend logs for SSL errors..."
docker logs clarityxdr-backend --tail 10

echo ""
echo "✅ Quick fix applied!"
echo ""
echo "📋 Next steps:"
echo "1. If services are now healthy, SSL has been successfully disabled"
echo "2. To enable SSL later, run: ./enable-ssl.sh"
echo "3. Monitor logs with: docker-compose logs -f"
echo ""
echo "🌐 Access your application at: https://${DOMAIN_NAME:-portal.clarityxdr.com}"
