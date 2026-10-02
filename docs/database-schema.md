# NotAI database proposal — 2026-10-02

Status: draft, not applied. Read-only inspection of the NotAI project found no public tables or migration history. Auth and Storage are managed Supabase schemas and are not replaced by this migration.

## Saved designs
A registered user can create any number of named designs, revisit them, duplicate them, and archive them. Each explicit save creates an immutable design_revisions row. A design contains a title and ownership; its latest revision_number is the current version. Revision numbering is allocated in a server transaction that locks the design row. An expected revision number prevents silently overwriting another tab's changes. Restoring an older revision makes a new revision rather than rewriting history. Debounce editing locally; save explicit revisions rather than storing every keystroke.

Each revision stores two tag lines (current UI limit: 32 characters each), a stable icon key, font key, accent, shirt color, layout JSON, and format version. Stable icon keys such as soccer refer to a versioned artwork library, rather than depending on a device's emoji font. Font keys are mapped to licensed production font assets. Product sizes are chosen for each order item, not built into a reusable design. Empty tag lines are allowed.

Draft designs are private. Soft archives retain purchased revisions. Duplicate designs receive a new ID and their own revision sequence. Sharing designs publicly is a separate later feature, not implicit in saving.

## Tables
| Table | Purpose |
|---|---|
| profiles | Internal permanent identity, nullable unique Auth link, name, optional lowercase unique handle, avatar path, network visibility (private by default) |
| designs | Named, user-owned editable project, timestamps and archive flag |
| design_revisions | Immutable personalization versions, with composite ownership foreign keys |
| design_assets | Artwork/preview files attached to exact revisions, rendering version and optional generation metadata |
| product_variants | Server-owned SKU, size, color, price, currency and fulfillment-provider mapping |
| orders | Registered buyer, sequential order number, idempotency key, monetary totals, payment/fulfillment states, contact and address snapshots |
| order_items | Quantity, variant and exact purchased design/production snapshots; immutable |
| shirts | One row per physical shirt, random unique QR token and activation state |
| shipments / shipment_shirts | Multiple shipments per order with actual individual-shirt membership |
| referral_attributions | At most one credited source shirt/referrer per order; excludes self-referral, stores reward-rule version |
| network_edges | Directed inspiration connection derived from an attribution, separate from credits |
| credit_ledger | Append-only amounts in integer minor units, idempotency keys and compensating entries |
| payment_events | Deduplicated provider events, payment references, processing/retry state; no card details |
| order_events | Internal order status/audit history |

## Identity, privacy and access
Supabase Auth holds login emails, identity providers and passwords; application profiles do not store passwords. Names are not unique. A profile retains its independent internal ID if the Auth account is deleted; access disappears when the Auth link becomes null. Account deletion/anonymization and retention periods need a deliberate workflow before launch.

Every order must have a profile linked to a non-anonymous Auth user. A database insert trigger rejects orders for detached, archived or anonymous profiles. Anonymous sign-in is not a registered account. The server must separately verify the request's current authenticated user and derive profile ownership; the service role bypasses RLS, so the trigger alone does not authenticate a browser request.

All application tables have RLS enabled. Users can read their own profiles, designs, revisions, assets, orders, shirts, shipments and credit entries. Public users can read active catalog variants only. All writes initially go through authenticated server endpoints. Payment events, attribution and network tables remain server-only. This keeps a public graph from exposing orders or customer identifiers. Public QR/profile responses will be explicitly whitelisted projections with user consent; no email/address disclosure. An opted-in graph needs both participants' visibility checked before publication.

Storage buckets and policies are not created in this proposal. Art and previews must use private storage with ownership-checked signed URLs and immutable/versioned paths. Never persist expiring signed URLs as permanent file identifiers; store bucket/path and content hash instead. QR access is a public lookup identifier, never an authorization credential.

## Orders and fulfillment
The server selects catalog variants and verifies color/size compatibility, price, currency and ownership. It copies the exact selected revision into an immutable order-item snapshot, including line1, line2, icon/font/asset versions, accent, shirt color, layout, and artwork checksums. Future edits do not modify the order. Artwork_snapshot stores production file references; production readiness must be validated before fulfillment.

A checkout transaction validates and totals order items, discounts, taxes, shipping and available credits. The database verifies nonnegative order amounts and the total equation. Cross-table sum/currency checks and allocation are mandatory backend logic, not fully enforced by this initial DDL. Lock a user's credit account (profile row) while spending credits; calculate balance per currency and append a debit in the same transaction to prevent double spending. Do not trust totals sent by a browser.

Webhook handling verifies the provider signature, records its unique event ID, and updates payment/order/referral state transactionally. Store minimal event facts, not full raw payloads with unnecessary personal/payment data. A received or failed event is retryable; a processed event is not applied twice. A redirect never proves payment.

Create quantity shirt rows with unit_number 1..quantity. The server enforces that count; QR codes activate only under the qualifying production/payment policy. Shipment rows refer to shirts belonging to the same order (enforce in server transaction); the initial foreign keys enforce shared ownership but not same-order membership. Exchanges/reshipments need a follow-up migration; no speculative returns subsystem is included yet.

## Human Network and credits
An attribution captures the referring physical shirt, referrer, buyer, order, reward amount, currency and rule version. Server logic freezes attribution when checkout starts and verifies the source QR is active. No self-referral or browser-written rewards.

Recommended launch rule: $3 USD per qualifying referred order, not per shirt. It is snapshotted, not hardwired into account balances. Qualification timing, partial refunds, abuse checks, attribution window and credit expiration remain product decisions before reward automation. Until agreed, rewards stay pending.

A qualified order can create an inspiration edge and a credit entry once. The server verifies the ledger recipient/currency match attribution and uses stable idempotency keys. Refund/reversal uses a compensating ledger entry; never erase the original. The inspiration relationship can remain even when a monetary reward reverses. Edge visibility is separate from financial qualification. Repeated purchases can yield repeated order-level edges; the graph UI can aggregate them without altering records.

## Rollout and verification
The migration is additive and wrapped in a transaction; collisions fail rather than silently accepting incompatible existing tables. No seed prices or variant choices are inserted until production product selection is confirmed. No website, Auth setting or production schema has been changed.

Before applying: test this migration in an isolated Supabase/Postgres environment, check foreign keys/triggers/grants/RLS, and run advisors. Required cases: Alice cannot read Bob's designs/orders; unauthenticated and anonymous accounts cannot order; saved edits preserve ordered revisions; invalid ownership fails; duplicate payment events do not double-credit; concurrent saves/spends conflict safely; snapshots and currency sums remain correct.

Static parsing is only a preliminary check. The DDL is not approval-ready for deployment until isolated runtime and access-control tests pass. The website will need account login, My Designs, save/load/duplicate/archive endpoints and checkout integration; a schema alone does not add these screens.

Rollback: before data exists an isolated test database may be discarded. For production, disable affected app features or revert compatible code; preserve tables and records and issue forward repair migrations. Do not run DROP TABLE to undo a deployment containing orders/users/credits. GitHub history preserves schema definitions, not database backups. Establish data backups before live orders.
