rule: ScheduledTaskCreation
meta:
  title: "Scheduled Task Creation (T1053)"
  author: "Auto-Generated"
  date: "2025-06-08"
  mitre_techniques: ["T1053"]
  severity: "medium"
  description: "Detects creation of scheduled tasks via schtasks or at.exe."
tables:
  primary: "DeviceProcessEvents"
detection:
  selection:
    ProcessCommandLine|contains:
      - "schtasks"
      - "at.exe"
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
