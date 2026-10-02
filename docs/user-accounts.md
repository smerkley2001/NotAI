# User accounts implementation

Adds signup.html, signin.html, forgot-password.html, reset-password.html and account.html. The existing customizer links to My account. Supabase Auth handles email/password authentication, confirmation, recovery, refresh and sign-out. Profile setup and editing use the existing profiles table. Public handles are optional, normalized lowercase, and required by the UI when choosing public network visibility. Real names/emails are not public profile data.

The profile migration grants only insert of ownership/name/handle/visibility and update of name/handle/visibility to authenticated users. Ownership predicates and non-anonymous checks apply via RLS. Clients cannot set internal IDs, change auth_user_id, archive accounts or write orders. This narrowly scoped profile exception replaces server-only writes for these nonprivileged fields; all commerce writes retain the original restriction.

A publishable key is intentionally in browser configuration. No secret/service-role key is included. SDK and build dependencies are pinned with a lockfile. Browser callbacks use the Supabase-supported implicit flow and clear the fragment after initialization. Password changes require the current password on the account page; recovery uses the emailed session. Input is rendered using textContent, not HTML. Redirect destinations are allowlisted. Supabase rate limits apply; CAPTCHA remains a launch configuration consideration.

## Build and checks
- npm ci && npm run build && npm test
- npx playwright install chromium && npm run test:browser
- Optional CHROME_PATH specifies an existing Chromium executable.
- Browser tests mock all Supabase network requests, preventing emails and production writes.
- Database access tests were run with the migration inside a fully rolled-back transaction; tests cover own profile insert/update, ownership and archive protection, other-user isolation and anonymous rejection.
- Vercel preview builds block all account form submissions to avoid modifying production accounts. Local tests mock network requests. Production build enables forms.

## Required before production release
1. Apply account_profile_access migration; it has been prepared and rollback-tested, not deployed in this feature branch.
2. Supabase Auth URL configuration: production Site URL should be the canonical HTTPS site. Allow the exact account.html and reset-password.html redirect URLs on the production hostname(s). No broad wildcard over untrusted domains. Current application sends the current origin for callbacks.
3. Verify SMTP/custom email delivery and sender configuration. Public Auth settings confirm email signups enabled, confirmations required, anonymous users disabled. The connector did not expose Site URL/redirect/SMTP settings for verification. Test a real signup confirmation and password recovery using a designated test mailbox before launch.
4. Review the Vercel preview, then merge/deploy the app commit. Existing /api/generate-preview remains in the root api directory; smoke-test its method handling after deployment without paid generation.
5. Merge prerequisite schema/workflow PRs first or retarget the stacked branch accordingly. Do not reapply the two already-deployed schema migrations.

No real signup email was sent, no real customer credentials were used, and profile permissions were not changed persistently during implementation. Design-management pages, avatar upload, email-address change, account deletion/anonymization, public network rendering and checkout remain separate features. Account deletion must respect retained orders and ledger history.

Rollback: revert the frontend feature commit. To withdraw profile editing, revoke its column grants and drop only the new insert/update policies using a follow-up migration. Preserve profiles and Auth users; do not drop tables or delete accounts to revert this feature.
