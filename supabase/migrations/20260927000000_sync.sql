-- catat. F8: sinkron local-first.
-- Tiap baris SQLite disimpan apa adanya sebagai JSON (per tabel), jadi
-- perubahan skema di app tidak butuh migrasi di sini.

create sequence if not exists public.sync_rev;

create table if not exists public.sync_rows (
  user_id    uuid        not null default auth.uid()
             references auth.users (id) on delete cascade,
  table_name text        not null,
  id         text        not null,
  data       jsonb,
  -- Waktu perubahan di HP (detik unix): yang terakhir menang.
  changed_at bigint      not null,
  deleted    boolean     not null default false,
  -- Nomor urut server, kursor tarik di HP.
  rev        bigint      not null default nextval('public.sync_rev'),
  primary key (user_id, table_name, id)
);

create index if not exists sync_rows_user_rev on public.sync_rows (user_id, rev);

alter table public.sync_rows enable row level security;

-- Izin eksplisit (project baru tidak selalu memberi otomatis). Tetap dibatasi
-- RLS: user hanya melihat & menulis barisnya sendiri.
grant usage on sequence public.sync_rev to authenticated;
grant select, insert, update on public.sync_rows to authenticated;

drop policy if exists "baris sendiri" on public.sync_rows;
create policy "baris sendiri" on public.sync_rows
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- Kirim perubahan dari HP. Hanya menimpa kalau perubahan ini tidak lebih
-- lama dari yang tersimpan.
create or replace function public.push_rows(rows jsonb)
returns void
language sql
security invoker
set search_path = ''
as $$
  insert into public.sync_rows as s (user_id, table_name, id, data, changed_at, deleted)
  select (select auth.uid()), r->>'table', r->>'id', r->'data',
         (r->>'changed_at')::bigint, coalesce((r->>'deleted')::boolean, false)
  from jsonb_array_elements(rows) r
  on conflict (user_id, table_name, id) do update
    set data = excluded.data,
        changed_at = excluded.changed_at,
        deleted = excluded.deleted,
        rev = nextval('public.sync_rev')
    where s.changed_at <= excluded.changed_at;
$$;

revoke all on function public.push_rows(jsonb) from public, anon;
grant execute on function public.push_rows(jsonb) to authenticated;

-- Hapus akun & semua data (wajib Play Store). Baris data ikut terhapus
-- lewat on delete cascade.
create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'belum masuk';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
