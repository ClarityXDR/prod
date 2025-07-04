# ClarityXDR Production-Ready Docker Deployment

This repository has been updated with production-ready Docker configurations based on comprehensive research and best practices.

## 🚀 Key Improvements

### 1. **Docker Compose Architecture**
- ✅ Multi-service orchestration with health checks
- ✅ Proper dependency management with condition checks
- ✅ Connection pooling with PgBouncer
- ✅ Automatic backup service
- ✅ Named volumes for data persistence
- ✅ Custom bridge network for isolation

### 2. **SSL/HTTPS Automation with Traefik**
- ✅ Automatic SSL certificate generation via Let's Encrypt
- ✅ HTTP to HTTPS redirection
- ✅ Dynamic service discovery
- ✅ Load balancing capabilities
- ✅ Zero-downtime certificate renewal

### 3. **Security Enhancements**
- ✅ Non-root user execution in containers
- ✅ Environment-based secrets management
- ✅ AES-256 encryption for sensitive data
- ✅ Network isolation between services
- ✅ Security headers in nginx

### 4. **Performance Optimizations**
- ✅ Multi-stage Docker builds for smaller images
- ✅ Layer caching optimization
- ✅ Ubuntu kernel parameter tuning
- ✅ Connection pooling for PostgreSQL
- ✅ Gzip compression for static assets
- ✅ Modern Particle.js implementation with @tsparticles

### 5. **Deployment Automation**
- ✅ Blue-green deployment script
- ✅ GitHub Actions CI/CD pipeline
- ✅ Health check validation
- ✅ Automatic rollback on failure
- ✅ One-liner deployment commands

## 📋 Prerequisites

- Ubuntu 20.04+ server
- Docker Engine 24.0+
- Docker Compose v2.20+
- Domain name with DNS configured
- Open ports: 80, 443

## 🛠️ Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/yourusername/clarityxdr.git
cd clarityxdr
```

### 2. Configure Environment
```bash
cp .env.example .env
nano .env  # Edit with your values
```

### 3. Run Ubuntu Optimizations
```bash
sudo chmod +x ubuntu-optimizations.sh
sudo ./ubuntu-optimizations.sh
```

### 4. Deploy with One Command
```bash
chmod +x deploy-production.sh
./deploy-production.sh
```

## 🧹 Safe Cleanup (Preserves Other Containers)

### Clean Up Only ClarityXDR Containers
```bash
# Stop only ClarityXDR containers
docker-compose down

# Remove only ClarityXDR containers (preserves AdGuard, Unifi, etc.)
docker rm -f $(docker ps -aq --filter "name=clarityxdr")

# Remove only ClarityXDR images
docker rmi $(docker images --filter "reference=*clarityxdr*" -q)

# Clean up only ClarityXDR volumes
docker volume prune -f --filter "label=clarityxdr"
```

### ⚠️ DANGEROUS - Complete Reset (Removes ALL Docker Data)
```bash
# ⚠️ WARNING: This will remove ALL containers, volumes, and networks
# Only use if you want to completely reset Docker
sudo systemctl stop docker
sudo rm -rf /var/lib/docker
sudo systemctl start docker
```

### 🔧 Container Recovery Commands
```bash
# Run the recovery script for AdGuard Home and Unifi Controller
./container-recovery.sh

# Or manually check for your containers
docker ps -a | grep -E "(adguard|unifi)"
docker volume ls | grep -E "(adguard|unifi)"
```

## 🔧 Configuration

### Environment Variables

Create a `.env` file with the following variables:

```env
# Domain Configuration
DOMAIN_NAME=clarityxdr.com
ACME_EMAIL=admin@clarityxdr.com

# Database Configuration
POSTGRES_DB=clarityxdr
POSTGRES_USER=postgres
POSTGRES_PASSWORD=<secure_password>

# Security
ENCRYPTION_KEY=<32_character_key>

# API Configuration
REACT_APP_API_URL=https://api.clarityxdr.com
```

### SSL Certificates

Traefik automatically manages SSL certificates. Just ensure:
1. Your domain DNS points to the server
2. Ports 80 and 443 are open
3. The ACME_EMAIL is valid

## 🚀 Deployment Commands

### Production Deployment (Blue-Green)
```bash
# Deploy to production with zero downtime
./deploy-production.sh

# Or use one-liner
docker-compose pull && docker-compose up -d --remove-orphans
```

### Development Deployment
```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop all services
docker-compose down
```

### Backup Management
```bash
# Manual backup
docker exec postgres-backup pg_dump -h postgres -U postgres -Fc clarityxdr > backup_$(date +%Y%m%d_%H%M%S).dump

# Restore backup
docker exec -i postgres pg_restore -h postgres -U postgres -d clarityxdr < backup_file.dump
```

## 🏗️ Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│    Traefik      │────▶│   React SPA     │────▶│   Go Backend    │
│   (SSL/Proxy)   │     │   (Frontend)    │     │   (API Server)  │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         │                       │                        │
         └───────────────────────┴────────────────────────┘
                                 │
                         ┌───────┴────────┐
                         │   PgBouncer    │
                         │ (Connection    │
                         │    Pooling)    │
                         └───────┬────────┘
                                 │
                         ┌───────┴────────┐
                         │  PostgreSQL    │
                         │   Database     │
                         └────────────────┘
```

## 📊 Monitoring

### Health Checks
```bash
# Check all services health
docker-compose ps

# Check specific service
curl http://localhost:8080/health  # Backend
curl http://localhost/health        # Frontend
```

### Resource Usage
```bash
# View container stats
docker stats

# Run monitoring script
/usr/local/bin/docker-monitor.sh
```

### Logs
```bash
# View all logs
docker-compose logs

# View specific service logs
docker-compose logs backend -f

# View Traefik access logs
docker-compose logs traefik | grep -E "Host|Path"
```

## 🔒 Security Best Practices

1. **Secrets Management**
   - Never commit `.env` files
   - Use strong passwords (32+ characters)
   - Rotate secrets regularly

2. **Network Security**
   - Services communicate only through internal network
   - Only Traefik exposes ports 80/443
   - Database not accessible from outside

3. **Container Security**
   - All containers run as non-root users
   - Minimal base images (Alpine Linux)
   - Regular security updates

4. **Data Encryption**
   - SSL/TLS for all external traffic
   - AES-256 encryption for sensitive data at rest
   - Encrypted database connections

## 🆘 Troubleshooting

### Common Issues

1. **SSL Certificate Issues**
   ```bash
   # Check Traefik logs
   docker-compose logs traefik | grep -i error
   
   # Verify DNS
   dig +short clarityxdr.com
   ```

2. **Database Connection Issues**
   ```bash
   # Check PostgreSQL logs
   docker-compose logs postgres
   
   # Test connection
   docker exec -it postgres psql -U postgres -d clarityxdr
   ```

3. **Container Won't Start**
   ```bash
   # Check specific container logs
   docker-compose logs <service_name>
   
   # Rebuild container
   docker-compose build --no-cache <service_name>
   ```

## 📈 Performance Tuning

### Scaling Services
```yaml
# In docker-compose.yml
services:
  backend:
    deploy:
      replicas: 3
```

### Resource Limits
```yaml
services:
  backend:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 512M
```

## 🔄 Updates and Maintenance

### Update Process
1. Pull latest changes: `git pull`
2. Review changes in `.env.example`
3. Update images: `docker-compose pull`
4. Deploy: `./deploy-production.sh`

### Regular Maintenance
- Weekly: Check logs for errors
- Monthly: Update base images
- Quarterly: Security audit
- Yearly: Major version upgrades

## 📞 Support

For issues or questions:
- Create an issue on GitHub
- Email: support@clarityxdr.com
- Documentation: https://docs.clarityxdr.com

---

**Note**: This production setup follows Docker best practices and includes enterprise-grade features for security, performance, and reliability.