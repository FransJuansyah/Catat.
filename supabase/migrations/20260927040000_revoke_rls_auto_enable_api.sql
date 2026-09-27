-- Fungsi event trigger bawaan Supabase (auto RLS) tidak perlu bisa dipanggil
-- lewat API (/rest/v1/rpc). Event trigger tetap jalan.
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
