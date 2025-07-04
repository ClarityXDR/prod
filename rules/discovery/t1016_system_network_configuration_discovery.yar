// filepath: rules/discovery/t1016_system_network_configuration_discovery.yar
rule: SystemNetworkConfigurationDiscovery
meta:
  title: "System Network Configuration Discovery (T1016)"
  author: "Auto-Generated"
  date: "2025-06-08"
  mitre_techniques: ["T1016"]
  severity: "medium"
  description: "Detects use of network configuration commands."
tables:
  primary: "DeviceProcessEvents"
detection:
  selection:
    ProcessCommandLine|has_any:
      - "ipconfig"
      - "ifconfig"
      - "netstat"
      - "route print"
      - "arp -a"
  filter: {}
timeframe: "7d"
frequency: "1h"
condition: "selection"
response:
  actions:
    - type: "collect_investigation_package"
      target: "DeviceId"
output:
  required_columns: ["Timestamp", "DeviceName", "ProcessCommandLine", "InitiatingProcessAccountName"]
  entity_columns: []
