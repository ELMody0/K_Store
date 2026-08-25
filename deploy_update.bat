@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

REM ============================================================
REM  K_Store auto-deploy script  (APK on GitHub Releases, public repo)
REM  Usage:  deploy_update.bat 1.0.3
REM  (عدّل رسالة التحديث يدوياً في الأسفل قبل التشغيل)
REM ============================================================

REM --- رسالة التحديث (عدّلها يدوياً كل مرة) ---
set "UPDATE_TITLE=تحديث 1.0.3"
set "UPDATE_BODY=تحسينات في الأداء وإصلاحات عامة لتجربة أفضل."

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
    echo [ERROR] Pass new version. Example: deploy_update.bat 1.0.3
    pause
    exit /b 1
)
set "NEW_VER=%~1"
set "TAG=v%NEW_VER%"
set "APK_PATH=build\app\outputs\flutter-apk\app-release.apk"

echo ============================================================
echo   Deploying K_Store %NEW_VER%
echo ============================================================

echo [1/5] Building APK...
call flutter build apk --release
if not exist "%APK_PATH%" (
    echo [ERROR] APK not built.
    pause
    exit /b 1
)

REM رابط التحميل من GitHub Releases (repo must be Public for direct download)
set "APK_URL=https://github.com/%GITHUB_OWNER%/%GITHUB_REPO%/releases/download/%TAG%/app-release.apk"

echo [2/5] Creating GitHub release %TAG%...
REM لو الـ release موجود من قبل، نمسحه عشان نعيد إنشاؤه نظيف
curl -s -o /dev/null -w "%%{http_code}" -H "Authorization: Bearer %GITHUB_TOKEN%" "https://api.github.com/repos/%GITHUB_OWNER%/%GITHUB_REPO%/releases/tags/%TAG%" > existing_rel.json
set /p EXISTING_ID=<existing_rel.json
REM (نسيب EXISTING_ID كـ JSON مؤقت - هنمسحه لو موجود)
powershell -NoProfile -Command "$j=Get-Content existing_rel.json -Raw; if($j -match '\"id\":\s*(\d+)'){ $id=$matches[1]; Invoke-RestMethod -Method Delete -Uri 'https://api.github.com/repos/%GITHUB_OWNER%/%GITHUB_REPO%/releases/'+$id -Headers @{'Authorization'='Bearer %GITHUB_TOKEN%'} | Out-Null; Write-Host ('Deleted existing release '+ $id) }"

curl -s -X POST -H "Authorization: Bearer %GITHUB_TOKEN%" -H "Accept: application/vnd.github+json" "https://api.github.com/repos/%GITHUB_OWNER%/%GITHUB_REPO%/releases" -d "{\"tag_name\":\"%TAG%\"}" > release.json

for /f "tokens=*" %%L in ('powershell -NoProfile -Command "(Get-Content release.json | ConvertFrom-Json).id"') do set "REL_ID=%%L"
echo     Release ID: %REL_ID%

curl -s -X POST -H "Authorization: Bearer %GITHUB_TOKEN%" -H "Content-Type: application/vnd.android.package-archive" --data-binary "@%APK_PATH%" "https://uploads.github.com/repos/%GITHUB_OWNER%/%GITHUB_REPO%/releases/%REL_ID%/assets?name=app-release.apk"

echo [3/5] Publishing update message to Supabase app_updates...
powershell -NoProfile -ExecutionPolicy Bypass -File build_json.ps1 -title "%UPDATE_TITLE%" -body "%UPDATE_BODY%" -version "%NEW_VER%" -apkUrl "%APK_URL%"
REM نتأكد إن الملف اتكتب قبل ما نبعته
if not exist "update_row.json" (
  echo [ERROR] update_row.json not created.
  pause
  exit /b 1
)
timeout /t 1 >nul

curl -s -X POST "%SUPABASE_URL%/rest/v1/app_updates" ^
  -H "Authorization: Bearer %SUPABASE_SERVICE_KEY%" ^
  -H "apikey: %SUPABASE_SERVICE_KEY%" ^
  -H "Content-Type: application/json" ^
  -H "Prefer: return=minimal" ^
  --data-binary "@update_row.json"

echo [4/5] Updating update.json on Supabase Storage...
REM (update.json already written by build_json.ps1 above)

echo [5/5] Bumping pubspec version + committing code...
powershell -NoProfile -Command ^
  "$f='pubspec.yaml'; $c=[System.IO.File]::ReadAllText($f, [System.Text.Encoding]::UTF8); $c=$c -replace 'version:\s*\d+\.\d+\.\d+\+\d+', 'version: %NEW_VER%+1'; [System.IO.File]::WriteAllText($f, $c, [System.Text.Encoding]::UTF8)"

git add .
git -c user.name="%GITHUB_OWNER%" -c user.email="%GITHUB_OWNER%@users.noreply.github.com" commit -m "Release %TAG%"
git push origin main

echo ============================================================
echo   DONE! %NEW_VER% is live.
echo   APK: %APK_URL%
echo ============================================================
pause
