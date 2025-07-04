rule: DetectFilesEncryptedForImpact
meta:
  title: "Data Encrypted for Impact"
  author: "Auto-Converted"
  date: "2025-06-08"
  mitre_techniques: ["T1486"]
  severity: "high"
  description: "Detects processes encrypting multiple files, indicating ransomware activity. Adjust extensions and patterns as needed."
  references: []

tables:
  primary: "DeviceFileEvents"

detection:
  selection:
    ActionType|equals: "FileModified"
    FileName|endswith:
      - ".encrypted"
    FileName|matches_regex:
      - ".*\\.(lock|crypt|cry)$"
    InitiatingProcessFileName|not_equals: "explorer.exe"
    FileCount|greater_than: 100
  filter: {}

timeframe: "1d"
frequency: "1h"
condition: "selection"

response:
  actions:
    - type: "collect_investigation_package"
      target: "DeviceId"

output:
  required_columns: ["DeviceName", "InitiatingProcessFileName", "InitiatingProcessCommandLine"]
  entity_columns: []
