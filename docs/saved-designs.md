# Saved designs and member pages

Adds a named design library, editor save/copy/revision restore controls, reversible archive, order history/details, credit history, and a private Human Network landing page with owned shirt status. All reads use the signed-in user's RLS policies. Anonymous visitors can customize; signing in and completing a profile is required to persist a design. Unsaved personalization is retained in session storage through sign-in. No guest order creation is introduced.

Saved design writes use an additive migration with owner-derived, fixed-search-path private functions and public invoker wrappers. Save locks the design row and compares the expected revision before appending an immutable revision. Restoring earlier personalization appends a new revision. Archiving never deletes designs/revisions. Copies receive a new design identity. Server validation restricts supported fonts, icons, colors, and line lengths. No prices or order/payment states are writable from these pages.

## Rollout

This feature stacks on feat/user-accounts. Both the pending account_profile_access migration and saved_design_workflows migration must be applied through the migration deployment workflow before enabling production writes. This work does not apply either migration to production. SQL verification runs proposed DDL plus synthetic fixtures in a transaction ending ROLLBACK, preserving the existing database. Preview builds disable profile/design mutations; do not enable production writes merely to test preview UI.

Order pages show actual stored purchase snapshots/statuses and shipment identifiers; they do not place orders. Credit balances are recorded ledger totals per currency; checkout redemption remains unimplemented. The Human Network landing page shows owned shirt status and explains privacy; public connections, active QR routing, referral qualification and payment/fulfillment integrations remain future work. No fabricated public graph is shown. Credit ledger pagination prevents a default 1000-row API cap from silently truncating the balance.

## Validation and revert

npm run build; npm test; CHROME_PATH=/tmp/chromium npm run test:browser. Browser tests mock all Supabase requests and verify save/revision increments, archive/restore, member navigation, empty-state pages, responsive width, and account regression flows. SQL tests verify conflict rejection, supported personalization, archive/restore, owner isolation, blocked direct revision edits, and anonymous rejection. No paid image generation or real email is invoked.

Revert the application commit to return to the account-only UI. Leave immutable design rows/revisions and migration functions in place; do not drop user data. Production rollout should record the deployment and migration versions. This change keeps the image-generation endpoint unchanged and does not set preview API secrets.
