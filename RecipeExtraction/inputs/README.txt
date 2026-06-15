================================================================================
THE CULINARY JOURNAL — RECIPE INPUT FOLDER (Betty)
================================================================================

Everything YOU provide goes in this "inputs" folder.
You do not edit files in MyCookbook/, engines/, or the root of RecipeExtraction.

After you add files here, run ONE command from RecipeExtraction:

  Books only:     .\run_books.bat          (extract + upload + polish)
  All 7 sources:  .\run_pipeline.bat       (same, all sources)
  Catch-up polish: .\run_admin_routine.bat (weekly or if Groq limit hit)

  Full routine guide:  open ROUTINE.txt in RecipeExtraction
  SQL guide:           open database/WHATS-WHAT.md


================================================================================
FOLDER MAP — WHAT GOES WHERE
================================================================================

  inputs/
    books/                          Your PDF cookbooks and typed notes
    videos/                         Downloaded cooking video files
    word_docs/                      Word (.docx) cookbooks
    urls/
      websites.txt                  Website addresses to scrape for recipes
      instagram.txt                 Individual Instagram reel/post links
      youtube.txt                   YouTube video or channel links
    instagram/
      saved_reels/
        saved_collections.json      Export of your Instagram Saved Collection


================================================================================
1. BOOKS  (inputs/books/)
================================================================================

WHAT TO DROP HERE
  - PDF cookbooks (e.g. "60 Ways Rice - Marshall Cavendish.pdf")
  - Typed recipe notes (.txt or .md)
  - Optional: .docx if you prefer not to use word_docs/

SUPPORTED FORMATS
  .pdf   .txt   .md   .docx

HOW IT WORKS
  - Marshall Cavendish / "In 60 Ways" style books (Serves / Ingredients /
    Method layout) are detected automatically.
  - Other PDF layouts may need extra tuning — only verified recipes upload.
  - Re-running is safe: already-processed books are skipped.

COMMAND
  .\run_books.bat
  (Extract → upload → Groq polish — all in one command)

IF GROQ LIMIT HIT
  .\run_admin_routine.bat

OUTPUT
  MyCookbook/books/   (JSON files — you do not need to open these)


================================================================================
2. WORD COOKBOOK  (inputs/word_docs/)
================================================================================

WHAT TO DROP HERE
  - Your main Word cookbook file(s)

SUPPORTED FORMATS
  .docx   .txt   .md

COMMAND
  .\run_pipeline.ps1 --source word


================================================================================
3. DOWNLOADED VIDEOS  (inputs/videos/)
================================================================================

WHAT TO DROP HERE
  - Cooking videos you saved to your computer (not Instagram links)

SUPPORTED FORMATS
  .mp4   .mkv   .mov   .webm   .m4v   .mp3   .m4a   .wav

REQUIRES
  GROQ_API_KEY in setup-env.ps1 (for speech transcription)

COMMAND
  .\run_pipeline.ps1 --source videos


================================================================================
4. WEBSITES  (inputs/urls/websites.txt)
================================================================================

WHAT THIS IS
  A list of chef/recipe websites. The pipeline discovers recipe pages and
  extracts them (curryworld, Taste.com.au, etc.).

HOW TO EDIT
  1. Open websites.txt in Notepad
  2. One website URL per line
  3. Lines starting with # are ignored
  4. Save

EXAMPLE
  https://curryworld.me
  https://www.taste.com.au/

COMMAND
  .\run_pipeline.ps1 --source websites

NOTES
  - Admin can turn sites OFF in Dashboard → Website sources
  - Re-runs only fetch NEW recipes (duplicates skipped)


================================================================================
5. INSTAGRAM SAVED COLLECTION (REELS YOU SAVED)  (inputs/instagram/saved_reels/)
================================================================================

WHAT THIS IS
  When you save cooking reels on Instagram into a Collection, this export
  file lists all those saved links. The pipeline downloads audio, transcribes
  with Groq, and turns them into recipes.

WHERE TO PUT THE FILE
  Save/export AS exactly:

    inputs/instagram/saved_reels/saved_collections.json

  (Replace the old file when you export a fresh copy from Instagram.)

HOW TO GET saved_collections.json
  Use the same export method you used before (Instagram data export or your
  saved-collection JSON export tool). The file must be JSON containing your
  saved reel/post URLs.

  If you are unsure: keep your last working export file and copy it to:
    RecipeExtraction\inputs\instagram\saved_reels\saved_collections.json

REQUIRES
  GROQ_API_KEY in setup-env.ps1

COMMAND
  .\run_pipeline.ps1 --source reels

OUTPUT
  MyCookbook/reels/*.md  then uploaded to your site inbox


================================================================================
6. INSTAGRAM INDIVIDUAL LINKS  (inputs/urls/instagram.txt)
================================================================================

WHAT THIS IS
  For one-off Instagram reel/post URLs (NOT the full Saved Collection export).

HOW TO EDIT
  1. Open instagram.txt in Notepad
  2. Paste one full reel URL per line, e.g.:
       https://www.instagram.com/reel/ABC123xyz/
  3. Use individual post/reel links — not just a profile homepage
  4. Save

REQUIRES
  GROQ_API_KEY in setup-env.ps1

COMMAND
  .\run_pipeline.ps1 --source instagram_profiles


================================================================================
7. YOUTUBE  (inputs/urls/youtube.txt)
================================================================================

WHAT TO ADD
  One YouTube video or channel URL per line in youtube.txt

REQUIRES
  GROQ_API_KEY in setup-env.ps1

COMMAND
  .\run_pipeline.ps1 --source youtube


================================================================================
QUICK REFERENCE — WHICH COMMAND FOR WHAT
================================================================================

  Books (PDFs in inputs/books/)     →  .\run_books.bat
  Everything / all sources          →  .\run_pipeline.ps1
  Websites only                     →  .\run_pipeline.ps1 --source websites
  Instagram Saved Collection        →  .\run_pipeline.ps1 --source reels
  Instagram single URLs             →  .\run_pipeline.ps1 --source instagram_profiles
  YouTube                           →  .\run_pipeline.ps1 --source youtube
  Videos in inputs/videos/          →  .\run_pipeline.ps1 --source videos
  Word docs                         →  .\run_pipeline.ps1 --source word


================================================================================
TIPS
================================================================================

  - Drop files in batches (10, 50, 100 books) — same commands each time.
  - Already-processed items are skipped automatically.
  - You never paste keys into this folder — keys live in setup-env.ps1 only.
  - If a book extracts badly, tell support which book title — layout can be
    improved without you changing your workflow.

================================================================================
