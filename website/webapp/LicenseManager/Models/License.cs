using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace ClarityXDR.WebApp.LicenseManager.Models
{
    public class License
    {
        [Key]
        public int Id { get; set; }
        
        [Required]
        public string LicenseKey { get; set; }
        
        [Required]
        public DateTime IssueDate { get; set; }
        
        [Required]
        public DateTime ExpirationDate { get; set; }
        
        [Required]
        public bool IsActive { get; set; }
        
        public string Notes { get; set; }
        
        [Required]
        public int ClientId { get; set; }
        public Client Client { get; set; }
        
        public virtual ICollection<LicenseFeature> Features { get; set; }
        public virtual ICollection<LicenseCheck> LicenseChecks { get; set; }
    }
    
    public class Client
    {
        [Key]
        public int Id { get; set; }
        
        [Required]
        public string ClientId { get; set; }
        
        [Required]
        public string Name { get; set; }
        
        public string ContactEmail { get; set; }
        public string ContactPhone { get; set; }
        
        public virtual ICollection<License> Licenses { get; set; }
    }
    
    public class LicenseFeature
    {
        [Key]
        public int Id { get; set; }
        
        [Required]
        public string Name { get; set; }
        
        public string Description { get; set; }
        
        [Required]
        public int LicenseId { get; set; }
        public License License { get; set; }
    }
    
    public class LicenseCheck
    {
        [Key]
        public int Id { get; set; }
        
        [Required]
        public int LicenseId { get; set; }
        public License License { get; set; }
        
        [Required]
        public DateTime CheckedAt { get; set; }
        
        [Required]
        public string Product { get; set; }
        
        public string IPAddress { get; set; }
    }
}
