// filepath: rules/initial_access/t1133_external_remote_services.yar
rule: ExternalRemoteServices
meta:
  title: "External Remote Services (T1133)"
  author: "Auto-Generated"
  date: "2025-06-08"
  mitre_techniques: ["T1133"]
  severity: "high"
  description: "Detects successful remote desktop or SSH logons from external/public IP addresses."
tables:
  primary: "DeviceLogonEvents"
detection:
  selection:
    LogonType|equals: "RemoteInteractive"
    RemoteIP|not_in:
      - "127.0.0.1"
      - "::1"
    RemoteIP|not_empty: true
    RemoteIPType|equals: "Public"
  filter: {}
timeframe: "7d"
frequency: "1h"
condition: "selection"
response:
  actions:
    - type: "collect_investigation_package"
      target: "DeviceId"
output:
  required_columns: ["Timestamp", "DeviceName", "AccountName", "RemoteIP", "LogonType"]
  entity_columns: []
