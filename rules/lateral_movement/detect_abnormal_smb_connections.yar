rule: DetectAbnormalSMBConnections
meta:
  title: "Detect abnormal SMB connections"
  author: "Auto-Converted"
  date: "2025-06-08"
  mitre_techniques: ["T1021.002"]
  severity: "medium"
  description: "Detects SMB connections on port 445. Customize port for other SMB variants."
  references: []

tables:
  primary: "DeviceNetworkEvents"

detection:
  selection:
    RemotePort|equals: 445
  filter: {}

timeframe: "1d"
frequency: "1h"
condition: "selection"

response:
  actions:
    - type: "collect_investigation_package"
      target: "DeviceId"

output:
  required_columns: ["DeviceName", "RemoteIP"]
  entity_columns: []
