begin;
-- Narrow exception to server-only writes: owners may edit non-privileged profile fields.
-- Ownership, archival state and internal IDs cannot be changed by browser clients.
grant insert(auth_user_id,full_name,handle,network_visibility) on public.profiles to authenticated;
grant update(full_name,handle,network_visibility) on public.profiles to authenticated;
create policy insert_own_registered_profile on public.profiles for insert to authenticated
with check(auth_user_id=(select auth.uid()) and ((select auth.jwt())->>'is_anonymous')::boolean is false);
create policy update_own_registered_profile on public.profiles for update to authenticated
using(auth_user_id=(select auth.uid()) and archived_at is null and ((select auth.jwt())->>'is_anonymous')::boolean is false)
with check(auth_user_id=(select auth.uid()) and archived_at is null and ((select auth.jwt())->>'is_anonymous')::boolean is false);
-- Whitespace-only names were previously valid at the database layer.
alter table public.profiles add constraint profiles_name_not_blank check(length(btrim(full_name))>0) not valid;
commit;
