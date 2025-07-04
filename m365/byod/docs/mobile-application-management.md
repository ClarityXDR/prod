# Intune MAM Policies for Office 365 Bundle and Microsoft Edge

## Overview

This document provides guidance for configuring Microsoft Intune Mobile Application Management (MAM) policies for the Office 365 bundle and Microsoft Edge browser in a BYOD (Bring Your Own Device) environment.

## Office 365 Bundle MAM Configuration

### Supported Applications
- Microsoft Outlook
- Microsoft Word
- Microsoft Excel
- Microsoft PowerPoint
- Microsoft OneNote
- Microsoft OneDrive
- Microsoft Teams
- Microsoft SharePoint

### Key Policy Settings

#### Data Protection
```
- Prevent backup of org data: Yes
- Send org data to other apps: Policy managed apps
- Receive data from other apps: Policy managed apps
- Restrict cut, copy, and paste between apps: Policy managed apps with paste in
- Screen capture and Google Assistant: Block
```

#### Access Requirements
```
- PIN for access: Require
- Work or school account for access: Require
- Recheck access requirements after (minutes): 30
- Offline grace period: 720 minutes
```

#### Conditional Launch
```
- Max PIN attempts: 5
- Offline grace period: 720 minutes
- Jailbroken/rooted devices: Block access
- Min OS version: iOS 14.0 / Android 8.0
- Min app version: Latest
- Max allowed device threat level: Medium
```

## Microsoft Edge MAM Configuration

### Browser-Specific Settings

#### Data Protection
```
- Prevent backup of org data: Yes
- Send org data to other apps: Policy managed apps
- Org data on personal browsing: Block
- Restrict web content transfer with other apps: Policy managed apps
- Bookmarks sync: Block
- Password sync: Block
```

#### InPrivate Browsing
```
- InPrivate browsing: Allow
- Block printing org data: Yes
- Block screenshots of org data: Yes
```

#### Site Access
```
- Allowed sites: Configure based on organizational needs
- Blocked sites: Social media, personal cloud storage
- Proxy configuration: As per organizational policy
```

## Implementation Steps

### 1. Create App Protection Policy

1. Sign in to Microsoft Endpoint Manager admin center
2. Navigate to **Apps** > **App protection policies**
3. Select **Create policy** > **iOS/iPadOS** or **Android**
4. Configure basic information:
   - Name: "Office 365 MAM Policy - [Platform]"
   - Description: "MAM policy for Office 365 apps"

### 2. Select Apps

For Office 365 Bundle:
```
- Microsoft Excel
- Microsoft Outlook
- Microsoft PowerPoint
- Microsoft Word
- Microsoft OneNote
- Microsoft OneDrive for Business
- Microsoft Teams
- Microsoft SharePoint
```

For Edge:
```
- Microsoft Edge
```

### 3. Configure Data Protection Settings

Apply the settings outlined in the configuration sections above.

### 4. Set Conditional Launch Rules

Configure device compliance and security requirements.

### 5. Assign to Groups

Assign policies to appropriate Azure AD groups containing target users.

## Best Practices

### Security Recommendations
- Enable PIN requirements with complexity rules
- Set appropriate offline grace periods
- Block access from jailbroken/rooted devices
- Implement app version controls
- Use device threat level restrictions

### User Experience Considerations
- Provide clear communication about policy changes
- Offer training on new app behaviors
- Set reasonable offline grace periods
- Consider user productivity when setting restrictions

### Monitoring and Compliance
- Regular review of policy effectiveness
- Monitor app protection status reports
- Track policy compliance metrics
- Adjust settings based on security incidents

## Policy Templates

### High Security Template
```yaml
Data Protection:
  - Backup: Blocked
  - Data transfer: Policy managed apps only
  - Screenshots: Blocked
  - PIN: Required (complex)
  
Access:
  - Offline grace: 480 minutes
  - Recheck interval: 15 minutes
  - Device compliance: Required
```

### Balanced Security Template
```yaml
Data Protection:
  - Backup: Blocked
  - Data transfer: Policy managed apps with exceptions
  - Screenshots: Blocked for org data
  - PIN: Required (simple)
  
Access:
  - Offline grace: 720 minutes
  - Recheck interval: 30 minutes
  - Device compliance: Recommended
```

## Troubleshooting

### Common Issues
1. **Apps not receiving policy**
   - Verify user assignment
   - Check app registration status
   - Confirm policy deployment

2. **Users unable to access apps**
   - Review conditional launch failures
   - Check device compliance status
   - Verify PIN configuration

3. **Data sharing restrictions**
   - Review allowed apps list
   - Check copy/paste restrictions
   - Verify sharing policy settings

### Logging and Diagnostics
- Use Intune app protection logs
- Review Azure AD sign-in logs
- Monitor app-specific error codes
- Check device compliance reports

## Compliance and Reporting

### Key Metrics to Monitor
- Policy deployment success rate
- App protection status
- Conditional launch violations
- Data leakage incidents
- User compliance rates

### Regular Review Tasks
- Monthly policy effectiveness review
- Quarterly security assessment
- Annual policy update cycle
- Incident-based policy adjustments

## Related Documentation
- [Intune App Protection Policies Overview](link)
- [Office 365 Mobile Security Best Practices](link)
- [Microsoft Edge Enterprise Documentation](link)
- [BYOD Security Guidelines](link)