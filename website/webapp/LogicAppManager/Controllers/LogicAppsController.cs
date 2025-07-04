using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using ClarityXDR.WebApp.LogicAppManager;
using ClarityXDR.WebApp.Data;
using ClarityXDR.WebApp.Models;

namespace ClarityXDR.WebApp.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize(Roles = "Admin")]
    public class LogicAppsController : ControllerBase
    {
        private readonly LicenseDbContext _licenseContext;
        private readonly LogicAppDeploymentService _deploymentService;
        private readonly ILogger<LogicAppsController> _logger;

        public LogicAppsController(
            LicenseDbContext licenseContext,
            LogicAppDeploymentService deploymentService,
            ILogger<LogicAppsController> logger)
        {
            _licenseContext = licenseContext;
            _deploymentService = deploymentService;
            _logger = logger;
        }

        [HttpGet("clients")]
        public async Task<IActionResult> GetClients()
        {
            var clients = await _licenseContext.Clients
                .Select(c => new { c.ClientId, c.Name })
                .ToListAsync();
                
            return Ok(clients);
        }

        [HttpGet("templates")]
        public IActionResult GetTemplates()
        {
            var templateDir = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Templates", "LogicApps");
            if (!Directory.Exists(templateDir))
            {
                return NotFound("Template directory not found");
            }

            var templates = new List<object>();
            foreach (var file in Directory.GetFiles(templateDir, "*.json"))
            {
                var fileInfo = new FileInfo(file);
                templates.Add(new
                {
                    Name = Path.GetFileNameWithoutExtension(file),
                    FileName = fileInfo.Name,
                    Size = fileInfo.Length,
                    LastModified = fileInfo.LastWriteTimeUtc
                });
            }

            return Ok(templates);
        }

        [HttpPost("deploy")]
        public async Task<IActionResult> DeployLogicApp([FromBody] LogicAppDeploymentRequest request)
        {
            if (string.IsNullOrEmpty(request.ClientId) || 
                string.IsNullOrEmpty(request.SubscriptionId) || 
                string.IsNullOrEmpty(request.ResourceGroup) || 
                string.IsNullOrEmpty(request.LogicAppName) || 
                string.IsNullOrEmpty(request.TemplateName))
            {
                return BadRequest("Missing required parameters");
            }

            // Verify client exists and has valid license
            var client = await _licenseContext.Clients
                .Include(c => c.Licenses.Where(l => l.IsActive && l.ExpirationDate > DateTime.UtcNow))
                .FirstOrDefaultAsync(c => c.ClientId == request.ClientId);

            if (client == null)
            {
                return NotFound("Client not found");
            }

            if (!client.Licenses.Any())
            {
                return BadRequest("Client does not have an active license");
            }

            try
            {
                // Get the template content
                var templatePath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "Templates", "LogicApps", $"{request.TemplateName}.json");
                if (!System.IO.File.Exists(templatePath))
                {
                    return NotFound($"Template '{request.TemplateName}' not found");
                }

                var templateContent = await System.IO.File.ReadAllTextAsync(templatePath);

                // Deploy the Logic App
                var success = await _deploymentService.DeployLogicAppAsync(
                    request.ClientId,
                    request.SubscriptionId,
                    request.ResourceGroup,
                    request.LogicAppName,
                    templateContent);

                if (success)
                {
                    // Record the deployment
                    var deployment = new LogicAppDeployment
                    {
                        ClientId = client.Id,
                        LogicAppName = request.LogicAppName,
                        SubscriptionId = request.SubscriptionId,
                        ResourceGroup = request.ResourceGroup,
                        TemplateName = request.TemplateName,
                        DeployedAt = DateTime.UtcNow,
                        Status = "Success"
                    };

                    _licenseContext.LogicAppDeployments.Add(deployment);
                    await _licenseContext.SaveChangesAsync();

                    return Ok(new { success = true, message = "Logic App deployed successfully" });
                }
                else
                {
                    return StatusCode(500, new { success = false, message = "Failed to deploy Logic App" });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error deploying Logic App '{request.LogicAppName}' for client '{request.ClientId}'");
                return StatusCode(500, new { success = false, message = "An error occurred during deployment", error = ex.Message });
            }
        }

        [HttpPost("disable")]
        public async Task<IActionResult> DisableLogicApp([FromBody] LogicAppDisableRequest request)
        {
            if (string.IsNullOrEmpty(request.ClientId) || 
                string.IsNullOrEmpty(request.SubscriptionId) || 
                string.IsNullOrEmpty(request.ResourceGroup) || 
                string.IsNullOrEmpty(request.LogicAppName))
            {
                return BadRequest("Missing required parameters");
            }

            try
            {
                // Disable the Logic App
                var success = await _deploymentService.DisableLogicAppAsync(
                    request.SubscriptionId,
                    request.ResourceGroup,
                    request.LogicAppName);

                if (success)
                {
                    return Ok(new { success = true, message = "Logic App disabled successfully" });
                }
                else
                {
                    return StatusCode(500, new { success = false, message = "Failed to disable Logic App" });
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, $"Error disabling Logic App '{request.LogicAppName}' for client '{request.ClientId}'");
                return StatusCode(500, new { success = false, message = "An error occurred", error = ex.Message });
            }
        }
    }

    public class LogicAppDeploymentRequest
    {
        public string ClientId { get; set; }
        public string SubscriptionId { get; set; }
        public string ResourceGroup { get; set; }
        public string LogicAppName { get; set; }
        public string TemplateName { get; set; }
    }

    public class LogicAppDisableRequest
    {
        public string ClientId { get; set; }
        public string SubscriptionId { get; set; }
        public string ResourceGroup { get; set; }
        public string LogicAppName { get; set; }
    }

    public class LogicAppDeployment
    {
        public int Id { get; set; }
        public int ClientId { get; set; }
        public Client Client { get; set; }
        public string LogicAppName { get; set; }
        public string SubscriptionId { get; set; }
        public string ResourceGroup { get; set; }
        public string TemplateName { get; set; }
        public DateTime DeployedAt { get; set; }
        public string Status { get; set; }
    }
}
