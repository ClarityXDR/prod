// filepath: rules/credential_access/t1552_unsecured_credentials.yar
rule: UnsecuredCredentials
meta:
  title: "Unsecured Credentials (T1552)"
  author: "Auto-Generated"
  date: "2025-06-08"
  mitre_techniques: ["T1552"]
  severity: "medium"
  description: "Detects access to email attachments or files that may contain unsecured credentials."
tables:
  primary: "EmailAttachmentInfo"
detection:
  selection:
    FileName|matches regex:
      - ".*(password|cred|secret|key).*\\.(txt|xml|json|csv|ini|config)$"
    ThreatTypes|contains: "Credential"
  filter: {}
timeframe: "7d"
frequency: "1h"
condition: "selection"
response:
  actions:
    - type: "collect_investigation_package"
      target: "NetworkMessageId"
output:
  required_columns: ["Timestamp", "NetworkMessageId", "FileName", "ThreatTypes", "SHA256"]
  entity_columns: []
