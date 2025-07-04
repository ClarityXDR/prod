rule: DefacementWebContent
meta:
  title: "Defacement of Web Content (T1491)"
  author: "Auto-Generated"
  date: "2025-06-08"
  mitre_techniques: ["T1491"]
  severity: "high"
  description: "Detects modifications to web server content directories."
tables:
  primary: "DeviceFileEvents"
detection:
  selection:
    ActionType|in:
      - "FileCreated"
      - "FileModified"
      - "FileDeleted"
    FolderPath|startswith:
      - "C:\\inetpub\\wwwroot"
      - "/var/www/html"
    InitiatingProcessFileName|not_in:
      - "w3wp.exe"
      - "httpd.exe"
      - "nginx.exe"
  filter: {}
timeframe: "7d"
frequency: "1h"
condition: "selection"
response:
  actions:
    - type: "collect_investigation_package"
      target: "DeviceId"
output:
  required_columns: ["Timestamp", "DeviceName", "ActionType", "FileName", "FolderPath", "InitiatingProcessFileName", "InitiatingProcessCommandLine"]
  entity_columns: []
