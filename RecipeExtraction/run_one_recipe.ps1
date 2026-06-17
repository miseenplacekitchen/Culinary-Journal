# Upload ONE book recipe to Admin Pending — NO Groq.
# Run repeatedly: each run uploads the next recipe not yet in Supabase.

Set-Location $PSScriptRoot

if (Test-Path "setup-env.ps1") {
    . .\setup-env.ps1
} else {
    Write-Host "Copy setup-env.example.ps1 to setup-env.ps1 first." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "=== TCJ — one recipe ===" -ForegroundColor Cyan
Write-Host "Uploading next Lebanese book recipe (no Groq) ..." -ForegroundColor White
python ingest_tcj.py --subdir books --until-ok 1
$code = $LASTEXITCODE

Write-Host ""
python admin_routine.py --skip-polish

Write-Host ""
Write-Host "Next: Admin dashboard -> Recipes -> Pending" -ForegroundColor Green
Write-Host "  Edit all fields if needed, then Approve." -ForegroundColor Green
Write-Host "Run .\run_one_recipe.bat again for the next recipe." -ForegroundColor DarkGray

exit $code
