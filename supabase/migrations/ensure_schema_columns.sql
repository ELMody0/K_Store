-- ============================================================
-- K_Store — التأكد من وجود الأعمدة المطلوبة (آمن للتكرار)
-- شغّل ده في Supabase SQL Editor. كل أمر IF NOT EXISTS فمش هيكسر حاجة لو موجودة.
-- ============================================================

-- جدول chats: أعمدة الإخفاء والدعم وآخر رسالة
alter table public.chats add column if not exists user1_hidden boolean not null default false;
alter table public.chats add column if not exists user2_hidden boolean not null default false;
alter table public.chats add column if not exists is_support boolean not null default false;
alter table public.chats add column if not exists last_message_at timestamptz;

-- جدول messages: حالة القراءة ونوع الرسالة
alter table public.messages add column if not exists read boolean not null default false;
alter table public.messages add column if not exists message_type text not null default 'text';
alter table public.messages add column if not exists reply_to uuid;
alter table public.messages add column if not exists product_id uuid;
alter table public.messages add column if not exists file_url text;
alter table public.messages add column if not exists duration int;

-- جدول profiles: حالة الحظر + إشعارات
alter table public.profiles add column if not exists is_blocked boolean not null default false;
alter table public.profiles add column if not exists message_notifications boolean not null default true;

-- فهارس للأداء
create index if not exists idx_chats_user1 on public.chats (user1_id);
create index if not exists idx_chats_user2 on public.chats (user2_id);
create index if not exists idx_messages_chat on public.messages (chat_id);
create index if not exists idx_messages_sender on public.messages (sender_id);
