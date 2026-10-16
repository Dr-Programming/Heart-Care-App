<#
.SYNOPSIS
    Registers test patient accounts for the JMeter mobile users and writes them to patients.csv.

        powershell -File monitoring\jmeter\create-test-patients.ps1 -Count 10 -BaseUrl http://localhost:8080

.DESCRIPTION
    Each account gets a phone number in the +25190000xxxx test range and the PIN given by -Pin.
    The backend allows 10 registrations per client IP per hour (app.rate-limit.register), so asking
    for more than 10 stops at the limit; the CSV keeps every account created so far, and JMeter
    recycles rows, so 10 accounts are enough for any number of mobile threads.

    Use this only against a demonstration database: it creates real rows.
#>
param(
    [int]$Count = 10,
    [string]$BaseUrl = "http://localhost:8080",
    [string]$Pin = "2468",
    [string]$Output = (Join-Path $PSScriptRoot "patients.csv")
)

$ErrorActionPreference = "Stop"
$created = @()
$start = Get-Random -Minimum 1000 -Maximum 8000

for ($i = 0; $i -lt $Count; $i++) {
    $phone = "+25190000" + ($start + $i).ToString("0000")
    $body = @{ phone = $phone; pin = $Pin; name = "Load Test $($i + 1)"; preferredLanguage = "en" } | ConvertTo-Json
    try {
        Invoke-RestMethod -Method Post -Uri "$BaseUrl/api/v1/auth/register" -ContentType "application/json" -Body $body | Out-Null
        $created += [pscustomobject]@{ phone = $phone; pin = $Pin }
        Write-Host "Registered $phone"
    } catch {
        $status = $_.Exception.Response.StatusCode.value__
        if ($status -eq 429) {
            Write-Warning "Registration rate limit reached after $($created.Count) accounts. Run again in an hour for more."
            break
        }
        Write-Warning "Could not register ${phone}: $($_.Exception.Message)"
    }
}

if ($created.Count -gt 0) {
    $exists = Test-Path $Output
    $created | ConvertTo-Csv -NoTypeInformation | ForEach-Object { $_ -replace '"', '' } |
        Select-Object -Skip ([int]$exists) | Add-Content -Path $Output -Encoding utf8
    Write-Host "Wrote $($created.Count) accounts to $Output" -ForegroundColor Green
}
