rule: ValidAccountsPrivilegeEscalation
meta:
  title: "Valid Accounts Privilege Escalation (T1078)"
  author: "Auto-Generated"
  date: "2025-06-08"
  mitre_techniques: ["T1078"]
  severity: "high"
  description: "Detects creation of new user accounts or addition to privileged groups."
tables:
  primary: "DeviceEvents"
detection:
  selection:
    ActionType|in:
      - "UserAccountCreated"
      - "UserAddedToGroup"
    GroupName|in:
      - "Admin"
      - "Remote Desktop Users"
      - "Domain Admins"
  filter: {}
timeframe: "7d"
frequency: "1h"
condition: "selection"
response:
  actions:
    - type: "collect_investigation_package"
      target: "DeviceId"
output:
  required_columns: ["Timestamp", "DeviceName", "ActionType", "AccountName", "InitiatingProcessAccountName", "AdditionalFields"]
  entity_columns: []
