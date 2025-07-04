rule: DetectMultipleFailedNetworkLogons
meta:
  title: "Identify multiple failed network logon attempts"
  author: "Auto-Converted"
  date: "2025-06-08"
  mitre_techniques: []
  severity: "medium"
  description: "Detects accounts with more than 5 failed network logon attempts. Adjust threshold as needed."
  references: []

tables:
  primary: "DeviceLogonEvents"

detection:
  selection:
    ActionType|==: "LogonFailed"
  filter: {}

timeframe: "1d"
frequency: "1h"
condition: "selection"

response:
  actions:
    - type: "collect_investigation_package"
      target: "DeviceId"

output:
  required_columns: ["Timestamp", "DeviceName", "AccountName", "RemoteIP"]
  entity_columns: []
