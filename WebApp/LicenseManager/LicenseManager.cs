using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System.Security.Cryptography;
using System.Text;

namespace ClarityXDR.WebApp.LicenseManager
{
    [ApiController]
    [Route("api/[controller]")]
    public class LicensingController : ControllerBase
    {
        private readonly LicenseDbContext _context;
        private readonly ILogger<LicensingController> _logger;

        public LicensingController(LicenseDbContext context, ILogger<LicensingController> logger)
        {
            _context = context;
            _logger = logger;
        }

        [HttpGet("validate")]
        public async Task<IActionResult> ValidateLicense([FromHeader(Name = "x-license-key")] string licenseKey,
                                                         [FromHeader(Name = "x-client-id")] string clientId,
                                                         [FromHeader(Name = "x-product-name")] string productName)
        {
            if (string.IsNullOrEmpty(licenseKey) || string.IsNullOrEmpty(clientId))
            {
                return BadRequest(new LicenseValidationResponse
                {
                    Valid = false,
                    Message = "License key and client ID are required"
                });
            }

            try
            {
                var license = await _context.Licenses
                    .Include(l => l.Client)
                    .Include(l => l.Features)
                    .FirstOrDefaultAsync(l => l.LicenseKey == licenseKey && l.Client.ClientId == clientId);

                if (license == null)
                {
                    _logger.LogWarning($"License validation failed: License {licenseKey} for client {clientId} not found");
                    return Ok(new LicenseValidationResponse
                    {
                        Valid = false,
                        Message = "Invalid license key"
                    });
                }

                if (license.ExpirationDate < DateTime.UtcNow)
                {
                    _logger.LogWarning($"License validation failed: License {licenseKey} expired on {license.ExpirationDate}");
                    return Ok(new LicenseValidationResponse
                    {
                        Valid = false,
                        ExpirationDate = license.ExpirationDate.ToString("o"),
                        Message = "License has expired"
                    });
                }

                if (!license.IsActive)
                {
                    _logger.LogWarning($"License validation failed: License {licenseKey} is inactive");
                    return Ok(new LicenseValidationResponse
                    {
                        Valid = false,
                        ExpirationDate = license.ExpirationDate.ToString("o"),
                        Message = "License has been deactivated"
                    });
                }

                // Record license check in telemetry
                _context.LicenseChecks.Add(new LicenseCheck
                {
                    LicenseId = license.Id,
                    CheckedAt = DateTime.UtcNow,
                    Product = productName,
                    IPAddress = HttpContext.Connection.RemoteIpAddress.ToString()
                });
                await _context.SaveChangesAsync();

                // Return success response with license details
                return Ok(new LicenseValidationResponse
                {
                    Valid = true,
                    ExpirationDate = license.ExpirationDate.ToString("o"),
                    Features = license.Features.Select(f => f.Name).ToArray(),
                    Message = "License is valid"
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error validating license");
                return StatusCode(500, new LicenseValidationResponse
                {
                    Valid = false,
                    Message = "An error occurred validating the license"
                });
            }
        }
    }

    public class LicenseValidationResponse
    {
        public bool Valid { get; set; }
        public string ExpirationDate { get; set; }
        public string[] Features { get; set; } = Array.Empty<string>();
        public string Message { get; set; }
    }
}
