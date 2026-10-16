# Windows Exporter (host metrics)

Docker Desktop runs containers inside a Linux VM, so host CPU, RAM, disk and network have to be
read on Windows itself. [windows_exporter](https://github.com/prometheus-community/windows_exporter)
is a small Windows service that serves those metrics on port 9182. Prometheus scrapes it through
`host.docker.internal:9182`.

## Install

From an **elevated** PowerShell at the repo root:

```powershell
powershell -ExecutionPolicy Bypass -File monitoring\windows-exporter\install.ps1
```

The script:

1. Downloads the official MSI (version set by `-Version`, default `0.30.5`).
2. Installs it as a service with the `cpu, memory, logical_disk, net, os, system` collectors.
3. Restricts the firewall rule the MSI creates to loopback and private ranges.
4. Checks that `http://localhost:9182/metrics` answers.

If the download fails because that version no longer exists, look up the current one on the
[releases page](https://github.com/prometheus-community/windows_exporter/releases) and pass it,
for example `-Version 0.31.3`.

## Check

- `http://localhost:9182/metrics` should list `windows_cpu_time_total`.
- In Prometheus (`http://localhost:9090/targets`), the `windows` job should be **UP**.

Until it is installed, the `windows` target shows DOWN. The dashboard then shows host metrics as
"Not available" and keeps working.

## Uninstall

`Settings → Apps → windows_exporter → Uninstall`, or `msiexec /x <path-to-msi> /qn`.
