begin;
create table notai_private.finance_entries(
 id uuid primary key default gen_random_uuid(),request_key uuid not null unique,
 order_id uuid references public.orders(id),category text not null check(category in('cogs_product','cogs_shipping','cogs_supplier_tax','cogs_packaging','cogs_other','payment_fee','opex_software','opex_marketing','opex_other')),
 basis text not null check(basis in('actual','estimate')),amount_minor bigint not null check(amount_minor<>0 and abs(amount_minor)<=100000000),currency text not null default 'USD' check(currency='USD'),
 occurred_on date not null,provider text not null default '' check(length(provider)<=100),reference text not null default '' check(length(reference)<=200),note text not null check(length(note) between 1 and 1000),
 reverses_id uuid unique references notai_private.finance_entries(id),recorded_by uuid not null,created_at timestamptz not null default now(),
 check((category like 'opex_%' and order_id is null) or (category not like 'opex_%' and order_id is not null))
);
create index finance_entries_order on notai_private.finance_entries(order_id);
create index finance_entries_date on notai_private.finance_entries(occurred_on desc,id);
create table notai_private.order_finance_reviews(order_id uuid primary key references public.orders(id),cogs_complete boolean not null default false,fees_complete boolean not null default false,refund_tax_minor bigint,refund_total_minor bigint,reviewed_by uuid not null,updated_at timestamptz not null default now(),check(refund_tax_minor is null or refund_tax_minor>=0));
create table notai_private.finance_review_events(id bigint generated always as identity primary key,order_id uuid not null references public.orders(id),actor_id uuid not null,details jsonb not null,created_at timestamptz not null default now());
create index finance_review_events_order on notai_private.finance_review_events(order_id,created_at desc);
alter table notai_private.finance_entries enable row level security;
alter table notai_private.order_finance_reviews enable row level security;
alter table notai_private.finance_review_events enable row level security;
revoke all on notai_private.finance_entries,notai_private.order_finance_reviews,notai_private.finance_review_events from public,anon,authenticated;
create index orders_finance_cohort on public.orders(created_at desc,id) where payment_status in('paid','partially_refunded','refunded');
-- This view is private and only used inside explicitly owner-checked functions.
create view notai_private.finance_order_metrics as
with costs as(select order_id,
 coalesce(sum(amount_minor) filter(where basis='actual' and category like 'cogs_%'),0)::bigint as cogs_actual,
 coalesce(sum(amount_minor) filter(where basis='estimate' and category like 'cogs_%'),0)::bigint as cogs_estimate,
 coalesce(sum(amount_minor) filter(where basis='actual' and category='payment_fee'),0)::bigint as fees_actual,
 coalesce(sum(amount_minor) filter(where basis='estimate' and category='payment_fee'),0)::bigint as fees_estimate
 from notai_private.finance_entries where order_id is not null group by order_id),raw as(
 select o.id,o.order_number,o.created_at,o.payment_status,o.fulfillment_status,o.currency,o.subtotal_minor,o.shipping_minor,o.discount_minor,o.credit_minor,o.tax_minor,o.total_minor,o.refunded_minor,
 (o.total_minor-o.tax_minor)::bigint as original_revenue,
 case when o.refunded_minor=0 then 0 when o.refunded_minor=o.total_minor then o.tax_minor when r.refund_total_minor=o.refunded_minor and r.refund_tax_minor is not null then r.refund_tax_minor else round(o.refunded_minor::numeric*o.tax_minor/nullif(o.total_minor,0))::bigint end as tax_refunded,
 (o.refunded_minor>0 and o.refunded_minor<o.total_minor and o.tax_minor>0 and (r.refund_total_minor is distinct from o.refunded_minor or r.refund_tax_minor is null)) as refund_estimated,
 coalesce(c.cogs_actual,0) as cogs_actual,coalesce(c.cogs_estimate,0) as cogs_estimate,coalesce(c.fees_actual,0) as fees_actual,coalesce(c.fees_estimate,0) as fees_estimate,
 coalesce(r.cogs_complete,false) as cogs_complete,coalesce(r.fees_complete,false) as fees_complete,r.refund_tax_minor as recorded_refund_tax_minor,r.refund_total_minor as recorded_refund_total_minor
 from public.orders o left join costs c on c.order_id=o.id left join notai_private.order_finance_reviews r on r.order_id=o.id
 where o.currency='USD' and o.payment_status in('paid','partially_refunded','refunded')),
 net as(select *, (refunded_minor-tax_refunded)::bigint as revenue_refunded,(original_revenue-refunded_minor+tax_refunded)::bigint as net_revenue from raw)
select *,case when cogs_complete then net_revenue-cogs_actual else null end as gross_profit,
 case when cogs_complete and fees_complete then net_revenue-cogs_actual-fees_actual else null end as contribution,
 case when cogs_complete and net_revenue>0 then round(100.0*(net_revenue-cogs_actual)/net_revenue,2) else null end as gross_margin_percent
from net;
revoke all on notai_private.finance_order_metrics from public,anon,authenticated;
create function notai_private.finance_record(p_data jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();key uuid;order_key uuid;old notai_private.finance_entries;result uuid;entry_category text;entry_basis text;amount bigint;entry_date date;begin
 if actor is null or not exists(select 1 from public.shop_owners where auth_user_id=actor) then raise exception 'Owner access required.' using errcode='42501';end if;
 key:=(p_data->>'request_key')::uuid;if key is null then raise exception 'Request key required.';end if;
 perform pg_advisory_xact_lock(hashtextextended(key::text,9));
 select id into result from notai_private.finance_entries where request_key=key;if found then return result;end if;
 if p_data->>'reverses_id' is not null then
 select order_id into order_key from notai_private.finance_entries where id=(p_data->>'reverses_id')::uuid;
 if order_key is not null then perform pg_advisory_xact_lock(hashtextextended(order_key::text,10));end if;
 select * into old from notai_private.finance_entries where id=(p_data->>'reverses_id')::uuid for update;
 if old.id is null or old.reverses_id is not null or exists(select 1 from notai_private.finance_entries where reverses_id=old.id) then raise exception 'This entry cannot be reversed again.';end if;
 insert into notai_private.finance_entries(request_key,order_id,category,basis,amount_minor,occurred_on,provider,reference,note,reverses_id,recorded_by) values(key,old.order_id,old.category,old.basis,-old.amount_minor,(now() at time zone 'America/Chicago')::date,old.provider,old.reference,'Correction: '||coalesce(p_data->>'note',''),old.id,actor) returning id into result;
 order_key:=old.order_id;entry_category:=old.category;entry_basis:=old.basis;
 else
 order_key:=nullif(p_data->>'order_id','')::uuid;if order_key is not null then perform pg_advisory_xact_lock(hashtextextended(order_key::text,10));end if;entry_category:=p_data->>'category';entry_basis:=p_data->>'basis';amount:=(p_data->>'amount_minor')::bigint;entry_date:=(p_data->>'occurred_on')::date;
 if order_key is not null and not exists(select 1 from public.orders where id=order_key and currency='USD') then raise exception 'Choose an existing USD order.';end if;
 if entry_date is null or entry_date>'2100-01-01'::date or entry_date<'2000-01-01'::date or nullif(btrim(p_data->>'note'),'') is null then raise exception 'Enter the date and a description.';end if;
 insert into notai_private.finance_entries(request_key,order_id,category,basis,amount_minor,occurred_on,provider,reference,note,recorded_by) values(key,order_key,entry_category,entry_basis,amount,entry_date,coalesce(p_data->>'provider',''),coalesce(p_data->>'reference',''),btrim(p_data->>'note'),actor) returning id into result;
 end if;
 -- Adding or correcting an actual cost invalidates its prior completion review.
 if order_key is not null and entry_basis='actual' then
 insert into notai_private.order_finance_reviews(order_id,reviewed_by) values(order_key,actor) on conflict(order_id) do nothing;
 update notai_private.order_finance_reviews set cogs_complete=case when entry_category like 'cogs_%' then false else cogs_complete end,fees_complete=case when entry_category='payment_fee' then false else fees_complete end,reviewed_by=actor,updated_at=now() where order_id=order_key;
 end if;
 return result;
end $$;
create function notai_private.finance_review(p_order uuid,p_cogs boolean,p_fees boolean,p_refund_tax bigint default null) returns void language plpgsql security definer set search_path='' as $$declare actor uuid:=auth.uid();o public.orders;begin
 if actor is null or not exists(select 1 from public.shop_owners where auth_user_id=actor) then raise exception 'Owner access required.' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_order::text,10));
 select * into o from public.orders where id=p_order and currency='USD' for update;
 if o.id is null or p_cogs is null or p_fees is null then raise exception 'Choose an order and completion status.';end if;
 if p_refund_tax is not null and (p_refund_tax<greatest(0,o.refunded_minor-(o.total_minor-o.tax_minor)) or p_refund_tax>least(o.tax_minor,o.refunded_minor)) then raise exception 'Refunded tax does not match this order refund.';end if;
 insert into notai_private.order_finance_reviews(order_id,cogs_complete,fees_complete,refund_tax_minor,refund_total_minor,reviewed_by) values(o.id,p_cogs,p_fees,p_refund_tax,case when p_refund_tax is null then null else o.refunded_minor end,actor)
 on conflict(order_id) do update set cogs_complete=excluded.cogs_complete,fees_complete=excluded.fees_complete,refund_tax_minor=excluded.refund_tax_minor,refund_total_minor=excluded.refund_total_minor,reviewed_by=actor,updated_at=now();
 insert into notai_private.finance_review_events(order_id,actor_id,details) values(o.id,actor,jsonb_build_object('cogs_complete',p_cogs,'fees_complete',p_fees,'refund_tax_minor',p_refund_tax,'refund_total_minor',o.refunded_minor));
end $$;
create function notai_private.finance_report(p_from date,p_to date,p_offset integer default 0,p_order uuid default null) returns jsonb language plpgsql security definer set search_path='' as $$declare actor uuid:=auth.uid();result jsonb;begin
 if actor is null or not exists(select 1 from public.shop_owners where auth_user_id=actor) then raise exception 'Owner access required.' using errcode='42501';end if;
 if p_from is null or p_to is null or p_to<p_from or p_offset is null or p_offset<0 or p_offset>100000 then raise exception 'Check dates and page.';end if;
 if p_order is not null and not exists(select 1 from public.orders where id=p_order and currency='USD' and payment_status in('paid','partially_refunded','refunded')) then raise exception 'Paid USD order not found.';end if;
 with selected as(select * from notai_private.finance_order_metrics where (p_order is not null and id=p_order) or (p_order is null and created_at >= (p_from::timestamp at time zone 'America/Chicago') and created_at < ((p_to+1)::timestamp at time zone 'America/Chicago'))),summary as(
 select count(*) as order_count,coalesce(sum(original_revenue),0) as sales_before_refunds,coalesce(sum(revenue_refunded),0) as refunds_excluding_tax,coalesce(sum(net_revenue),0) as net_revenue,coalesce(sum(tax_minor-tax_refunded),0) as net_customer_tax,
 coalesce(sum(cogs_actual),0) as recorded_cogs,coalesce(sum(fees_actual),0) as recorded_fees,count(*) filter(where not cogs_complete) as missing_cogs,count(*) filter(where not fees_complete) as missing_fees,count(*) filter(where refund_estimated) as estimated_refunds,
 case when bool_and(cogs_complete) or count(*)=0 then coalesce(sum(gross_profit),0) else null end as gross_profit,
 case when bool_and(cogs_complete and fees_complete) or count(*)=0 then coalesce(sum(contribution),0) else null end as contribution,
 coalesce(sum(gross_profit) filter(where cogs_complete),0) as reviewed_gross_profit,count(*) filter(where cogs_complete) as reviewed_orders from selected),
 page as(select * from selected order by created_at desc,id desc limit 20 offset p_offset),
 expenses as(select coalesce(sum(amount_minor),0) as operating_expenses from notai_private.finance_entries where category like 'opex_%' and basis='actual' and occurred_on between p_from and p_to)
 select jsonb_build_object('currency','USD','summary',(select to_jsonb(s)||jsonb_build_object('gross_margin_percent',case when s.gross_profit is not null and s.net_revenue>0 then round(100.0*s.gross_profit/s.net_revenue,2) else null end,'operating_expenses',e.operating_expenses,'after_expenses',case when s.contribution is not null then s.contribution-e.operating_expenses else null end) from summary s cross join expenses e),'orders',coalesce((select jsonb_agg(to_jsonb(page) order by created_at desc,id desc) from page),'[]'::jsonb),
 'entries',coalesce((select jsonb_agg(to_jsonb(e) order by e.occurred_on desc,e.created_at desc) from(select f.*,exists(select 1 from notai_private.finance_entries r where r.reverses_id=f.id) as reversed from notai_private.finance_entries f where (p_order is not null and f.order_id=p_order) or (p_order is null and f.occurred_on between p_from and p_to) order by f.occurred_on desc,f.created_at desc limit 20 offset p_offset)e),'[]'::jsonb),
 'entry_count',(select count(*) from notai_private.finance_entries f where (p_order is not null and f.order_id=p_order) or (p_order is null and f.occurred_on between p_from and p_to)),
 'credit_liability',(select coalesce(sum(greatest(balance,0)),0) from(select sum(amount_minor) as balance from public.credit_ledger where currency='USD' group by user_id)b),
 'reviews',case when p_order is not null then coalesce((select jsonb_agg(to_jsonb(r) order by r.created_at desc) from(select actor_id,details,created_at from notai_private.finance_review_events where order_id=p_order order by created_at desc limit 10)r),'[]'::jsonb) else '[]'::jsonb end) into result;
 return result;
end $$;
revoke all on function notai_private.finance_record(jsonb),notai_private.finance_review(uuid,boolean,boolean,bigint),notai_private.finance_report(date,date,integer,uuid) from public,anon,authenticated;
grant execute on function notai_private.finance_record(jsonb),notai_private.finance_review(uuid,boolean,boolean,bigint),notai_private.finance_report(date,date,integer,uuid) to authenticated;
create function public.finance_record(p_data jsonb) returns uuid language sql security invoker set search_path='' as $$select notai_private.finance_record(p_data);$$;
create function public.finance_review(p_order uuid,p_cogs boolean,p_fees boolean,p_refund_tax bigint default null) returns void language sql security invoker set search_path='' as $$select notai_private.finance_review(p_order,p_cogs,p_fees,p_refund_tax);$$;
create function public.finance_report(p_from date,p_to date,p_offset integer default 0,p_order uuid default null) returns jsonb language sql security invoker set search_path='' as $$select notai_private.finance_report(p_from,p_to,p_offset,p_order);$$;
revoke all on function public.finance_record(jsonb),public.finance_review(uuid,boolean,boolean,bigint),public.finance_report(date,date,integer,uuid) from public,anon,authenticated;
grant execute on function public.finance_record(jsonb),public.finance_review(uuid,boolean,boolean,bigint),public.finance_report(date,date,integer,uuid) to authenticated;
commit;
