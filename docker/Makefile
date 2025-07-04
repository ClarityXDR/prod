# ClarityXDR Docker Makefile
# Convenient commands for managing your deployment

.PHONY: help up down restart logs ps build pull clean backup restore shell status health init

# Default target
help:
	@echo "ClarityXDR Docker Management Commands"
	@echo "===================================="
	@echo "  make init       - Initialize environment and configuration"
	@echo "  make up         - Start all services"
	@echo "  make down       - Stop all services"
	@echo "  make restart    - Restart all services"
	@echo "  make logs       - View logs (all services)"
	@echo "  make ps         - Show service status"
	@echo "  make build      - Build images locally"
	@echo "  make pull       - Pull latest images"
	@echo "  make clean      - Clean up volumes and data"
	@echo "  make backup     - Create database backup"
	@echo "  make restore    - Restore latest backup"
	@echo "  make shell      - Shell into a service (e.g., make shell service=backend)"
	@echo "  make status     - Detailed status check"
	@echo "  make health     - Check service health"
	@echo "  make monitor    - Start monitoring stack"
	@echo ""
	@echo "Examples:"
	@echo "  make logs service=backend  - View backend logs only"
	@echo "  make shell service=postgres - Shell into postgres container"

# Initialize environment
init:
	@echo "Initializing ClarityXDR environment..."
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "Created .env file - please edit with your configuration"; \
	else \
		echo ".env file already exists"; \
	fi
	@chmod +x scripts/backup.sh
	@mkdir -p backups logs/backend logs/nginx letsencrypt traefik
	@echo "Initialization complete!"

# Start services
up:
	docker compose up -d
	@echo "Services starting... Run 'make logs' to view output"

# Stop services
down:
	docker compose down

# Restart services
restart:
	docker compose restart

# View logs
logs:
	@if [ -z "$(service)" ]; then \
		docker compose logs -f --tail=100; \
	else \
		docker compose logs -f --tail=100 $(service); \
	fi

# Show service status
ps:
	docker compose ps

# Build images locally
build:
	docker compose build --no-cache

# Pull latest images
pull:
	docker compose pull

# Clean up everything (WARNING: Deletes all data!)
clean:
	@echo "WARNING: This will delete all data!"
	@read -p "Are you sure? [y/N] " confirm; \
	if [ "$$confirm" = "y" ]; then \
		docker compose down -v; \
		rm -rf backups/* logs/* letsencrypt/* traefik/*; \
		echo "Cleanup complete"; \
	else \
		echo "Cleanup cancelled"; \
	fi

# Create backup
backup:
	@echo "Creating database backup..."
	@docker compose exec backup /backup.sh
	@echo "Backup complete! Check backups/ directory"

# Restore latest backup
restore:
	@echo "Available backups:"
	@ls -la backups/*.sql.gz 2>/dev/null || echo "No backups found"
	@read -p "Enter backup filename (or 'latest.sql.gz'): " backup_file; \
	if [ -f "backups/$$backup_file" ]; then \
		echo "Restoring from $$backup_file..."; \
		gunzip -c "backups/$$backup_file" | docker compose exec -T postgres psql -U postgres clarityxdr; \
		echo "Restore complete!"; \
	else \
		echo "Backup file not found"; \
	fi

# Shell into a service
shell:
	@if [ -z "$(service)" ]; then \
		echo "Usage: make shell service=<service_name>"; \
		echo "Available services:"; \
		docker compose ps --services; \
	else \
		docker compose exec $(service) sh; \
	fi

# Detailed status check
status:
	@echo "=== ClarityXDR Status ==="
	@echo ""
	@echo "Services:"
	@docker compose ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@echo "Volumes:"
	@docker volume ls | grep clarityxdr
	@echo ""
	@echo "Disk Usage:"
	@docker system df
	@echo ""
	@echo "Resource Usage:"
	@docker stats --no-stream

# Health check
health:
	@echo "Checking service health..."
	@echo ""
	@echo "Frontend: "
	@curl -sf http://localhost/health > /dev/null && echo "✅ Healthy" || echo "❌ Unhealthy"
	@echo ""
	@echo "Backend: "
	@curl -sf http://localhost:8080/health > /dev/null && echo "✅ Healthy" || echo "❌ Unhealthy"
	@echo ""
	@echo "Database: "
	@docker compose exec postgres pg_isready > /dev/null 2>&1 && echo "✅ Healthy" || echo "❌ Unhealthy"
	@echo ""
	@echo "Redis: "
	@docker compose exec redis redis-cli ping > /dev/null 2>&1 && echo "✅ Healthy" || echo "❌ Unhealthy"

# Start monitoring stack
monitor:
	docker compose --profile monitoring up -d
	@echo "Monitoring stack started!"
	@echo "Prometheus: http://localhost:9090"
	@echo "Grafana: http://localhost:3000"

# Quick deploy (combines init and up)
deploy: init
	@echo "Starting deployment..."
	@make up
	@sleep 10
	@make health

# Update deployment
update: pull
	@echo "Updating services..."
	@docker compose up -d
	@echo "Update complete!"

# View recent logs with errors
errors:
	@docker compose logs --tail=1000 | grep -E "(ERROR|FATAL|PANIC|Exception)"

# Database operations
db-shell:
	docker compose exec postgres psql -U postgres clarityxdr

db-dump:
	@timestamp=$$(date +%Y%m%d_%H%M%S); \
	docker compose exec postgres pg_dump -U postgres clarityxdr > "backups/manual_backup_$$timestamp.sql"; \
	echo "Database dumped to backups/manual_backup_$$timestamp.sql"

# Development helpers
dev-reset:
	@echo "Resetting development environment..."
	@make down
	@docker volume rm clarityxdr_postgres_data 2>/dev/null || true
	@make up
	@echo "Development environment reset!"

# Show environment info
info:
	@echo "=== ClarityXDR Environment Info ==="
	@echo "Domain: $$(grep DOMAIN_NAME .env | cut -d'=' -f2)"
	@echo "Database: $$(grep POSTGRES_DB .env | cut -d'=' -f2)"
	@echo "Docker Compose Version: $$(docker compose version)"
	@echo "Docker Version: $$(docker --version)"
	@echo "Public IP: $$(curl -s ifconfig.me)"