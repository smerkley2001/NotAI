# Database deployment — 2026-10-02

Deployed to the existing NotAI Supabase project, on user instruction.

Applied migrations:
- 20261002233722 initial_notai_schema
- 20261002233815 index_ownership_keys

Before application, tested the complete schema and synthetic fixtures in a transaction rolled back in full on the target database. Verified service-role registered orders, anonymous buyer rejection, Alice/Bob design isolation, own-order reads, blocked direct client writes, and immutable design revisions. No fixtures remain.

Post-deployment: 15 public tables, RLS enabled on all. Performance recheck has no missing-FK-index or auth-initplan findings. Unused-index notices are expected for a new empty database. Security report has four informational RLS-without-policy notices for intentionally server-only network_edges, order_events, payment_events and referral_attributions. These have no anon/authenticated table grants; do not add permissive policies just to silence notices.

The registered-buyer trigger uses a SECURITY DEFINER function in the unexposed notai_private schema, fixed empty search_path, no PUBLIC/anon/authenticated execute grant, validates an Auth UID when present, and checks an active non-anonymous Auth account. Service-role endpoints must independently authenticate the caller and derive ownership.

Website, Auth providers, storage buckets, product prices and checkout were not changed. Saved-design and login screens still need implementation. Runtime tests cover the schema/access smoke cases, not unimplemented payment/idempotency/concurrency application flows.

Rollback: retain populated tables and issue forward repair migrations. GitHub filenames now exactly match Supabase migration versions. Schema files do not back up user data; establish backups before real orders.

Security notice explanation: https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy
