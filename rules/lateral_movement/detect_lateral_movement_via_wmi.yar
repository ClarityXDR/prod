rule: DetectLateralMovementViaWMI
meta:
  title: "Detect lateral movement via WMI"
  author: "Auto-Converted"
  date: "2025-06-08"
  mitre_techniques: ["T1047"]
  severity: "medium"
  description: "Detects WMI commands with network paths, indicating lateral movement. Add other WMI commands if needed."
  references: []

tables:
  primary: "DeviceProcessEvents"

detection:
  selection:
    ProcessCommandLine|contains:
      - "wmic"
      - "\\"
  filter: {}

timeframe: "1d"
frequency: "1h"
condition: "selection"

response:
  actions:
    - type: "collect_investigation_package"
      target: "DeviceId"

output:
  required_columns: ["DeviceName", "ProcessCommandLine", "Timestamp"]
  entity_columns: []
