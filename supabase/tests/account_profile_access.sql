-- Run after pending migration DDL in one transaction; roll back everything.
insert into auth.users(id,email,is_anonymous) values
('00000000-0000-4000-8000-000000000011','account-test-a@example.invalid',false),
('00000000-0000-4000-8000-000000000012','account-test-b@example.invalid',false),
('00000000-0000-4000-8000-000000000013',null,true);
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000011","role":"authenticated","is_anonymous":false}',true);
set local role authenticated;
insert into public.profiles(auth_user_id,full_name,handle) values ('00000000-0000-4000-8000-000000000011','Alice','account_test_alice');
update public.profiles set full_name='Alice Updated',network_visibility='public' where auth_user_id='00000000-0000-4000-8000-000000000011';
do $$ begin
 if (select full_name from public.profiles where handle='account_test_alice')<>'Alice Updated' then raise exception 'Own profile update failed'; end if;
 begin update public.profiles set auth_user_id='00000000-0000-4000-8000-000000000012'; raise exception 'Ownership mutation accepted'; exception when insufficient_privilege then null; end;
 begin update public.profiles set archived_at=now(); raise exception 'Archive mutation accepted'; exception when insufficient_privilege then null; end;
 begin insert into public.profiles(auth_user_id,full_name) values ('00000000-0000-4000-8000-000000000012','Impersonation'); raise exception 'Impersonation accepted'; exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000012","role":"authenticated","is_anonymous":false}',true);
set local role authenticated;
do $$ declare n integer; begin
 if (select count(*) from public.profiles)<>0 then raise exception 'Cross-account read'; end if;
 update public.profiles set full_name='Bob' where handle='account_test_alice'; get diagnostics n=row_count;
 if n<>0 then raise exception 'Cross-account write'; end if;
end $$;
reset role;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000013","role":"authenticated","is_anonymous":true}',true);
set local role authenticated;
do $$ begin
 begin insert into public.profiles(auth_user_id,full_name) values ('00000000-0000-4000-8000-000000000013','Guest'); raise exception 'Guest profile accepted'; exception when insufficient_privilege then null; end;
end $$;
reset role;
select 'PASS: profile creation, editing, identity protection, cross-user isolation and anonymous rejection' as result;
rollback;
