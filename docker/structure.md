# ClarityXDR Docker Directory Structure

## Complete Directory Layout

```
clarityxdr/
├── docker/                          # This directory - Docker deployment files
│   ├── docker-compose.yml          # Main orchestration file
│   ├── .env.example                # Environment template
│   ├── .env                        # Your configuration (create from .env.example)
│   ├── Dockerfile.allinone         # All-in-one demo container
│   ├── Makefile                    # Convenience commands
│   ├── README.md                   # Docker deployment guide
│   ├── STRUCTURE.md                # This file
│   │
│   ├── scripts/                    # Utility scripts
│   │   └── backup.sh              # Automated backup script
│   │
│   ├── prometheus/                 # Monitoring configuration
│   │   └── prometheus.yml         # Prometheus scrape configs
│   │
│   ├── grafana/                    # Dashboards (optional)
│   │   └── provisioning/
│   │       ├── dashboards/
│   │       └── datasources/
│   │
│   ├── traefik/                    # Auto-generated SSL config
│   │   └── (generated files)
│   │
│   ├── letsencrypt/                # SSL certificates
│   │   └── acme.json              # Auto-generated cert storage
│   │
│   ├── backups/                    # Database backups
│   │   ├── clarityxdr_backup_*.sql.gz
│   │   └── latest.sql.gz          # Symlink to most recent
│   │
│   ├── logs/                       # Application logs
│   │   ├── backend/
│   │   └── nginx/
│   │
│   ├── repositories/               # Git repository storage
│   │   └── (user git repos)
│   │
│   └── uploads/                    # File upload storage
│       └── (uploaded files)
│
├── website/                        # Source code
│   ├── frontend/                   # React application
│   │   ├── Dockerfile
│   │   ├── package.json
│   │   └── src/
│   │
│   ├── backend/                    # Go API server
│   │   ├── Dockerfile
│   │   ├── go.mod
│   │   └── cmd/
│   │
│   └── docker-compose.yml          # Development compose file
│
├── install.sh                      # One-line installer script
├── deploy-production.sh            # Production deployment script
└── README.md                       # Main project README
```

## File Purposes

### Configuration Files
- **docker-compose.yml** - Defines all services and their relationships
- **.env** - Contains sensitive configuration (passwords, domains, etc.)
- **Makefile** - Provides easy-to-use commands like `make up`, `make backup`

### Data Directories
- **backups/** - Automated daily PostgreSQL backups
- **logs/** - Application and web server logs
- **repositories/** - Git repositories managed by ClarityXDR
- **uploads/** - User-uploaded files

### Auto-Generated
- **traefik/** - Traefik dynamic configuration
- **letsencrypt/** - SSL certificate storage
- **postgres_data** - Docker volume for database
- **redis_data** - Docker volume for cache

## Quick Setup

1. **Copy environment template:**
   ```bash
   cd docker/
   cp .env.example .env
   ```

2. **Edit configuration:**
   ```bash
   nano .env
   ```

3. **Initialize and deploy:**
   ```bash
   make init
   make deploy
   ```

4. **Check status:**
   ```bash
   make status
   make health
   ```

## Common Tasks

- **View logs:** `make logs`
- **Create backup:** `make backup`
- **Update services:** `make update`
- **Access database:** `make db-shell`
- **Check health:** `make health`

## Security Notes

1. The `.env` file contains secrets - never commit it to git
2. Add `.env` to your `.gitignore` file
3. Backups may contain sensitive data - protect the `backups/` directory
4. SSL certificates in `letsencrypt/` should be kept secure

## Deployment Modes

### Production (with SSL)
```bash
DOMAIN_NAME=clarityxdr.com make up
```

### Local Development (no SSL)
```bash
DOMAIN_NAME=localhost make up
```

### Demo Mode (all-in-one)
```bash
docker build -f Dockerfile.allinone -t clarityxdr-demo .
docker run -p 80:80 clarityxdr-demo
```