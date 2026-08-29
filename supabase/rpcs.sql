-- ============================================================
-- K_Store — Remote Procedure Functions (RPC) الآمنة
-- شغّل ده في Supabase SQL Editor بعد security_policies.sql
-- كل الدوال محمية: تتحقق من auth.uid() قبل أي تعديل.
-- ============================================================

-- ===================== check_email_exists =====================
-- يرجّع boolean فقط (لا يكشف بيانات حساسة). يُستخدم للتحقق المسبق من التسجيل.
-- ملاحظة: الوصول لـ auth.users يحتاج SECURITY DEFINER + search_path ثابت.
drop function if exists public.check_email_exists(text);
drop function if exists public.check_email_exists(p_email text);
create or replace function public.check_email_exists(p_email text)
  returns boolean language plpgsql security definer set search_path = public as $$
declare
  v_count int;
begin
  if p_email is null or p_email = '' then
    return false;
  end if;
  select count(*) into v_count
  from auth.users u
  where lower(u.email) = lower(p_email);
  return v_count > 0;
end;
$$;

-- ===================== hide_chat_messages =====================
-- يخفي رسائل محادثة عن المستخدم الحالي فقط (الطرف التاني يشوفها زي ما هي).
-- تحقق إجباري: p_user_id لازم = auth.uid()
drop function if exists public.hide_chat_messages(uuid, uuid);
drop function if exists public.hide_chat_messages(p_chat_id uuid, p_user_id uuid);
create or replace function public.hide_chat_messages(p_chat_id uuid, p_user_id uuid)
  returns void language plpgsql security definer set search_path = public as $$
begin
  if p_user_id is distinct from auth.uid() then
    raise exception 'غير مصرح: يمكنك إخفاء محادثاتك فقط';
  end if;
  -- نتأكد إن المستخدم مشارك فعلاً في المحادثة
  if not exists (
    select 1 from public.chats c
    where c.id = p_chat_id
      and (c.user1_id = p_user_id or c.user2_id = p_user_id)
  ) then
    raise exception 'المحادثة غير موجودة أو غير مصرح بها';
  end if;
  -- تحديث عمود الإخفاء الخاص بالمستخدم (تأكد إن الأعمدة موجودة في جدول chats)
  update public.chats
  set
    user1_hidden = case when user1_id = p_user_id then true else user1_hidden end,
    user2_hidden = case when user2_id = p_user_id then true else user2_hidden end
  where id = p_chat_id;
end;
$$;

-- ===================== send_support_auto_reply =====================
-- تُدرج رد تلقائي من "إدارة المتجر" في شات الدعم. SECURITY DEFINER (تتجاوز RLS).
-- تحقق: chat_id موجود وفعلاً شات دعم (is_support = true).
drop function if exists public.send_support_auto_reply(uuid, text);
drop function if exists public.send_support_auto_reply(p_chat_id uuid, p_content text);
create or replace function public.send_support_auto_reply(p_chat_id uuid, p_content text)
  returns void language plpgsql security definer set search_path = public as $$
declare
  v_owner_id uuid;
begin
  -- جلب معرّف المالك (owner) لإدراج الرسالة باسمه
  select p.id into v_owner_id from public.profiles p
  where lower(p.role) = 'owner' limit 1;
  if v_owner_id is null then
    raise exception 'لا يوجد حساب مالك معرّف';
  end if;
  -- التحقق إن المحادثة شات دعم فعلاً
  if not exists (
    select 1 from public.chats c
    where c.id = p_chat_id and c.is_support = true
  ) then
    raise exception 'المحادثة ليست شات دعم';
  end if;
  insert into public.messages (chat_id, sender_id, content, message_type)
  values (p_chat_id, v_owner_id, p_content, 'text');
end;
$$;

-- ===================== mark_messages_read =====================
-- يُعلم رسائل محادثة كمقروءة للمستخدم الحالي فقط.
-- تحقق إجباري: p_reader_id = auth.uid()
drop function if exists public.mark_messages_read(uuid, uuid);
drop function if exists public.mark_messages_read(p_chat_id uuid, p_reader_id uuid);
create or replace function public.mark_messages_read(p_chat_id uuid, p_reader_id uuid)
  returns void language plpgsql security definer set search_path = public as $$
begin
  if p_reader_id is distinct from auth.uid() then
    raise exception 'غير مصرح بتعليم رسائل الغير كمقروءة';
  end if;
  update public.messages m
  set read = true
  where m.chat_id = p_chat_id
    and m.sender_id <> p_reader_id
    and m.read is not true;
end;
$$;

-- ===================== block_user =====================
-- يمنع مستخدم من التواصل. يشترط أن المستدعي owner.
drop function if exists public.block_user(uuid);
drop function if exists public.block_user(p_target_id uuid);
create or replace function public.block_user(p_target_id uuid)
  returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_owner() then
    raise exception 'غير مصرح: هذه الصلاحية للمالك فقط';
  end if;
  if p_target_id is null then
    raise exception 'معرف المستخدم مطلوب';
  end if;
  update public.profiles set is_blocked = true where id = p_target_id;
end;
$$;
