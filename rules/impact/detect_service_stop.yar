rule: DetectServiceStop
meta:
  title: "Service Stop"
  author: "Auto-Converted"
  date: "2025-06-08"
  mitre_techniques: ["T1489"]
  severity: "high"
  description: "Detects attempts to stop or disable services. Adjust commands as needed."
  references: []

tables:
  primary: "DeviceProcessEvents"

detection:
  selection:
    ProcessCommandLine|has_any:
      - "net stop"
      - "sc stop"
      - "Set-Service -Status Stopped"
      - "Stop-Service"
  filter: {}

timeframe: "1d"
frequency: "1h"
condition: "selection"

response:
  actions:
    - type: "collect_investigation_package"
      target: "DeviceId"

output:
  required_columns: ["Timestamp", "DeviceName", "FileName", "ProcessCommandLine", "InitiatingProcessFileName", "InitiatingProcessCommandLine"]
  entity_columns: []
