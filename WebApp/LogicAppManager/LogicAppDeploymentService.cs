using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Identity.Client;
using Newtonsoft.Json.Linq;
using System.IO;

namespace ClarityXDR.WebApp.LogicAppManager
{
    public class LogicAppDeploymentService
    {
        private readonly IConfiguration _configuration;
        private readonly ILogger<LogicAppDeploymentService> _logger;
        private readonly HttpClient _httpClient;

        public LogicAppDeploymentService(
            IConfiguration configuration,
            ILogger<LogicAppDeploymentService> logger,
            HttpClient httpClient)
        {
            _configuration = configuration;
            _logger = logger;
            _httpClient = httpClient;
        }

        public async Task<bool> DeployLogicAppAsync(string clientId, string subscriptionId, string resourceGroup, string logicAppName, string logicAppDefinition)
        {
            try
            {
                // Get access token for Azure Resource Manager
                var accessToken = await GetAccessTokenAsync();
                _httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

                // Replace placeholders in Logic App definition
                var processedDefinition = ReplaceLogicAppPlaceholders(logicAppDefinition, clientId);

                // Prepare the API request to deploy the Logic App
                var url = $"https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroup}/providers/Microsoft.Logic/workflows/{logicAppName}?api-version=2016-06-01";
                var content = new StringContent(processedDefinition, Encoding.UTF8, "application/json");

                // Send the PUT request to create or update the Logic App
                var response = await _httpClient.PutAsync(url, content);

                if (response.IsSuccessStatusCode)
                {
                    _logger.LogInformation($"Successfully deployed Logic App '{logicAppName}' for client '{clientId}'");
                    return true;
                }
                else
                {
                    var errorContent = await response.Content.ReadAsStringAsync();
                    _logger.LogError($"Failed to deploy Logic App '{logicAppName}'. Status: {response.StatusCode}, Error: {errorContent}");
                    return false;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error deploying Logic App '{logicAppName}' for client '{clientId}'");
                return false;
            }
        }

        public async Task<bool> DisableLogicAppAsync(string subscriptionId, string resourceGroup, string logicAppName)
        {
            try
            {
                // Get access token for Azure Resource Manager
                var accessToken = await GetAccessTokenAsync();
                _httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

                // Prepare the API request to get current Logic App
                var getUrl = $"https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroup}/providers/Microsoft.Logic/workflows/{logicAppName}?api-version=2016-06-01";
                var getResponse = await _httpClient.GetAsync(getUrl);

                if (!getResponse.IsSuccessStatusCode)
                {
                    var errorContent = await getResponse.Content.ReadAsStringAsync();
                    _logger.LogError($"Failed to get Logic App '{logicAppName}'. Status: {getResponse.StatusCode}, Error: {errorContent}");
                    return false;
                }

                // Parse the current Logic App definition
                var logicAppJson = await getResponse.Content.ReadAsStringAsync();
                var logicApp = JObject.Parse(logicAppJson);

                // Set the state to Disabled
                logicApp["properties"]["state"] = "Disabled";

                // Prepare the API request to update the Logic App
                var url = $"https://management.azure.com/subscriptions/{subscriptionId}/resourceGroups/{resourceGroup}/providers/Microsoft.Logic/workflows/{logicAppName}?api-version=2016-06-01";
                var content = new StringContent(logicApp.ToString(), Encoding.UTF8, "application/json");

                // Send the PUT request to update the Logic App
                var response = await _httpClient.PutAsync(url, content);

                if (response.IsSuccessStatusCode)
                {
                    _logger.LogInformation($"Successfully disabled Logic App '{logicAppName}'");
                    return true;
                }
                else
                {
                    var errorContent = await response.Content.ReadAsStringAsync();
                    _logger.LogError($"Failed to disable Logic App '{logicAppName}'. Status: {response.StatusCode}, Error: {errorContent}");
                    return false;
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error disabling Logic App '{logicAppName}'");
                return false;
            }
        }

        private async Task<string> GetAccessTokenAsync()
        {
            var tenantId = _configuration["Azure:TenantId"];
            var clientId = _configuration["Azure:ClientId"];
            var clientSecret = _configuration["Azure:ClientSecret"];

            var app = ConfidentialClientApplicationBuilder
                .Create(clientId)
                .WithClientSecret(clientSecret)
                .WithAuthority($"https://login.microsoftonline.com/{tenantId}")
                .Build();

            var scopes = new[] { "https://management.azure.com/.default" };
            var result = await app.AcquireTokenForClient(scopes).ExecuteAsync();
            
            return result.AccessToken;
        }

        private string ReplaceLogicAppPlaceholders(string logicAppDefinition, string clientId)
        {
            var definition = JObject.Parse(logicAppDefinition);

            // Add or update LicenseGUID parameter
            var licenseGuid = GetClientLicenseGuid(clientId);
            
            if (definition["parameters"] == null)
            {
                definition["parameters"] = new JObject();
            }

            if (definition["parameters"]["LicenseGUID"] == null)
            {
                definition["parameters"]["LicenseGUID"] = new JObject
                {
                    ["type"] = "String",
                    ["defaultValue"] = licenseGuid
                };
            }
            else
            {
                definition["parameters"]["LicenseGUID"]["defaultValue"] = licenseGuid;
            }

            // Add or update ClientID parameter
            if (definition["parameters"]["ClientID"] == null)
            {
                definition["parameters"]["ClientID"] = new JObject
                {
                    ["type"] = "String",
                    ["defaultValue"] = clientId
                };
            }
            else
            {
                definition["parameters"]["ClientID"]["defaultValue"] = clientId;
            }

            // Replace other placeholders based on client configuration
            // You would typically fetch these values from a database based on clientId
            
            return definition.ToString();
        }

        private string GetClientLicenseGuid(string clientId)
        {
            // In a real implementation, you would fetch this from the database
            // For now, we're just returning a static GUID
            return Guid.NewGuid().ToString();
        }
    }
}
