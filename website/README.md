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

**One-line deployment:**

```bash
curl -sSL https://raw.githubusercontent.com/ClarityXDR/prod/refs/heads/main/website/deployment/deploy-ubuntu.sh | sudo bash
```

This one-liner will:
1. Check system prerequisites and install required packages
2. Interactively collect configuration (domain, email, API keys)
3. Generate secure random passwords and encryption keys automatically
4. Download and set up the application from GitHub
5. Apply system optimizations with your confirmation
6. Start all services with Docker Compose
7. Display access URLs and credentials

**Manual deployment for advanced users:**

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

### Environment Variables Setup

During installation, you'll be prompted to configure several critical environment variables. Below is a detailed explanation of the key variables to help you set them correctly:

- `DOMAIN_NAME`: The fully qualified domain name where your application will be hosted (e.g., `portal.clarityxdr.com` or `xdr.yourdomain.com`). This is used for SSL certificates and service discovery. Do NOT include http:// or https:// prefixes.

- `ACME_EMAIL`: Your email address for Let's Encrypt SSL certificate notifications.

- `TRAEFIK_DASHBOARD_AUTH`: Username/password for the Traefik dashboard in htpasswd format. You can generate this using: 
  ```
  echo $(htpasswd -nb admin YourSecurePassword)
  ```

- `POSTGRES_DB`: Database name (default: clarityxdr).

- `POSTGRES_USER`: Database username (default: postgres).

- `POSTGRES_PASSWORD`: A strong, secure password for the PostgreSQL database. Recommended to use a randomly generated password of at least 16 characters including special characters.

- `REDIS_PASSWORD`: A strong, secure password for Redis. Similar recommendations as for POSTGRES_PASSWORD.

- `ENCRYPTION_KEY`: A 32-character encryption key used to secure sensitive data. Must be exactly 32 characters long. You can generate this using:
  ```
  openssl rand -base64 24
  ```

- `JWT_SECRET`: Secret key used for JWT token signing and verification. Should be a strong random string. You can generate this using:
  ```
  openssl rand -base64 32
  ```

- `JWT_EXPIRES_IN`: JWT token expiration time (default: 24h).

- `OPENAI_API_KEY`: Your OpenAI API key for AI agent functionality. Obtain this from your OpenAI account.

- `AZURE_OPENAI_API_KEY` and `AZURE_OPENAI_ENDPOINT`: If using Azure OpenAI instead of OpenAI directly, provide these values from your Azure OpenAI resource.

### Interactive Setup Helper

For convenience, the deployment script includes an interactive setup helper that will guide you through configuring these variables:

```bash
# Interactive setup
cd /opt/clarityxdr/website
./setup-env.sh
```

This script will:
1. Generate secure random passwords
2. Prompt you for required external services like OpenAI
3. Create a properly configured .env file
4. Validate your configuration before deployment

### Manual Configuration

If you prefer to configure manually:

```bash
# Copy the example environment file
cp .env.example .env

# Edit with your preferred text editor
nano .env

# Validate your configuration
./validate-env.sh
```

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
Copyright © 2025 ClarityXDR. All rights reserved.
