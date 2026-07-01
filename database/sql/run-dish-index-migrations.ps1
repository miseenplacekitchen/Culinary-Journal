# run-dish-index-migrations.ps1 — Run all Dish Index SQL in order via psql (bypasses SQL Editor fetch errors).
#
# Prerequisites:
#   1. PostgreSQL client (psql) installed — https://www.postgresql.org/download/windows/
#   2. Database connection string in $env:DATABASE_URL
#
# Get DATABASE_URL from Supabase:
#   Project Settings → Database → Connection string → URI (Session pooler or Direct)
#   Replace [YOUR-PASSWORD] with your database password.
#
# Example:
#   $env:DATABASE_URL = "postgresql://postgres.kzywmodvfbyexqgipcjt:YOUR_PASSWORD@aws-0-ap-southeast-1.pooler.supabase.com:5432/postgres"
#   .\database\sql\run-dish-index-migrations.ps1
#
# Optional: run a single step
#   .\database\sql\run-dish-index-migrations.ps1 -FromStep 4

param(
    [int]$FromStep = 1,
    [int]$ToStep = 8
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$Steps = @(
    @{ N = 1; File = "fix-recipe-name-library.sql";       Label = "Base table + RPCs" },
    @{ N = 2; File = "fix-dish-index-columns.sql";        Label = "Metadata columns" },
    @{ N = 3; File = "fix-dish-index-ops.sql";            Label = "DI codes, bulk, sync" },
    @{ N = 4; File = "fix-dish-index-list-filter.sql";    Label = "Archived filter (list RPC)" },
    @{ N = 5; File = "fix-dish-index-list-filter-csv.sql"; Label = "Hero Ingredient CSV alias" },
    @{ N = 6; File = "fix-dish-index-phase-abc.sql";      Label = "Drift, restore, queue counts" },
    @{ N = 7; File = "fix-dish-index-intelligence.sql";   Label = "Duplicate clusters + coverage gaps" },
    @{ N = 8; File = "fix-dish-index-table-ux.sql";       Label = "Visibility + table UX SQL" }
)

if (-not $env:DATABASE_URL) {
    Write-Host "ERROR: Set DATABASE_URL first (Supabase → Database → Connection string → URI)." -ForegroundColor Red
    Write-Host '  $env:DATABASE_URL = "postgresql://postgres.[ref]:[password]@[host]:5432/postgres"' -ForegroundColor DarkGray
    exit 1
}

$psql = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psql) {
    Write-Host "ERROR: psql not found. Install PostgreSQL client tools and add to PATH." -ForegroundColor Red
    exit 1
}

Write-Host "Dish Index migrations (steps $FromStep–$ToStep)" -ForegroundColor Cyan
Write-Host "Using psql: $($psql.Source)" -ForegroundColor DarkGray
Write-Host ""

foreach ($step in $Steps) {
    if ($step.N -lt $FromStep -or $step.N -gt $ToStep) { continue }

    $path = Join-Path $ScriptDir $step.File
    if (-not (Test-Path $path)) {
        Write-Host "Step $($step.N): MISSING $($step.File)" -ForegroundColor Red
        exit 1
    }

    Write-Host "Step $($step.N)/6: $($step.Label) — $($step.File) ..." -ForegroundColor Yellow
    & psql $env:DATABASE_URL -v ON_ERROR_STOP=1 -f $path
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAILED at step $($step.N). Fix the error above, then re-run with -FromStep $($step.N)" -ForegroundColor Red
        exit $LASTEXITCODE
    }
    Write-Host "  OK" -ForegroundColor Green
    Write-Host ""
}

Write-Host "All Dish Index migrations complete." -ForegroundColor Green
