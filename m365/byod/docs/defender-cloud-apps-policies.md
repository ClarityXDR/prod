# Microsoft Defender for Cloud Apps (MDCA) Session Policy Architecture

## 1.0 Overview and Principles

This document defines the architecture for session policies within Microsoft Defender for Cloud Apps (MDCA). These policies are a critical component of the BYOD security solution, providing real-time, in-session controls for browser-based access from unmanaged devices. They act as the final layer of defense to prevent data exfiltration during a user's session.

The architecture is founded on these core principles:

- **Real-time Prevention**: Move beyond detection and alerting to actively block high-risk activities in real-time as they happen.
- **Granularity**: Apply specific controls to specific activities, users, and content, rather than broad, one-size-fits-all blocking.
- **Context-Awareness**: Policies leverage a rich set of contextual information, including device state, user risk, and data sensitivity, to make informed decisions.
- **User Education**: Provide real-time feedback to users when their actions are blocked, educating them on security policies.
- **Enhanced User Experience**: Leverage Microsoft Edge for Business integration to provide seamless protection without performance degradation.

## 1.1 Protection Delivery Methods

MDCA provides session protection through two primary mechanisms:

### 1.1.1 Traditional Reverse Proxy Protection

- Standard session control using proxy redirection
- Sessions show the `.mcas.ms` suffix in the URL
- Universal browser support
- Slight latency due to proxy routing

### 1.1.2 Microsoft Edge for Business In-Browser Protection (Preview)

- Direct browser-based protection without proxy redirection
- No `.mcas.ms` suffix in URLs
- Improved performance and user experience
- Visual protection indicators (lock icon with suitcase symbol)
- Requires Microsoft Edge for Business work profiles
- Automatic fallback to reverse proxy for unsupported scenarios

## 2.0 Architecture and Design

MDCA Session Policies are triggered by the Conditional Access policy that redirects browser sessions from unmanaged devices. The following policies will be implemented to provide a layered defense against data leakage.

### 2.1 Policy: Block Downloads of Sensitive Information

- **Policy Goal**: Prevent sensitive corporate data from being downloaded to unmanaged personal devices.
- **Policy Logic**:
  - **Activity Source**: Filter for file download activities (`Activity type` equals `Download`).
  - **Content Inspection**: Inspect the file content in real-time using:
    - **Sensitivity Labels**: Block files with `Confidential` or `Highly Confidential` labels
    - **Microsoft Data Classification Services (DCS)**: Advanced inspection using:
      - Built-in sensitive information types (SITs)
      - Custom sensitive information types
      - Trainable classifiers for organization-specific content patterns
      - Fingerprinting for structured data matching
      - Exact Data Match (EDM) for precise sensitive data identification
  - **Action**: `Block` the download and display a custom message to the user explaining why the action was blocked.
  - **Evidence Analysis**: Utilize short evidence feature to analyze multiple SITs within files with color-coded differentiation.

### 2.2 Policy: Block Cut/Copy/Paste of Sensitive Content

- **Policy Goal**: Prevent users from copying sensitive information from a protected application and pasting it into an unprotected local application (e.g., Notepad, personal email).
- **Policy Logic**:
  - **Activity Source**: Filter for `Cut/Copy` and `Paste` activities.
  - **Action**: `Block` the activity. This can be configured to block copying from the app, pasting into the app, or both. For BYOD, the primary control is blocking the copy *from* the application.
  - **Edge Integration**: Enhanced protection when using Microsoft Edge for Business with developer tools disabled.

### 2.3 Policy: Block Printing

- **Policy Goal**: Prevent the printing of corporate documents from unmanaged devices.
- **Policy Logic**:
  - **Activity Source**: Filter for `Print` activities.
  - **Action**: `Block` the print job and provide a custom notification.
  - **Enhanced Enforcement**: Stronger protection through Microsoft Edge for Business integration.

### 2.4 Policy: Block Malicious File Uploads

- **Policy Goal**: Protect the corporate environment from malware being uploaded from unmanaged (and potentially infected) personal devices.
- **Policy Logic**:
  - **Activity Source**: Filter for file upload activities (`Activity type` equals `Upload`).
  - **Threat Detection**: Utilize Microsoft's threat intelligence to scan files for malware upon upload.
  - **Action**: If malware is detected, `Block` the upload and alert security administrators.
  - **DCS Integration**: Enhanced malware detection using Microsoft Data Classification Services.

### 2.5 Policy: Step-up Authentication on Risky Action

- **Policy Goal**: Add an additional layer of identity verification when a user attempts a potentially risky action within an established session.
- **Policy Logic**:
  - **Activity Source**: Filter for a specific high-risk activity, such as the download of a file with a `Confidential` sensitivity label that is not blocked by the primary download policy.
  - **Action**: `Require step-up authentication`. This forces the user to re-authenticate with MFA in the middle of their session before the action is allowed to proceed.
  - **Authentication Context**: Leverage Microsoft Entra authentication contexts for granular step-up requirements.

### 2.6 Policy: Advanced Content Classification and Protection

- **Policy Goal**: Provide comprehensive protection for organization-specific sensitive content beyond standard sensitivity labels.
- **Policy Logic**:
  - **Content Analysis**: Use Microsoft Data Classification Services for:
    - Custom trainable classifiers for organization-specific document types
    - Fingerprinting for structured data (employee records, financial data)
    - Exact Data Match for precise identification of sensitive datasets
  - **Action**: Apply appropriate controls based on classification results (block, protect, monitor).
  - **Evidence Examination**: Provide detailed analysis of detected sensitive information types within files.

## 3.0 Policy Scoping and Assignment

- **Device Context**: All session policies will be scoped to apply only to activities originating from devices where the `Device tag` is *not* `Compliant` or `Azure AD Joined`. This ensures the controls only impact unmanaged BYOD sessions.
- **Application Scope**: Policies will be targeted to the relevant Microsoft 365 applications (e.g., SharePoint Online, OneDrive for Business, Exchange Online).
- **Browser Enforcement**: Configure Microsoft Edge for Business enforcement levels:
  - **Do not enforce**: Allow any browser (default)
  - **Unmanaged devices only**: Require Edge for Business on unmanaged devices
  - **Allow access only from Edge**: Restrict access to Edge for Business only
  - **Enforce access from Edge when possible**: Use Edge when context permits

## 4.0 Monitoring and Alerting

- **Alerting**: In addition to blocking actions, policies will be configured to generate alerts in the MDCA portal and forward them to:
  - Corporate SIEM (e.g., Microsoft Sentinel)
  - **Power Automate workflows** for automated response and custom integrations
- **Activity Log**: All monitored and blocked activities are recorded in the MDCA activity log for investigation, threat hunting, and auditing purposes.
- **Enhanced Reporting**:
  - Export Cloud Discovery logs for detailed traffic analysis
  - Evidence examination reports for sensitive content analysis
  - Session protection method reporting (Edge vs. proxy)

## 5.0 Integration with Microsoft Purview

- **Coordination with Endpoint DLP**: When both MDCA session policies and Microsoft Purview Endpoint DLP policies apply to the same context and action, the Endpoint DLP policy takes precedence.
- **Unified Data Protection**: Leverage shared sensitivity labels and classification services across cloud and endpoint protection.
- **Policy Alignment**: Ensure MDCA policies complement rather than conflict with Endpoint DLP configurations.

## 6.0 Implementation Considerations

### 6.1 Microsoft Edge for Business Requirements

- **Work Profile**: Users must be in Microsoft Edge for Business work profile
- **Supported Versions**: Last two stable Edge versions
- **Operating Systems**: Windows 10/11, macOS
- **Identity Platform**: Microsoft Entra ID
- **Fallback Support**: Automatic fallback to reverse proxy for unsupported scenarios

### 6.2 Policy Template Usage

- Leverage pre-built policy templates to accelerate deployment
- Customize templates based on organizational requirements
- Test thoroughly in report-only mode before enforcement

### 6.3 User Communication

- Configure custom messages for blocked activities
- Provide clear guidance on approved alternatives
- Implement user education programs for policy awareness
