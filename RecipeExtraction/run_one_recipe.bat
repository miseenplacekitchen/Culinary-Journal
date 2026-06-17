@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_one_recipe.ps1"
exit /b %ERRORLEVEL%
