# ClarityXDR Web Application

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FClarityXDR%2Fprod%2Frefs%2Fheads%2Fmain%2Fwebsite%2Fazure-deployment%2Fazure-container-apps-secure.json)

## Overview

ClarityXDR is an AI-driven security operations platform that transforms Microsoft Defender XDR into a mature, AI-driven SOC. Built with a "designed by humans, operated by AI" philosophy, ClarityXDR leverages multiple specialized AI agents to handle security operations, business functions, and customer interactions.

![ClarityXDR Logo](https://github.com/ClarityXDR/prod/blob/main/brand-assets/Icon_256x256.png)

## Features

### Security Operations
- **AI Agent Orchestra**: Multiple specialized AI agents working together to handle security operations, business functions, and customer interactions
- **KQL Query Interface**: Advanced interface for hunting threats across Microsoft Defender environments with AI-powered query generation
- **Custom MDE Rule Repository**: GitHub-style repositories for client-specific MDE detection rules with version control
- **Central Threat Intelligence**: Manage and sync threat indicators across all client environments to Microsoft Sentinel
- **Multi-tenant Architecture**: Each client has their own isolated environment and dedicated resources

### Business Operations
- **License Management**: Comprehensive license key generation, validation, and tracking system
- **Logic App Deployment**: Deploy and manage Azure Logic Apps with integrated license validation
- **GitHub Issues Integration**: AI agents operate via GitHub Issues, with customized Mission Control Protocol (MCP) guidelines
- **Automated Invoicing**: AI-driven invoice generation, payment tracking, and service management
- **Customer Ticketing**: GitHub Issues-based ticketing system with AI-powered responses

### Technical Features
- **Modern React UI**: Sleek, responsive user interface with real-time visualizations and particle effects
- **Real-time Dashboard**: Live threat metrics, deployment status, and system health monitoring
- **RESTful API**: Comprehensive API for all platform features with JWT authentication
- **Database Multi-tenancy**: PostgreSQL with schema-based isolation for each client
- **Redis Caching**: High-performance caching for real-time data and session management

## Prerequisites

- Docker and Docker Compose v2+
- 4GB+ RAM, 2+ CPU cores
- Domain name (for production deployment)
- SSL certificates (handled automatically by Traefik)
- GitHub account with repository access
- OpenAI API key (for AI agent functionality)

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

- `LICENSE_API_ENDPOINT`: The endpoint for license validation (default: https://api.clarityxdr.com/api/licensing/validate).

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

### Core Services
- **Frontend**: React-based SPA served by Nginx
  - TypeScript React application with modern hooks
  - React Router for navigation
  - Axios for API communication
  - TSParticles for visual effects
  - Bootstrap for UI components

- **Backend**: Go API server for business logic
  - RESTful API with Gorilla Mux router
  - JWT-based authentication
  - PostgreSQL database integration
  - Redis caching layer
  - WebSocket support for real-time updates

- **Agent Orchestrator**: Python service for AI agent coordination
  - OpenAI GPT-4 integration
  - GitHub Issues monitoring and response
  - Mission Control Protocol (MCP) enforcement
  - Multi-agent task distribution

- **ASP.NET Core WebApp**: Logic App deployment and management
  - Azure Resource Manager integration
  - License validation middleware
  - Logic App template management
  - Client-specific deployment tracking

### Infrastructure Services
- **Database**: PostgreSQL with PgBouncer connection pooling
  - Multi-tenant schema isolation
  - Automatic migrations
  - Backup and restore capabilities

- **Cache**: Redis for fast data access and message queuing
  - Session management
  - Real-time data caching
  - Pub/Sub for inter-service communication

- **Proxy**: Traefik for routing, SSL termination, and load balancing
  - Automatic SSL certificate management
  - Service discovery
  - Load balancing
  - Rate limiting

## AI Agent Architecture

ClarityXDR uses GitHub Issues as its primary AI agent interaction mechanism. Each agent has specific Mission Control Protocol (MCP) guidelines that govern its behavior and responses:

### Agent Types and MCP Guidelines

- **Executive Agents**: Make high-level decisions with strategic context and business impact awareness
  - CEO Agent: Strategic planning and vision
  - CFO Agent: Financial management and budgeting
  - CTO Agent: Technical architecture decisions

- **Security Agents**: Follow strict security protocols with data protection and compliance focus
  - SOC Analyst Agent: Incident response and triage
  - Threat Hunter Agent: Proactive threat detection
  - Compliance Agent: Regulatory compliance monitoring

- **Business Agents**: Operate with customer service, sales, and marketing best practices
  - Sales Agent: Lead qualification and quote generation
  - Support Agent: Customer issue resolution
  - Marketing Agent: Content creation and campaigns

- **Orchestrator Agent**: Coordinates all other agents, ensuring proper task delegation and completion
  - Task distribution based on agent capabilities
  - Conflict resolution between agents
  - Performance monitoring and optimization

Each agent automatically monitors GitHub Issues assigned to it, processes the requests according to its MCP guidelines, and posts responses back to the Issue thread. This creates a transparent, auditable trail of all AI decision-making and actions.

To customize an agent's MCP guidelines:

```bash
# Edit an agent's MCP configuration
cd /opt/clarityxdr/website
./edit-agent-mcp.sh <agent_id>
```

## Development

### Local Development Setup

```bash
# Clone the repository
git clone https://github.com/ClarityXDR/prod.git
cd prod/website

# Start the development environment
docker-compose -f docker-compose.dev.yml up

# Frontend development (separate terminal)
cd frontend
npm install
npm start

# Backend development (separate terminal)
cd backend
go mod download
go run main.go
```

### Project Structure

```
/website
├── /frontend                   # React frontend application
│   ├── /src
│   │   ├── /components        # Reusable React components
│   │   │   ├── /deployments   # Deployment-specific components
│   │   │   └── Navbar.js      # Navigation component
│   │   ├── /pages            # Page components
│   │   └── App.js            # Main application component
│   └── package.json
├── /backend                   # Go backend API server
│   ├── /handlers             # HTTP request handlers
│   ├── /internal             # Internal packages
│   ├── /config              # Configuration management
│   └── main.go
├── /agent-orchestrator       # Python AI agent service
│   ├── /agents              # Individual agent implementations
│   ├── /mcp                 # Mission Control Protocols
│   └── main.py
├── /webapp                   # ASP.NET Core web application
│   ├── /LogicAppManager     # Logic App deployment service
│   ├── /Controllers         # API controllers
│   └── /ClientApp           # React components for Logic Apps
├── /init-scripts            # Database initialization scripts
├── /deployment              # Deployment scripts for various platforms
├── /azure-deployment        # Azure-specific deployment templates
├── /templates               # Logic App and MDE rule templates
├── docker-compose.yml       # Production Docker Compose configuration
└── docker-compose.dev.yml   # Development Docker Compose configuration
```

## API Documentation

### Authentication
All API endpoints require JWT authentication except for public endpoints like `/api/health`.

```bash
# Authenticate
POST /api/auth/login
{
  "email": "user@example.com",
  "password": "password"
}

# Returns
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "user": { ... }
}
```

### Key Endpoints

#### License Management
```bash
# Validate license
GET /api/licensing/validate
Headers:
  x-license-key: <license_key>
  x-client-id: <client_id>
  x-product-name: <product_name>

# Create license
POST /api/licensing/licenses
{
  "client_id": "client123",
  "expiration_date": "2025-12-31",
  "features": ["feature1", "feature2"]
}
```

#### Logic App Deployment
```bash
# Deploy Logic App
POST /api/logicapps/deploy
{
  "clientId": "client123",
  "templateName": "sentinel-integration",
  "logicAppName": "MyLogicApp",
  "subscriptionId": "sub123",
  "resourceGroup": "rg-clarityxdr"
}
```

#### Threat Intelligence
```bash
# Add threat indicator
POST /api/threat-intel/indicators
{
  "type": "ip",
  "value": "192.168.1.1",
  "threatType": "malware",
  "confidence": 80
}

# Sync to Sentinel
POST /api/threat-intel/sync-sentinel
{
  "clientId": "client123"
}
```

## Security

ClarityXDR implements several security best practices:

- **HTTPS Everywhere**: All traffic is encrypted using SSL/TLS
- **Least Privilege**: Container services run as non-root users
- **Secret Management**: Sensitive data stored securely using environment variables
- **Input Validation**: All user inputs are validated and sanitized
- **Secure Headers**: HTTP security headers implemented in Nginx and Traefik
- **Rate Limiting**: API rate limiting to prevent abuse
- **CORS Protection**: Strict CORS policies enforced
- **SQL Injection Protection**: Parameterized queries throughout
- **XSS Protection**: React's built-in XSS protection plus additional sanitization

## License

Copyright © 2025 ClarityXDR. All rights reserved.

## Critical Post-Deployment Steps

### 1. DNS Configuration
Point your DNS A records for your domain and subdomains to your server's public IP address:
- `yourdomain.com` → Your server IP
- `api.yourdomain.com` → Your server IP
- `traefik.yourdomain.com` → Your server IP

### 2. Enable Database SSL (Important Security Measure)
By default, the database connection uses an unencrypted connection initially to ensure first-time deployment success. After confirming the application is running correctly, enable SSL for database connections:

```bash
cd /opt/clarityxdr && sudo bash -c "$(declare -f enable_database_ssl); enable_database_ssl"
```

This command will:
- Generate self-signed SSL certificates for PostgreSQL
- Configure PostgreSQL to use SSL
- Update the connection parameters to require SSL
- Restart the services to apply changes

**Why this is important:** Enabling SSL for database connections ensures that all traffic between the application and database is encrypted, protecting sensitive data from potential network-level attacks.

### 3. Configure AI Agents
Set up your AI agents with appropriate MCP guidelines:

```bash
# List available agents
cd /opt/clarityxdr/website
./list-agents.sh

# Configure an agent
./configure-agent.sh <agent_id>
```

### 4. Set Up GitHub Integration
1. Create a GitHub App or use a Personal Access Token
2. Configure webhook URLs for issue notifications
3. Set up repository permissions for agent access

### 5. Initial Client Setup
1. Access the admin dashboard at `https://yourdomain.com/dashboard`
2. Create your first client organization
3. Generate license keys for the client
4. Deploy initial Logic Apps and MDE rules

### 6. Access and Credentials
- Main application: `https://yourdomain.com`
- API endpoints: `https://api.yourdomain.com`
- Traefik dashboard: `https://traefik.yourdomain.com`
- Admin dashboard: `https://yourdomain.com/dashboard`

All credentials are stored in the `/opt/clarityxdr/CREDENTIALS.txt` file.

## Maintenance

### Common Commands
```bash
# View logs
cd /opt/clarityxdr/website && docker-compose logs -f

# View specific service logs
docker-compose logs -f backend
docker-compose logs -f frontend
docker-compose logs -f agent-orchestrator

# Restart services
systemctl restart clarityxdr

# Check status
systemctl status clarityxdr

# Stop services
systemctl stop clarityxdr

# Update application
cd /opt/clarityxdr
git pull origin main
cd website
docker-compose down
docker-compose pull
docker-compose up -d
```

### Database Management
```bash
# Create manual backup
cd /opt/clarityxdr/website
./backup-database.sh

# Restore from backup
./restore-database.sh <backup_file>

# Access PostgreSQL CLI
docker-compose exec postgres psql -U postgres -d clarityxdr
```

### Monitoring
- System metrics: Available in the dashboard at `/dashboard/metrics`
- Application logs: Centralized in `/opt/clarityxdr/website/logs`
- AI agent activity: Monitor via GitHub Issues and agent dashboard

### Backups
Database backups are automatically created daily in the `/opt/clarityxdr/website/backups` directory. Configure off-site backup storage for production environments.

## Troubleshooting

### Common Issues

**Services won't start:**
```bash
# Check Docker service
systemctl status docker

# Check disk space
df -h

# Check logs
docker-compose logs
```

**SSL certificate issues:**
```bash
# Force certificate renewal
docker-compose exec traefik traefik-certs-dumper --restart-containers
```

**Database connection issues:**
```bash
# Test database connection
docker-compose exec backend nc -zv postgres 5432

# Check database logs
docker-compose logs postgres
```

**AI agents not responding:**
```bash
# Check agent orchestrator logs
docker-compose logs agent-orchestrator

# Verify GitHub API access
curl -H "Authorization: token YOUR_GITHUB_TOKEN" https://api.github.com/user
```

## Support

For support, please:
1. Check the troubleshooting section above
2. Review logs in `/opt/clarityxdr/website/logs`
3. Create an issue in the GitHub repository
4. Contact support at support@clarityxdr.com

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.
