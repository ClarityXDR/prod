rule: DetectUnusualDNSRequests
meta:
  title: "Unusual DNS requests"
  author: "Auto-Converted"
  date: "2025-06-08"
  mitre_techniques: ["T1071.004"]
  severity: "medium"
  description: "Detects DNS requests to uncommon TLDs. Adjust TLDs as needed."
  references: []

tables:
  primary: "DeviceNetworkEvents"

detection:
  selection:
    RemotePort|==: 53
    RemoteUrl|!contains:
      - ".com"
      - ".org"
      - ".net"
  filter: {}

timeframe: "1d"
frequency: "1h"
condition: "selection"

response:
  actions:
    - type: "collect_investigation_package"
      target: "DeviceId"

output:
  required_columns: ["DeviceName", "RemoteUrl", "Timestamp"]
  entity_columns: []
