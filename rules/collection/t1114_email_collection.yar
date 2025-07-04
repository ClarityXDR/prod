// filepath: rules/collection/t1114_email_collection.yar
rule: EmailCollection
meta:
  title: "Email Collection (T1114)"
  author: "Auto-Generated"
  date: "2025-06-08"
  mitre_techniques: ["T1114"]
  severity: "high"
  description: "Detects mass mailbox access or downloads, indicating potential email collection."
tables:
  primary: "EmailEvents"
detection:
  selection:
    EmailAction|in:
      - "MailRead"
      - "MailExport"
      - "MailDownload"
  filter: {}
timeframe: "7d"
frequency: "1h"
condition: "selection"
response:
  actions:
    - type: "collect_investigation_package"
      target: "RecipientEmailAddress"
output:
  required_columns: ["Timestamp", "RecipientEmailAddress", "EmailAction", "SenderFromAddress", "Subject"]
  entity_columns: []
