begin;
-- All fixtures and access changes are rolled back.
insert into auth.users(id,email,email_confirmed_at,is_anonymous,raw_user_meta_data) values('90000000-0000-4000-8000-000000000081','owner-access-fixture@example.invalid',now(),false,'{}'),('90000000-0000-4000-8000-000000000082','unconfirmed-access-fixture@example.invalid',null,false,'{}');
select set_config('request.jwt.claims',json_build_object('sub',(select auth_user_id from public.shop_owners limit 1),'role','authenticated')::text,true);
do $$declare actor uuid:=auth.uid();before_count bigint;begin
 select count(*) into before_count from public.shop_owners;
 perform public.owner_directory('owner-access-fixture',null,false);
 if before_count=1 then
  begin perform public.manage_owner(actor,false);raise exception 'Last owner removed';exception when check_violation then null;end;
 end if;
 begin perform public.manage_owner('90000000-0000-4000-8000-000000000082',true);raise exception 'Unconfirmed user granted';exception when raise_exception then if SQLERRM='Unconfirmed user granted' then raise;end if;end;
 perform public.manage_owner('90000000-0000-4000-8000-000000000081',true);
 if (select count(*) from public.shop_owners)<>before_count+1 then raise exception 'Grant failed';end if;
 perform public.manage_owner('90000000-0000-4000-8000-000000000081',true);
 if (select count(*) from public.shop_owners)<>before_count+1 then raise exception 'Grant not idempotent';end if;
 perform public.manage_owner('90000000-0000-4000-8000-000000000081',false);
 if (select count(*) from public.shop_owners)<>before_count then raise exception 'Revoke failed';end if;
 if (select count(*) from notai_private.owner_access_events where target_id='90000000-0000-4000-8000-000000000081')<>2 then raise exception 'Audit failed';end if;
end $$;
select set_config('request.jwt.claims','{"sub":"90000000-0000-4000-8000-000000000081","role":"authenticated"}',true);
do $$begin
 begin perform public.owner_directory('',null,true);raise exception 'Non-owner read allowed';exception when insufficient_privilege then null;end;
 begin perform public.manage_owner('90000000-0000-4000-8000-000000000081',true);raise exception 'Non-owner self-grant allowed';exception when insufficient_privilege then null;end;
end $$;
rollback;
