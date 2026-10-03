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

-- Extends the existing, not-yet-deployed saved-design migration.
alter table public.shirts add column wearer_id uuid references public.profiles(id), add column story text not null default '' check(length(story)<=1000), add column story_public boolean not null default false, add column design_public boolean not null default false;
alter table public.orders add column refunded_minor bigint not null default 0 check(refunded_minor>=0), add column stripe_session_id text unique, add column stripe_payment_intent text unique;
create table public.design_shares(id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles(id),revision_id uuid not null,token text not null unique default replace(gen_random_uuid()::text,'-',''),revoked_at timestamptz,created_at timestamptz not null default now(),foreign key(revision_id,user_id) references public.design_revisions(id,user_id));
alter table public.design_shares enable row level security;
grant select on public.design_shares to authenticated;grant all on public.design_shares to service_role;
create policy own_shares on public.design_shares for select to authenticated using(user_id in(select id from public.profiles where auth_user_id=(select auth.uid())));
create index on public.design_shares(user_id);create index on public.design_shares(revision_id);
create table public.gift_invitations(id uuid primary key default gen_random_uuid(),user_id uuid not null references public.profiles(id),token text not null unique default replace(gen_random_uuid()::text,'-',''),message text not null check(length(message)<=500),recipient_id uuid references public.profiles(id),revision_id uuid references public.design_revisions(id),variant_id uuid references public.product_variants(id),status text not null default 'invited' check(status in ('invited','submitted','buying','paid','closed')),created_at timestamptz not null default now());
alter table public.gift_invitations enable row level security;
grant select(id,user_id,token,message,status,created_at) on public.gift_invitations to authenticated;grant all on public.gift_invitations to service_role;
create policy own_invitations on public.gift_invitations for select to authenticated using(user_id in(select id from public.profiles where auth_user_id=(select auth.uid())));
create index on public.gift_invitations(user_id);create index on public.gift_invitations(recipient_id);create index on public.gift_invitations(revision_id);
alter table public.shirts add column effective_owner_id uuid generated always as (coalesce(wearer_id,user_id)) stored;
alter table public.shirts add constraint shirt_effective_owner_unique unique(id,effective_owner_id);
alter table public.referral_attributions drop constraint referral_attributions_source_shirt_id_referrer_id_fkey;
alter table public.referral_attributions add constraint referral_shirt_owner foreign key(source_shirt_id,referrer_id) references public.shirts(id,effective_owner_id);
alter table public.product_variants add column fit_notes text,add column measurements jsonb not null default '{}' check(jsonb_typeof(measurements)='object');
alter table public.orders add column gift_invitation_id uuid references public.gift_invitations(id);
create unique index one_active_gift_order on public.orders(gift_invitation_id) where payment_status in ('pending','paid','partially_refunded');
create index on public.shirts(wearer_id);create index on public.gift_invitations(variant_id);
create policy worn_shirts on public.shirts for select to authenticated using(wearer_id in(select id from public.profiles where auth_user_id=(select auth.uid())));
create function notai_private.personalization(r public.design_revisions) returns jsonb language sql immutable set search_path='' as $$select jsonb_build_object('line1',r.line1,'line2',r.line2,'icon_key',r.icon_key,'font_key',r.font_key,'accent_color',r.accent_color,'shirt_color',r.shirt_color);$$;
revoke all on function notai_private.personalization(public.design_revisions) from public,anon,authenticated;
create function notai_private.share_design(p_revision uuid,p_revoke text default null) returns text language plpgsql security definer set search_path='' as $$
declare owner_id uuid:=notai_private.current_profile(); result text;
begin
 if p_revoke is not null then update public.design_shares set revoked_at=now() where token=p_revoke and user_id=owner_id;if not found then raise exception 'Share not found' using errcode='42501';end if;return null;end if;
 if not exists(select 1 from public.design_revisions r join public.designs d on d.id=r.design_id where r.id=p_revision and r.user_id=owner_id and d.archived_at is null) then raise exception 'Design not found' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(owner_id::text,2));
 if (select count(*) from public.design_shares where user_id=owner_id and created_at>now()-interval '1 day')>=100 then raise exception 'Share limit reached; reuse an existing link';end if;
 insert into public.design_shares(user_id,revision_id) values(owner_id,p_revision) returning token into result;return result;
end $$;
create function notai_private.read_share(p_token text) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('design',notai_private.personalization(r),'version',r.revision_number) from public.design_shares s join public.design_revisions r on r.id=s.revision_id join public.profiles p on p.id=s.user_id where s.token=p_token and s.revoked_at is null and p.archived_at is null;
$$;
create function notai_private.shirt_settings(p_id uuid,p_story text,p_story_public boolean,p_design_public boolean) returns void language plpgsql security definer set search_path='' as $$
declare owner_id uuid:=notai_private.current_profile();begin
 if p_story is null or length(p_story)>1000 or p_story_public is null or p_design_public is null then raise exception 'Invalid story settings';end if;
 update public.shirts set story=p_story,story_public=p_story_public,design_public=p_design_public where id=p_id and coalesce(wearer_id,user_id)=owner_id;
 if not found then raise exception 'Shirt not found' using errcode='42501';end if;
end $$;
create function notai_private.read_shirt(p_token text) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('handle',case when p.network_visibility='public' then p.handle else null end,'story',case when s.story_public then s.story else null end,'design',case when s.design_public then i.personalization_snapshot else null end)
 from public.shirts s join public.profiles p on p.id=coalesce(s.wearer_id,s.user_id) join public.order_items i on i.id=s.order_item_id join public.orders o on o.id=i.order_id
 where s.qr_token=p_token and s.qr_state='active' and o.payment_status in ('paid','partially_refunded') and p.archived_at is null;
$$;
create function notai_private.my_referrals() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare owner_id uuid:=notai_private.current_profile();begin
 return coalesce((select jsonb_agg(jsonb_build_object('status',a.status,'reward_minor',a.reward_minor,'currency',a.currency,'created_at',a.attributed_at) order by a.attributed_at desc) from public.referral_attributions a where a.referrer_id=owner_id),'[]');end $$;
create function notai_private.my_network() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare owner_id uuid:=notai_private.current_profile();begin
 return coalesce((with recursive connections as (
 select a.buyer_id,a.id,1 as depth,array[owner_id,a.buyer_id] as path from public.referral_attributions a join public.network_edges e on e.attribution_id=a.id where a.referrer_id=owner_id and a.status='qualified' and e.hidden_at is null
 union all
 select a.buyer_id,a.id,c.depth+1,c.path||a.buyer_id from connections c join public.profiles parent on parent.id=c.buyer_id join public.referral_attributions a on a.referrer_id=c.buyer_id join public.network_edges e on e.attribution_id=a.id where c.depth<3 and parent.network_visibility='public' and parent.archived_at is null and a.status='qualified' and e.hidden_at is null and not a.buyer_id=any(c.path)
 ) select jsonb_agg(jsonb_build_object('connection',c.id,'depth',c.depth,'handle',case when p.network_visibility='public' and p.archived_at is null then p.handle else null end)) from connections c join public.profiles p on p.id=c.buyer_id),'[]');end $$;
create function notai_private.gift_invite(p_message text,p_close text default null) returns text language plpgsql security definer set search_path='' as $$
declare owner_id uuid:=notai_private.current_profile(); result text;begin
 if p_close is not null then update public.gift_invitations set status='closed' where token=p_close and user_id=owner_id and status in ('invited','submitted');if not found then raise exception 'Invitation not found' using errcode='42501';end if;return null;end if;
 if p_message is null or length(p_message)>500 then raise exception 'Message must be up to 500 characters';end if;
 perform pg_advisory_xact_lock(hashtextextended(owner_id::text,3));
 if (select count(*) from public.gift_invitations where user_id=owner_id and created_at>now()-interval '1 day')>=20 then raise exception 'Gift invitation limit reached';end if;
 insert into public.gift_invitations(user_id,message) values(owner_id,p_message) returning token into result;return result;
end $$;
create function notai_private.read_gift(p_token text) returns jsonb language sql stable security definer set search_path='' as $$select jsonb_build_object('message',message,'status',status) from public.gift_invitations where token=p_token and status<>'closed';$$;
create function notai_private.gift_reply(p_token text,p_revision uuid,p_variant uuid) returns void language plpgsql security definer set search_path='' as $$
declare owner_id uuid:=notai_private.current_profile();begin
 if not exists(select 1 from public.design_revisions where id=p_revision and user_id=owner_id) then raise exception 'Choose your own design' using errcode='42501';end if;
 if not exists(select 1 from public.product_variants v join public.design_revisions r on r.id=p_revision where v.id=p_variant and v.active and v.color_key=r.shirt_color) then raise exception 'Choose an available size';end if;
 update public.gift_invitations set recipient_id=owner_id,revision_id=p_revision,variant_id=p_variant,status='submitted' where token=p_token and status='invited' and user_id<>owner_id;
 if not found then raise exception 'Invitation unavailable';end if;
end $$;
create function notai_private.gift_submissions() returns jsonb language plpgsql stable security definer set search_path='' as $$declare owner_id uuid:=notai_private.current_profile();begin return coalesce((select jsonb_agg(jsonb_build_object('token',g.token,'message',g.message,'status',g.status,'design',case when r.id is not null then notai_private.personalization(r) else null end,'variant_id',g.variant_id)) from public.gift_invitations g left join public.design_revisions r on r.id=g.revision_id where g.user_id=owner_id),'[]');end $$;
-- Only the server may create orders or process payments; ownership and catalog prices are derived here.
create function notai_private.prepare_order(p_auth_user uuid,p_revision uuid,p_variant uuid,p_quantity integer,p_shipping_minor bigint,p_referral text,p_key uuid,p_gift text default null,p_use_credit boolean default false) returns jsonb language plpgsql security definer set search_path='' as $$
declare owner_id uuid;v public.product_variants;r public.design_revisions;o public.orders;item_id uuid;source public.shirts;gift public.gift_invitations;available_credit bigint:=0;credit_used bigint:=0;begin
 select p.id into owner_id from public.profiles p join auth.users u on u.id=p.auth_user_id where u.id=p_auth_user and u.is_anonymous is false and p.archived_at is null;
 if owner_id is null then raise exception 'Registered account required' using errcode='42501';end if;
 if p_quantity is null or p_quantity not between 1 and 10 or p_shipping_minor is null or p_shipping_minor<0 or p_shipping_minor>100000 or p_key is null then raise exception 'Invalid order';end if;
 perform pg_advisory_xact_lock(hashtextextended(owner_id::text,0));
 select * into o from public.orders where user_id=owner_id and idempotency_key=p_key::text;
 if found then
  if not exists(select 1 from public.order_items where order_id=o.id and revision_id=p_revision and variant_id=p_variant and quantity=p_quantity) then raise exception 'Request key already used';end if;
  return to_jsonb(o);
 end if;
 if (select count(*) from public.orders where user_id=owner_id and created_at>now()-interval '1 hour')>=10 then raise exception 'Order rate limit reached';end if;
 select * into v from public.product_variants where id=p_variant and active;
 select * into r from public.design_revisions where id=p_revision and user_id=owner_id;
 if v.id is null or r.id is null or v.currency<>'USD' or v.color_key<>r.shirt_color then raise exception 'Choose an available matching variant and your own saved revision';end if;
 if p_gift is not null then
 select * into gift from public.gift_invitations where token=p_gift and user_id=owner_id and status='submitted' for update;
 if gift.id is null or gift.variant_id<>v.id or p_quantity<>1 or notai_private.personalization(r) is distinct from (select notai_private.personalization(gr) from public.design_revisions gr where gr.id=gift.revision_id) then raise exception 'Gift selection mismatch';end if;
 end if;
 if p_use_credit then
 select coalesce(sum(amount_minor),0) into available_credit from public.credit_ledger where user_id=owner_id and currency=v.currency;
 available_credit:=available_credit-(select coalesce(sum(credit_minor),0) from public.orders where user_id=owner_id and currency=v.currency and payment_status='pending');
 credit_used:=greatest(0,least(available_credit,v.price_minor*p_quantity,greatest(0,v.price_minor*p_quantity+p_shipping_minor-50)));
 end if;
 insert into public.orders(user_id,idempotency_key,currency,subtotal_minor,shipping_minor,credit_minor,total_minor,contact_email,shipping_address)
 select owner_id,p_key::text,v.currency,v.price_minor*p_quantity,p_shipping_minor,credit_used,v.price_minor*p_quantity+p_shipping_minor-credit_used,u.email,'{}' from auth.users u where u.id=p_auth_user returning * into o;
 insert into public.order_items(order_id,user_id,revision_id,variant_id,quantity,unit_price_minor,product_snapshot,personalization_snapshot)
 values(o.id,owner_id,r.id,v.id,p_quantity,v.price_minor,jsonb_build_object('product_name',v.product_name,'sku',v.sku,'color',v.color_key,'size',v.size_key),notai_private.personalization(r)) returning id into item_id;
 if gift.id is not null then update public.orders set gift_invitation_id=gift.id where id=o.id;update public.gift_invitations set status='buying' where id=gift.id;end if;
 insert into public.shirts(order_item_id,user_id,wearer_id,unit_number) select item_id,owner_id,gift.recipient_id,n from generate_series(1,p_quantity) n;
 select s.* into source from public.shirts s join public.order_items i on i.id=s.order_item_id join public.orders so on so.id=i.order_id join public.profiles sp on sp.id=coalesce(s.wearer_id,s.user_id) where s.qr_token=p_referral and s.qr_state='active' and so.payment_status='paid' and sp.archived_at is null and coalesce(s.wearer_id,s.user_id)<>owner_id and (gift.recipient_id is null or coalesce(s.wearer_id,s.user_id)<>gift.recipient_id);
 if source.id is not null and gift.id is null then insert into public.referral_attributions(order_id,buyer_id,referrer_id,source_shirt_id,currency) values(o.id,owner_id,coalesce(source.wearer_id,source.user_id),source.id,o.currency);end if;
 return to_jsonb(o);
end $$;
create function notai_private.process_payment(p_event text,p_order uuid,p_kind text,p_reference text,p_intent text,p_amount bigint,p_tax bigint,p_currency text,p_shipping jsonb) returns void language plpgsql security definer set search_path='' as $$
declare o public.orders;a public.referral_attributions;earned public.credit_ledger;begin
 if p_kind not in ('paid','refund','expired') or p_event is null or length(p_event)>200 then raise exception 'Unsupported payment event';end if;
 select * into o from public.orders where id=p_order for update;if o.id is null then raise exception 'Order not found';end if;
 if exists(select 1 from public.payment_events where provider='stripe' and provider_event_id=p_event) then return;end if;
 if p_currency is distinct from o.currency or p_amount is null or p_amount<0 then raise exception 'Payment mismatch';end if;
 if p_kind='paid' then
  if p_reference is distinct from o.stripe_session_id or p_intent is null or p_tax is null or p_tax<0 or p_amount<>o.subtotal_minor+o.shipping_minor+p_tax-o.credit_minor or jsonb_typeof(p_shipping) is distinct from 'object' or p_shipping='{}' then raise exception 'Paid amount, shipping or session mismatch';end if;
  if o.payment_status in ('pending','failed') then
   perform pg_advisory_xact_lock(hashtextextended(o.user_id::text,0));
   if o.credit_minor>0 then insert into public.credit_ledger(user_id,currency,amount_minor,kind,order_id,idempotency_key) values(o.user_id,o.currency,-o.credit_minor,'spend',o.id,'credit-spend:'||o.id::text) on conflict(idempotency_key) do nothing;end if;
   update public.orders set payment_status='paid',stripe_payment_intent=p_intent,tax_minor=p_tax,total_minor=p_amount,shipping_address=p_shipping,updated_at=now() where id=o.id;
   if o.gift_invitation_id is not null then update public.gift_invitations set status='paid' where id=o.gift_invitation_id;end if;
   update public.shirts set qr_state='active' where order_item_id in(select id from public.order_items where order_id=o.id);
   select * into a from public.referral_attributions where order_id=o.id for update;
   if a.id is not null and a.status='pending' then
    update public.referral_attributions set status='qualified',qualified_at=now() where id=a.id;
    insert into public.credit_ledger(user_id,currency,amount_minor,kind,order_id,attribution_id,idempotency_key) values(a.referrer_id,a.currency,a.reward_minor,'earn',o.id,a.id,'referral:'||a.id::text) on conflict(idempotency_key) do nothing;
    insert into public.network_edges(attribution_id) values(a.id) on conflict(attribution_id) do nothing;
   end if;
  end if;
 elsif p_kind='refund' then
  if p_intent is distinct from o.stripe_payment_intent or o.payment_status not in ('paid','partially_refunded','refunded') or p_amount>o.total_minor then raise exception 'Refund mismatch';end if;
  if p_amount>o.refunded_minor then
   update public.orders set refunded_minor=p_amount,payment_status=case when p_amount=o.total_minor then 'refunded' else 'partially_refunded' end,updated_at=now() where id=o.id;
   if p_amount=o.total_minor and o.credit_minor>0 then insert into public.credit_ledger(user_id,currency,amount_minor,kind,order_id,idempotency_key) values(o.user_id,o.currency,o.credit_minor,'refund',o.id,'credit-return:'||o.id::text) on conflict(idempotency_key) do nothing;end if;
   if p_amount=o.total_minor then update public.shirts set qr_state='disabled' where order_item_id in(select id from public.order_items where order_id=o.id);end if;
   select * into a from public.referral_attributions where order_id=o.id for update;
   if a.id is not null and a.status='qualified' then
    select * into earned from public.credit_ledger where attribution_id=a.id and kind='earn';
    if earned.id is not null then insert into public.credit_ledger(user_id,currency,amount_minor,kind,order_id,attribution_id,reverses_entry_id,idempotency_key) values(a.referrer_id,a.currency,-earned.amount_minor,'reversal',o.id,a.id,earned.id,'refund-referral:'||a.id::text) on conflict(idempotency_key) do nothing;end if;
    update public.referral_attributions set status='reversed' where id=a.id;update public.network_edges set hidden_at=now() where attribution_id=a.id;
   end if;
  end if;
 elsif p_kind='expired' then
  if p_reference is distinct from o.stripe_session_id then raise exception 'Session mismatch';end if;
  update public.orders set payment_status='failed',updated_at=now() where id=o.id and payment_status='pending';
  if o.gift_invitation_id is not null and o.payment_status='pending' then update public.gift_invitations set status='submitted' where id=o.gift_invitation_id;end if;
  update public.referral_attributions set status='rejected' where order_id=o.id and status='pending';
 end if;
 insert into public.payment_events(order_id,provider,provider_event_id,payment_reference,event_type,amount_minor,currency,processing_status,processed_at) values(o.id,'stripe',p_event,p_reference,p_kind,p_amount,p_currency,'processed',now());
end $$;

grant usage on schema notai_private to anon,authenticated,service_role;
revoke all on function notai_private.share_design(uuid,text) from public,anon,authenticated;
grant execute on function notai_private.share_design(uuid,text) to authenticated;
create function public.share_design(p_revision uuid,p_revoke text default null) returns text language sql security invoker set search_path='' as $$select notai_private.share_design(p_revision,p_revoke);$$;
revoke all on function public.share_design(uuid,text) from public,anon,authenticated;
grant execute on function public.share_design(uuid,text) to authenticated;
revoke all on function notai_private.read_share(text) from public,anon,authenticated;
grant execute on function notai_private.read_share(text) to anon,authenticated;
create function public.read_share(p_token text) returns jsonb language sql security invoker set search_path='' as $$select notai_private.read_share(p_token);$$;
revoke all on function public.read_share(text) from public,anon,authenticated;
grant execute on function public.read_share(text) to anon,authenticated;
revoke all on function notai_private.shirt_settings(uuid,text,boolean,boolean) from public,anon,authenticated;
grant execute on function notai_private.shirt_settings(uuid,text,boolean,boolean) to authenticated;
create function public.shirt_settings(p_id uuid,p_story text,p_story_public boolean,p_design_public boolean) returns void language sql security invoker set search_path='' as $$select notai_private.shirt_settings(p_id,p_story,p_story_public,p_design_public);$$;
revoke all on function public.shirt_settings(uuid,text,boolean,boolean) from public,anon,authenticated;
grant execute on function public.shirt_settings(uuid,text,boolean,boolean) to authenticated;
revoke all on function notai_private.read_shirt(text) from public,anon,authenticated;
grant execute on function notai_private.read_shirt(text) to anon,authenticated;
create function public.read_shirt(p_token text) returns jsonb language sql security invoker set search_path='' as $$select notai_private.read_shirt(p_token);$$;
revoke all on function public.read_shirt(text) from public,anon,authenticated;
grant execute on function public.read_shirt(text) to anon,authenticated;
revoke all on function notai_private.my_referrals() from public,anon,authenticated;
grant execute on function notai_private.my_referrals() to authenticated;
create function public.my_referrals() returns jsonb language sql security invoker set search_path='' as $$select notai_private.my_referrals();$$;
revoke all on function public.my_referrals() from public,anon,authenticated;
grant execute on function public.my_referrals() to authenticated;
revoke all on function notai_private.my_network() from public,anon,authenticated;
grant execute on function notai_private.my_network() to authenticated;
create function public.my_network() returns jsonb language sql security invoker set search_path='' as $$select notai_private.my_network();$$;
revoke all on function public.my_network() from public,anon,authenticated;
grant execute on function public.my_network() to authenticated;
revoke all on function notai_private.gift_invite(text,text) from public,anon,authenticated;
grant execute on function notai_private.gift_invite(text,text) to authenticated;
create function public.gift_invite(p_message text,p_close text default null) returns text language sql security invoker set search_path='' as $$select notai_private.gift_invite(p_message,p_close);$$;
revoke all on function public.gift_invite(text,text) from public,anon,authenticated;
grant execute on function public.gift_invite(text,text) to authenticated;
revoke all on function notai_private.read_gift(text) from public,anon,authenticated;
grant execute on function notai_private.read_gift(text) to anon,authenticated;
create function public.read_gift(p_token text) returns jsonb language sql security invoker set search_path='' as $$select notai_private.read_gift(p_token);$$;
revoke all on function public.read_gift(text) from public,anon,authenticated;
grant execute on function public.read_gift(text) to anon,authenticated;
revoke all on function notai_private.gift_reply(text,uuid,uuid) from public,anon,authenticated;
grant execute on function notai_private.gift_reply(text,uuid,uuid) to authenticated;
create function public.gift_reply(p_token text,p_revision uuid,p_variant uuid) returns void language sql security invoker set search_path='' as $$select notai_private.gift_reply(p_token,p_revision,p_variant);$$;
revoke all on function public.gift_reply(text,uuid,uuid) from public,anon,authenticated;
grant execute on function public.gift_reply(text,uuid,uuid) to authenticated;
revoke all on function notai_private.gift_submissions() from public,anon,authenticated;
grant execute on function notai_private.gift_submissions() to authenticated;
create function public.gift_submissions() returns jsonb language sql security invoker set search_path='' as $$select notai_private.gift_submissions();$$;
revoke all on function public.gift_submissions() from public,anon,authenticated;
grant execute on function public.gift_submissions() to authenticated;
revoke all on function notai_private.prepare_order(uuid,uuid,uuid,integer,bigint,text,uuid,text,boolean) from public,anon,authenticated;
grant execute on function notai_private.prepare_order(uuid,uuid,uuid,integer,bigint,text,uuid,text,boolean) to service_role;
create function public.prepare_order(p_auth_user uuid,p_revision uuid,p_variant uuid,p_quantity integer,p_shipping_minor bigint,p_referral text,p_key uuid,p_gift text default null,p_use_credit boolean default false) returns jsonb language sql security invoker set search_path='' as $$select notai_private.prepare_order(p_auth_user,p_revision,p_variant,p_quantity,p_shipping_minor,p_referral,p_key,p_gift,p_use_credit);$$;
revoke all on function public.prepare_order(uuid,uuid,uuid,integer,bigint,text,uuid,text,boolean) from public,anon,authenticated;
grant execute on function public.prepare_order(uuid,uuid,uuid,integer,bigint,text,uuid,text,boolean) to service_role;
revoke all on function notai_private.process_payment(text,uuid,text,text,text,bigint,bigint,text,jsonb) from public,anon,authenticated;
grant execute on function notai_private.process_payment(text,uuid,text,text,text,bigint,bigint,text,jsonb) to service_role;
create function public.process_payment(p_event text,p_order uuid,p_kind text,p_reference text,p_intent text,p_amount bigint,p_tax bigint,p_currency text,p_shipping jsonb) returns void language sql security invoker set search_path='' as $$select notai_private.process_payment(p_event,p_order,p_kind,p_reference,p_intent,p_amount,p_tax,p_currency,p_shipping);$$;
revoke all on function public.process_payment(text,uuid,text,text,text,bigint,bigint,text,jsonb) from public,anon,authenticated;
grant execute on function public.process_payment(text,uuid,text,text,text,bigint,bigint,text,jsonb) to service_role;


create table notai_private.ai_requests(id uuid primary key,user_id uuid not null references public.profiles(id),status text not null default 'reserved' check(status in ('reserved','completed','failed')),model text,provider_id text,suggestions jsonb,created_at timestamptz not null default now());
alter table notai_private.ai_requests enable row level security;create index on notai_private.ai_requests(user_id,created_at);
create function notai_private.reserve_ai(p_key uuid) returns void language plpgsql security definer set search_path='' as $$declare owner_id uuid:=notai_private.current_profile();begin
 perform pg_advisory_xact_lock(hashtextextended(owner_id::text,1));
 if (select count(*) from notai_private.ai_requests where user_id=owner_id and created_at>now()-interval '1 hour')>=10 then raise exception 'Please try wording help again later';end if;
 insert into notai_private.ai_requests(id,user_id) values(p_key,owner_id);
end $$;
revoke all on function notai_private.reserve_ai(uuid) from public,anon;grant execute on function notai_private.reserve_ai(uuid) to authenticated;
create function public.reserve_ai(p_key uuid) returns void language sql security invoker set search_path='' as $$select notai_private.reserve_ai(p_key);$$;
revoke all on function public.reserve_ai(uuid) from public,anon;grant execute on function public.reserve_ai(uuid) to authenticated;
create function notai_private.finish_ai(p_key uuid,p_model text,p_provider text,p_suggestions jsonb) returns void language sql security definer set search_path='' as $$update notai_private.ai_requests set model=p_model,provider_id=p_provider,suggestions=p_suggestions,status=case when p_suggestions is null then 'failed' else 'completed' end where id=p_key and status='reserved';$$;
revoke all on function notai_private.finish_ai(uuid,text,text,jsonb) from public,anon,authenticated;grant execute on function notai_private.finish_ai(uuid,text,text,jsonb) to service_role;
create function public.finish_ai(p_key uuid,p_model text,p_provider text,p_suggestions jsonb) returns void language sql security invoker set search_path='' as $$select notai_private.finish_ai(p_key,p_model,p_provider,p_suggestions);$$;
revoke all on function public.finish_ai(uuid,text,text,jsonb) from public,anon,authenticated;grant execute on function public.finish_ai(uuid,text,text,jsonb) to service_role;


create function notai_private.record_shipment(p_order uuid,p_carrier text,p_tracking text,p_key uuid,p_delivered boolean default false) returns uuid language plpgsql security definer set search_path='' as $$
declare o public.orders;shipment uuid;begin
 select * into o from public.orders where id=p_order and payment_status='paid' for update;if o.id is null then raise exception 'Only fully paid orders can be fulfilled';end if;
 if p_carrier is null or length(btrim(p_carrier)) not between 1 and 100 or p_tracking is null or length(btrim(p_tracking)) not between 1 and 150 or p_key is null or p_delivered is null then raise exception 'Carrier and tracking required';end if;
 select id into shipment from public.shipments where provider_shipment_id='manual:'||p_key::text and order_id=p_order;
 if shipment is null then
  if exists(select 1 from public.shipment_shirts ss join public.order_items i on i.id=(select order_item_id from public.shirts where id=ss.shirt_id) where i.order_id=p_order) then raise exception 'Order already has a shipment';end if;
  insert into public.shipments(order_id,user_id,carrier,tracking_number,provider_shipment_id,shipped_at,delivered_at) values(o.id,o.user_id,btrim(p_carrier),btrim(p_tracking),'manual:'||p_key::text,now(),case when p_delivered then now() else null end) returning id into shipment;
  insert into public.shipment_shirts(shipment_id,shirt_id,user_id) select shipment,s.id,s.user_id from public.shirts s join public.order_items i on i.id=s.order_item_id where i.order_id=o.id;
 else
  if p_delivered then update public.shipments set delivered_at=coalesce(delivered_at,now()) where id=shipment;end if;
 end if;
 update public.orders set fulfillment_status=case when p_delivered then 'delivered' else 'shipped' end,updated_at=now() where id=o.id;
 insert into public.order_events(order_id,event_type,details) values(o.id,'shipment_recorded',jsonb_build_object('shipment_id',shipment));return shipment;
end $$;
revoke all on function notai_private.record_shipment(uuid,text,text,uuid,boolean) from public,anon,authenticated;grant execute on function notai_private.record_shipment(uuid,text,text,uuid,boolean) to service_role;
create function public.record_shipment(p_order uuid,p_carrier text,p_tracking text,p_key uuid,p_delivered boolean default false) returns uuid language sql security invoker set search_path='' as $$select notai_private.record_shipment(p_order,p_carrier,p_tracking,p_key,p_delivered);$$;
revoke all on function public.record_shipment(uuid,text,text,uuid,boolean) from public,anon,authenticated;grant execute on function public.record_shipment(uuid,text,text,uuid,boolean) to service_role;

commit;
