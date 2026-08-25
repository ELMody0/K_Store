-- إضافة أعمدة التحديث التلقائي لجدول app_updates
-- شغّل ده مرة واحدة في Supabase Dashboard → SQL Editor

ALTER TABLE public.app_updates
  ADD COLUMN IF NOT EXISTS version text,
  ADD COLUMN IF NOT EXISTS apk_url text;

-- (اختياري) فهرس للبحث السريع
CREATE INDEX IF NOT EXISTS idx_app_updates_version ON public.app_updates (version);
