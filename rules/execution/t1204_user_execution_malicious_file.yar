rule: UserExecutionMaliciousFile
meta:
  title: "User Execution of Malicious File (T1204)"
  author: "Auto-Generated"
  date: "2025-06-08"
  mitre_techniques: ["T1204"]
  severity: "medium"
  description: "Detects user-initiated execution of potentially malicious files from Downloads or Temp folders."
tables:
  primary: "DeviceProcessEvents"
detection:
  selection:
    InitiatingProcessFolderPath|contains:
      - "Downloads"
      - "Temp"
    FileName|endswith:
      - ".exe"
      - ".js"
      - ".vbs"
      - ".scr"
  filter: {}
timeframe: "7d"
frequency: "1h"
condition: "selection"
response:
  actions:
    - type: "collect_investigation_package"
      target: "DeviceId"
output:
  required_columns: ["Timestamp", "DeviceName", "FileName", "InitiatingProcessFolderPath"]
  entity_columns: []
