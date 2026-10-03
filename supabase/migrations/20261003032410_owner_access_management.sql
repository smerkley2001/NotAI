begin;
create table notai_private.owner_access_events(id bigint generated always as identity primary key,actor_id uuid not null,target_id uuid not null,action text not null check(action in('granted','revoked')),created_at timestamptz not null default now());
alter table notai_private.owner_access_events enable row level security;
revoke all on notai_private.owner_access_events from public,anon,authenticated;
create index owner_access_events_recent on notai_private.owner_access_events(created_at desc,id desc);
create function notai_private.protect_last_owner() returns trigger language plpgsql security definer set search_path='' as $$begin
 perform pg_advisory_xact_lock(hashtextextended('notai-owner-access',0));
 if (select count(*) from public.shop_owners)<=1 then raise exception 'The last owner cannot be removed.' using errcode='23514';end if;
 return old;
end $$;
revoke all on function notai_private.protect_last_owner() from public,anon,authenticated;
create trigger protect_last_owner before delete on public.shop_owners for each row execute function notai_private.protect_last_owner();
create function notai_private.manage_owner(p_target uuid,p_grant boolean) returns void language plpgsql security definer set search_path='' as $$declare actor uuid:=auth.uid();begin
 perform pg_advisory_xact_lock(hashtextextended('notai-owner-access',0));
 if actor is null or not exists(select 1 from public.shop_owners where auth_user_id=actor) then raise exception 'Owner access required.' using errcode='42501';end if;
 if p_target is null or p_grant is null then raise exception 'Choose a user and an access action.';end if;
 if p_grant then
  if not exists(select 1 from auth.users where id=p_target and email_confirmed_at is not null and is_anonymous=false and (banned_until is null or banned_until<now())) then raise exception 'Choose an existing confirmed user.';end if;
  insert into public.shop_owners(auth_user_id) values(p_target) on conflict do nothing;
 else delete from public.shop_owners where auth_user_id=p_target;end if;
 if found then insert into notai_private.owner_access_events(actor_id,target_id,action) values(actor,p_target,case when p_grant then 'granted' else 'revoked' end);end if;
end $$;
revoke all on function notai_private.manage_owner(uuid,boolean) from public,anon,authenticated;
grant execute on function notai_private.manage_owner(uuid,boolean) to authenticated;
create function public.manage_owner(p_target uuid,p_grant boolean) returns void language sql security invoker set search_path='' as $$select notai_private.manage_owner(p_target,p_grant);$$;
revoke all on function public.manage_owner(uuid,boolean) from public,anon,authenticated;grant execute on function public.manage_owner(uuid,boolean) to authenticated;
create function notai_private.owner_directory(p_search text default '',p_cursor uuid default null,p_owners_only boolean default true) returns jsonb language plpgsql security definer set search_path='' as $$declare result jsonb;term text:=lower(btrim(coalesce(p_search,'')));begin
 if auth.uid() is null or not exists(select 1 from public.shop_owners where auth_user_id=auth.uid()) then raise exception 'Owner access required.' using errcode='42501';end if;
 if length(term)>100 or (not p_owners_only and length(term)<2) or p_owners_only is null then raise exception 'Enter at least two characters to search users.';end if;
 term:=replace(replace(replace(term,'\','\\'),'%','\%'),'_','\_');
 with matches as (
 select u.id,u.email,coalesce(p.full_name,u.raw_user_meta_data->>'full_name','') as full_name,p.handle,(o.auth_user_id is not null) as is_owner,(u.email_confirmed_at is not null and u.is_anonymous=false and (u.banned_until is null or u.banned_until<now())) as eligible
 from auth.users u left join public.profiles p on p.auth_user_id=u.id left join public.shop_owners o on o.auth_user_id=u.id
 where (p_cursor is null or u.id>p_cursor) and (not p_owners_only or o.auth_user_id is not null) and (p_owners_only or (u.is_anonymous=false and (lower(u.email) like term||'%' or lower(p.full_name) like term||'%' or lower(p.handle) like term||'%')))
 order by u.id limit 21
 ),page as(select * from matches order by id limit 20)
 select jsonb_build_object('users',coalesce((select jsonb_agg(to_jsonb(page) order by id) from page),'[]'::jsonb),'next_cursor',case when (select count(*) from matches)>20 then (select id from page order by id desc limit 1) else null end,'owner_count',(select count(*) from public.shop_owners),'self_id',auth.uid(),'events',coalesce((select jsonb_agg(to_jsonb(e) order by e.created_at desc,e.id desc) from(select a.id,a.action,a.created_at,coalesce(actor.email,a.actor_id::text) as actor,coalesce(target.email,a.target_id::text) as target from notai_private.owner_access_events a left join auth.users actor on actor.id=a.actor_id left join auth.users target on target.id=a.target_id order by a.created_at desc,a.id desc limit 20)e),'[]'::jsonb)) into result;
 return result;
end $$;
revoke all on function notai_private.owner_directory(text,uuid,boolean) from public,anon,authenticated;grant execute on function notai_private.owner_directory(text,uuid,boolean) to authenticated;
create function public.owner_directory(p_search text default '',p_cursor uuid default null,p_owners_only boolean default true) returns jsonb language sql security invoker set search_path='' as $$select notai_private.owner_directory(p_search,p_cursor,p_owners_only);$$;
revoke all on function public.owner_directory(text,uuid,boolean) from public,anon,authenticated;grant execute on function public.owner_directory(text,uuid,boolean) to authenticated;
commit;
