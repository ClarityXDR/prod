rule: DetectPsExecToolUse
meta:
  title: "Detect use of PsExec tool"
  author: "Auto-Converted"
  date: "2025-06-08"
  mitre_techniques: ["T1569.002"]
  severity: "medium"
  description: "Detects use of PsExec tool via command line. Adjust for known variants or switches."
  references: []

tables:
  primary: "DeviceProcessEvents"

detection:
  selection:
    ProcessCommandLine|contains:
      - "psexec"
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
