-- Append after migration DDL with its final COMMIT removed, on an empty database.
-- Entire migration and synthetic fixtures roll back. Never run after production migration.

-- Synthetic fixtures: transaction is rolled back in full.
insert into auth.users(id,email,is_anonymous) values
('00000000-0000-4000-8000-000000000001','alice@example.invalid',false),
('00000000-0000-4000-8000-000000000002','bob@example.invalid',false),
('00000000-0000-4000-8000-000000000003',null,true);
insert into public.profiles(id,auth_user_id,full_name) values
('10000000-0000-4000-8000-000000000001','00000000-0000-4000-8000-000000000001','Alice'),
('10000000-0000-4000-8000-000000000002','00000000-0000-4000-8000-000000000002','Bob'),
('10000000-0000-4000-8000-000000000003','00000000-0000-4000-8000-000000000003','Guest');
insert into public.designs(id,user_id,name) values
('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','Alice draft'),
('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002','Bob draft');
insert into public.design_revisions(id,design_id,user_id,revision_number,line1,line2,icon_key,font_key,accent_color,shirt_color) values
('30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001',1,'First','Soccer','soccer','modern','#22b8ff','black');
set local role service_role;
insert into public.orders(id,user_id,idempotency_key,subtotal_minor,total_minor,contact_email,shipping_address) values
('40000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','test-1',2799,2799,'alice@example.invalid','{}');
do $$ begin
 begin
 insert into public.orders(user_id,idempotency_key,subtotal_minor,total_minor,contact_email,shipping_address) values
 ('10000000-0000-4000-8000-000000000003','guest',2799,2799,'guest@example.invalid','{}');
 raise exception 'TEST: guest order accepted';
 exception when raise_exception then
 if sqlerrm <> 'Order requires a registered account' then raise; end if;
 end;
end $$;
reset role;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000001","role":"authenticated","is_anonymous":false}',true);
set local role authenticated;
do $$ begin
 if (select count(*) from public.designs)<>1 then raise exception 'TEST: design isolation failed'; end if;
 if (select count(*) from public.orders)<>1 then raise exception 'TEST: order read failed'; end if;
 begin
 update public.designs set name='Tampered';
 raise exception 'TEST: client write accepted';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
do $$ begin
 begin update public.design_revisions set line1='Changed'; raise exception 'TEST: revision mutable';
 exception when raise_exception then if sqlerrm not like 'Record is immutable%' then raise; end if; end;
end $$;
select 'PASS: registered buyer, guest rejection, owner reads, client write denial and revision immutability' as result;
rollback;