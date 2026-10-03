# Owner ordering and payment setup

The owner dashboard at /owner.html is discoverable under Orders, credits & more only for a registered shop owner. Each backend request verifies the bearer token with Supabase and checks an RLS-protected shop_owners membership. Members cannot self-enroll; a privileged operator enrolls an existing confirmed non-anonymous Auth account. The production owner was enrolled separately from the migration; no account identifiers or customer data are committed.

Migration 20261003031228_owner_shop_controls adds shop_owners and service-only shop_settings. It preserves existing products, orders and payment records. Settings default to closed ordering. Public shop-status exposes only availability, shipping and fulfillment messaging, never credentials.

Owner pages manage per-color/size product records, USD prices, supplier references, activity, shipping and fulfillment text. The server owns pricing; order preparation snapshots immutable design/product data. Existing paid orders can enter production, then use /fulfillment.html to download a private ZIP with shipping details, artwork and one QR per physical shirt. Shipment recording is restricted to paid orders and real carrier handoff. This is manual fulfillment, not automatic supplier submission. Refunds are initiated through Stripe and reconciled by existing signed webhooks.

Secrets stay in Vercel environment variables. Dashboard provides direct settings links and boolean readiness indicators, but never accepts, stores or reveals secret keys. Configure SUPABASE_SERVICE_ROLE_KEY, STRIPE_SECRET_KEY (sk_ or appropriately scoped rk_), STRIPE_WEBHOOK_SECRET and NOTAI_CHECKOUT_ENABLED=true. Production also requires a live key; previews require an isolated database, test key, explicit write opt-in, and HTTPS return origin. Shipping is now read from shop_settings, not NOTAI_SHIPPING_MINOR; owner membership supersedes NOTAI_ADMIN_USER_IDS.

Stripe: complete account activation and banking; configure Stripe Tax; add endpoint https://www.notaijusti.com/api/stripe-webhook with checkout.session.completed, checkout.session.async_payment_succeeded, checkout.session.expired, checkout.session.async_payment_failed and charge.refunded. Save the matching signing secret to Vercel and redeploy. Hosted Checkout needs no browser publishable key or pre-created Stripe Price because line items use server-owned catalog prices. Add actual fulfillment products and review real garment size/print details before opening orders.

Closing new ordering no longer disables webhook processing or fulfillment. Never mark paid from a browser redirect. Existing webhook signature, payment amount and currency checks and transactional deduplication remain intact. No new card details are stored by the app.

Verification: build and 17 unit tests; customer browser flows; owner setup/catalog/shipping/production controls, non-owner denial, mobile overflow; database membership and mutation privilege tests. No real Stripe credentials or complete test payment were available, so live payment, Stripe Tax, webhook delivery and supplier print quality remain setup-dependent.

Rollback: revert feature PR to main 15ba97e185bfff183619ab15f58e0fe4f18beff9. Keep additive tables and existing customer records. If restoring old checkout code, retain NOTAI_CHECKOUT_ENABLED=false until reviewing its legacy environment configuration. Existing payments require webhook compatibility before any rollback.

Security advisor: shop_settings has deliberately no client policies and no anonymous/authenticated grants; owner membership uses a self-read-only policy. Existing leaked-password-protection warning remains: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection.
