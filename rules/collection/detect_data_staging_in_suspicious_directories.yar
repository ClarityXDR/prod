rule: DetectDataStagingInSuspiciousDirectories
meta:
  title: "Detect data staging in suspicious directories"
  author: "Auto-Converted"
  date: "2025-06-08"
  mitre_techniques: []
  severity: "medium"
  description: "Detects archiving of data in Temp, Downloads, or AppData directories. Edit folder paths as needed."
  references: []

tables:
  primary: "DeviceFileEvents"

detection:
  selection:
    FolderPath|contains:
      - "Temp"
      - "Downloads"
      - "AppData"
    FileName|endswith:
      - ".zip"
      - ".rar"
      - ".7z"
  filter: {}

timeframe: "1d"
frequency: "1h"
condition: "selection"

response:
  actions:
    - type: "collect_investigation_package"
      target: "DeviceId"

output:
  required_columns: ["Timestamp", "DeviceName", "FolderPath", "FileName", "FileSize"]
  entity_columns: []
