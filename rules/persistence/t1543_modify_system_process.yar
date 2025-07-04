rule: ModifySystemProcess
meta:
  title: "Modify System Process (T1543)"
  author: "Auto-Generated"
  date: "2025-06-08"
  mitre_techniques: ["T1543"]
  severity: "high"
  description: "Detects creation or modification of system services for persistence."
tables:
  primary: "DeviceProcessEvents"
detection:
  selection:
    ProcessCommandLine|contains:
      - "sc.exe create"
      - "New-Service"
      - "Set-Service"
  filter: {}
timeframe: "7d"
frequency: "1h"
condition: "selection"
response:
  actions:
    - type: "collect_investigation_package"
      target: "DeviceId"
output:
  required_columns: ["Timestamp", "DeviceName", "ProcessCommandLine"]
  entity_columns: []
