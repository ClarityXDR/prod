# Conditional Access Architecture for BYOD

## 1.0 Overview and Principles

Conditional Access is the central policy engine in the Microsoft 365 Zero Trust framework. This document outlines the Conditional Access architecture designed to secure access for Bring Your Own Device (BYOD) scenarios. The architecture enforces the principle of "never trust, always verify" by evaluating multiple signals to make intelligent access decisions.

## 2.0 Policy Architecture

The Conditional Access policy set is designed as a series of interlocking rules that provide comprehensive coverage for all access scenarios. The policies are designed to be as specific as possible, targeting particular applications, user groups, and conditions.

### 2.1 Foundational Policies

These policies establish a baseline of security for all users and access requests.

- **Block Legacy Authentication**: A strict policy to block legacy authentication protocols (e.g., POP3, IMAP, SMTP) that do not support modern authentication methods and MFA.
- **Enforce Phishing-Resistant MFA for All Users**: A baseline policy requiring phishing-resistant multi-factor authentication for all users, leveraging YubiKey FIDO2 or Microsoft Authenticator Passkeys. SMS and Voice methods have been completely phased out except for limited emergency scenarios.
- **Enforce Enhanced MFA for Privileged Roles**: A more stringent MFA policy targeting administrative roles, requiring YubiKey FIDO2 as the primary method with Microsoft Authenticator Passkeys as backup.

### 2.2 BYOD-Specific Policies

These policies are designed to manage the specific risks associated with unmanaged personal devices.

#### 2.2.1 Mobile Devices (iOS/Android)

- **Policy**: `Require App Protection Policy and Approved App`
- **Target**: All users, on iOS and Android devices, accessing Microsoft 365 cloud apps.
- **Controls**: Grant access only if the user is using an approved client application (e.g., Microsoft Outlook Mobile) that is protected by an Intune App Protection Policy. This ensures that corporate data is contained within a secure, managed container on the device.

#### 2.2.2 Desktop Devices (Windows/macOS)

- **Policy**: `Block Thick Clients and Enforce Browser Session Controls for Unmanaged Desktops`
- **Target**: All users, on Windows and macOS devices, accessing Microsoft 365 cloud apps.
- **Conditions**: This policy applies to devices that are *not* marked as compliant or hybrid Azure AD joined or Intune Enrolled. MDMID exists to identify devices still managed by SCCM if applicable. Additionally, this policy will consider devices that are not enrolled in any mobile device management solution.
- **Controls**:
    1. **Block Access for Desktop Clients**: Block access from thick client applications (e.g., desktop Outlook, Teams) on unmanaged devices, allowing browser only.
    2. **Grant Access for Browser with Session Controls**: Grant access for browser sessions but enforce session controls via Microsoft Defender for Cloud Apps. This redirects the session through a reverse proxy, allowing for real-time monitoring and control (e.g., block download, copy/paste, print, post restrictions).

#### 2.2.3 Monitor Only Policy for PoC

- **Policy**: `Monitor Only - MDCA Session Controls for Office 365`
- **Target**: All users, excluding break glass accounts and service accounts.
- **Applications**: Office 365 bundle (limited scope for Proof of Concept). Exclusions added for Windows Admin Center and other apps deemed excluded.
- **Conditions**: All platforms and device states.
- **Controls**: Grant access with session controls via Microsoft Defender for Cloud Apps in monitor-only mode. This policy enables visibility and behavioral analytics without blocking access, providing insights into user activities and data access patterns during the pilot phase. This is a key component of the telemetry into MDCA. The other telemetry source is MDE.

#### 2.2.4 Block Downloads on Unmanaged Devices

- **Policy**: `Block Downloads on Unmanaged Devices - All Platforms`
- **Target**: All users on unmanaged devices (both desktop and mobile platforms).
- **Applications**: Microsoft 365 cloud apps.
- **Conditions**: This policy applies to devices that are *not* marked as compliant, hybrid Azure AD joined, or Azure AD joined.
- **Controls**: Block download of files to unmanaged devices while still allowing access to view and edit documents online. This prevents corporate data from being stored on personal devices while maintaining productivity.

#### 2.2.5 Idle Session Timeout for BYOD

- **Policy**: `Enforce Idle Session Timeout on Unmanaged Devices`
- **Target**: All users on unmanaged devices (both desktop and mobile platforms).
- **Applications**: Microsoft 365 cloud apps.
- **Conditions**: This policy applies to devices that are *not* marked as compliant, hybrid Azure AD joined, or Azure AD joined.
- **Controls**: 
    1. **Session Timeout**: Enforce a 4-hour maximum session lifetime for unmanaged devices to limit exposure of corporate data on personal devices.
    2. **Re-authentication Required**: Users must re-authenticate after the session timeout expires, ensuring continued verification of user identity.
    3. **Persistent Browser Session Control**: Sessions cannot be marked as "persistent" on unmanaged devices, requiring fresh authentication for each new session.

#### 2.2.6 Email Attachment Restrictions for Outlook Web Access

- **Policy**: `Enhanced Monitoring for Outlook Web Access - Unmanaged Devices`
- **Target**: All users on unmanaged devices accessing Outlook on the Web and New Outlook.
- **Applications**: Office 365 Exchange Online (specifically Outlook on the Web and New Outlook client).
- **Conditions**: This policy applies to devices that are *not* marked as compliant, hybrid Azure AD joined, or Azure AD joined.
- **Controls**:
    1. **Session Monitoring via MDCA**: Route sessions through Microsoft Defender for Cloud Apps to monitor and log all email activities for security analysis.
    2. **Copy/Paste Restrictions**: Block copying of email content to prevent data exfiltration through clipboard operations.
    3. **Print Blocking**: Prevent printing of emails and attachments from unmanaged devices.
    4. **Enhanced Auditing**: Comprehensive logging of email access, attachment viewing, and user activities within Outlook Web Access.
- **Note**: Direct attachment download/upload blocking is not available as a granular MDCA session control. Organizations should rely on Exchange Online Protection policies and Purview Endpoint DLP for attachment-specific controls.

