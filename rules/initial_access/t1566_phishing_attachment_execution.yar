rule: PhishingAttachmentExecution
meta:
  title: "Phishing Attachment Execution (T1566)"
  author: "Auto-Generated"
  date: "2025-06-08"
  mitre_techniques: ["T1566"]
  severity: "high"
  description: "Detects execution of suspicious attachments from email clients."
tables:
  primary: "DeviceProcessEvents"
detection:
  selection:
    InitiatingProcessFileName|in:
      - "outlook.exe"
      - "thunderbird.exe"
      - "winmail.exe"
    FileName|endswith:
      - ".exe"
      - ".dll"
      - ".scr"
      - ".hta"
  filter: {}
timeframe: "7d"
frequency: "1h"
condition: "selection"
response:
  actions:
    - type: "collect_investigation_package"
      target: "DeviceId"
output:
  required_columns: ["Timestamp", "DeviceName", "FileName", "ProcessCommandLine", "InitiatingProcessFileName"]
  entity_columns: []
