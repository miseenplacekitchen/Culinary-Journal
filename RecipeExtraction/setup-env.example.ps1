# Copy this file to setup-env.ps1 and fill in your secrets.
# setup-env.ps1 is gitignored — never commit it.
#
# Where to find each value:
#   SUPABASE_URL              — already filled below (your TCJ project)
#   SUPABASE_SERVICE_ROLE_KEY — Supabase → Project Settings → API → service_role
#   TCJ_INGEST_USER_ID        — Supabase → Authentication → Users → your UUID
#   GROQ_API_KEY              — optional; Instagram/reels only (NOT needed for books)

$env:SUPABASE_URL = "https://kzywmodvfbyexqgipcjt.supabase.co"
$env:SUPABASE_SERVICE_ROLE_KEY = "PASTE_SERVICE_ROLE_KEY_HERE"
$env:TCJ_INGEST_USER_ID = "PASTE_YOUR_USER_UUID_HERE"
$env:GROQ_API_KEY = "PASTE_GROQ_KEY_HERE"

Write-Host "TCJ secrets loaded from setup-env.ps1" -ForegroundColor Green
