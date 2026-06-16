# Betty — run books: extract → upload → Groq polish (one command)

Set-Location $PSScriptRoot

if (Test-Path "setup-env.ps1") {
    . .\setup-env.ps1
} else {
    Write-Host ""
    Write-Host "First time only: copy setup-env.example.ps1 to setup-env.ps1" -ForegroundColor Yellow
    Write-Host "Open setup-env.ps1 in Notepad, paste your Supabase + Groq keys, save." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "=== TCJ Books ===" -ForegroundColor Cyan
Write-Host "Step 1/3: Extract books from inputs\books\ (always refresh) ..." -ForegroundColor White
$bookFiles = @(Get-ChildItem -Path "inputs\books\*" -File -Include *.pdf,*.docx,*.txt,*.md,*.text -ErrorAction SilentlyContinue)
if (-not $bookFiles -or $bookFiles.Count -eq 0) {
    Write-Host "No book files in inputs\books\" -ForegroundColor Red
    exit 1
}
foreach ($book in $bookFiles) {
    Write-Host "  -> $($book.Name)" -ForegroundColor DarkGray
    python engines/extract_books.py --refresh $book.Name
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host ""
Write-Host "Step 2/3: Upload verified recipes to Admin inbox ..." -ForegroundColor White
Write-Host "(Only JSON for books in inputs\books\; skips junk and duplicates)" -ForegroundColor DarkGray
python ingest_tcj.py --subdir books
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Step 3/3: Groq polish (titles, ingredients, procedure) ..." -ForegroundColor White
Write-Host "(Skips already-polished. Re-run run_admin_routine.bat if Groq limit hits.)" -ForegroundColor DarkGray
python polish_pending.py --import-path book-batch
$polishExit = $LASTEXITCODE

Write-Host ""
Write-Host "--- Inbox summary ---" -ForegroundColor Cyan
python admin_routine.py --skip-polish

if ($polishExit -ne 0) {
    Write-Host ""
    Write-Host "Some recipes need another polish pass. Later run:" -ForegroundColor Yellow
    Write-Host "  .\run_admin_routine.bat" -ForegroundColor Yellow
}

exit $polishExit
