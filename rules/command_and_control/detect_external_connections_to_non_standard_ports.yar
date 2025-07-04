rule: DetectExternalConnectionsToNonStandardPorts
meta:
  title: "Detect external connections to non-standard ports"
  author: "Auto-Converted"
  date: "2025-06-08"
  mitre_techniques: ["T1071"]
  severity: "medium"
  description: "Detects external connections to ports outside the standard range. Adjust port range as needed."
  references: []

tables:
  primary: "DeviceNetworkEvents"

detection:
  selection:
    RemoteIP|matches regex: "^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
    RemotePort|<: 1024
  filter: {}

timeframe: "1d"
frequency: "1h"
condition: "selection"

response:
  actions:
    - type: "collect_investigation_package"
      target: "DeviceId"

output:
  required_columns: ["DeviceName", "RemoteIP", "RemotePort", "Timestamp"]
  entity_columns: []
