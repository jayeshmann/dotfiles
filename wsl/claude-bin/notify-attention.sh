#!/usr/bin/env bash
# Windows toast notification for Claude Code hooks (WSL2 → WezTerm/Windows).
# Reads Claude's hook JSON from stdin, shows a balloon toast via PowerShell NotifyIcon.

set -u

msg=$(jq -r '.message // "Needs your attention"' 2>/dev/null)
[ -z "${msg:-}" ] && msg="Needs your attention"

# Escape single quotes for PS single-quoted string (PS uses '' to escape ').
msg_ps=$(printf '%s' "$msg" | sed "s/'/''/g")

powershell.exe -NoProfile -WindowStyle Hidden -Command "
Add-Type -AssemblyName System.Windows.Forms | Out-Null
\$n = New-Object System.Windows.Forms.NotifyIcon
\$n.Icon = [System.Drawing.SystemIcons]::Information
\$n.Visible = \$true
\$n.ShowBalloonTip(5000, 'Claude Code', '$msg_ps', 'Info')
Start-Sleep -Seconds 2
\$n.Dispose()
" >/dev/null 2>&1 &

disown 2>/dev/null || true
exit 0
