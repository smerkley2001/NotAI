insert into auth.users(id,email,is_anonymous) values
('00000000-0000-4000-8000-000000000031','qr-a@example.invalid',false),('00000000-0000-4000-8000-000000000032','qr-b@example.invalid',false),('00000000-0000-4000-8000-000000000033','qr-c@example.invalid',false);
insert into public.profiles(id,auth_user_id,full_name) values
('10000000-0000-4000-8000-000000000031','00000000-0000-4000-8000-000000000031','Alice'),('10000000-0000-4000-8000-000000000032','00000000-0000-4000-8000-000000000032','Bob'),('10000000-0000-4000-8000-000000000033','00000000-0000-4000-8000-000000000033','Carol');
insert into public.product_variants(id,sku,product_name,color_key,size_key,currency,price_minor) values('30000000-0000-4000-8000-000000000031','test-qr-black-M','Test shirt','black','M','USD',2799);
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000031","role":"authenticated","is_anonymous":false}',true);
set local role authenticated;
do $$declare r jsonb;t text;begin
 r:=public.save_design(null,0,'Test','{"line1":"Private words","line2":"Human","icon_key":"soccer","font_key":"modern","shirt_color":"black","accent_color":"#22b8ff"}');
 perform set_config('notai.rev_a',r->>'revision_id',true);t:=public.share_design((r->>'revision_id')::uuid,null);perform set_config('notai.share',t,true);
 if public.read_share(t)->'design'->>'line1'<>'Private words' then raise exception 'Share projection failed';end if;
 if public.read_share(t)::text like '%user_id%' then raise exception 'Share leaked identity';end if;
 perform public.share_design(null,t);if public.read_share(t) is not null then raise exception 'Revocation failed';end if;
end $$;
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);set local role service_role;
do $$declare o jsonb;s text;begin
 o:=public.prepare_order('00000000-0000-4000-8000-000000000031',current_setting('notai.rev_a')::uuid,'30000000-0000-4000-8000-000000000031',2,500,null,'40000000-0000-4000-8000-000000000031',null,false);
 perform set_config('notai.order_a',o->>'id',true);if (select count(*) from public.shirts where user_id='10000000-0000-4000-8000-000000000031')<>2 then raise exception 'Per-unit shirts missing';end if;
 update public.orders set stripe_session_id='cs_a' where id=(o->>'id')::uuid;
 perform public.process_payment('evt_a',(o->>'id')::uuid,'paid','cs_a','pi_a',6098,0,'USD','{"address":{"line1":"Test"}}');
 perform public.record_shipment((o->>'id')::uuid,'Test carrier','TRACK', '60000000-0000-4000-8000-000000000031',false);
 perform public.record_shipment((o->>'id')::uuid,'Test carrier','TRACK', '60000000-0000-4000-8000-000000000031',false);
 if (select count(*) from public.shipments where order_id=(o->>'id')::uuid)<>1 then raise exception 'Shipment duplicate';end if;
 select qr_token into s from public.shirts where user_id='10000000-0000-4000-8000-000000000031' limit 1;perform set_config('notai.qr_a',s,true);
end $$;
reset role;select set_config('request.jwt.claims','{"role":"anon"}',true);set local role anon;
do $$declare r jsonb;begin r:=public.read_shirt(current_setting('notai.qr_a'));if r is null or r->>'story' is not null or r->>'handle' is not null or r->>'design' is not null then raise exception 'Default private projection failed';end if;
 begin perform public.prepare_order(null,null,null,1,0,null,gen_random_uuid(),null,false);raise exception 'Guest order allowed';exception when insufficient_privilege then null;end;
end $$;
reset role;select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000032","role":"authenticated","is_anonymous":false}',true);set local role authenticated;
do $$declare r jsonb;begin r:=public.save_design(null,0,'Bob','{"line1":"B","line2":"Human","icon_key":"soccer","font_key":"modern","shirt_color":"black","accent_color":"#22b8ff"}');perform set_config('notai.rev_b',r->>'revision_id',true);end $$;
reset role;select set_config('request.jwt.claims','{"role":"service_role"}',true);set local role service_role;
do $$declare o jsonb;begin
 o:=public.prepare_order('00000000-0000-4000-8000-000000000032',current_setting('notai.rev_b')::uuid,'30000000-0000-4000-8000-000000000031',1,500,current_setting('notai.qr_a'),'40000000-0000-4000-8000-000000000032',null,false);perform set_config('notai.order_b',o->>'id',true);
 update public.orders set stripe_session_id='cs_b' where id=(o->>'id')::uuid;
 begin perform public.process_payment('evt_bad',(o->>'id')::uuid,'paid','cs_b','pi_b',1,0,'USD','{"address":{}}');raise exception 'Wrong amount accepted';exception when raise_exception then if sqlerrm='Wrong amount accepted' then raise;end if;end;
 perform public.process_payment('evt_b',(o->>'id')::uuid,'paid','cs_b','pi_b',3299,0,'USD','{"address":{"line1":"Test"}}');
 perform public.process_payment('evt_b',(o->>'id')::uuid,'paid','cs_b','pi_b',3299,0,'USD','{"address":{"line1":"Test"}}');
 if (select sum(amount_minor) from public.credit_ledger where user_id='10000000-0000-4000-8000-000000000031')<>300 then raise exception 'Reward missing or duplicated';end if;
end $$;
reset role;select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000031","role":"authenticated","is_anonymous":false}',true);set local role authenticated;
do $$declare g jsonb;t text;begin
 g:=public.my_network();if jsonb_array_length(g)<>1 or g->0->>'handle' is not null then raise exception 'Private network projection failed';end if;
 t:=public.gift_invite('Pick your own words',null);perform set_config('notai.gift',t,true);
end $$;
reset role;select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000032","role":"authenticated","is_anonymous":false}',true);set local role authenticated;
select public.gift_reply(current_setting('notai.gift'),current_setting('notai.rev_b')::uuid,'30000000-0000-4000-8000-000000000031');
reset role;select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000031","role":"authenticated","is_anonymous":false}',true);set local role authenticated;
do $$declare r jsonb;begin r:=public.save_design(null,0,'Gift copy','{"line1":"B","line2":"Human","icon_key":"soccer","font_key":"modern","shirt_color":"black","accent_color":"#22b8ff"}');perform set_config('notai.gift_revision',r->>'revision_id',true);end $$;
reset role;select set_config('request.jwt.claims','{"role":"service_role"}',true);set local role service_role;
do $$declare o jsonb;s public.shirts;begin
 o:=public.prepare_order('00000000-0000-4000-8000-000000000031',current_setting('notai.gift_revision')::uuid,'30000000-0000-4000-8000-000000000031',1,500,null,'40000000-0000-4000-8000-000000000033',current_setting('notai.gift'),true);
 if (o->>'credit_minor')::bigint<>300 then raise exception 'Credit reservation failed';end if;
 update public.orders set stripe_session_id='cs_gift' where id=(o->>'id')::uuid;
 perform public.process_payment('evt_gift',(o->>'id')::uuid,'paid','cs_gift','pi_gift',2999,0,'USD','{"address":{"line1":"Gift"}}');
 select * into s from public.shirts where order_item_id in(select id from public.order_items where order_id=(o->>'id')::uuid);
 if s.effective_owner_id<>'10000000-0000-4000-8000-000000000032' then raise exception 'Gift identity not assigned to recipient';end if;
 perform set_config('notai.gift_shirt',s.id::text,true);
 perform public.process_payment('evt_refund_b',current_setting('notai.order_b')::uuid,'refund','ch_b','pi_b',3299,0,'USD','{}');
 perform public.process_payment('evt_old_partial',current_setting('notai.order_b')::uuid,'refund','ch_b','pi_b',100,0,'USD','{}');
 if (select payment_status from public.orders where id=current_setting('notai.order_b')::uuid)<>'refunded' then raise exception 'Refund status moved backwards';end if;
 if (select sum(amount_minor) from public.credit_ledger where user_id='10000000-0000-4000-8000-000000000031')<>-300 then raise exception 'Spent referral refund should leave negative recoverable balance';end if;
end $$;
reset role;select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000032","role":"authenticated","is_anonymous":false}',true);set local role authenticated;
select public.shirt_settings(current_setting('notai.gift_shirt')::uuid,'My gift story',true,false);
reset role;select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000031","role":"authenticated","is_anonymous":false}',true);set local role authenticated;
do $$begin begin perform public.shirt_settings(current_setting('notai.gift_shirt')::uuid,'Giver edit',true,true);raise exception 'Giver edited recipient privacy';exception when insufficient_privilege then null;end;end $$;
reset role;
select 'PASS: real order shirts, QR projection/revocation, service-only payments, reward idempotency, refund reversal, credit spend, gifted identity and privacy' as result;
rollback;
