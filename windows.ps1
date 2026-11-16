# New Windows machine: install OpenSSH Server, trust the Mac's SSH key, join Tailscale,
# so the Mac can SSH in over Tailscale.
# Usage (PowerShell, machine online):  irm is.gd/nkwin | iex
# Safe to run again; finished steps are skipped. ASCII only on purpose (irm | iex encoding).

$ErrorActionPreference = 'Stop'
$SelfUrl = 'https://is.gd/nkwin'
$MacKey  = 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJpZBHkayfHyqkMd3Up10zjIDCATGNZYgEGLDILRK4RO'

function Step($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  if ($SelfUrl -like 'http*') {
    Write-Host 'Asking for administrator rights; click Yes. The rest runs in the new window.' -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList '-NoExit', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', "irm '$SelfUrl' | iex"
    return
  }
  throw 'Open PowerShell as Administrator (Win+X, Terminal (Admin)) and run the command again.'
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

Step '1/5 Install OpenSSH Server'
if (-not (Get-Service sshd -ErrorAction SilentlyContinue)) {
  $cap = Get-WindowsCapability -Online -Name 'OpenSSH.Server*' | Select-Object -First 1
  Add-WindowsCapability -Online -Name $cap.Name | Out-Null
}
Set-Service sshd -StartupType Automatic
Start-Service sshd
New-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name DefaultShell -Value "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -PropertyType String -Force | Out-Null
# Allow SSH on every network profile, but only from Tailscale addresses.
$rule = Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue
if (-not $rule) {
  New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH Server (sshd)' -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow | Out-Null
}
Set-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -Enabled True -Profile Any -RemoteAddress @('100.64.0.0/10', 'fd7a:115c:a1e0::/48')

Step "2/5 Trust the Mac's SSH key"
# Administrators read this file instead of ~\.ssh\authorized_keys.
$f = "$env:ProgramData\ssh\administrators_authorized_keys"
if (Test-Path $f) { icacls $f /grant '*S-1-5-32-544:(F)' | Out-Null }
if (-not (Test-Path $f) -or -not (Select-String -LiteralPath $f -SimpleMatch $MacKey -Quiet)) {
  Add-Content -LiteralPath $f -Value $MacKey -Encoding ascii
}
icacls $f /inheritance:r /grant:r '*S-1-5-18:(F)' '*S-1-5-32-544:(F)' | Out-Null
Restart-Service sshd

Step '3/5 Keep the machine awake on AC power'
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0

Step '4/5 Install Tailscale'
$ts = "$env:ProgramFiles\Tailscale\tailscale.exe"
if (-not (Test-Path $ts)) {
  $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'amd64' }
  $msi = Join-Path $env:TEMP 'tailscale-setup.msi'
  Invoke-WebRequest -UseBasicParsing "https://pkgs.tailscale.com/stable/tailscale-setup-latest-$arch.msi" -OutFile $msi
  Start-Process msiexec.exe -Wait -ArgumentList '/i', "`"$msi`"", '/qn', '/norestart'
  if (-not (Test-Path $ts)) { throw 'Tailscale install failed. Install it from https://tailscale.com/download and run this again.' }
}

Step '5/5 Join the tailnet'
& $ts status *> $null
if ($LASTEXITCODE -eq 0) {
  Write-Host 'Already logged in to Tailscale.'
} else {
  Write-Host 'Send the login URL below (or a photo of the QR code) to Nick, then wait here until it says Success.' -ForegroundColor Yellow
  & $ts up --unattended --qr
}

$ip = (& $ts ip -4 2>$null | Select-Object -First 1)
$sshd = (Get-Service sshd).Status
Write-Host "`nDONE. Send this line to Nick:" -ForegroundColor Green
Write-Host "  user=$env:USERNAME  host=$env:COMPUTERNAME  tailscale_ip=$ip  os=windows  sshd=$sshd"
