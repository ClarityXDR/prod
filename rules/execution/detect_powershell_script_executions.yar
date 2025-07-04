rule: DetectPowerShellScriptExecutions
meta:
  title: "Identify PowerShell script executions"
  author: "Auto-Converted"
  date: "2025-06-08"
  mitre_techniques: ["T1059.001"]
  severity: "medium"
  description: "Detects execution of PowerShell scripts. Add specific commands as needed."
  references: []

tables:
  primary: "DeviceProcessEvents"

detection:
  selection:
    ProcessCommandLine|contains:
      - "powershell"
  filter: {}

timeframe: "1d"
frequency: "1h"
condition: "selection"

response:
  actions:
    - type: "collect_investigation_package"
      target: "DeviceId"

output:
  required_columns: ["DeviceName", "ProcessCommandLine", "Timestamp"]
  entity_columns: []
