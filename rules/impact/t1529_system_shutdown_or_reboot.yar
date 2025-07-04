rule: SystemShutdownOrReboot
meta:
  title: "System Shutdown or Reboot (T1529)"
  author: "Auto-Generated"
  date: "2025-06-08"
  mitre_techniques: ["T1529"]
  severity: "medium"
  description: "Detects processes initiating system shutdown or reboot."
tables:
  primary: "DeviceProcessEvents"
detection:
  selection:
    ProcessCommandLine|has_any:
      - "shutdown /s"
      - "shutdown /r"
      - "Restart-Computer"
      - "Stop-Computer"
  filter: {}
timeframe: "7d"
frequency: "1h"
condition: "selection"
response:
  actions:
    - type: "collect_investigation_package"
      target: "DeviceId"
output:
  required_columns: ["Timestamp", "DeviceName", "FileName", "ProcessCommandLine", "InitiatingProcessFileName", "InitiatingProcessCommandLine"]
  entity_columns: []
