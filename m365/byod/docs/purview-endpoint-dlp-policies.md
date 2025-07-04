# Microsoft Purview Endpoint Data Loss Prevention (DLP) Architecture

## 1.0 Overview and Principles

This document defines the architecture for Microsoft Purview Endpoint Data Loss Prevention (DLP) policies as part of the comprehensive BYOD security solution. Endpoint DLP provides device-level protection for sensitive data across endpoints, working in coordination with cloud-based session controls to create a unified data protection framework.

The architecture is founded on these core principles:

- **Device-Level Protection**: Protect sensitive data at the endpoint level, regardless of application or browser used
- **Unified Policy Framework**: Leverage shared sensitivity labels and classification services across cloud and endpoint
- **Policy Precedence**: Endpoint DLP takes precedence over cloud session policies when both apply to the same context
- **Cross-Platform Coverage**: Extend protection across Windows, macOS, and mobile platforms
- **Real-time Monitoring**: Continuous monitoring of data activities across all endpoint applications

## 2.0 Architecture and Design

### 2.1 Endpoint DLP Components

#### 2.1.1 Data Classification Engine

- **Sensitivity Label Recognition**: Automatic detection of Microsoft Information Protection labels
- **Content Inspection**: Deep content analysis using Microsoft Data Classification Services
- **Custom Classifiers**: Organization-specific trainable classifiers and fingerprints
- **Exact Data Match (EDM)**: Precise matching against structured sensitive datasets

#### 2.1.2 Activity Monitoring

- **File Operations**: Monitor create, modify, copy, move, delete, and share operations
- **Application Activity**: Track data usage across all applications (Office, browsers, email clients)
- **Removable Media**: Control data transfer to USB drives and external storage
- **Network Sharing**: Monitor data sharing over network protocols

#### 2.1.3 Enforcement Engine

- **Real-time Blocking**: Immediate prevention of policy violations
- **User Notifications**: Contextual policy tips and justification prompts
- **Administrative Alerts**: Detailed incident reporting to security teams
- **Audit Logging**: Comprehensive activity logs for compliance and investigation

## 3.0 Policy Framework

### 3.1 Policy: Sensitive Data Protection on Unmanaged Devices

- **Policy Goal**: Prevent sensitive corporate data from being accessed, copied, or shared from unmanaged BYOD devices
- **Policy Logic**:
  - **Content Detection**: Files with `Confidential` or `Highly Confidential` sensitivity labels
  - **Device Scope**: Apply to devices not marked as `Compliant` or `Azure AD Joined`
  - **Protected Actions**:
    - Block copy to clipboard from protected documents
    - Prevent upload to personal cloud services
    - Restrict printing of sensitive documents
    - Block transfer to removable media
  - **User Experience**: Provide clear policy tips explaining restrictions

### 3.2 Policy: Prevent Data Exfiltration via Removable Media

- **Policy Goal**: Protect against data theft through USB drives and external storage devices
- **Policy Logic**:
  - **Content Analysis**: Scan files for sensitive information types and labels
  - **Device Detection**: Monitor all removable storage device connections
  - **Actions**:
    - Block copying sensitive files to removable media
    - Allow with business justification for approved users
    - Audit all removable media activities
  - **Exceptions**: Configure exemptions for approved devices and users

### 3.3 Policy: Control Data Sharing via Personal Applications

- **Policy Goal**: Prevent sensitive data from being shared through personal email, messaging, or cloud storage applications
- **Policy Logic**:
  - **Application Monitoring**: Track data usage in personal applications (Gmail, WhatsApp, Dropbox, etc.)
  - **Content Inspection**: Identify sensitive content being shared
  - **Actions**:
    - Block sharing of classified documents
    - Require justification for certain data transfers
    - Remove sensitive content from uploads
  - **User Education**: Provide guidance on approved sharing methods

### 3.4 Policy: Browser-Based Data Protection

- **Policy Goal**: Extend protection to browser-based activities beyond session controls
- **Policy Logic**:
  - **Browser Integration**: Monitor data activities across all browsers
  - **Upload Protection**: Scan files being uploaded to web services
  - **Download Controls**: Classify and protect downloaded sensitive content
  - **Coordination with MDCA**: Ensure Endpoint DLP takes precedence over session policies for overlapping scenarios

### 3.5 Policy: Printer and Network Share Protection

- **Policy Goal**: Control printing and network sharing of sensitive documents
- **Policy Logic**:
  - **Print Monitoring**: Scan documents being sent to printers
  - **Network Share Detection**: Monitor file sharing over network protocols
  - **Actions**:
    - Block printing sensitive documents to non-corporate printers
    - Prevent sharing classified files to unauthorized network locations
    - Watermark printed documents with user and timestamp information
  - **Approved Destinations**: Configure exemptions for corporate printers and shares

## 4.0 Integration and Coordination

### 4.1 Coordination with Microsoft Defender for Cloud Apps

- **Policy Precedence**: When both Endpoint DLP and MDCA session policies apply to the same context and action, Endpoint DLP policy is applied
- **Complementary Coverage**: Endpoint DLP provides broader application coverage while MDCA provides cloud session insights
- **Shared Classification**: Both solutions leverage the same sensitivity labels and classification services

### 4.2 Microsoft Information Protection Integration

- **Unified Labeling**: Leverage consistent sensitivity labels across cloud and endpoint
- **Label Inheritance**: Maintain label protection when files move between cloud and endpoint
- **Protection Templates**: Apply Rights Management protection based on sensitivity labels

### 4.3 Microsoft Defender for Endpoint Integration

- **Threat Intelligence**: Leverage threat intelligence for enhanced malware detection
- **Device Risk Assessment**: Factor device risk scores into DLP policy decisions
- **Incident Correlation**: Correlate DLP violations with security incidents

## 5.0 Device Coverage and Requirements

### 5.1 Windows Devices

- **Supported Versions**: Windows 10 (1809+), Windows 11
- **Deployment**: Microsoft Intune or Configuration Manager
- **Features**: Full DLP capability including advanced content inspection

### 5.2 macOS Devices

- **Supported Versions**: macOS 10.15+ (Catalina and later)
- **Deployment**: Microsoft Intune
- **Features**: Core DLP functionality with platform-appropriate controls

### 5.3 Mobile Devices (iOS/Android)

- **Coverage**: Microsoft 365 mobile applications
- **Integration**: Coordinate with Mobile Application Management (MAM) policies
- **Limitations**: Platform restrictions on system-level monitoring

## 6.0 Monitoring and Reporting

### 6.1 Activity Monitoring

- **Real-time Dashboards**: Monitor DLP policy matches and user activities
- **Trend Analysis**: Identify patterns in data usage and policy violations
- **User Risk Scoring**: Track user behavior for risk assessment

### 6.2 Incident Management

- **Alert Generation**: Immediate alerts for high-risk policy violations
- **Investigation Tools**: Detailed forensic capabilities for incident response
- **Remediation Actions**: Automated and manual response options

### 6.3 Compliance Reporting

- **Audit Logs**: Comprehensive logging for compliance requirements
- **Executive Dashboards**: High-level reporting for leadership visibility
- **Regulatory Alignment**: Support for industry-specific compliance requirements

## 7.0 Implementation Considerations

### 7.1 Phased Deployment

- **Phase 1**: Deploy in monitor-only mode to establish baseline
- **Phase 2**: Enable enforcement for high-risk scenarios
- **Phase 3**: Full enforcement with user education and support

### 7.2 User Experience Optimization

- **Policy Tips**: Clear, actionable guidance for users
- **Business Justification**: Allow legitimate business use with proper justification
- **Performance Impact**: Minimize system performance impact through optimized scanning

### 7.3 Exception Management

- **Approved Applications**: Whitelist approved business applications
- **User Exemptions**: Configure exemptions for specific roles or scenarios
- **Temporary Overrides**: Emergency access procedures for business continuity

## 8.0 Testing and Validation

### 8.1 Policy Testing

- **Simulation Environment**: Test policies in isolated environment before production
- **User Acceptance Testing**: Validate user experience and business workflows
- **Performance Testing**: Ensure minimal impact on system performance

### 8.2 Integration Testing

- **MDCA Coordination**: Verify proper policy precedence and coordination
- **Application Compatibility**: Test with business-critical applications
- **Cross-platform Validation**: Ensure consistent behavior across device types
