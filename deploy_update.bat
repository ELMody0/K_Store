@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

REM ============================================================
REM  K_Store auto-deploy script  (APK on public Supabase Storage)
REM  Usage:  deploy_update.bat 1.0.2
REM  (عدّل رسالة التحديث يدوياً في الأسفل قبل التشغيل)
REM ============================================================

REM --- رسالة التحديث (عدّلها يدوياً كل مرة) ---
set "UPDATE_TITLE=تحديث تجريبي 1.0.2"
set "UPDATE_BODY=تم إصلاح مشاكل التحميل وتحسين سرعة فتح التطبيق."

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
    echo [ERROR] Pass new version. Example: deploy_update.bat 1.0.2
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

REM رابط التحميل العام من Supabase Storage (bucket is public)
set "APK_URL=%SUPABASE_URL%/storage/v1/object/public/%SUPABASE_BUCKET%/app-release.apk"

echo [2/5] Uploading APK to Supabase Storage (public)...
curl -s -X POST "%SUPABASE_URL%/storage/v1/object/%SUPABASE_BUCKET%/app-release.apk" ^
  -H "Authorization: Bearer %SUPABASE_SERVICE_KEY%" ^
  -H "Content-Type: application/vnd.android.package-archive" ^
  -H "x-upsert: true" ^
  --data-binary "@%APK_PATH%"

echo [3/5] Publishing update message to Supabase app_updates...
REM نكتب JSON بـ UTF-8 صحيح عبر PowerShell
powershell -NoProfile -Command ^
  "$j = @{title='%UPDATE_TITLE%'; body='%UPDATE_BODY%'; version='%NEW_VER%'; apk_url='%APK_URL%'} | ConvertTo-Json -Compress; [System.IO.File]::WriteAllText('update_row.json', $j, [System.Text.Encoding]::UTF8)"

curl -s -X POST "%SUPABASE_URL%/rest/v1/app_updates" ^
  -H "Authorization: Bearer %SUPABASE_SERVICE_KEY%" ^
  -H "apikey: %SUPABASE_SERVICE_KEY%" ^
  -H "Content-Type: application/json" ^
  -H "Prefer: return=minimal" ^
  --data-binary "@update_row.json"

echo [4/5] Updating update.json on Supabase Storage...
powershell -NoProfile -Command ^
  "$j = @{version='%NEW_VER%'; apk_url='%APK_URL%'; title='K Store %TAG%'; notes='%UPDATE_BODY%'} | ConvertTo-Json -Compress; [System.IO.File]::WriteAllText('update.json', $j, [System.Text.Encoding]::UTF8)"

curl -s -X POST "%SUPABASE_URL%/storage/v1/object/%SUPABASE_BUCKET%/update.json" -H "Authorization: Bearer %SUPABASE_SERVICE_KEY%" -H "Content-Type: application/json" -H "x-upsert: true" --data-binary "@update.json"

echo [5/5] Bumping pubspec version + committing code...
REM نحدّث رقم الإصدار في pubspec.yaml عشان الفحص يقارن صح
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
