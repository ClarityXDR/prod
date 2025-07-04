// filepath: rules/initial_access/t1200_hardware_additions.yar
rule: HardwareAdditions
meta:
  title: "Hardware Additions (T1200)"
  author: "Auto-Generated"
  date: "2025-06-08"
  mitre_techniques: ["T1200"]
  severity: "medium"
  description: "Detects execution of files from removable media (USB drives), which may indicate hardware-based initial access."
tables:
  primary: "DeviceProcessEvents"
detection:
  selection:
    FolderPath|contains:
      - ":\\USB"
      - ":\\Removable"
      - ":\\Media"
      - ":\\Flash"
    FileName|endswith:
      - ".exe"
      - ".dll"
      - ".js"
      - ".vbs"
      - ".scr"
      - ".bat"
  filter: {}
timeframe: "7d"
frequency: "1h"
condition: "selection"
response:
  actions:
    - type: "collect_investigation_package"
      target: "DeviceId"
output:
  required_columns: ["Timestamp", "DeviceName", "FileName", "FolderPath", "ProcessCommandLine", "InitiatingProcessFileName"]
  entity_columns: []
