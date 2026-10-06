-- catat. chat AI: hitungan pesan per akun per hari (batas di edge function
-- catat-chat). Hanya fungsi itu (service role) yang menulis; user tidak bisa
-- membaca/mengubah lewat API.

create table if not exists public.chat_usage (
  user_id uuid not null references auth.users (id) on delete cascade,
  day     date not null,
  count   int  not null default 0,
  primary key (user_id, day)
);

alter table public.chat_usage enable row level security;
-- Sengaja tanpa policy: anon & authenticated tidak punya akses.

-- Tambah 1 pesan hari ini (zona waktu WIB), kembalikan jumlahnya.
create or replace function public.bump_chat_usage(p_user uuid)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  n int;
begin
  insert into public.chat_usage as c (user_id, day, count)
  values (p_user, (now() at time zone 'Asia/Jakarta')::date, 1)
  on conflict (user_id, day) do update set count = c.count + 1
  returning c.count into n;
  return n;
end;
$$;

revoke all on function public.bump_chat_usage(uuid) from public, anon, authenticated;
grant execute on function public.bump_chat_usage(uuid) to service_role;
