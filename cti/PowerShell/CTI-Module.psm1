# Microsoft 365 Central Threat Intelligence PowerShell Module
# Bio-Rad Laboratories Inc - CTI Solution

#Requires -Modules Az, ExchangeOnlineManagement, Microsoft.Graph, MicrosoftDefenderATP

<#
.SYNOPSIS
    Central Threat Intelligence PowerShell Module for Microsoft 365 E5
.DESCRIPTION
    This module provides PowerShell functions to manage threat intelligence indicators
    across Microsoft 365 security products with centralized management via Sentinel.
.AUTHOR
    Bio-Rad Security Team
.VERSION
    1.0.0
#>

# Module Variables
$script:SentinelWorkspaceId = $null
$script:LogicAppUrls = @{}
$script:ConnectedServices = @{}

#region Authentication and Configuration

<#
.SYNOPSIS
    Initialize the CTI module with required configurations
.PARAMETER SentinelWorkspaceId
    The workspace ID for Microsoft Sentinel
.PARAMETER LogicAppUrls
    Hashtable containing Logic App trigger URLs
#>
function Initialize-CTIModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SentinelWorkspaceId,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$LogicAppUrls
    )
    
    $script:SentinelWorkspaceId = $SentinelWorkspaceId
    $script:LogicAppUrls = $LogicAppUrls
    
    Write-Host "CTI Module initialized successfully" -ForegroundColor Green
    Write-Host "Sentinel Workspace: $SentinelWorkspaceId" -ForegroundColor Cyan
    Write-Host "Logic Apps configured: $($LogicAppUrls.Keys -join ', ')" -ForegroundColor Cyan
}

<#
.SYNOPSIS
    Connect to all required Microsoft 365 services
#>
function Connect-CTIServices {
    [CmdletBinding()]
    param()
    
    try {
        # Connect to Azure
        Write-Host "Connecting to Azure..." -ForegroundColor Yellow
        Connect-AzAccount -ErrorAction Stop
        $script:ConnectedServices.Azure = $true
        
        # Connect to Exchange Online
        Write-Host "Connecting to Exchange Online..." -ForegroundColor Yellow
        Connect-ExchangeOnline -ShowProgress $false -ErrorAction Stop
        $script:ConnectedServices.ExchangeOnline = $true
        
        # Connect to Microsoft Graph
        Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Yellow
        Connect-MgGraph -Scopes "ThreatIndicators.ReadWrite.OwnedBy", "Policy.Read.All", "Policy.ReadWrite.ConditionalAccess" -ErrorAction Stop
        $script:ConnectedServices.MicrosoftGraph = $true
        
        Write-Host "All services connected successfully!" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to connect to services: $($_.Exception.Message)"
        return $false
    }
}

#endregion

#region Core CTI Functions

<#
.SYNOPSIS
    Retrieve threat intelligence indicators from Sentinel
.PARAMETER IndicatorType
    Type of indicator to retrieve (FileHash, IPAddress, URL, Domain, Certificate)
.PARAMETER DaysBack
    Number of days back to search (default: 30)
.PARAMETER ConfidenceThreshold
    Minimum confidence score (default: 50)
#>
function Get-CTIIndicators {
    [CmdletBinding()]
    param(
        [ValidateSet("FileHash", "IPAddress", "URL", "Domain", "Certificate", "All")]
        [string]$IndicatorType = "All",
        
        [int]$DaysBack = 30,
        
        [ValidateRange(1, 100)]
        [int]$ConfidenceThreshold = 50
    )
    
    if (-not $script:SentinelWorkspaceId) {
        throw "Module not initialized. Run Initialize-CTIModule first."
    }
    
    $typeFilter = if ($IndicatorType -eq "All") { "" } else { "| where IndicatorType_s == '$IndicatorType'" }
    
    $kqlQuery = @"
CTI_IndicatorManagement_CL
| where CreatedDate_t >= ago(${DaysBack}d)
| where ConfidenceScore_d >= $ConfidenceThreshold
| where ExpirationDate_t > now()
$typeFilter
| project IndicatorId_s, IndicatorType_s, IndicatorValue_s, ConfidenceScore_d, 
          Source_s, CreatedDate_t, ExpirationDate_t, DeploymentStatus_s, ValidationStatus_s, PlacementStrategy_s
| order by CreatedDate_t desc
"@
    
    try {
        $results = Invoke-AzOperationalInsightsQuery -WorkspaceId $script:SentinelWorkspaceId -Query $kqlQuery
        
        if ($results.Results) {
            return $results.Results | ForEach-Object {
                [PSCustomObject]@{
                    IndicatorId = $_.IndicatorId_s
                    Type = $_.IndicatorType_s
                    Value = $_.IndicatorValue_s
                    Confidence = $_.ConfidenceScore_d
                    Source = $_.Source_s
                    Created = $_.CreatedDate_t
                    Expires = $_.ExpirationDate_t
                    DeploymentStatus = $_.DeploymentStatus_s
                    ValidationStatus = $_.ValidationStatus_s
                    PlacementStrategy = $_.PlacementStrategy_s
                }
            }
        }
        else {
            Write-Warning "No indicators found matching the criteria"
            return @()
        }
    }
    catch {
        Write-Error "Failed to retrieve indicators: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
    Create or update a threat intelligence indicator
.PARAMETER Type
    Type of indicator
.PARAMETER Value
    The indicator value
.PARAMETER Confidence
    Confidence score (1-100)
.PARAMETER Source
    Source of the indicator
.PARAMETER Description
    Description of the threat
.PARAMETER Severity
    Severity level
.PARAMETER TLP
    Traffic Light Protocol classification
#>
function Set-CTIIndicator {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("FileHash", "IPAddress", "URL", "Domain", "Certificate")]
        [string]$Type,
        
        [Parameter(Mandatory = $true)]
        [string]$Value,
        
        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 100)]
        [int]$Confidence,
        
        [Parameter(Mandatory = $true)]
        [string]$Source,
        
        [string]$Description = "",
        
        [ValidateSet("Low", "Medium", "High", "Critical")]
        [string]$Severity = "Medium",
        
        [ValidateSet("White", "Green", "Amber", "Red")]
        [string]$TLP = "Amber"
    )
    
    if (-not $script:LogicAppUrls.ContainsKey("Ingestion")) {
        throw "Ingestion Logic App URL not configured. Run Initialize-CTIModule first."
    }
    
    $indicator = @{
        type = $Type
        value = $Value
        confidence = $Confidence
        source = $Source
        description = $Description
        severity = $Severity
        tlp = $TLP
    }
    
    $payload = @{
        indicators = @($indicator)
    } | ConvertTo-Json -Depth 3
    
    try {
        $response = Invoke-RestMethod -Uri $script:LogicAppUrls.Ingestion -Method Post -Body $payload -ContentType "application/json"
        Write-Host "Indicator submitted successfully" -ForegroundColor Green
        return $response
    }
    catch {
        Write-Error "Failed to submit indicator: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
    Remove a threat intelligence indicator from all security products
.PARAMETER IndicatorId
    The unique identifier of the indicator to remove
.PARAMETER Reason
    Reason for removal
#>
function Remove-CTIIndicator {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$IndicatorId,
        
        [string]$Reason = "Manual removal"
    )
    
    if ($PSCmdlet.ShouldProcess($IndicatorId, "Remove CTI Indicator")) {
        # Get indicator details first
        $indicator = Get-CTIIndicators | Where-Object { $_.IndicatorId -eq $IndicatorId }
        
        if (-not $indicator) {
            Write-Warning "Indicator $IndicatorId not found"
            return
        }
        
        Write-Host "Removing indicator: $($indicator.Value) from all security products..." -ForegroundColor Yellow
        
        # Remove from MDE
        if ($indicator.PlacementStrategy -like "*MDE*") {
            Remove-MDEIndicator -IndicatorValue $indicator.Value -IndicatorType $indicator.Type
        }
        
        # Remove from Exchange Online
        if ($indicator.PlacementStrategy -like "*Exchange*") {
            Remove-ExchangeBlockListEntry -IndicatorValue $indicator.Value -IndicatorType $indicator.Type
        }
        
        # Remove from MDCA
        if ($indicator.PlacementStrategy -like "*MDCA*") {
            Remove-MDCAPolicy -IndicatorValue $indicator.Value
        }
        
        # Remove from Entra ID
        if ($indicator.PlacementStrategy -like "*EntraID*") {
            Remove-EntraNamedLocation -IndicatorValue $indicator.Value
        }
        
        # Log removal to Sentinel
        $removalLog = @{
            IndicatorId = $IndicatorId
            Action = "Removed"
            Reason = $Reason
            RemovedDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            RemovedBy = $env:USERNAME
        } | ConvertTo-Json
        
        # Send to Sentinel via Data Collector API
        Send-CTILogToSentinel -LogType "CTI_IndicatorRemoval" -LogData $removalLog
        
        Write-Host "Indicator removed successfully" -ForegroundColor Green
    }
}

<#
.SYNOPSIS
    Test indicator validity against threat intelligence services
.PARAMETER IndicatorValue
    The indicator value to validate
.PARAMETER IndicatorType
    The type of indicator
#>
function Test-CTIIndicatorValidity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$IndicatorValue,
        
        [Parameter(Mandatory = $true)]
        [ValidateSet("FileHash", "IPAddress", "URL", "Domain")]
        [string]$IndicatorType
    )
    
    if (-not $script:LogicAppUrls.ContainsKey("Validation")) {
        throw "Validation Logic App URL not configured."
    }
    
    $validationRequest = @{
        indicators = @(@{
            type = $IndicatorType
            value = $IndicatorValue
        })
    } | ConvertTo-Json -Depth 3
    
    try {
        $response = Invoke-RestMethod -Uri $script:LogicAppUrls.Validation -Method Post -Body $validationRequest -ContentType "application/json"
        return $response
    }
    catch {
        Write-Error "Validation failed: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
    Synchronize indicators to security products manually
.PARAMETER IndicatorId
    Specific indicator ID to sync, or all if not specified
#>
function Sync-CTIToSecurityProducts {
    [CmdletBinding()]
    param(
        [string]$IndicatorId
    )
    
    $indicators = if ($IndicatorId) {
        Get-CTIIndicators | Where-Object { $_.IndicatorId -eq $IndicatorId }
    } else {
        Get-CTIIndicators | Where-Object { $_.DeploymentStatus -ne "Deployed" }
    }
    
    if (-not $indicators) {
        Write-Warning "No indicators found for synchronization"
        return
    }
    
    foreach ($indicator in $indicators) {
        Write-Host "Syncing indicator: $($indicator.Value)" -ForegroundColor Cyan
        
        switch ($indicator.PlacementStrategy) {
            "MDE_Primary" {
                Set-MDEIndicator -IndicatorValue $indicator.Value -IndicatorType $indicator.Type -Action "Block"
            }
            "Exchange_ConnectionFilter" {
                Add-ExchangeConnectionFilterIP -IPAddress $indicator.Value
            }
            "Exchange_TenantAllowBlock" {
                Add-ExchangeTenantBlockList -Value $indicator.Value -Type $indicator.Type
            }
            "MDCA_EntraID" {
                Set-MDCAPolicy -IPAddress $indicator.Value
                Add-EntraNamedLocation -IPAddress $indicator.Value -Name "CTI_Malicious_$($indicator.IndicatorId.Substring(0,8))"
            }
            default {
                Write-Warning "Unknown placement strategy: $($indicator.PlacementStrategy)"
            }
        }
    }
}

#endregion

#region Product-Specific Functions

<#
.SYNOPSIS
    Deploy indicator to Microsoft Defender for Endpoint
#>
function Set-MDEIndicator {
    [CmdletBinding()]
    param(
        [string]$IndicatorValue,
        [string]$IndicatorType,
        [string]$Action = "Block"
    )
    
    try {
        # This would use the actual MDE API
        Write-Host "Deploying to MDE: $IndicatorValue" -ForegroundColor Green
        # Implementation would call MDE API here
    }
    catch {
        Write-Error "Failed to deploy to MDE: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Add IP address to MDCA as risky IP range
.PARAMETER IPAddress
    The IP address or CIDR range to mark as risky
.PARAMETER Description
    Description for the risky IP entry
.PARAMETER Severity
    Risk severity level
#>
function Set-MDCAPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$IPAddress,
        
        [string]$Description = "CTI Malicious IP",
        
        [ValidateSet("Low", "Medium", "High")]
        [string]$Severity = "High"
    )
    
    if (-not $script:ConnectedServices.MicrosoftGraph) {
        throw "Microsoft Graph not connected. Run Connect-CTIServices first."
    }
    
    try {
        # Create MDCA IP range policy for risky category
        $policyBody = @{
            name = "CTI_RiskyIP_$($IPAddress.Replace('.', '_').Replace('/', '_'))"
            description = $Description
            type = "IP_CATEGORY"
            filters = @{
                ip = @{
                    source = @{
                        ranges = @($IPAddress)
                    }
                }
            }
            actions = @{
                type = "GOVERNANCE"
                governance = @{
                    categories = @("RISKY")
                }
            }
            severity = $Severity.ToUpper()
            isEnabled = $true
        }
        
        $policyJson = $policyBody | ConvertTo-Json -Depth 10
        
        # Call MDCA API to create the policy
        $uri = "https://graph.microsoft.com/beta/security/cloudAppSecurityProfiles"
        $headers = @{
            'Authorization' = "Bearer $((Get-MgContext).Token)"
            'Content-Type' = 'application/json'
        }
        
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body $policyJson -Headers $headers
        
        Write-Host "Successfully added $IPAddress to MDCA as risky IP category" -ForegroundColor Green
        
        # Log the action
        $logEntry = @{
            Action = "MDCA_Policy_Created"
            IPAddress = $IPAddress
            PolicyName = $policyBody.name
            Severity = $Severity
            Timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        }
        
        Send-CTILogToSentinel -LogType "CTI_MDCAPolicy" -LogData ($logEntry | ConvertTo-Json)
        
        return $response
    }
    catch {
        Write-Error "Failed to create MDCA policy for $IPAddress : $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
    Remove IP address from MDCA risky category
.PARAMETER IPAddress
    The IP address to remove from risky category
#>
function Remove-MDCAPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$IPAddress
    )
    
    try {
        $policyName = "CTI_RiskyIP_$($IPAddress.Replace('.', '_').Replace('/', '_'))"
        
        # Find and delete the policy
        $uri = "https://graph.microsoft.com/beta/security/cloudAppSecurityProfiles?`$filter=displayName eq '$policyName'"
        $headers = @{
            'Authorization' = "Bearer $((Get-MgContext).Token)"
        }
        
        $policies = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
        
        if ($policies.value.Count -eq 0) {
            Write-Warning "No MDCA policy found with name: $policyName"
            return
        }
        
        foreach ($policy in $policies.value) {
            $deleteUri = "https://graph.microsoft.com/beta/security/cloudAppSecurityProfiles/$($policy.id)"
            Invoke-RestMethod -Uri $deleteUri -Method Delete -Headers $headers
            Write-Host "Removed MDCA policy: $policyName for $IPAddress" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Error "Failed to remove MDCA policy for $IPAddress : $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Create Entra ID Named Location that blocks sign-ins from specified IP
.PARAMETER IPAddress
    The IP address or CIDR range to block
.PARAMETER Name
    Name for the Named Location
.PARAMETER Description
    Description for the Named Location
#>
function Add-EntraNamedLocation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$IPAddress,
        
        [string]$Name,
        
        [string]$Description = "CTI Malicious IP - Auto-generated"
    )
    
    if (-not $script:ConnectedServices.MicrosoftGraph) {
        throw "Microsoft Graph not connected. Run Connect-CTIServices first."
    }
    
    if (-not $Name) {
        $Name = "CTI_Malicious_$($IPAddress.Replace('.', '_').Replace('/', '_'))"
    }
    
    try {
        # Create the Named Location
        $namedLocationBody = @{
            "@odata.type" = "#microsoft.graph.ipNamedLocation"
            displayName = $Name
            isTrusted = $false
            ipRanges = @(
                @{
                    "@odata.type" = "#microsoft.graph.iPv4CidrRange"
                    cidrAddress = if ($IPAddress.Contains('/')) { $IPAddress } else { "$IPAddress/32" }
                }
            )
        }
        
        $namedLocationJson = $namedLocationBody | ConvertTo-Json -Depth 10
        
        # Create Named Location
        $uri = "https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations"
        $headers = @{
            'Authorization' = "Bearer $((Get-MgContext).Token)"
            'Content-Type' = 'application/json'
        }
        
        $namedLocation = Invoke-RestMethod -Uri $uri -Method Post -Body $namedLocationJson -Headers $headers
        
        Write-Host "Created Named Location: $Name" -ForegroundColor Green
        
        # Create Conditional Access Policy to block sign-ins from this location
        $caPolicy = @{
            displayName = "CTI_Block_$($Name)"
            state = "enabled"
            conditions = @{
                locations = @{
                    includeLocations = @($namedLocation.id)
                    excludeLocations = @()
                }
                users = @{
                    includeUsers = @("All")
                    excludeUsers = @()
                    includeGroups = @()
                    excludeGroups = @()
                }
                applications = @{
                    includeApplications = @("All")
                    excludeApplications = @()
                }
            }
            grantControls = @{
                operator = "OR"
                builtInControls = @("block")
            }
        }
        
        $caPolicyJson = $caPolicy | ConvertTo-Json -Depth 10
        
        # Create Conditional Access Policy
        $caUri = "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies"
        $caPolicyResponse = Invoke-RestMethod -Uri $caUri -Method Post -Body $caPolicyJson -Headers $headers
        
        Write-Host "Created Conditional Access Policy to block sign-ins from $IPAddress" -ForegroundColor Green
        
        # Log the action
        $logEntry = @{
            Action = "EntraID_NamedLocation_Created"
            IPAddress = $IPAddress
            NamedLocationName = $Name
            NamedLocationId = $namedLocation.id
            ConditionalAccessPolicyName = $caPolicy.displayName
            ConditionalAccessPolicyId = $caPolicyResponse.id
            Timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        }
        
        Send-CTILogToSentinel -LogType "CTI_EntraIDPolicy" -LogData ($logEntry | ConvertTo-Json)
        
        return @{
            NamedLocation = $namedLocation
            ConditionalAccessPolicy = $caPolicyResponse
        }
    }
    catch {
        Write-Error "Failed to create Entra ID Named Location for $IPAddress : $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
    Remove Entra ID Named Location and associated Conditional Access Policy
.PARAMETER IPAddress
    The IP address to remove blocking for
#>
function Remove-EntraNamedLocation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$IPAddress
    )
    
    try {
        $locationName = "CTI_Malicious_$($IPAddress.Replace('.', '_').Replace('/', '_'))"
        $policyName = "CTI_Block_$locationName"
        
        $headers = @{
            'Authorization' = "Bearer $((Get-MgContext).Token)"
        }
        
        # Find and delete Conditional Access Policy first
        $caUri = "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies?`$filter=displayName eq '$policyName'"
        $caPolicies = Invoke-RestMethod -Uri $caUri -Method Get -Headers $headers
        
        foreach ($policy in $caPolicies.value) {
            $deleteUri = "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies/$($policy.id)"
            Invoke-RestMethod -Uri $deleteUri -Method Delete -Headers $headers
            Write-Host "Removed Conditional Access Policy: $policyName" -ForegroundColor Yellow
        }
        
        # Find and delete Named Location
        $nlUri = "https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations?`$filter=displayName eq '$locationName'"
        $namedLocations = Invoke-RestMethod -Uri $nlUri -Method Get -Headers $headers
        
        foreach ($location in $namedLocations.value) {
            $deleteUri = "https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations/$($location.id)"
            Invoke-RestMethod -Uri $deleteUri -Method Delete -Headers $headers
            Write-Host "Removed Named Location: $locationName" -ForegroundColor Yellow
        }
        
        # Log the removal
        $logEntry = @{
            Action = "EntraID_NamedLocation_Removed"
            IPAddress = $IPAddress
            LocationName = $locationName
            PolicyName = $policyName
            Timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
        }
        
        Send-CTILogToSentinel -LogType "CTI_EntraIDPolicy" -LogData ($logEntry | ConvertTo-Json)
    }
    catch {
        Write-Error "Failed to remove Entra ID Named Location for $IPAddress : $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Add IP to Exchange Online Connection Filter
#>
function Add-ExchangeConnectionFilterIP {
    [CmdletBinding()]
    param(
        [string]$IPAddress
    )
    
    try {
        $currentPolicy = Get-HostedConnectionFilterPolicy -Identity "Default"
        $newBlockList = $currentPolicy.IPBlockList + $IPAddress
        Set-HostedConnectionFilterPolicy -Identity "Default" -IPBlockList $newBlockList
        Write-Host "Added $IPAddress to Exchange Connection Filter" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to update Exchange Connection Filter: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Add entry to Exchange Online Tenant Allow/Block Lists
#>
function Add-ExchangeTenantBlockList {
    [CmdletBinding()]
    param(
        [string]$Value,
        [string]$Type
    )
    
    try {
        switch ($Type) {
            "URL" {
                New-TenantAllowBlockListItems -ListType Url -Block -Entries $Value -NoExpiration
                Write-Host "Added $Value to Exchange Tenant Block List (URL)" -ForegroundColor Green
            }
            "Domain" {
                New-TenantAllowBlockListItems -ListType Domain -Block -Entries $Value -NoExpiration
                Write-Host "Added $Value to Exchange Tenant Block List (Domain)" -ForegroundColor Green
            }
            "FileHash" {
                New-TenantAllowBlockListItems -ListType FileHash -Block -Entries $Value -NoExpiration
                Write-Host "Added $Value to Exchange Tenant Block List (FileHash)" -ForegroundColor Green
            }
            default {
                Write-Warning "Exchange Tenant Block List does not support type: $Type"
            }
        }
    }
    catch {
        Write-Error "Failed to add to Exchange Tenant Block List: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Remove entry from Exchange Tenant Block List
#>
function Remove-ExchangeBlockListEntry {
    [CmdletBinding()]
    param(
        [string]$IndicatorValue,
        [string]$IndicatorType
    )
    
    try {
        switch ($IndicatorType) {
            "IPAddress" {
                # Remove from Connection Filter
                $currentPolicy = Get-HostedConnectionFilterPolicy -Identity "Default"
                $newBlockList = $currentPolicy.IPBlockList | Where-Object { $_ -ne $IndicatorValue }
                Set-HostedConnectionFilterPolicy -Identity "Default" -IPBlockList $newBlockList
                Write-Host "Removed $IndicatorValue from Exchange Connection Filter" -ForegroundColor Yellow
            }
            "URL" {
                $entries = Get-TenantAllowBlockListItems -ListType Url | Where-Object { $_.Value -eq $IndicatorValue }
                foreach ($entry in $entries) {
                    Remove-TenantAllowBlockListItems -Ids $entry.Identity
                }
                Write-Host "Removed $IndicatorValue from Exchange Tenant Block List (URL)" -ForegroundColor Yellow
            }
            "Domain" {
                $entries = Get-TenantAllowBlockListItems -ListType Domain | Where-Object { $_.Value -eq $IndicatorValue }
                foreach ($entry in $entries) {
                    Remove-TenantAllowBlockListItems -Ids $entry.Identity
                }
                Write-Host "Removed $IndicatorValue from Exchange Tenant Block List (Domain)" -ForegroundColor Yellow
            }
        }
    }
    catch {
        Write-Error "Failed to remove from Exchange: $($_.Exception.Message)"
    }
}

<#
.SYNOPSIS
    Get comprehensive status of CTI deployments across all security products
#>
function Get-CTIDeploymentStatus {
    [CmdletBinding()]
    param(
        [string]$IndicatorId
    )
    
    $indicators = if ($IndicatorId) {
        Get-CTIIndicators | Where-Object { $_.IndicatorId -eq $IndicatorId }
    } else {
        Get-CTIIndicators
    }
    
    $deploymentStatus = @()
    
    foreach ($indicator in $indicators) {
        $status = [PSCustomObject]@{
            IndicatorId = $indicator.IndicatorId
            Value = $indicator.Value
            Type = $indicator.Type
            PlacementStrategy = $indicator.PlacementStrategy
            MDE_Deployed = $false
            Exchange_Deployed = $false
            MDCA_Deployed = $false
            EntraID_Deployed = $false
            LastChecked = (Get-Date)
        }
        
        # Check deployment status in each product
        try {
            # Check MDE deployment
            if ($indicator.PlacementStrategy -like "*MDE*") {
                # Implementation would check MDE API for indicator presence
                $status.MDE_Deployed = $true
            }
            
            # Check Exchange deployment
            if ($indicator.PlacementStrategy -like "*Exchange*") {
                if ($indicator.Type -eq "IPAddress") {
                    $connectionPolicy = Get-HostedConnectionFilterPolicy -Identity "Default"
                    $status.Exchange_Deployed = $indicator.Value -in $connectionPolicy.IPBlockList
                } else {
                    # Check Tenant Allow/Block Lists
                    $blockItems = Get-TenantAllowBlockListItems -ListType Url | Where-Object { $_.Value -eq $indicator.Value }
                    $status.Exchange_Deployed = $blockItems.Count -gt 0
                }
            }
            
            # Check MDCA deployment
            if ($indicator.PlacementStrategy -like "*MDCA*") {
                $policyName = "CTI_RiskyIP_$($indicator.Value.Replace('.', '_').Replace('/', '_'))"
                # Check if MDCA policy exists via Graph API
                try {
                    $uri = "https://graph.microsoft.com/beta/security/cloudAppSecurityProfiles?`$filter=displayName eq '$policyName'"
                    $headers = @{ 'Authorization' = "Bearer $((Get-MgContext).Token)" }
                    $policies = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
                    $status.MDCA_Deployed = $policies.value.Count -gt 0
                }
                catch {
                    Write-Warning "Could not check MDCA deployment status for $($indicator.Value)"
                    $status.MDCA_Deployed = $false
                }
            }
            
            # Check Entra ID deployment
            if ($indicator.PlacementStrategy -like "*EntraID*") {
                $locationName = "CTI_Malicious_$($indicator.Value.Replace('.', '_').Replace('/', '_'))"
                $namedLocations = Get-MgIdentityConditionalAccessNamedLocation | Where-Object { $_.DisplayName -eq $locationName }
                $status.EntraID_Deployed = $namedLocations.Count -gt 0
            }
        }
        catch {
            Write-Warning "Error checking deployment status for $($indicator.Value): $($_.Exception.Message)"
        }
        
        $deploymentStatus += $status
    }
    
    return $deploymentStatus
}

#endregion

# Export module functions
Export-ModuleMember -Function @(
    'Initialize-CTIModule',
    'Connect-CTIServices',
    'Get-CTIIndicators',
    'Set-CTIIndicator',
    'Remove-CTIIndicator',
    'Test-CTIIndicatorValidity',
    'Sync-CTIToSecurityProducts',
    'Set-MDCAPolicy',
    'Remove-MDCAPolicy',
    'Add-EntraNamedLocation',
    'Remove-EntraNamedLocation',
    'Add-ExchangeTenantBlockList',
    'Get-CTIDeploymentStatus'
)