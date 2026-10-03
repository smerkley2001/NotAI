begin;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000099","role":"authenticated"}',true);
do $$begin
 if exists(select 1 from public.shop_owners) then raise exception 'Non-owner can see memberships'; end if;
 begin insert into public.shop_owners(auth_user_id) values('00000000-0000-4000-8000-000000000099'); raise exception 'Self-enrollment unexpectedly allowed'; exception when insufficient_privilege then null; end;
 begin update public.shop_settings set ordering_open=true; raise exception 'Settings mutation unexpectedly allowed'; exception when insufficient_privilege then null; end;
end $$;
rollback;
