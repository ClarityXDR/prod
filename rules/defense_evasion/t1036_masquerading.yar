rule: Masquerading
meta:
  title: "Masquerading (T1036)"
  author: "Auto-Generated"
  date: "2025-06-08"
  mitre_techniques: ["T1036"]
  severity: "medium"
  description: "Detects suspicious process names or file extensions used for masquerading."
tables:
  primary: "DeviceProcessEvents"
detection:
  selection:
    FileName|endswith:
      - ".scr"
      - ".com"
      - ".pif"
      - ".cpl"
    ProcessCommandLine|contains:
      - "svchost.exe"
      - "explorer.exe"
      - "lsass.exe"
  filter: {}
timeframe: "7d"
frequency: "1h"
condition: "selection"
response:
  actions:
    - type: "collect_investigation_package"
      target: "DeviceId"
output:
  required_columns: ["Timestamp", "DeviceName", "FileName", "ProcessCommandLine"]
  entity_columns: []
