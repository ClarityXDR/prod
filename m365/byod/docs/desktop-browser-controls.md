# Unmanaged Desktop Browser Access Architecture

## 1.0 Overview and Principles

This document outlines the security architecture for managing access from unmanaged desktop and laptop devices (BYOD) to Microsoft 365 services. The primary goal is to allow productive browser-based access while preventing data exfiltration to the local, unmanaged device. This is achieved by forcing unmanaged devices into a controlled browser session, where real-time policies can be applied.

The architecture is founded on these core principles:

- **Zero Trust for Unmanaged Endpoints**: Unmanaged devices are inherently untrusted. No corporate data should be stored or allowed to persist on them.
- **Browser as the Secure Sandbox**: The web browser, when combined with cloud-based session controls, becomes the secure sandbox for interacting with corporate data.
- **Block by Default**: Access from rich client applications (e.g., desktop Outlook, Teams, OneDrive sync client) on unmanaged devices is blocked by default.
- **Real-time Control**: Security policies are applied in real-time at the session level, allowing for dynamic control over user actions based on context.

## 2.0 Architecture and Design

The solution is a combination of two key Conditional Access policies that work in tandem to create the desired security posture.

### 2.1 Policy 1: Block Rich Client Access

This policy prevents the use of native desktop applications on unmanaged devices, which could otherwise be used to download and store data locally.

- **Policy Name**: `CA-BYOD-Desktop-BlockRichClients`
- **Target Users**: All users (excluding emergency access accounts).
- **Target Applications**: All Microsoft 365 cloud apps.
- **Conditions**:
  - **Device Platforms**: Windows, macOS.
  - **Client Apps**: `Mobile apps and desktop clients` (This targets all non-browser application protocols).
  - **Device State (Exclude)**: The policy excludes devices that are `Marked as compliant` or `Hybrid Azure AD joined`. This ensures the policy only applies to unmanaged devices.
- **Access Control**: `Block access`.

### 2.2 Policy 2: Force Browser Access into Session Control

This policy allows browser access from unmanaged devices but redirects the session to Microsoft Defender for Cloud Apps for real-time control.

- **Policy Name**: `CA-BYOD-Desktop-BrowserSessionControl`
- **Target Users**: All users (excluding emergency access accounts).
- **Target Applications**: All Microsoft 365 cloud apps.
- **Conditions**:
  - **Device Platforms**: Windows, macOS.
  - **Client Apps**: `Browser`.
  - **Device State (Exclude)**: The policy excludes devices that are `Marked as compliant` or `Hybrid Azure AD joined`.
- **Access Control**: `Grant access`.
- **Session Control**: `Use Conditional Access App Control`. This setting is the key integration point that invokes Microsoft Defender for Cloud Apps.

## 3.0 Integration with Microsoft Defender for Cloud Apps (MDCA)

When a user on an unmanaged desktop accesses a Microsoft 365 service via a browser, the Conditional Access policy redirects their session through the MDCA reverse proxy. This enables the application of MDCA Session Policies, which provide granular, real-time data loss prevention (DLP) controls. The specific MDCA policies are detailed in the `defender-cloud-apps-policies.md` document, but they include capabilities such as:

- **Blocking file downloads** to the local device.
- **Restricting copy/paste** of sensitive information out of the browser.
- **Blocking printing**.
- **Applying sensitivity labels** to files on download (to a managed location).

## 4.0 User Experience

1. A user on their personal laptop opens a web browser and navigates to `portal.office.com`.
2. They authenticate with their corporate credentials.
3. Conditional Access evaluates the sign-in. It determines the device is unmanaged.
4. The `CA-BYOD-Desktop-BlockRichClients` policy is not triggered because the client app is `Browser`.
5. The `CA-BYOD-Desktop-BrowserSessionControl` policy is triggered. Access is granted, but the session is proxied via MDCA.
6. The user sees a notification that their session is being monitored. The URL in the browser is rewritten to include the MDCA proxy suffix (e.g., `.mcas.ms`).
7. The user can now use the web applications, but any actions they take (like trying to download a file) are subject to the real-time MDCA session policies.

## 5.0 Additional Resources

- [Microsoft Docs: Conditional Access - Grant controls](https://docs.microsoft.com/en-us/azure/active-directory/conditional-access/concept-conditional-access-grant)
- [Microsoft Docs: Protect with Microsoft Defender for Cloud Apps](https://docs.microsoft.com/en-us/azure/active-directory/conditional-access/concept-conditional-access-session)
