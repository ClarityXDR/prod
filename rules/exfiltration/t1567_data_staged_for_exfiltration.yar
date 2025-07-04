rule: DataStagedForExfiltration
meta:
  title: "Data Staged for Exfiltration (T1567)"
  author: "Auto-Generated"
  date: "2025-06-08"
  mitre_techniques: ["T1567"]
  severity: "medium"
  description: "Detects creation of archive files in user directories, indicating data staging for exfiltration."
tables:
  primary: "DeviceFileEvents"
detection:
  selection:
    FileName|endswith:
      - ".zip"
      - ".rar"
      - ".7z"
      - ".tar.gz"
    FolderPath|contains:
      - "Users"
      - "Documents"
      - "Temp"
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
