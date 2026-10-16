<#
.SYNOPSIS
    Installs windows_exporter on this Windows host so the System Control Centre can show host
    CPU, memory, disk and network. Run from an elevated (Administrator) PowerShell:

        powershell -ExecutionPolicy Bypass -File monitoring\windows-exporter\install.ps1

.DESCRIPTION
    Downloads the official MSI from the prometheus-community GitHub releases, installs it as a
    Windows service listening on port 9182, and restricts the firewall rule the MSI creates to
    local and Docker Desktop traffic only (Prometheus scrapes it via host.docker.internal).
#>
param(
    [string]$Version = "0.30.5",
    [string]$Collectors = "cpu,memory,logical_disk,net,os,system"
)

$ErrorActionPreference = "Stop"

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run this script from an elevated (Administrator) PowerShell."
}

$msi = Join-Path $env:TEMP "windows_exporter-$Version-amd64.msi"
$url = "https://github.com/prometheus-community/windows_exporter/releases/download/v$Version/windows_exporter-$Version-amd64.msi"

Write-Host "Downloading windows_exporter $Version ..."
Invoke-WebRequest -Uri $url -OutFile $msi -UseBasicParsing

Write-Host "Installing with collectors: $Collectors"
$arguments = "/i `"$msi`" ENABLED_COLLECTORS=$Collectors LISTEN_PORT=9182 /qn /norestart"
$process = Start-Process msiexec.exe -ArgumentList $arguments -Wait -PassThru
if ($process.ExitCode -ne 0) {
    throw "msiexec failed with exit code $($process.ExitCode)"
}

# The MSI opens 9182 to every network. Narrow it to loopback and private ranges (Docker Desktop's
# VM sits on a private subnet), so the metrics are never offered to the internet.
Get-NetFirewallRule -DisplayName "windows_exporter*" -ErrorAction SilentlyContinue |
    Set-NetFirewallRule -RemoteAddress @("127.0.0.1", "LocalSubnet", "172.16.0.0/12", "192.168.0.0/16", "10.0.0.0/8")

Start-Sleep -Seconds 3
try {
    $response = Invoke-WebRequest -Uri "http://localhost:9182/metrics" -UseBasicParsing -TimeoutSec 10
    if ($response.Content -match "windows_cpu_time_total") {
        Write-Host "windows_exporter is running: http://localhost:9182/metrics" -ForegroundColor Green
    } else {
        Write-Warning "windows_exporter answered but CPU metrics are missing; check the collectors."
    }
} catch {
    Write-Warning "windows_exporter did not answer on port 9182 yet: $($_.Exception.Message)"
    Write-Warning "Check the service with: Get-Service windows_exporter"
}
