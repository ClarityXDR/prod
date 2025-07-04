rule: DetectInhibitSystemRecovery
meta:
  title: "Inhibit System Recovery"
  author: "Auto-Converted"
  date: "2025-06-08"
  mitre_techniques: ["T1490"]
  severity: "high"
  description: "Detects attempts to delete or modify system recovery configurations or shadow copies. Adjust commands as needed."
  references: []

tables:
  primary: "DeviceProcessEvents"

detection:
  selection:
    ProcessCommandLine|has_any:
      - "vssadmin delete shadows"
      - "wmic shadowcopy delete"
      - "diskshadow"
      - "bcdedit /set"
      - "wbadmin delete"
      - "Remove-Item"
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
