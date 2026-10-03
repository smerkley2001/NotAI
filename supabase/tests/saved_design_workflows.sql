insert into auth.users(id,email,is_anonymous) values
('00000000-0000-4000-8000-000000000021','design-a@example.invalid',false),
('00000000-0000-4000-8000-000000000022','design-b@example.invalid',false),
('00000000-0000-4000-8000-000000000023',null,true);
insert into public.profiles(id,auth_user_id,full_name) values
('10000000-0000-4000-8000-000000000021','00000000-0000-4000-8000-000000000021','Alice'),
('10000000-0000-4000-8000-000000000022','00000000-0000-4000-8000-000000000022','Bob');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000021","role":"authenticated","is_anonymous":false}',true);
set local role authenticated;
do $$ declare d jsonb := '{"line1":"Hello","line2":"Human","icon_key":"soccer","font_key":"modern","shirt_color":"black","accent_color":"#22b8ff"}'; r jsonb; id uuid; begin
 r:=public.save_design(null,0,'First idea',d);id:=(r->>'design_id')::uuid;
 perform set_config('notai.test_design',id::text,true);
 r:=public.save_design(id,1,'Edited idea',d||'{"line1":"Edited"}');
 if (r->>'revision_number')::integer<>2 then raise exception 'Revision increment failed';end if;
 begin perform public.save_design(id,1,'Stale',d);raise exception 'Stale update accepted';exception when serialization_failure then null;end;
 begin perform public.save_design(null,0,'Bad',d||'{"line1":123}');raise exception 'Invalid line accepted';exception when raise_exception then if sqlerrm='Invalid line accepted' then raise;end if;end;
 perform public.save_design(null,0,'Copy',d);
 perform public.archive_design(id,true);
 if (select count(*) from public.list_my_designs(true,0))<>1 then raise exception 'Archive failed';end if;
 begin perform public.save_design(id,2,'Archived edit',d);raise exception 'Archived edit accepted';exception when insufficient_privilege then null;end;
 perform public.archive_design(id,false);
 if (select count(*) from public.list_my_designs(false,0))<>2 then raise exception 'Restore failed';end if;
 begin update public.design_revisions set line1='Changed';raise exception 'Direct mutation accepted';exception when insufficient_privilege then null;end;
end $$;
reset role;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000022","role":"authenticated","is_anonymous":false}',true);
set local role authenticated;
do $$ begin
 if (select count(*) from public.list_my_designs(false,0))<>0 then raise exception 'Cross-user read';end if;
 begin perform public.archive_design(current_setting('notai.test_design')::uuid,true);raise exception 'Cross-user archive';exception when insufficient_privilege then null;end;
 begin perform public.save_design(current_setting('notai.test_design')::uuid,2,'Stolen','{}');raise exception 'Cross-user write';exception when insufficient_privilege or raise_exception then if sqlerrm='Cross-user write' then raise;end if;end;
end $$;
reset role;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000023","role":"authenticated","is_anonymous":true}',true);
set local role authenticated;
do $$ begin
 begin perform public.save_design(null,0,'Guest','{}');raise exception 'Guest accepted';exception when insufficient_privilege then null;end;
end $$;
reset role;
select 'PASS: revisions, conflict protection, archive/restore, owner isolation, anonymous rejection' as result;
rollback;
