# Catch-up: polish anything still messy + inbox summary — Betty
# Run weekly or when Groq limit stopped mid-batch.

param(
    [int]$Limit = 0,
    [switch]$DryRun,
    [switch]$SkipPolish
)

Set-Location $PSScriptRoot

if (Test-Path "setup-env.ps1") {
    . .\setup-env.ps1
} else {
    Write-Host "Copy setup-env.example.ps1 to setup-env.ps1 first." -ForegroundColor Yellow
    exit 1
}

$args = @("admin_routine.py")
if ($Limit -gt 0) { $args += @("--limit", $Limit) }
if ($DryRun) { $args += "--dry-run" }
if ($SkipPolish) { $args += "--skip-polish" }

Write-Host ""
Write-Host "=== TCJ Admin Routine ===" -ForegroundColor Cyan
python @args
exit $LASTEXITCODE
