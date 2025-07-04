param location string = resourceGroup().location
param name string = 'clarityxdr'
param containerRegistryUrl string
param containerRegistryUsername string
@secure()
param containerRegistryPassword string
param frontendImage string = 'clarityxdr/frontend:latest'
param backendImage string = 'clarityxdr/backend:latest'

// Environment for Container Apps
resource environment 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: '${name}-environment'
  location: location
  properties: {}
}

// Frontend Container App
resource frontendApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: '${name}-frontend'
  location: location
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 80
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      registries: [
        {
          server: containerRegistryUrl
          username: containerRegistryUsername
          passwordSecretRef: 'registry-password'
        }
      ]
      secrets: [
        {
          name: 'registry-password'
          value: containerRegistryPassword
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'frontend'
          image: '${containerRegistryUrl}/${frontendImage}'
          resources: {
            cpu: 1
            memory: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
      }
    }
  }
}

// Backend Container App
resource backendApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: '${name}-backend'
  location: location
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
      registries: [
        {
          server: containerRegistryUrl
          username: containerRegistryUsername
          passwordSecretRef: 'registry-password'
        }
      ]
      secrets: [
        {
          name: 'registry-password'
          value: containerRegistryPassword
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'backend'
          image: '${containerRegistryUrl}/${backendImage}'
          resources: {
            cpu: 1
            memory: '1Gi'
          }
          env: [
            {
              name: 'DB_HOST'
              value: postgreSQL.properties.fullyQualifiedDomainName
            }
            {
              name: 'DB_PORT'
              value: '5432'
            }
            {
              name: 'DB_USER'
              value: '${dbUser}@${postgreSQL.name}'
            }
            {
              name: 'DB_PASSWORD'
              secretRef: 'db-password'
            }
            {
              name: 'DB_NAME'
              value: 'clarityxdr'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
      }
    }
  }
}

// PostgreSQL Database
param dbUser string = 'postgres'
@secure()
param dbPassword string

resource postgreSQL 'Microsoft.DBforPostgreSQL/servers@2017-12-01' = {
  name: '${name}-db'
  location: location
  properties: {
    version: '14'
    administratorLogin: dbUser
    administratorLoginPassword: dbPassword
    sslEnforcement: 'Disabled'
    createMode: 'Default'
  }
}

resource postgreSQLFirewall 'Microsoft.DBforPostgreSQL/servers/firewallRules@2017-12-01' = {
  parent: postgreSQL
  name: 'AllowAllAzureIPs'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource postgreSQLDatabase 'Microsoft.DBforPostgreSQL/servers/databases@2017-12-01' = {
  parent: postgreSQL
  name: 'clarityxdr'
  properties: {
    charset: 'utf8'
    collation: 'en_US.utf8'
  }
}

output frontendUrl string = 'https://${frontendApp.properties.configuration.ingress.fqdn}'
output backendUrl string = 'https://${backendApp.properties.configuration.ingress.fqdn}'
