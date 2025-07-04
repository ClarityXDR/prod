# ClarityXDR Web Application

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FClarityXDR%2Fprod%2Frefs%2Fheads%2Fmain%2Fwebsite%2Fazure-deployment%2Fazure-container-apps-secure.json)

## Overview

ClarityXDR is an AI-driven security operations platform that transforms Microsoft Defender XDR into a mature, AI-driven SOC. Built with a "designed by humans, operated by AI" philosophy, ClarityXDR leverages multiple specialized AI agents to handle security operations, business functions, and customer interactions.

![ClarityXDR Logo](https://raw.githubusercontent.com/ClarityXDR/prod/refs/heads/main/website/brand-assets/Icon_512x512.png)

## Features

- **AI Agent Orchestra**: Multiple specialized AI agents working together to handle security operations, business functions, and customer interactions
- **KQL Query Interface**: Advanced interface for hunting threats across Microsoft Defender environments
- **Custom MDE Rule Repository**: GitHub-style repositories for client-specific MDE detection rules
- **Multi-tenant Architecture**: Each client has their own isolated environment and dedicated resources
- **Modern React UI**: Sleek, responsive user interface with real-time visualizations

## Prerequisites

- Docker and Docker Compose v2+
- 4GB+ RAM, 2+ CPU cores
- Domain name (for production deployment)
- SSL certificates (handled automatically by Traefik)

## Deployment Options

### Option 1: Deploy to Ubuntu Server

For a one-line deployment to your Ubuntu server:

```bash
curl -sSL https://raw.githubusercontent.com/ClarityXDR/prod/refs/heads/main/website/deployment/deploy-ubuntu.sh | sudo bash
```

For more control over the deployment process:

```bash
# Create directory and download files
mkdir -p /opt/clarityxdr && cd /opt/clarityxdr
git clone https://github.com/ClarityXDR/prod.git .
cd website

# Configure environment variables
cp .env.example .env
nano .env  # Edit with your specific values

# Apply system optimizations (optional)
sudo chmod +x ubuntu-optimizations.sh
sudo ./ubuntu-optimizations.sh

# Start the application
docker-compose up -d
```

### Option 2: Deploy to Azure

1. Click the "Deploy to Azure" button at the top of this README
2. Fill in the required parameters in the Azure deployment form
3. Click "Review + Create" and then "Create" to start the deployment
4. Once deployment is complete, access your application using the provided URLs

Alternatively, use the PowerShell or Bash scripts in the `deployment` folder:

```powershell
# PowerShell deployment
./deployment/deploy.ps1 -ResourceGroupName "clarityxdr-rg" -Location "eastus" -ContainerRegistryName "clarityxdracr" -DomainName "your-domain.com"
```

```bash
# Bash deployment
./deployment/deploy.sh clarityxdr-rg eastus clarityxdracr your-domain.com
```

## Configuration

### Environment Variables

The `.env` file contains all necessary configuration options. Key variables include:

- `DOMAIN_NAME`: Your domain name for the application
- `POSTGRES_PASSWORD`: Secure password for the database
- `REDIS_PASSWORD`: Secure password for Redis
- `ENCRYPTION_KEY`: 32-character encryption key for sensitive data
- `JWT_SECRET`: Secret key for JWT authentication
- `OPENAI_API_KEY`: API key for OpenAI services

See `.env.example` for a complete list of available options.

## Architecture

ClarityXDR uses a microservices architecture with the following components:

- **Frontend**: React-based SPA served by Nginx
- **Backend**: Go API server for business logic
- **Agent Orchestrator**: Python service for AI agent coordination
- **Database**: PostgreSQL with PgBouncer connection pooling
- **Cache**: Redis for fast data access and message queuing
- **Proxy**: Traefik for routing, SSL termination, and load balancing

## Development

### Local Development Setup

```bash
# Clone the repository
git clone https://github.com/ClarityXDR/prod.git
cd prod/website

# Start the development environment
docker-compose -f docker-compose.dev.yml up
```

### Project Structure

- `/frontend`: React frontend application
- `/backend`: Go backend API server
- `/agent-orchestrator`: Python service for AI agent management
- `/init-scripts`: Database initialization scripts
- `/deployment`: Deployment scripts for various platforms
- `/azure-deployment`: Azure-specific deployment templates

## Security

ClarityXDR implements several security best practices:

- **HTTPS Everywhere**: All traffic is encrypted using SSL/TLS
- **Least Privilege**: Container services run as non-root users
- **Secret Management**: Sensitive data stored securely using environment variables
- **Input Validation**: All user inputs are validated and sanitized
- **Secure Headers**: HTTP security headers implemented in Nginx and Traefik

## License

Copyright © 2025 ClarityXDR. All rights reserved.
