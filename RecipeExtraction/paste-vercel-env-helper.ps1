# Opens the RIGHT Vercel page (project env vars, not team overview)
# and copies each value to clipboard — you only Paste in Vercel 3 times.
#
# Run from PowerShell:
#   cd RecipeExtraction
#   .\paste-vercel-env-helper.ps1

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$setupEnv = Join-Path $PSScriptRoot 'setup-env.ps1'
$supabaseJs = Join-Path $root 'supabase-config.js'

# Project env vars — NOT the team "Environment Variables" sidebar item
$vercelUrls = @(
    'https://vercel.com/miseenplacekitchen/culinary-journal/settings/environment-variables',
    'https://vercel.com/mise-en-places-projects/culinary-journal/settings/environment-variables'
)

Write-Host ''
Write-Host '=== TCJ — Vercel env vars (3 pastes) ===' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Opening project Environment Variables in your browser...' -ForegroundColor Yellow
Write-Host '(NOT the team page under the main sidebar — must be inside culinary-journal project.)'
Write-Host ''

Start-Process $vercelUrls[0]

if (-not (Test-Path $setupEnv)) {
    Write-Host 'Missing setup-env.ps1 — copy setup-env.example.ps1 and fill in keys first.' -ForegroundColor Red
    exit 1
}

. $setupEnv

$groq = $env:GROQ_API_KEY
$service = $env:SUPABASE_SERVICE_ROLE_KEY
$anon = $null
if (Test-Path $supabaseJs) {
    if ($supabaseJs -match "var KEY = '([^']+)'") {
        $anon = $Matches[1]
    }
}

if (-not $groq -or $groq -like '*PASTE*') {
    Write-Host 'GROQ_API_KEY not set in setup-env.ps1' -ForegroundColor Red
    exit 1
}
if (-not $service -or $service -like '*PASTE*') {
    Write-Host 'SUPABASE_SERVICE_ROLE_KEY not set in setup-env.ps1' -ForegroundColor Red
    exit 1
}
if (-not $anon) {
    Write-Host 'Could not read anon key from supabase-config.js' -ForegroundColor Red
    exit 1
}

function Copy-Step {
    param([string]$Name, [string]$Value, [string]$Hint)
    Set-Clipboard -Value $Value
    Write-Host ''
    Write-Host ">>> $Name" -ForegroundColor Green
    Write-Host "    Copied to clipboard. $Hint"
    Write-Host '    In Vercel: Add New -> paste Value -> check Production -> Save'
    Read-Host '    Press Enter when pasted and saved'
}

Write-Host 'In Vercel (culinary-journal project): Settings -> Environment Variables -> Add New'
Write-Host 'Enable Production for each variable.'
Write-Host ''

Copy-Step 'GROQ_API_KEY' $groq 'Key name: GROQ_API_KEY'
Copy-Step 'SUPABASE_SERVICE_ROLE_KEY' $service 'Key name: SUPABASE_SERVICE_ROLE_KEY'
Copy-Step 'SUPABASE_ANON_KEY' $anon 'Key name: SUPABASE_ANON_KEY'

Write-Host ''
Write-Host 'Done. Redeploy: Deployments -> ... -> Redeploy' -ForegroundColor Cyan
Write-Host 'Then hard-refresh admin and try Bulk Autopilot.' -ForegroundColor Cyan
Write-Host ''
