begin;
-- Server-side transactions with derived ownership; no direct design table writes.
create function notai_private.current_profile() returns uuid
language plpgsql security definer set search_path='' as $$
declare profile_id uuid;
begin
 if (select auth.uid()) is null then raise exception 'Sign in to continue' using errcode='42501'; end if;
 select p.id into profile_id from public.profiles p join auth.users u on u.id=p.auth_user_id
 where u.id=(select auth.uid()) and u.is_anonymous is false and p.archived_at is null;
 if profile_id is null then raise exception 'Complete your account profile first' using errcode='42501'; end if;
 return profile_id;
end $$;
revoke all on function notai_private.current_profile() from public,anon,authenticated;
create function notai_private.save_design(p_design_id uuid,p_expected_revision integer,p_name text,p_design jsonb) returns jsonb
language plpgsql security definer set search_path='' as $$
declare owner_id uuid; target_id uuid; current_revision integer; new_revision uuid;
begin
 owner_id:=notai_private.current_profile();
 if p_name is null or length(btrim(p_name)) not between 1 and 120 then raise exception 'Name must be 1–120 characters'; end if;
 if jsonb_typeof(p_design) is distinct from 'object'
 or jsonb_typeof(p_design->'line1') is distinct from 'string' or p_design->>'line1' is null or length(p_design->>'line1')>32
 or jsonb_typeof(p_design->'line2') is distinct from 'string' or p_design->>'line2' is null or length(p_design->>'line2')>32
 or p_design->>'icon_key' is null or p_design->>'icon_key' not in ('soccer','volleyball','basketball','guitar','art','paw','books','star','heart','gaming')
 or p_design->>'font_key' is null or p_design->>'font_key' not in ('modern','classic','tech-mono','friendly','clean')
 or p_design->>'shirt_color' is null or p_design->>'shirt_color' not in ('charcoal','black','navy','white')
 or p_design->>'accent_color' is null or p_design->>'accent_color' !~ '^#[0-9A-Fa-f]{6}$'
 then raise exception 'Invalid personalization'; end if;
 if p_design_id is null then
  if p_expected_revision is distinct from 0 then raise exception 'New design must start at revision 0'; end if;
  insert into public.designs(user_id,name) values(owner_id,btrim(p_name)) returning id into target_id;
  current_revision:=0;
 else
  select id into target_id from public.designs where id=p_design_id and user_id=owner_id and archived_at is null for update;
  if target_id is null then raise exception 'Design not found' using errcode='42501'; end if;
  select coalesce(max(revision_number),0) into current_revision from public.design_revisions where design_id=target_id;
  if p_expected_revision is distinct from current_revision then raise exception 'Design changed in another tab; reload or save a copy' using errcode='40001'; end if;
  update public.designs set name=btrim(p_name),updated_at=now() where id=target_id;
 end if;
 insert into public.design_revisions(design_id,user_id,revision_number,line1,line2,icon_key,font_key,accent_color,shirt_color,format_version,layout)
 values(target_id,owner_id,current_revision+1,p_design->>'line1',p_design->>'line2',p_design->>'icon_key',p_design->>'font_key',p_design->>'accent_color',p_design->>'shirt_color',1,'{}')
 returning id into new_revision;
 return jsonb_build_object('design_id',target_id,'revision_id',new_revision,'revision_number',current_revision+1);
end $$;
revoke all on function notai_private.save_design(uuid,integer,text,jsonb) from public,anon,authenticated;
create function public.save_design(p_design_id uuid,p_expected_revision integer,p_name text,p_design jsonb) returns jsonb
language sql security invoker set search_path='' as $$ select notai_private.save_design(p_design_id,p_expected_revision,p_name,p_design); $$;
revoke all on function public.save_design(uuid,integer,text,jsonb) from public,anon;
grant usage on schema notai_private to authenticated;
grant execute on function notai_private.save_design(uuid,integer,text,jsonb) to authenticated;
grant execute on function public.save_design(uuid,integer,text,jsonb) to authenticated;
create function notai_private.archive_design(p_design_id uuid,p_archived boolean) returns void
language plpgsql security definer set search_path='' as $$
declare owner_id uuid;
begin
 owner_id:=notai_private.current_profile();
 if p_archived is null then raise exception 'Choose archive state'; end if;
 update public.designs set archived_at=case when p_archived then now() else null end,updated_at=now()
 where id=p_design_id and user_id=owner_id;
 if not found then raise exception 'Design not found' using errcode='42501'; end if;
end $$;
revoke all on function notai_private.archive_design(uuid,boolean) from public,anon;
create function public.archive_design(p_design_id uuid,p_archived boolean) returns void
language sql security invoker set search_path='' as $$ select notai_private.archive_design(p_design_id,p_archived); $$;
revoke all on function public.archive_design(uuid,boolean) from public,anon;
grant execute on function notai_private.archive_design(uuid,boolean) to authenticated;
grant execute on function public.archive_design(uuid,boolean) to authenticated;
create function public.list_my_designs(p_archived boolean default false,p_offset integer default 0)
returns table(id uuid,name text,updated_at timestamptz,archived_at timestamptz,revision jsonb)
language sql stable security invoker set search_path='' as $$
 select d.id,d.name,d.updated_at,d.archived_at,to_jsonb(r)
 from public.designs d join public.profiles p on p.id=d.user_id
 left join lateral(select * from public.design_revisions x where x.design_id=d.id order by revision_number desc limit 1) r on true
 where p.auth_user_id=(select auth.uid()) and (d.archived_at is not null)=p_archived
 order by d.updated_at desc,d.id limit 24 offset greatest(p_offset,0);
$$;
revoke all on function public.list_my_designs(boolean,integer) from public,anon;
grant execute on function public.list_my_designs(boolean,integer) to authenticated;
commit;
