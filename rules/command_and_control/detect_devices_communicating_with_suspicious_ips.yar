rule: DetectDevicesCommunicatingWithSuspiciousIPs
meta:
  title: "Identify devices communicating with suspicious IPs"
  author: "Auto-Converted"
  date: "2025-06-08"
  mitre_techniques: ["T1071"]
  severity: "medium"
  description: "Detects devices communicating with known malicious IPs. Edit IP list as needed."
  references: []

tables:
  primary: "DeviceNetworkEvents"

detection:
  selection:
    RemoteIP|in:
      - "known_bad_ip_1"
      - "known_bad_ip_2"
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
