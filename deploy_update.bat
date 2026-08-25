@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

REM ============================================================
REM  K_Store auto-deploy script
REM  Usage: deploy_update.bat 1.0.1
REM ============================================================

REM --- load .env ---
for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
    if /i "%%A"=="GITHUB_TOKEN" set "GITHUB_TOKEN=%%B"
    if /i "%%A"=="GITHUB_OWNER" set "GITHUB_OWNER=%%B"
    if /i "%%A"=="GITHUB_REPO" set "GITHUB_REPO=%%B"
    if /i "%%A"=="SUPABASE_URL" set "SUPABASE_URL=%%B"
    if /i "%%A"=="SUPABASE_SERVICE_KEY" set "SUPABASE_SERVICE_KEY=%%B"
    if /i "%%A"=="SUPABASE_BUCKET" set "SUPABASE_BUCKET=%%B"
)

if "%~1"=="" (
    echo [ERROR] Pass new version. Example: deploy_update.bat 1.0.1
    pause
    exit /b 1
)
set "NEW_VER=%~1"
set "TAG=v%NEW_VER%"
set "APK_PATH=build\app\outputs\flutter-apk\app-release.apk"

echo ============================================================
echo   Deploying K_Store %NEW_VER%
echo ============================================================

echo [1/4] Building APK...
call flutter build apk --release
if not exist "%APK_PATH%" (
    echo [ERROR] APK not built.
    pause
    exit /b 1
)

echo [2/4] Creating GitHub release %TAG%...
curl -s -X POST -H "Authorization: Bearer %GITHUB_TOKEN%" -H "Accept: application/vnd.github+json" "https://api.github.com/repos/%GITHUB_OWNER%/%GITHUB_REPO%/releases" -d "{\"tag_name\":\"%TAG%\"}" > release.json

for /f "tokens=*" %%L in ('powershell -NoProfile -Command "(Get-Content release.json | ConvertFrom-Json).id"') do set "REL_ID=%%L"
echo     Release ID: %REL_ID%

curl -s -X POST -H "Authorization: Bearer %GITHUB_TOKEN%" -H "Content-Type: application/vnd.android.package-archive" --data-binary "@%APK_PATH%" "https://uploads.github.com/repos/%GITHUB_OWNER%/%GITHUB_REPO%/releases/%REL_ID%/assets?name=app-release.apk"

set "APK_URL=https://github.com/%GITHUB_OWNER%/%GITHUB_REPO%/releases/download/%TAG%/app-release.apk"

echo [3/4] Updating update.json on Supabase...
echo { > update.json
echo   "version": "%NEW_VER%", >> update.json
echo   "apk_url": "%APK_URL%", >> update.json
echo   "title": "K Store %TAG%", >> update.json
echo   "notes": "New update available" >> update.json
echo } >> update.json

curl -s -X POST "%SUPABASE_URL%/storage/v1/object/%SUPABASE_BUCKET%/update.json" -H "Authorization: Bearer %SUPABASE_SERVICE_KEY%" -H "Content-Type: application/json" -H "x-upsert: true" --data-binary "@update.json"

echo [4/4] Committing code...
git add .
git -c user.name="%GITHUB_OWNER%" -c user.email="%GITHUB_OWNER%@users.noreply.github.com" commit -m "Release %TAG%"
git push origin main

echo ============================================================
echo   DONE! %NEW_VER% is live.
echo   APK: %APK_URL%
echo ============================================================
pause
