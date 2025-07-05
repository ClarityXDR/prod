<#
.SYNOPSIS
    Configures Azure Logic Apps for SOC automation
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$LogicAppName,
    
    [Parameter(Mandatory=$true)]
    [string]$SharePointSiteUrl
)

# Create Logic App for incident notification
$logicAppDefinition = @{
    "definition" = @{
        '$schema' = "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#"
        "contentVersion" = "1.0.0.0"
        "triggers" = @{
            "When_an_item_is_created" = @{
                "type" = "ApiConnection"
                "inputs" = @{
                    "host" = @{
                        "connection" = @{
                            "name" = "@parameters('$connections')['sharepointonline']['connectionId']"
                        }
                    }
                    "method" = "get"
                    "path" = "/datasets/@{encodeURIComponent('$SharePointSiteUrl')}/tables/@{encodeURIComponent('Security Incidents')}/onnewitems"
                }
            }
        }
        "actions" = @{
            "Send_Teams_notification" = @{
                "type" = "ApiConnection"
                "inputs" = @{
                    "host" = @{
                        "connection" = @{
                            "name" = "@parameters('$connections')['teams']['connectionId']"
                        }
                    }
                    "method" = "post"
                    "path" = "/v3/beta/teams/conversation/message/poster/Flow bot/location/@{encodeURIComponent('SOC Channel')}"
                    "body" = @{
                        "messageBody" = "New Security Incident: @{triggerBody()?['Title']} - Severity: @{triggerBody()?['Severity']}"
                    }
                }
            }
        }
    }
}

# Deploy Logic App
Write-Host "Creating Logic App: $LogicAppName"
az logic workflow create --resource-group $ResourceGroupName --name $LogicAppName --definition $logicAppDefinition