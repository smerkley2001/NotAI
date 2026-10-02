-- Proposal only: review and test in isolated Postgres/Supabase before deployment.
-- Additive migration. Does not change auth configuration or existing records.
begin;
create table public.profiles (
 id uuid primary key default gen_random_uuid(),
 auth_user_id uuid unique references auth.users(id) on delete set null,
 full_name text not null check (char_length(full_name) between 1 and 200),
 handle text unique check (handle ~ '^[a-z0-9_]{3,30}$'),
 avatar_path text,
 network_visibility text not null default 'private' check (network_visibility in ('private','public')),
 created_at timestamptz not null default now(), archived_at timestamptz
);
create table public.designs (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references public.profiles(id),
 name text not null default 'Untitled design' check (char_length(name) between 1 and 120),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 archived_at timestamptz, unique(id,user_id)
);
create table public.design_revisions (
 id uuid primary key default gen_random_uuid(),
 design_id uuid not null, user_id uuid not null,
 revision_number integer not null check (revision_number > 0),
 line1 text not null default '' check (char_length(line1)<=32),
 line2 text not null default '' check (char_length(line2)<=32),
 icon_key text not null, font_key text not null,
 accent_color text not null check (accent_color ~ '^#[0-9A-Fa-f]{6}$'),
 shirt_color text not null, format_version integer not null default 1 check (format_version>0),
 layout jsonb not null default '{}' check (jsonb_typeof(layout)='object'),
 created_at timestamptz not null default now(),
 foreign key (design_id,user_id) references public.designs(id,user_id),
 unique(design_id,revision_number), unique(id,user_id)
);
create table public.design_assets (
 id uuid primary key default gen_random_uuid(), revision_id uuid not null,
 user_id uuid not null, kind text not null check (kind in ('front_artwork','back_artwork','preview','ai_preview')),
 storage_bucket text not null, storage_path text not null, sha256 text,
 mime_type text not null, width_px integer check (width_px>0), height_px integer check (height_px>0),
 renderer_version text, provider_generation_id text, created_at timestamptz not null default now(),
 foreign key(revision_id,user_id) references public.design_revisions(id,user_id),
 unique(storage_bucket,storage_path)
);
create table public.product_variants (
 id uuid primary key default gen_random_uuid(), sku text unique not null,
 product_name text not null, color_key text not null, size_key text not null,
 currency text not null default 'USD' check (currency ~ '^[A-Z]{3}$'),
 price_minor bigint not null check(price_minor>=0), active boolean not null default true,
 fulfillment_provider text, provider_variant_id text, created_at timestamptz not null default now()
);
create table public.orders (
 id uuid primary key default gen_random_uuid(), order_number bigint generated always as identity unique,
 user_id uuid not null references public.profiles(id),
 idempotency_key text not null, unique(user_id,idempotency_key), unique(id,user_id),
 currency text not null default 'USD' check(currency ~ '^[A-Z]{3}$'),
 subtotal_minor bigint not null check(subtotal_minor>=0), shipping_minor bigint not null default 0 check(shipping_minor>=0),
 tax_minor bigint not null default 0 check(tax_minor>=0), discount_minor bigint not null default 0 check(discount_minor>=0),
 credit_minor bigint not null default 0 check(credit_minor>=0), total_minor bigint not null check(total_minor>=0),
 check(total_minor=subtotal_minor+shipping_minor+tax_minor-discount_minor-credit_minor),
 payment_status text not null default 'pending' check(payment_status in ('pending','paid','failed','partially_refunded','refunded')),
 fulfillment_status text not null default 'unfulfilled' check(fulfillment_status in ('unfulfilled','in_production','partially_shipped','shipped','delivered','cancelled')),
 contact_email text not null, shipping_address jsonb not null check(jsonb_typeof(shipping_address)='object'),
 billing_address jsonb check(jsonb_typeof(billing_address)='object'),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.order_items (
 id uuid primary key default gen_random_uuid(), order_id uuid not null, user_id uuid not null,
 revision_id uuid not null, variant_id uuid not null references public.product_variants(id),
 quantity integer not null check(quantity between 1 and 1000),
 unit_price_minor bigint not null check(unit_price_minor>=0),
 product_snapshot jsonb not null check(jsonb_typeof(product_snapshot)='object'),
 personalization_snapshot jsonb not null check(jsonb_typeof(personalization_snapshot)='object'),
 artwork_snapshot jsonb not null default '{}' check(jsonb_typeof(artwork_snapshot)='object'),
 created_at timestamptz not null default now(),
 foreign key(order_id,user_id) references public.orders(id,user_id),
 foreign key(revision_id,user_id) references public.design_revisions(id,user_id), unique(id,user_id)
);
create table public.shirts (
 id uuid primary key default gen_random_uuid(), order_item_id uuid not null, user_id uuid not null,
 unit_number integer not null check(unit_number>0),
 qr_token text not null unique default replace(gen_random_uuid()::text,'-',''),
 qr_state text not null default 'pending' check(qr_state in ('pending','active','disabled')),
 created_at timestamptz not null default now(),
 foreign key(order_item_id,user_id) references public.order_items(id,user_id),
 unique(order_item_id,unit_number), unique(id,user_id)
);
create table public.shipments (
 id uuid primary key default gen_random_uuid(), order_id uuid not null, user_id uuid not null,
 carrier text, tracking_number text, tracking_url text,
 provider_shipment_id text unique, shipped_at timestamptz, delivered_at timestamptz,
 foreign key(order_id,user_id) references public.orders(id,user_id), unique(id,user_id)
);
create table public.shipment_shirts (
 shipment_id uuid not null, shirt_id uuid primary key, user_id uuid not null,
 foreign key(shipment_id,user_id) references public.shipments(id,user_id),
 foreign key(shirt_id,user_id) references public.shirts(id,user_id)
);
create table public.referral_attributions (
 id uuid primary key default gen_random_uuid(), order_id uuid not null unique,
 buyer_id uuid not null, referrer_id uuid not null,
 source_shirt_id uuid not null,
 reward_minor bigint not null default 300 check(reward_minor>=0),
 currency text not null default 'USD' check(currency ~ '^[A-Z]{3}$'),
 rule_version text not null default 'v1-per-order',
 status text not null default 'pending' check(status in ('pending','qualified','rejected','reversed')),
 attributed_at timestamptz not null default now(), qualified_at timestamptz,
 check(buyer_id<>referrer_id),
 foreign key(order_id,buyer_id) references public.orders(id,user_id),
 foreign key(source_shirt_id,referrer_id) references public.shirts(id,user_id)
);
create table public.network_edges (
 id uuid primary key default gen_random_uuid(), attribution_id uuid not null unique references public.referral_attributions(id),
 -- Derived from attribution; endpoint user IDs are not duplicated here.
 created_at timestamptz not null default now(), hidden_at timestamptz
);
create table public.credit_ledger (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references public.profiles(id),
 currency text not null default 'USD' check(currency ~ '^[A-Z]{3}$'), amount_minor bigint not null check(amount_minor<>0),
 kind text not null check(kind in ('earn','spend','refund','reversal','adjustment')),
 order_id uuid references public.orders(id), attribution_id uuid references public.referral_attributions(id),
 reverses_entry_id uuid references public.credit_ledger(id), idempotency_key text not null unique,
 created_at timestamptz not null default now(),
 check((kind in ('earn','refund') and amount_minor>0) or (kind in ('spend','reversal') and amount_minor<0) or kind='adjustment')
);
create table public.payment_events (
 id uuid primary key default gen_random_uuid(), order_id uuid references public.orders(id),
 provider text not null, provider_event_id text not null, unique(provider,provider_event_id),
 payment_reference text, event_type text not null,
 amount_minor bigint check(amount_minor>=0), currency text check(currency ~ '^[A-Z]{3}$'),
 processing_status text not null default 'received' check(processing_status in ('received','processed','failed')),
 error_code text, received_at timestamptz not null default now(), processed_at timestamptz
);
create table public.order_events (
 id uuid primary key default gen_random_uuid(), order_id uuid not null references public.orders(id),
 actor_id uuid references public.profiles(id), event_type text not null,
 details jsonb not null default '{}' check(jsonb_typeof(details)='object'),
 created_at timestamptz not null default now()
);
-- Prevent service-side creation of orders for detached/deleted or anonymous accounts.
create function public.notai_require_registered_buyer() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
 if not exists(select 1 from public.profiles p join auth.users u on u.id=p.auth_user_id
               where p.id=new.user_id and u.is_anonymous is false and p.archived_at is null) then
  raise exception 'Order requires a registered account';
 end if;
 return new;
end $$;
revoke all on function public.notai_require_registered_buyer() from public, anon, authenticated;
create trigger orders_registered_buyer before insert on public.orders
for each row execute function public.notai_require_registered_buyer();
-- Append-only revisions and financial history. Back-office corrections use new rows.
create function public.notai_immutable_record() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin raise exception 'Record is immutable; create a new revision or compensating entry'; end $$;
revoke all on function public.notai_immutable_record() from public, anon, authenticated;
create trigger revision_immutable before update or delete on public.design_revisions
for each row execute function public.notai_immutable_record();
create trigger credit_immutable before update or delete on public.credit_ledger
for each row execute function public.notai_immutable_record();
create trigger item_immutable before update or delete on public.order_items
for each row execute function public.notai_immutable_record();
-- Default-deny all application tables; only narrowly defined client reads are granted.
do $$
declare t text;
begin
 foreach t in array array['profiles','designs','design_revisions','design_assets','product_variants','orders','order_items','shirts','shipments','shipment_shirts','referral_attributions','network_edges','credit_ledger','payment_events','order_events'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('revoke all on table public.%I from anon, authenticated',t);
 execute format('grant select, insert, update, delete on table public.%I to service_role',t);
 end loop;
end $$;
grant usage, select on sequence public.orders_order_number_seq to service_role;
grant select on public.profiles to authenticated;
create policy own_profile on public.profiles for select to authenticated
using(auth_user_id=(select auth.uid()) and (select (auth.jwt()->>'is_anonymous')::boolean) is false);
-- Server writes handle saving, revision concurrency, archives, and checkout transactions.
do $$
declare t text;
begin
 foreach t in array array['designs','design_revisions','design_assets','orders','order_items','shirts','shipments','shipment_shirts','credit_ledger'] loop
 execute format('grant select on table public.%I to authenticated',t);
 execute format('create policy own_rows on public.%I for select to authenticated using (user_id in (select id from public.profiles where auth_user_id=(select auth.uid())))',t);
 execute format('create index on public.%I(user_id)',t);
 end loop;
end $$;
grant select on public.product_variants to anon, authenticated;
create policy active_catalog on public.product_variants for select to anon, authenticated using(active);
-- Network, attribution, webhook payloads and internal order events remain server-only.
create index on public.design_revisions(design_id,created_at desc);
create index on public.design_assets(revision_id);
create index on public.orders(user_id,created_at desc);
create index on public.order_items(order_id);
create index on public.order_items(revision_id);
create index on public.order_items(variant_id);
create index on public.shirts(order_item_id);
create index on public.shipments(order_id);
create index on public.shipment_shirts(shipment_id);
create index on public.referral_attributions(referrer_id);
create index on public.referral_attributions(source_shirt_id);
create index on public.credit_ledger(order_id);
create index on public.credit_ledger(attribution_id);
create index on public.credit_ledger(reverses_entry_id);
create index on public.payment_events(order_id);
create index on public.order_events(order_id,created_at);
create index on public.order_events(actor_id);
commit;
