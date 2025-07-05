#!/bin/bash

# Script to enable SSL on an existing PostgreSQL instance
# Run this script to enable SSL on a running PostgreSQL container

CONTAINER_NAME="clarityxdr-postgres"

echo "Enabling SSL on PostgreSQL container: $CONTAINER_NAME"

# Check if container is running
if ! docker ps | grep -q "$CONTAINER_NAME"; then
    echo "Error: Container $CONTAINER_NAME is not running"
    exit 1
fi

echo "Generating SSL certificates inside the container..."
docker exec "$CONTAINER_NAME" sh -c '
    # Generate self-signed SSL certificate if none exists
    if [ ! -f "/var/lib/postgresql/data/server.crt" ]; then
        echo "Generating self-signed SSL certificate..."
        openssl req -new -x509 -days 365 -nodes -text \
            -out /var/lib/postgresql/data/server.crt \
            -keyout /var/lib/postgresql/data/server.key \
            -subj "/CN=postgres"
        
        # Set proper permissions
        chmod 600 /var/lib/postgresql/data/server.key
        chmod 644 /var/lib/postgresql/data/server.crt
        chown postgres:postgres /var/lib/postgresql/data/server.key /var/lib/postgresql/data/server.crt
    else
        echo "SSL certificates already exist"
    fi
'

echo "Updating PostgreSQL configuration for SSL..."
docker exec "$CONTAINER_NAME" sh -c '
    # Check if SSL is already configured
    if ! grep -q "ssl = on" /var/lib/postgresql/data/postgresql.conf; then
        echo "Adding SSL configuration to postgresql.conf..."
        cat >> /var/lib/postgresql/data/postgresql.conf << EOF

# SSL Configuration (added by enable-ssl script)
ssl = on
ssl_cert_file = '\''server.crt'\''
ssl_key_file = '\''server.key'\''
ssl_prefer_server_ciphers = on
ssl_protocols = '\''TLSv1.2,TLSv1.3'\''
EOF
    else
        echo "SSL configuration already present in postgresql.conf"
    fi
'

echo "Restarting PostgreSQL to apply SSL configuration..."
docker restart "$CONTAINER_NAME"

echo "Waiting for PostgreSQL to start with SSL enabled..."
sleep 10

# Test SSL connection
echo "Testing SSL connection..."
if docker exec "$CONTAINER_NAME" psql -U postgres -d postgres -c "SHOW ssl;" | grep -q "on"; then
    echo "✅ SSL successfully enabled on PostgreSQL!"
    echo ""
    echo "You can now update your .env file to use:"
    echo "DB_SSL_MODE=require"
    echo ""
    echo "Then restart the backend service:"
    echo "docker-compose restart backend"
else
    echo "❌ Failed to enable SSL on PostgreSQL"
    exit 1
fi
