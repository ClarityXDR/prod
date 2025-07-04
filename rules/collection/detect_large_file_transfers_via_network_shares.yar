rule: DetectLargeFileTransfersViaNetworkShares
meta:
  title: "Detect large file transfers via Network Shares"
  author: "Auto-Converted"
  date: "2025-06-08"
  mitre_techniques: []
  severity: "medium"
  description: "Detects creation or modification of large files over network shares. Adjust file size threshold as needed."
  references: []

tables:
  primary: "DeviceFileEvents"

detection:
  selection:
    ActionType|in~:
      - "FileCreated"
      - "FileModified"
    FolderPath|startswith: "\\\\"
    FileSize|>: 100000000
  filter: {}

timeframe: "1d"
frequency: "1h"
condition: "selection"

response:
  actions:
    - type: "collect_investigation_package"
      target: "DeviceId"

output:
  required_columns: ["Timestamp", "DeviceName", "FileName", "FolderPath", "FileSize"]
  entity_columns: []
