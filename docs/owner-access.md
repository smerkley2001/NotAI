# Owner access management

/owner-access.html is linked from the owner dashboard. A protected API verifies the current user and owner membership for every request. Existing confirmed non-anonymous, non-banned accounts can be granted full owner access; no new accounts are created. Grants do not use editable user metadata for authorization.

Search uses email/profile name/handle prefixes, a minimum of two characters, and a maximum of 100. The database returns at most 20 users with an opaque UUID keyset cursor; it never sends the full customer directory to the browser. Current owners have a separate paginated view. Confirmation names the exact selected email and explains privileges or self-removal. Last-owner removal is disabled in the UI and enforced by SQL.

Migration 20261003032410_owner_access_management adds a private audit table, scoped directory and mutation RPCs, and a last-owner delete trigger. Mutation RPCs take a shared transaction advisory lock and re-check the actor membership after locking. The delete trigger takes the same lock and rejects deletion when only one owner remains. Concurrent access changes are serialized; removal of an actor while they wait cannot grant stale privileges. Repeat grants/removals are idempotent and only actual changes produce an audit event. Current page displays the latest 20 events with actor, target and time.

The private SECURITY DEFINER functions use an empty search_path and explicitly check auth.uid against protected membership. Public wrappers are SECURITY INVOKER, executable only by authenticated users. The private audit table has RLS, no client grants and no direct policies. No service key is required for this page. Preview mutations retain the existing isolated database/test environment guard.

Tests: existing unit suite/build; transactional real-database grant, revoke, idempotency, last-owner protection, unconfirmed-account rejection, audit and non-owner denial, with rollback; browser search/paging/cancel/confirm/grant/revoke/last-owner UI/mobile. No real user privileges were changed by tests. The lock is shared across all supported mutation paths; actual concurrent production role changes were not initiated during tests.

Rollback: revert the application PR to 0059b52487b4f7c3ef1bb65da07cc2a817b4a228; keep the database safeguards and audit history. Database administrators remain privileged and can disable triggers; the last-owner invariant applies to the supported dashboard and deletion paths, not destructive database administrator operations.

Existing leaked-password protection warning remains a follow-up: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection. Security advisor reports the private audit table has RLS with no policies; this is intentional because access is scoped through checked RPCs.
