rule: ProcessInjection
meta:
  title: "Process Injection (T1055)"
  author: "Auto-Generated"
  date: "2025-06-08"
  mitre_techniques: ["T1055"]
  severity: "high"
  description: "Detects process injection by monitoring suspicious memory allocation and remote thread creation."
tables:
  primary: "DeviceProcessEvents"
detection:
  selection:
    ProcessCommandLine|contains:
      - "VirtualAllocEx"
      - "WriteProcessMemory"
      - "CreateRemoteThread"
  filter: {}
timeframe: "7d"
frequency: "1h"
condition: "selection"
response:
  actions:
    - type: "collect_investigation_package"
      target: "DeviceId"
output:
  required_columns: ["Timestamp", "DeviceName", "ProcessCommandLine"]
  entity_columns: []
