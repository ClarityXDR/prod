rule: RemoteFileCopy
meta:
  title: "Remote File Copy (T1105)"
  author: "Auto-Generated"
  date: "2025-06-08"
  mitre_techniques: ["T1105"]
  severity: "medium"
  description: "Detects file transfers to or from remote systems using SMB, FTP, or web protocols."
tables:
  primary: "DeviceFileEvents"
detection:
  selection:
    FolderPath|startswith: "\\\\"
    FileName|endswith:
      - ".exe"
      - ".dll"
      - ".ps1"
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
  required_columns: ["Timestamp", "DeviceName", "FileName", "FolderPath"]
  entity_columns: []
