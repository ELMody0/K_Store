@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

REM ============================================================
REM  سكريبت نشر تحديث تلقائي لـ K_Store
REM  الاستخدام: deploy_update.bat 1.0.1
REM  (الإصدار الجديد لازم أعلى من الحالي)
REM ============================================================

REM --- قراءة المتغيرات من ملف .env ---
for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
    set "line=%%A=%%B"
    if /i "%%A"=="GITHUB_TOKEN" set "GITHUB_TOKEN=%%B"
    if /i "%%A"=="GITHUB_OWNER" set "GITHUB_OWNER=%%B"
    if /i "%%A"=="GITHUB_REPO" set "GITHUB_REPO=%%B"
    if /i "%%A"=="SUPABASE_URL" set "SUPABASE_URL=%%B"
    if /i "%%A"=="SUPABASE_SERVICE_KEY" set "SUPABASE_SERVICE_KEY=%%B"
    if /i "%%A"=="SUPABASE_BUCKET" set "SUPABASE_BUCKET=%%B"
)

REM --- التحقق من المدخلات ---
if "%~1"=="" (
    echo [خطأ] لازم تكتب رقم الإصدار الجديد. مثال:
    echo        deploy_update.bat 1.0.1
    exit /b 1
)
set "NEW_VER=%~1"
set "TAG=v%NEW_VER%"
set "APK_PATH=build\app\outputs\flutter-apk\app-release.apk"

echo ============================================================
echo   نشر تحديث K_Store - الإصدار %NEW_VER%
echo ============================================================

REM --- 1) بناء الـ APK ---
echo [1/4] جاري بناء الـ APK...
call flutter build apk --release
if not exist "%APK_PATH%" (
    echo [خطأ] الـ APK مش اتبنى. تأكد من flutter.
    exit /b 1
)

REM --- 2) رفع الـ APK على GitHub Release ---
echo [2/4] رفع الـ APK على GitHub Release (%TAG%)...
curl -s -X POST ^
  -H "Authorization: Bearer %GITHUB_TOKEN%" ^
  -H "Accept: application/vnd.github+json" ^
  "https://api.github.com/repos/%GITHUB_OWNER%/%GITHUB_REPO%/releases" ^
  -d "{\"tag_name\":\"%TAG%\",\"name\":\"K Store %TAG%\",\"body\":\"تحديث تلقائي عبر deploy script\"}" > release.json

REM استخراج release id و upload_url من الرد
for /f "tokens=*" %%L in ('powershell -NoProfile -Command "(Get-Content release.json | ConvertFrom-Json).id"') do set "REL_ID=%%L"
echo     Release ID: %REL_ID%

curl -s -X POST ^
  -H "Authorization: Bearer %GITHUB_TOKEN%" ^
  -H "Content-Type: application/vnd.android.package-archive" ^
  --data-binary @"%APK_PATH%" ^
  "https://uploads.github.com/repos/%GITHUB_OWNER%/%GITHUB_REPO%/releases/%REL_ID%/assets?name=app-release.apk"

set "APK_URL=https://github.com/%GITHUB_OWNER%/%GITHUB_REPO%/releases/download/%TAG%/app-release.apk"

REM --- 3) تحديث update.json على Supabase ---
echo [3/4] تحديث update.json على Supabase...
(
echo {
echo   "version": "%NEW_VER%",
echo   "apk_url": "%APK_URL%",
echo   "title": "K Store %TAG%",
echo   "notes": "تحديث جديد متاح"
echo }
) > update.json

curl -s -X POST "%SUPABASE_URL%/storage/v1/object/%SUPABASE_BUCKET%/update.json" ^
  -H "Authorization: Bearer %SUPABASE_SERVICE_KEY%" ^
  -H "Content-Type: application/json" ^
  -H "x-upsert: true" ^
  --data-binary @update.json

REM --- 4) commit + push للكود ---
echo [4/4] حفظ التغييرات على GitHub...
git add .
git -c user.name="%GITHUB_OWNER%" -c user.email="%GITHUB_OWNER%@users.noreply.github.com" commit -m "Release %TAG%"
git push origin main

echo ============================================================
echo   تم النشر! الإصدار %NEW_VER% متاح للتحميل.
echo   رابط الـ APK: %APK_URL%
echo ============================================================
pause
