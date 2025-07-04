rule: DetectRemoteServiceCreation
meta:
  title: "Detect remote service creation"
  author: "Auto-Converted"
  date: "2025-06-08"
  mitre_techniques: ["T1021.002"]
  severity: "medium"
  description: "Detects remote service creation via sc.exe. Modify for alternative methods as needed."
  references: []

tables:
  primary: "DeviceProcessEvents"

detection:
  selection:
    ProcessCommandLine|contains:
      - "sc.exe"
      - "create"
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
