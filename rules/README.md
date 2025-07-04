# Microsoft Defender XDR Detection Rules

This directory contains detection rules for Microsoft Defender XDR, mapped to the MITRE ATT&CK framework and written in a standardized YARA-XDR format. These rules are designed to help security teams detect, investigate, and respond to a wide range of adversary techniques using Microsoft 365 Defender and Microsoft Sentinel data sources.

## Structure

- **Organized by MITRE ATT&CK Tactic:**
  - `initial_access/` — Techniques for gaining initial access (e.g., phishing, drive-by, exploits)
  - `execution/` — Malicious code execution (e.g., PowerShell, script, LOLBins)
  - `persistence/` — Maintaining access (e.g., registry, scheduled tasks)
  - `privilege_escalation/` — Gaining higher-level permissions
  - `defense_evasion/` — Avoiding detection (e.g., log clearing, masquerading)
  - `credential_access/` — Stealing credentials (e.g., brute force, dumping)
  - `discovery/` — Internal reconnaissance (e.g., account, network, process discovery)
  - `lateral_movement/` — Moving within the environment (e.g., RDP, SMB, PsExec)
  - `collection/` — Gathering data (e.g., clipboard, screenshots, file staging)
  - `command_and_control/` — C2 channels (e.g., DNS, HTTP, outbound traffic)
  - `exfiltration/` — Data theft (e.g., archive creation, cloud uploads)
  - `impact/` — Disruption (e.g., ransomware, defacement, shutdown)

## Rule Format

- **YARA-XDR YAML/YAR:**
  - Each rule includes metadata (title, author, MITRE technique, severity, description)
  - Detection logic leverages Defender XDR tables (e.g., DeviceProcessEvents, DeviceFileEvents)
  - MITRE ATT&CK technique numbers (Txxxx) are mapped in metadata
  - Response actions and output columns are defined for each rule

## Usage

- Rules are intended for automated deployment via Azure Automation and Azure Blob Storage (see repository root README for details)
- Each rule can be used for:
  - Threat detection and alerting
  - Threat hunting
  - Incident investigation

## Contributing

- Follow the YARA-XDR format for new rules
- Map each rule to the appropriate MITRE ATT&CK technique
- Place new rules in the correct subfolder by tactic
- Include a clear description and relevant metadata

## References
- [MITRE ATT&CK Framework](https://attack.mitre.org/)
- [Microsoft 365 Defender Advanced Hunting](https://learn.microsoft.com/en-us/microsoft-365/security/defender/advanced-hunting-overview)
- [YARA-XDR Rule Format](https://github.com/microsoft/Microsoft-365-Defender-Hunting-Rules)

## MITRE ATT&CK Coverage Chart

Below is a summary of MITRE ATT&CK tactics and techniques currently covered by rules in this directory. Each checked technique has a corresponding YARA-XDR rule.

| Tactic                | Techniques Covered                                                                                 |
|-----------------------|---------------------------------------------------------------------------------------------------|
| Initial Access        | T1133, T1189, T1190, T1200, T1566, T1078                                                           |
| Execution             | T1059.001, T1204, (PowerShell, LOLBins, User Execution, etc.)                                      |
| Persistence           | T1053, T1543, T1547                                                                               |
| Privilege Escalation  | T1078                                                                                            |
| Defense Evasion       | T1036, T1055, T1070, T1216, T1218, T1562                                                          |
| Credential Access     | T1003.001, T1110                                                                                  |
| Discovery             | T1007, T1016, T1046, T1057, T1082, T1087                                                          |
| Lateral Movement      | T1021.001, T1021.002, T1047, T1105, T1569.002                                                     |
| Collection            | (Clipboard, Data Staging, File Access, Screen Capture, etc.)                                      |
| Command & Control     | T1071, T1071.004                                                                                  |
| Exfiltration          | T1567                                                                                            |
| Impact                | T1486, T1489, T1490, T1491, T1529                                                                 |

- **Legend:**
  - Techniques are referenced by their MITRE T-number (e.g., T1190 = Exploit Public-Facing Application)
  - For a full list of rules and their mappings, see the subfolders and rule metadata

> **Tip:** To expand coverage, add new rules for uncovered techniques or update this chart as new rules are added.

> **Possible MITRE ATT&CK Techniques to Add:**
>
> - T1195: Supply Chain Compromise
> - T1199: Trusted Relationship
> - T1552: Unsecured Credentials (e.g., detection of access to config files, registry keys with passwords)
> - T1555: Credentials from Password Stores (e.g., browser stores, Windows Credential Manager)
> - T1112: Modify Registry (suspicious registry modifications outside persistence keys)
> - T1560: Archive Collected Data (expand to more archive formats/processes)
> - T1568: Dynamic Resolution (e.g., DNS over HTTPS, custom resolvers)
> - T1203: Exploitation for Client Execution (e.g., suspicious child processes from browsers/docs)
> - T1553: Subvert Trust Controls (e.g., use of signtool, Set-AuthenticodeSignature)
> - T1098: Account Manipulation (e.g., mailbox rule creation, permission changes)
> - T1114: Email Collection (mass mailbox access/downloads)
> - T1192: Spearphishing Link (clicks on suspicious links in emails)
> - T1078.004: Valid Accounts: Cloud Accounts (suspicious cloud logins)
> - T1217: Browser Bookmark Discovery
> - T1113: Screen Capture (expand detection)
> - T1027: Obfuscated Files or Information (e.g., use of packers, encoders)

---

For more information on rule deployment, versioning, and rollback, see the main repository documentation.
