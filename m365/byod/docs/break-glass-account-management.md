# Emergency Access (Break-Glass) Account Architecture

## 1.0 Overview and Principles

This document outlines the architecture for emergency access accounts (also known as "break-glass" accounts) within the Microsoft 365 environment. These accounts are a critical component of a secure identity strategy, providing a failsafe for administrative access during emergencies where standard administrative accounts are unavailable (e.g., Conditional Access policy misconfiguration, identity provider outage).

The architecture is founded on these core principles:

- **Redundancy**: Ensure access is always available by having multiple, independent emergency accounts.
- **Segregation**: Isolate emergency accounts from daily administrative and user accounts.
- **Least Privilege (Exception)**: While these accounts are highly privileged (Global Administrator), their use is restricted to emergencies only, representing a documented exception to the principle of least privilege.
- **Secure Storage**: Protect credentials from unauthorized access through robust physical and logical controls.
- **Comprehensive Auditing**: Monitor and alert on all activities performed by these accounts to detect and respond to potential misuse.

## 2.0 Architecture and Design

### 2.1 Account Provisioning

- **Dedicated Cloud-Only Accounts**: Two dedicated, cloud-only user accounts (e.g., `emergency-admin-1@tenant.onmicrosoft.com`) shall be created directly in Microsoft Entra ID. These accounts must not be synchronized from an on-premises directory to avoid on-premises dependencies or exploits.
- **Standardized Naming Convention**: A clear and consistent naming convention shall be used to easily identify these accounts for monitoring and policy exclusion.
- **Account Configuration**: Accounts will be configured with a clear display name (e.g., "Emergency Access Account 1"), job title, and department to signify their purpose.

### 2.2 Authentication and Credentials

- **Password Complexity**: Passwords must be a minimum of 24 characters, randomly generated, and contain a mix of uppercase letters, lowercase letters, numbers, and symbols.
- **Password Lifecycle**: Passwords for these accounts should be excluded from expiration policies. Credentials must be reset after each use.
- **Primary Authentication (Passwordless MFA)**: The primary authentication method must be a passwordless, phishing-resistant method. Hardware FIDO2 security keys are the required standard. Phone-based methods (SMS/voice) are explicitly forbidden for these accounts.
- **Credential Storage**:
  - FIDO2 keys and recovery codes must be stored securely in geographically separate, access-controlled locations (e.g., physical safes).
  - Access to credentials should require approval from multiple authorized individuals (implementing multi-party control).

### 2.3 Authorization and Privileges

- **Role Assignment**: The **Global Administrator** role shall be permanently assigned to these accounts. This is necessary to ensure they have sufficient permissions to remediate any issue.
- **Justification**: The permanent assignment is a documented and accepted risk, mitigated by the stringent authentication and monitoring controls outlined in this architecture.

### 2.4 Policy Exclusions

- **Dedicated Security Group**: A dedicated, non-dynamic security group (e.g., `SG-EmergencyAccessAccounts`) shall be created to contain the break-glass accounts.
- **Conditional Access Exclusions**: This security group must be explicitly excluded from all Conditional Access policies that could impede access, including those that enforce MFA, device compliance, location-based restrictions, or session controls.

### 2.5 Monitoring and Auditing

- **High-Priority Alerting**: Configure real-time alerts in Microsoft Sentinel, Azure Monitor, or a similar SIEM solution to be triggered upon any sign-in activity or failures or administrative action from these accounts.
- **Notification Channels**: Alerts should be sent to multiple destinations, including the security operations team's distribution list and a dedicated high-priority channel (e.g., PagerDuty, SMS alerts).
- **Audit Log Review**: All activities performed by break-glass accounts must be reviewed as part of regular security audits and after any incident. This includes a review of any anomalies or unauthorized access attempts.

## 3.0 Operational Procedures

### 3.1 Usage Protocol

- **Authorization**: Use of a break-glass account must be authorized by at least two individuals from a pre-defined list of senior IT and Security leadership.
- **Post-Use Actions**: After each use, a mandatory post-incident review must be conducted. The account's password must be reset, and any MFA methods should be re-issued if used or considered compromised.

### 3.2 Testing and Validation

- **Quarterly Testing**: The functionality of the break-glass accounts, including the ability to log in and perform key administrative tasks, must be tested quarterly.
- **Scenario Simulation**: Testing should include simulated emergency scenarios, such as an administrator lockout, to validate the end-to-end process.
- **Documentation**: All test results, including any issues found and their remediation, must be documented. This documentation should also include any lessons learned and recommendations for future improvements.

## 4.0 Best Practices Summary

- **NEVER use for daily administration.**
- **NEVER configure email mailboxes.**
- **NEVER link to any individual employee's phone or email.**
- **NEVER sync from on-premises Active Directory.**
- **ALWAYS store credentials in a physically secure, geographically dispersed manner.**
- **ALWAYS test accounts regularly and after any major platform change.**

## 5.0 Additional Resources

- [Microsoft Docs: Manage emergency access accounts in Azure AD](https://docs.microsoft.com/en-us/azure/active-directory/roles/security-emergency-access)
