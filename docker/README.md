# ClarityXDR Docker Configuration

This directory contains the Docker configuration files for ClarityXDR deployment.

## Quick Start

1. **Copy the environment template:**
   ```bash
   cp .env.example .env
   ```

2. **Edit the .env file with your settings:**
   ```bash
   nano .env
   ```

3. **Start the services:**
   ```bash
   docker-compose up -d
   ```

## SSL Configuration

### Default Setup (No SSL)
The default configuration disables SSL for ease of deployment:
- `DB_SSL_MODE=disable` in docker-compose.yml
- PostgreSQL runs without SSL certificates

### Enabling SSL
To enable SSL on an existing deployment:

1. **Run the SSL enablement script:**
   ```bash
   ./scripts/enable-ssl.sh
   ```

2. **Update your .env file:**
   ```bash
   echo "DB_SSL_MODE=require" >> .env
   ```

3. **Restart the backend:**
   ```bash
   docker-compose restart backend
   ```

## Directory Structure

```
docker/
├── docker-compose.yml      # Main Docker Compose configuration
├── .env.example           # Environment template
├── scripts/
│   ├── quick-fix-ssl.sh   # Quick fix for SSL issues
│   ├── enable-ssl.sh      # Enable SSL on running PostgreSQL
│   └── backup.sh          # Database backup script
├── init-scripts/
│   └── 01-configure-ssl.sh # PostgreSQL SSL initialization
├── letsencrypt/           # SSL certificates (auto-generated)
├── prometheus/            # Monitoring configuration
└── README.md             # This file
```

## Services

| Service | Description | Port |
|---------|-------------|------|
| traefik | Reverse proxy with SSL | 80, 443 |
| postgres | PostgreSQL database | 5432 |
| redis | Redis cache | 6379 |
| backend | Go API server | 8080 |
| frontend | React web app | 80 |
| backup | Automated database backup | - |

## Environment Variables

Key variables in `.env`:

```bash
# Domain and SSL
DOMAIN_NAME=your-domain.com
ACME_EMAIL=your-email@domain.com

# Database
POSTGRES_PASSWORD=secure-password
DB_SSL_MODE=disable  # or require for SSL

# Security
ENCRYPTION_KEY=32-character-key
JWT_SECRET=your-jwt-secret

# Redis
REDIS_PASSWORD=redis-password
```

## Health Checks

Check service status:
```bash
docker-compose ps
```

View logs:
```bash
docker-compose logs -f [service-name]
```

## Troubleshooting

### SSL Connection Issues
If you see "SSL is not enabled on the server":
1. Run `./scripts/quick-fix-ssl.sh`
2. Or manually set `DB_SSL_MODE=disable` in .env

### Service Won't Start
1. Check logs: `docker-compose logs [service]`
2. Verify environment variables
3. Ensure ports aren't in use

### Database Connection Issues
1. Check PostgreSQL is healthy: `docker-compose ps postgres`
2. Test connection: `docker exec clarityxdr-postgres pg_isready`
3. Check network: `docker network ls`

## Production Notes

- Use strong passwords for all services
- Enable SSL in production environments
- Set up proper backup schedules
- Monitor resource usage
- Use external SSL certificates for production

## Updates

To update services:
```bash
docker-compose pull
docker-compose up -d
```

## Backup

Automated backups are configured in the backup service. Manual backup:
```bash
docker exec clarityxdr-postgres pg_dump -U postgres clarityxdr > backup.sql
```
