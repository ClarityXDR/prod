rule: DetectPotentialDNSTunneling
meta:
  title: "Detect potential DNS tunneling activity"
  author: "Auto-Converted"
  date: "2025-06-08"
  mitre_techniques: ["T1071.004"]
  severity: "medium"
  description: "Detects high volume of DNS queries to uncommon TLDs, indicating possible DNS tunneling. Adjust TLDs and threshold as needed."
  references: []

tables:
  primary: "DeviceNetworkEvents"

detection:
  selection:
    RemotePort|==: 53
    RemoteUrl|endswith:
      - ".net"
      - ".info"
      - ".xyz"
  filter: {}

timeframe: "1d"
frequency: "1h"
condition: "selection"

response:
  actions:
    - type: "collect_investigation_package"
      target: "DeviceId"

output:
  required_columns: ["DeviceName", "RemoteUrl", "RemoteIP"]
  entity_columns: []
