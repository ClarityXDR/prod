rule: DetectUnusualFileExecutions
meta:
  title: "Detect unusual file executions"
  author: "Auto-Converted"
  date: "2025-06-08"
  mitre_techniques: []
  severity: "medium"
  description: "Detects .exe executions from Temp or AppData directories. Customize directories as needed."
  references: []

tables:
  primary: "DeviceProcessEvents"

detection:
  selection:
    ProcessCommandLine|contains:
      - ".exe"
    InitiatingProcessFolderPath|contains:
      - "Temp"
      - "AppData"
  filter: {}

timeframe: "1d"
frequency: "1h"
condition: "selection"

response:
  actions:
    - type: "collect_investigation_package"
      target: "DeviceId"

output:
  required_columns: ["DeviceName", "ProcessCommandLine", "InitiatingProcessFolderPath", "Timestamp"]
  entity_columns: []
