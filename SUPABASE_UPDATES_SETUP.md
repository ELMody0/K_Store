# خطوات تجهيز Supabase Storage لقناة التحديثات

## 1) اعمل Bucket عام اسمه `updates`
في لوحة Supabase: Storage ← New bucket ← الاسم: `updates` ← ✅ Public (عام)

## 2) اضبط الـ Policy (صلاحيات القراءة العامة)
Storage ← Bucket `updates` ← Policies ← New Policy ←
- اختار "For full customization"
- الاسم: `Public Read Updates`
- Allowed operation: `SELECT`
- Target roles: `public`
- Using expression: `bucket_id = 'updates'`
- وافق (Apply)

(لو بتستخدم SQL Editor بدل الواجهة، نفّذ:)
```sql
create policy "Public Read Updates"
on storage.objects for select
to public
using ( bucket_id = 'updates' );
```

## 3) ارفع الملفات على الـ Bucket
ارفع داخل Bucket `updates`:
- `update.json`  (الملف ده موجود أصلاً في جذر المشروع: update.json)
- `app-release.apk` (هتبنيه من: flutter build apk --release → build/app/outputs/flutter-apk/app-release.apk)

تأكد إن الأسماء بالظبط:
- update.json
- app-release.apk
(لازم تطابق الحقول في update.json: apk_path = "app-release.apk")

## 4) كل ما عايز تنشر تحديث جديد:
1. ابني APK جديد: `flutter build apk --release`
2. ارفع الـ APK الجديد على نفس المسار `app-release.apk` (يستبدل القديم)
3. عدّل `update.json`: غير "version" لرقم أعلى (مثلاً "1.0.1") + حدّث "notes"
4. احفظ

الناس هتفتح صفحة "تحديثات التطبيق" → يظهر البانر → تدوس → تتحمّل النسخة الجديدة.

## ملاحظة:
الكود بيقارن version المكتوب في update.json برقم version الموجود في pubspec.yaml
(الحالي عندك: 1.0.0+1). عشان البانر يظهر، لازم تكتب في update.json رقم أعلى من 1.0.0.
