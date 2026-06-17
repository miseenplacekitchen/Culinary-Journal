# Betty — run books: extract → upload (NO Groq — you review in admin)

Set-Location $PSScriptRoot

if (Test-Path "setup-env.ps1") {
    . .\setup-env.ps1
} else {
    Write-Host ""
    Write-Host "First time only: copy setup-env.example.ps1 to setup-env.ps1" -ForegroundColor Yellow
    Write-Host "Open setup-env.ps1 in Notepad, paste Supabase keys + TCJ_INGEST_USER_ID, save." -ForegroundColor Yellow
    Write-Host "(GROQ_API_KEY not needed for books.)" -ForegroundColor DarkGray
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "=== TCJ Books ===" -ForegroundColor Cyan
Write-Host "Step 0/3: Clean stale book data (keep inputs\books\ only) ..." -ForegroundColor White
python clean_book_workspace.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
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
Write-Host "(Only JSON for books in inputs\books\; no Groq — review in admin)" -ForegroundColor DarkGray
python ingest_tcj.py --subdir books
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "--- Inbox summary ---" -ForegroundColor Cyan
python admin_routine.py --skip-polish

exit 0
