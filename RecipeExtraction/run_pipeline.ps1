# TCJ live recipe pipeline — all enabled sources (extract + ingest)

Set-Location $PSScriptRoot



$localEnv = Join-Path $PSScriptRoot "setup-env.ps1"

if (Test-Path $localEnv) {

    . $localEnv

} else {

    Write-Host "TCJ Recipe Pipeline" -ForegroundColor Cyan

    Write-Host ""

    Write-Host "No setup-env.ps1 found." -ForegroundColor Yellow

    Write-Host "  1. Copy setup-env.example.ps1 to setup-env.ps1"

    Write-Host "  2. Open setup-env.ps1 in Notepad and paste your keys"

    Write-Host "  3. Run:  . .\setup-env.ps1"

    Write-Host ""

    Write-Host "Or paste into this terminal before ingest:" -ForegroundColor DarkGray

    Write-Host '  $env:SUPABASE_URL="https://kzywmodvfbyexqgipcjt.supabase.co"' -ForegroundColor DarkGray

    Write-Host '  $env:SUPABASE_SERVICE_ROLE_KEY="..."' -ForegroundColor DarkGray

    Write-Host '  $env:TCJ_INGEST_USER_ID="your-uuid"' -ForegroundColor DarkGray

    Write-Host '  $env:GROQ_API_KEY="..."' -ForegroundColor DarkGray

    Write-Host ""

}



python run_pipeline.py @args

exit $LASTEXITCODE

