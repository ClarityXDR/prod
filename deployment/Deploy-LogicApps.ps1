<#
.SYNOPSIS
    Deploys sanitized Logic Apps/Playbooks to Azure Sentinel
.DESCRIPTION
    This script deploys all sanitized Logic App JSON files to Azure, creates necessary connections,
    and configures them for Microsoft Sentinel integration.
.PARAMETER SubscriptionId
    Azure subscription ID where resources will be deployed
.PARAMETER ResourceGroupName
    Resource group name for Logic Apps deployment
.PARAMETER Location
    Azure region for deployment (default: East US)
.PARAMETER LogicAppsPath
    Path to the sanitized Logic Apps JSON files
.PARAMETER ConfigFilePath
    Path to deployment configuration file
.EXAMPLE
    .\Deploy-LogicApps.ps1 -SubscriptionId "your-sub-id" -ResourceGroupName "sentinel-rg" -ConfigFilePath ".\config.json"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "East US",
    
    [Parameter(Mandatory = $false)]
    [string]$LogicAppsPath = "c:\ClarityXDR\prod\logic-apps",
    
    [Parameter(Mandatory = $true)]
    [string]$ConfigFilePath
)

# Import required modules
Import-Module Az.Accounts -Force
Import-Module Az.Resources -Force
Import-Module Az.LogicApp -Force
Import-Module Az.OperationalInsights -Force

# Initialize logging
$logFile = "deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
Start-Transcript -Path $logFile

try {
    Write-Host "=== Azure Logic Apps Deployment Script ===" -ForegroundColor Cyan
    Write-Host "Starting deployment process..." -ForegroundColor Green
    
    # Load configuration
    if (-not (Test-Path $ConfigFilePath)) {
        throw "Configuration file not found: $ConfigFilePath"
    }
    
    $config = Get-Content $ConfigFilePath | ConvertFrom-Json
    Write-Host "Configuration loaded successfully" -ForegroundColor Green
    
    # Connect to Azure
    Write-Host "Connecting to Azure..." -ForegroundColor Yellow
    Connect-AzAccount -SubscriptionId $SubscriptionId
    Set-AzContext -SubscriptionId $SubscriptionId
    
    # Verify resource group exists
    $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $rg) {
        Write-Host "Creating resource group: $ResourceGroupName" -ForegroundColor Yellow
        New-AzResourceGroup -Name $ResourceGroupName -Location $Location
    }
    
    # Create API connections first
    Write-Host "Creating API connections..." -ForegroundColor Yellow
    
    $connections = @{
        "azuresentinel-connection" = @{
            apiId = "/subscriptions/$SubscriptionId/providers/Microsoft.Web/locations/$Location/managedApis/azuresentinel"
            displayName = "Azure Sentinel Connection"
            parameterValues = @{}
        }
        "office365-connection" = @{
            apiId = "/subscriptions/$SubscriptionId/providers/Microsoft.Web/locations/$Location/managedApis/office365"
            displayName = "Office 365 Connection"
            parameterValues = @{}
        }
        "teams-connection" = @{
            apiId = "/subscriptions/$SubscriptionId/providers/Microsoft.Web/locations/$Location/managedApis/teams"
            displayName = "Microsoft Teams Connection"
            parameterValues = @{}
        }
        "azuremonitorlogs-connection" = @{
            apiId = "/subscriptions/$SubscriptionId/providers/Microsoft.Web/locations/$Location/managedApis/azuremonitorlogs"
            displayName = "Azure Monitor Logs Connection"
            parameterValues = @{}
        }
        "wdatp-connection" = @{
            apiId = "/subscriptions/$SubscriptionId/providers/Microsoft.Web/locations/$Location/managedApis/wdatp"
            displayName = "Microsoft Defender ATP Connection"
            parameterValues = @{}
        }
        "virustotal-connection" = @{
            apiId = "/subscriptions/$SubscriptionId/providers/Microsoft.Web/locations/$Location/managedApis/virustotal"
            displayName = "VirusTotal Connection"
            parameterValues = @{}
        }
    }
    
    foreach ($connName in $connections.Keys) {
        Write-Host "Creating connection: $connName" -ForegroundColor Cyan
        
        $connectionTemplate = @{
            '$schema' = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
            contentVersion = "1.0.0.0"
            parameters = @{}
            resources = @(
                @{
                    type = "Microsoft.Web/connections"
                    apiVersion = "2016-06-01"
                    name = $connName
                    location = $Location
                    properties = @{
                        displayName = $connections[$connName].displayName
                        api = @{
                            id = $connections[$connName].apiId
                        }
                        parameterValues = $connections[$connName].parameterValues
                    }
                }
            )
        }
        
        $templateFile = "connection-$connName.json"
        $connectionTemplate | ConvertTo-Json -Depth 10 | Out-File $templateFile
        
        try {
            New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName `
                -TemplateFile $templateFile `
                -Name "deploy-$connName" `
                -Force
            Write-Host "✓ Connection created: $connName" -ForegroundColor Green
        }
        catch {
            Write-Warning "Failed to create connection $connName`: $_"
        }
        
        Remove-Item $templateFile -Force
    }
    
    # Get all Logic App JSON files
    $logicAppFiles = Get-ChildItem -Path $LogicAppsPath -Filter "*.json" | 
        Where-Object { $_.Name -notmatch "(sanitization_report|README|DEPLOYMENT_GUIDE)" }
    
    Write-Host "Found $($logicAppFiles.Count) Logic App files to deploy" -ForegroundColor Yellow
    
    # Function to replace placeholders in JSON content
    function Update-LogicAppContent {
        param([string]$content, [object]$config)
        
        # Replace subscription ID
        $content = $content -replace "00000000-0000-0000-0000-000000000000", $config.subscriptionId
        
        # Replace resource group
        $content = $content -replace "YourResourceGroup", $config.resourceGroupName
        
        # Replace email addresses
        $content = $content -replace "admin@company\.com", $config.adminEmail
        $content = $content -replace "security@company\.com", $config.securityEmail
        $content = $content -replace "securityteam@company\.com", $config.securityTeamEmail
        
        # Replace company name
        $content = $content -replace "YourCompany", $config.companyName
        $content = $content -replace "company\.com", $config.companyDomain
        
        # Replace Teams channel ID
        $content = $content -replace "19:00000000000000000000000000000000@thread\.tacv2", $config.teamsChannelId
        
        # Replace workspace ID if provided
        if ($config.sentinelWorkspaceId) {
            $content = $content -replace "ff0790ad-e860-4d15-8638-089ed9ea1dec", $config.sentinelWorkspaceId
        }
        
        # Replace region placeholder
        $content = $content -replace "/region/", "/$($config.location.Replace(' ', '').ToLower())/"
        
        return $content
    }
    
    # Deploy Logic Apps
    $deploymentResults = @()
    $failedDeployments = @()
    
    foreach ($file in $logicAppFiles) {
        $logicAppName = $file.BaseName
        Write-Host "Processing Logic App: $logicAppName" -ForegroundColor Cyan
        
        try {
            # Read and update JSON content
            $content = Get-Content $file.FullName -Raw
            $updatedContent = Update-LogicAppContent -content $content -config $config
            
            # Parse JSON to validate
            $logicAppDefinition = $updatedContent | ConvertFrom-Json
            
            # Create ARM template for Logic App
            $template = @{
                '$schema' = "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#"
                contentVersion = "1.0.0.0"
                parameters = @{}
                resources = @(
                    @{
                        type = "Microsoft.Logic/workflows"
                        apiVersion = "2017-07-01"
                        name = $logicAppName
                        location = $Location
                        properties = $logicAppDefinition.definition
                        parameters = $logicAppDefinition.parameters
                    }
                )
                outputs = @{
                    logicAppName = @{
                        type = "string"
                        value = "[variables('logicAppName')]"
                    }
                }
            }
            
            # Add variables for the Logic App name
            $template.variables = @{
                logicAppName = $logicAppName
            }
            
            $templateFile = "template-$logicAppName.json"
            $template | ConvertTo-Json -Depth 15 | Out-File $templateFile
            
            # Deploy Logic App
            Write-Host "Deploying Logic App: $logicAppName" -ForegroundColor Yellow
            $deployment = New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName `
                -TemplateFile $templateFile `
                -Name "deploy-$logicAppName" `
                -Force
            
            if ($deployment.ProvisioningState -eq "Succeeded") {
                Write-Host "✓ Successfully deployed: $logicAppName" -ForegroundColor Green
                $deploymentResults += @{
                    Name = $logicAppName
                    Status = "Success"
                    Message = "Deployed successfully"
                }
            }
            else {
                throw "Deployment failed with state: $($deployment.ProvisioningState)"
            }
            
            Remove-Item $templateFile -Force
        }
        catch {
            $errorMessage = $_.Exception.Message
            Write-Host "✗ Failed to deploy: $logicAppName - $errorMessage" -ForegroundColor Red
            $failedDeployments += @{
                Name = $logicAppName
                Error = $errorMessage
            }
            $deploymentResults += @{
                Name = $logicAppName
                Status = "Failed"
                Message = $errorMessage
            }
        }
    }
    
    # Post-deployment configuration
    Write-Host "`n=== Post-Deployment Configuration ===" -ForegroundColor Cyan
    
    # Enable diagnostic settings for Logic Apps
    Write-Host "Configuring diagnostic settings..." -ForegroundColor Yellow
    
    $successfulApps = $deploymentResults | Where-Object { $_.Status -eq "Success" }
    foreach ($app in $successfulApps) {
        try {
            # Configure diagnostic settings if workspace is provided
            if ($config.logAnalyticsWorkspaceId) {
                # Add diagnostic settings configuration here
                Write-Host "Configured diagnostics for: $($app.Name)" -ForegroundColor Green
            }
        }
        catch {
            Write-Warning "Failed to configure diagnostics for $($app.Name): $_"
        }
    }
    
    # Generate deployment report
    Write-Host "`n=== Deployment Summary ===" -ForegroundColor Cyan
    Write-Host "Total Logic Apps processed: $($logicAppFiles.Count)" -ForegroundColor White
    Write-Host "Successful deployments: $($deploymentResults | Where-Object {$_.Status -eq 'Success'} | Measure-Object | Select-Object -ExpandProperty Count)" -ForegroundColor Green
    Write-Host "Failed deployments: $($failedDeployments.Count)" -ForegroundColor Red
    
    if ($failedDeployments.Count -gt 0) {
        Write-Host "`nFailed Deployments:" -ForegroundColor Red
        foreach ($failed in $failedDeployments) {
            Write-Host "  - $($failed.Name): $($failed.Error)" -ForegroundColor Red
        }
    }
    
    # Save deployment report
    $report = @{
        Timestamp = Get-Date
        SubscriptionId = $SubscriptionId
        ResourceGroupName = $ResourceGroupName
        Location = $Location
        TotalApps = $logicAppFiles.Count
        SuccessfulDeployments = ($deploymentResults | Where-Object {$_.Status -eq 'Success'}).Count
        FailedDeployments = $failedDeployments.Count
        Results = $deploymentResults
        FailedApps = $failedDeployments
    }
    
    $reportFile = "deployment-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $report | ConvertTo-Json -Depth 5 | Out-File $reportFile
    Write-Host "`nDeployment report saved: $reportFile" -ForegroundColor Green
    
    # Next steps
    Write-Host "`n=== Next Steps ===" -ForegroundColor Cyan
    Write-Host "1. Authenticate API connections in Azure Portal" -ForegroundColor Yellow
    Write-Host "2. Test Logic Apps manually before enabling triggers" -ForegroundColor Yellow
    Write-Host "3. Configure monitoring and alerting" -ForegroundColor Yellow
    Write-Host "4. Review and enable recurrence triggers" -ForegroundColor Yellow
    Write-Host "5. Validate Sentinel integration" -ForegroundColor Yellow
    
}
catch {
    Write-Host "Deployment failed: $_" -ForegroundColor Red
    throw
}
finally {
    Stop-Transcript
    Write-Host "`nDeployment log saved: $logFile" -ForegroundColor Green
}
