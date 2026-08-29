-- ============================================================
-- K_Store — Row Level Security (RLS) Policies
-- شغّل السكربت ده في Supabase SQL Editor (أو عبر supabase db push).
-- مهم: مفتاح الـ anon عام بالطبيعة، وكل الحماية الحقيقية ضد الاختراق
-- لازم تكون هنا (RLS) لأن أي حد عنده المفتاح يقدر يستدعي PostgREST مباشرة.
-- السكربت idempotent (بيdrop ويأعيد إنشاء السياسات).
-- ============================================================

-- دالة مساعدة: هل المستخدم الحالي مالك (owner)؟
-- SECURITY DEFINER عشان تشوف الرتبة الحقيقية بدون recursion في RLS.
create or replace function public.is_owner() returns boolean
  language sql security definer
  set search_path = public
  as $$
    select exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and lower(p.role) = 'owner'
    );
  $$;

-- ===================== profiles =====================
alter table public.profiles enable row level security;

drop policy if exists "profiles_select_auth" on public.profiles;
create policy "profiles_select_auth" on public.profiles
  for select using (auth.uid() is not null);

drop policy if exists "profiles_update_self_or_owner" on public.profiles;
create policy "profiles_update_self_or_owner" on public.profiles
  for update using (auth.uid() = id or public.is_owner())
  with check (auth.uid() = id or public.is_owner());

-- منع رفع الصلاحيات: المستخدم العادي مش يقدر يغيّر role / is_verified
create or replace function public.prevent_profile_escalation()
  returns trigger language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner() then
    if coalesce(new.role, '') <> coalesce(old.role, '') then
      raise exception 'غير مصرح بتغيير الرتبة';
    end if;
    if coalesce(new.is_verified, false) <> coalesce(old.is_verified, false) then
      raise exception 'غير مصرح بتغيير التوثيق';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_profile_escalation on public.profiles;
create trigger trg_profile_escalation before update on public.profiles
  for each row execute function public.prevent_profile_escalation();

-- ===================== categories =====================
alter table public.categories enable row level security;

drop policy if exists "categories_select_public" on public.categories;
create policy "categories_select_public" on public.categories
  for select using (true);

drop policy if exists "categories_write_owner" on public.categories;
create policy "categories_write_owner" on public.categories
  for all using (public.is_owner()) with check (public.is_owner());

-- ===================== products =====================
alter table public.products enable row level security;

drop policy if exists "products_select_public" on public.products;
create policy "products_select_public" on public.products
  for select using (true);

drop policy if exists "products_insert_owner_user" on public.products;
create policy "products_insert_owner_user" on public.products
  for insert with check (auth.uid() = user_id and auth.uid() is not null);

drop policy if exists "products_update_owner_user" on public.products;
create policy "products_update_owner_user" on public.products
  for update using (auth.uid() = user_id or public.is_owner())
  with check (auth.uid() = user_id or public.is_owner());

drop policy if exists "products_delete_owner_user" on public.products;
create policy "products_delete_owner_user" on public.products
  for delete using (auth.uid() = user_id or public.is_owner());

-- ===================== chats =====================
alter table public.chats enable row level security;

drop policy if exists "chats_select_participant" on public.chats;
create policy "chats_select_participant" on public.chats
  for select using (auth.uid() = user1_id or auth.uid() = user2_id or public.is_owner());

drop policy if exists "chats_insert_participant" on public.chats;
create policy "chats_insert_participant" on public.chats
  for insert with check (auth.uid() = user1_id or auth.uid() = user2_id or public.is_owner());

drop policy if exists "chats_update_participant" on public.chats;
create policy "chats_update_participant" on public.chats
  for update using (auth.uid() = user1_id or auth.uid() = user2_id or public.is_owner())
  with check (auth.uid() = user1_id or auth.uid() = user2_id or public.is_owner());

drop policy if exists "chats_delete_owner" on public.chats;
create policy "chats_delete_owner" on public.chats
  for delete using (public.is_owner());

-- ===================== messages =====================
alter table public.messages enable row level security;

drop policy if exists "messages_select_participant" on public.messages;
create policy "messages_select_participant" on public.messages
  for select using (
    exists (
      select 1 from public.chats c
      where c.id = messages.chat_id
        and (c.user1_id = auth.uid() or c.user2_id = auth.uid() or public.is_owner())
    )
  );

drop policy if exists "messages_insert_sender" on public.messages;
create policy "messages_insert_sender" on public.messages
  for insert with check (
    auth.uid() = sender_id and auth.uid() is not null
    and exists (
      select 1 from public.chats c
      where c.id = chat_id
        and (c.user1_id = auth.uid() or c.user2_id = auth.uid() or public.is_owner())
    )
  );

drop policy if exists "messages_update_participant" on public.messages;
create policy "messages_update_participant" on public.messages
  for update using (
    exists (
      select 1 from public.chats c
      where c.id = messages.chat_id
        and (c.user1_id = auth.uid() or c.user2_id = auth.uid() or public.is_owner())
    )
  ) with check (
    exists (
      select 1 from public.chats c
      where c.id = messages.chat_id
        and (c.user1_id = auth.uid() or c.user2_id = auth.uid() or public.is_owner())
    )
  );

drop policy if exists "messages_delete_sender_or_owner" on public.messages;
create policy "messages_delete_sender_or_owner" on public.messages
  for delete using (auth.uid() = sender_id or public.is_owner());

-- ===================== comments =====================
alter table public.comments enable row level security;

drop policy if exists "comments_select_auth" on public.comments;
create policy "comments_select_auth" on public.comments
  for select using (auth.uid() is not null);

drop policy if exists "comments_insert_user" on public.comments;
create policy "comments_insert_user" on public.comments
  for insert with check (auth.uid() = user_id and auth.uid() is not null);

drop policy if exists "comments_update_user" on public.comments;
create policy "comments_update_user" on public.comments
  for update using (auth.uid() = user_id or public.is_owner())
  with check (auth.uid() = user_id or public.is_owner());

drop policy if exists "comments_delete_user" on public.comments;
create policy "comments_delete_user" on public.comments
  for delete using (auth.uid() = user_id or public.is_owner());

-- ===================== reports =====================
alter table public.reports enable row level security;

drop policy if exists "reports_select_owner" on public.reports;
create policy "reports_select_owner" on public.reports
  for select using (public.is_owner());

drop policy if exists "reports_insert_reporter" on public.reports;
create policy "reports_insert_reporter" on public.reports
  for insert with check (auth.uid() = reporter_id and auth.uid() is not null);

drop policy if exists "reports_update_owner" on public.reports;
create policy "reports_update_owner" on public.reports
  for update using (public.is_owner()) with check (public.is_owner());

drop policy if exists "reports_delete_owner" on public.reports;
create policy "reports_delete_owner" on public.reports
  for delete using (public.is_owner());

-- ===================== app_updates =====================
alter table public.app_updates enable row level security;

drop policy if exists "app_updates_select" on public.app_updates;
create policy "app_updates_select" on public.app_updates
  for select using (auth.uid() is not null);

drop policy if exists "app_updates_owner_write" on public.app_updates;
create policy "app_updates_owner_write" on public.app_updates
  for all using (public.is_owner()) with check (public.is_owner());

-- ===================== push_tokens =====================
alter table public.push_tokens enable row level security;

drop policy if exists "push_tokens_select_self" on public.push_tokens;
create policy "push_tokens_select_self" on public.push_tokens
  for select using (auth.uid() = user_id);

drop policy if exists "push_tokens_upsert_self" on public.push_tokens;
create policy "push_tokens_upsert_self" on public.push_tokens
  for insert with check (auth.uid() = user_id);

drop policy if exists "push_tokens_update_self" on public.push_tokens;
create policy "push_tokens_update_self" on public.push_tokens
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "push_tokens_delete_self" on public.push_tokens;
create policy "push_tokens_delete_self" on public.push_tokens
  for delete using (auth.uid() = user_id);

-- ============================================================
-- ملاحظات إجبارية على Edge Functions / RPCs (لازم تتأكد منها في الكود بتاعها):
-- 1) send-push: تحقق إن auth.uid() هو صاحب المنتج (للبث broadcast) أو مشارك في chat_id (للرسايل).
-- 2) mark_messages_read: تحقق إن p_reader_id = auth.uid() (تمنع تعليم رسايل حد تاني كمقروءة).
-- 3) hide_chat_messages: تحقق إن p_user_id = auth.uid().
-- 4) block_user: تحقق إن المستدعي owner.
-- 5) send_support_auto_reply: SECURITY DEFINER يُدرج كأدمن — تمام، بس تأكد إن chat_id موجود فعلاً.
-- 6) check_email_exists: يرجّع boolean بس (لا يكشف بيانات حساسة).
-- ============================================================
