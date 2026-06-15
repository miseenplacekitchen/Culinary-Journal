@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_books.ps1"
exit /b %ERRORLEVEL%
