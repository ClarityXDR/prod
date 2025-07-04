// filepath: rules/credential_access/t1555_credentials_from_password_stores.yar
rule: CredentialsFromPasswordStores
meta:
  title: "Credentials from Password Stores (T1555)"
  author: "Auto-Generated"
  date: "2025-06-08"
  mitre_techniques: ["T1555"]
  severity: "high"
  description: "Detects access to browser or email client password stores via suspicious processes."
tables:
  primary: "DeviceProcessEvents"
detection:
  selection:
    ProcessCommandLine|contains:
      - "chrome.exe --show-saved-passwords"
      - "firefox.exe -P"
      - "Get-WebCredential"
      - "Get-StoredCredential"
      - "cmdkey /list"
      - "vaultcmd /list"
  filter: {}
timeframe: "7d"
frequency: "1h"
condition: "selection"
response:
  actions:
    - type: "collect_investigation_package"
      target: "DeviceId"
output:
  required_columns: ["Timestamp", "DeviceName", "AccountName", "ProcessCommandLine", "InitiatingProcessFileName"]
  entity_columns: []
