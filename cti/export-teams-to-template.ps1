<#
.SYNOPSIS
    Export (and optionally re-import) an existing Microsoft Teams template
    from an Azure Cloud Shell PowerShell session.

.DESCRIPTION
    • Installs/updates the MicrosoftTeams module in the user scope
    • Authenticates to Teams with a device-code flow (works in Cloud Shell)
    • Lists tenant-scoped templates and lets you choose one interactively
    • Saves the template JSON to $HOME for download or version-control
    • Optionally re-imports the (edited) JSON as a brand-new template

.NOTES
    Tested in Cloud Shell PowerShell 7.x with MicrosoftTeams 7.1.0
#>

# ── 0. Ensure the Teams module is available ─────────────────────────────────────
try {
    Install-Module MicrosoftTeams -Scope CurrentUser -Force -ErrorAction Stop
} catch {
    Write-Host "✔ MicrosoftTeams module already present / up-to-date."
}
Import-Module MicrosoftTeams

# ── 1. Sign in (device-code flow) ──────────────────────────────────────────────
$tenantId = (Get-AzTenant).Id  # Re-use the tenant you opened Cloud Shell with
Connect-MicrosoftTeams -TenantId $tenantId -UseDeviceAuthentication

# ── 2. Show tenant-scoped templates and capture ODataId ────────────────────────
$templates =
    Get-CsTeamTemplateList |              # no -Locale switch – it doesn’t exist :contentReference[oaicite:0]{index=0}
    Where-Object { $_.Scope -eq 'Tenant' } |
    Select-Object @{n='Index';e={[array]::IndexOf($templates,$_) + 1}}, DisplayName, OdataId

if (-not $templates) {
    Write-Warning "No custom templates found in this tenant."
    return
}

$templates | Format-Table -AutoSize
[int]$choice = Read-Host "Enter the Index of the template to export"
$templateId = $templates[$choice-1].OdataId

# ── 3. Export the template to JSON ─────────────────────────────────────────────
$exportPath = Join-Path $HOME "TeamTemplate.json"
(Get-CsTeamTemplate -OdataId $templateId) |
    ConvertTo-Json -Depth 100 |
    Out-File -FilePath $exportPath -Encoding utf8
Write-Host "✔ Template exported to $exportPath"

# ── 4. Optional re-import as a new template ────────────────────────────────────
if ((Read-Host "Import the (edited) JSON as a new template? [y/N]") -match '^[yY]') {
    $json = Get-Content -Raw -Path $exportPath
    New-CsTeamTemplate -Locale 'en-US' -Body $json            # -Locale IS required here :contentReference[oaicite:1]{index=1}
    Write-Host "✔ New template created."
}

# ── 5. (Optional) Disconnect ───────────────────────────────────────────────────
# Disconnect-MicrosoftTeams
