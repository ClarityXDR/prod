#!/bin/bash
set -e

# This script configures PostgreSQL for SSL support
# It runs during database initialization

echo "Configuring PostgreSQL for SSL support..."

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
fi

# Configure PostgreSQL to support SSL
cat >> /var/lib/postgresql/data/postgresql.conf << EOF

# SSL Configuration
ssl = on
ssl_cert_file = 'server.crt'
ssl_key_file = 'server.key'
ssl_prefer_server_ciphers = on
ssl_protocols = 'TLSv1.2,TLSv1.3'
EOF

echo "SSL configuration completed. PostgreSQL will support SSL connections."
echo "You can now set DB_SSL_MODE=require or DB_SSL_MODE=prefer in your environment."
