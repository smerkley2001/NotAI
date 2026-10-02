# NotAI project instructions and baseline

## Required change workflow
- Preserve version history in smerkley2001/NotAI. Make each logical change a focused commit on a feature/fix/docs branch and open a pull request with behavior, checks, and rollback notes.
- Do not force-push shared history or replace history with git reset. Revert deployed changes with new git revert commits so history remains intact.
- Review and verify changes before production deployment. A request to prepare changes does not itself require merging to main.
- Keep baseline/2026-10-02 at fda6c1d55d63aeeea6989e42d5f44587185e695c as the initial preserved checkpoint.
- At releases record the exact commit, Vercel deployment, validation, and any database migrations. Use release tags where supported.
- Never commit secrets, credentials, customer data, or local environment files. This repository is public.
- Keep Supabase migration SQL in supabase/migrations. Prefer additive, backward-compatible changes that preserve production data; never reset the database to deploy a schema change.
- Application rollback does not undo database migrations, payments, or fulfilled orders. Coordinate compatibility before reverting code; back up before any destructive data migration.
- Use Vercel preview deployments for review; use test-mode payment credentials and a separate test database for writes in previews. Do not let previews fulfill production orders.
- Check for existing AGENTS.md instructions before editing.

## Code map inspected 2026-10-02
Baseline commit: fda6c1d55d63aeeea6989e42d5f44587185e695c.
- index.html: current lowercase entry point. Inline CSS and browser JavaScript; no React/Next.js build system.
- Customizer: two text lines (32 characters each), five fonts, eight accents, ten emoji symbols, four shirt colors, front/back views, XS through 2XL.
- Eight canonical shirt PNG assets exist. Charcoal files ending in -1 are duplicate assets.
- Price displayed: $27.99. Referral promise displayed: $3 store credit.
- Create My Shirt only opens a "Checkout is coming soon" alert. Size has no ID and is not sent anywhere.
- Back QR is a CSS checkerboard, not a scannable QR. /s/7F3K is sample copy, not an implemented route.
- AI preview: browser fetches selected blank front image, generates transparent 1024x1024 artwork in canvas, posts design and image data URLs to /api/generate-preview, and shows returned image.
- api/generate-preview.js: intended lowercase Vercel function. Uses native fetch, Blob, FormData and server-side OPENAI_API_KEY to call OpenAI image edits.
- Api/generate-preview.js: older case-sensitive duplicate with different multipart image field names. Avoid editing both blindly.
- Index.html and index-3.html: older customizer variants. Preserve until dependencies/links are checked and removal is reviewed.
- README.md: minimal hosting and brand description.
- NotAI-vercel-starter.zip: historical starter archive, not the authoritative working source.
- No package.json, automated test suite, checkout backend, Supabase client, database migrations, order persistence, referral ledger, account system, or fulfillment integration exists in the tracked baseline.
- No current vercel.json; it was deleted in commit 10ef11a.

## Deployment baseline
Verified through the connected Vercel app:
- Project: not-ai-just-i (prj_Tp0u7lF8RM4erYznl1GeCtO0NsH2).
- Latest production deployment: dpl_DhmR5GVcifYeMzW7DBpfbVxJTd1r, READY, same baseline GitHub commit from main.
- Assigned custom domains: notaijusti.com and www.notaijusti.com.
- Node version: 24.x; framework: null.
- Vercel authentication protection applies except on custom domains.
- Domain assignment/READY do not establish end-to-end app health, DNS verification, or functioning AI generation.
- Environment variable presence and ability to mutate Vercel settings have not been verified.

## Findings requiring future verification
- AI model identifier is hard-coded to gpt-image-2.5-sunburst. Verify current supported models in official provider documentation before changing it; no live paid generation was attempted.
- AI endpoint has a body-size check but no application authentication, rate limit, quota, or durable generation record. Address before promoting a public paid API feature.
- Native browser named-element globals are used instead of explicit DOM lookups. Replace deliberately when editing relevant UI.
- Canvas artwork is separate from DOM preview; wrapping and proportions can differ. It is not yet verified production print artwork; emoji/font rendering varies by platform.
- AI preview does not clear on design changes and can show an older design.
- Labels and generated selection buttons need accessibility review.
- Customer data and payment state must be stored server-side; do not trust browser prices or mark orders paid from a redirect alone.

## Next implementation sequence
1. Verify deployed UI and API behavior and settle the canonical files.
2. Add order/design schema with additive migrations, and durable server-side order creation.
3. Implement Stripe test checkout with server-owned prices and verified, idempotent webhooks.
4. Verify one full test order through a manually reviewable fulfillment handoff.
5. Add actual unique QR routes and referral accounting with reversals for refunds.
6. Broaden Human Network/accounts and improve optional AI previews after the first order path works.

## Rollback
For an application incident, restore a known-good Vercel production deployment if authorized and supported, then revert the offending merged commit(s) through a pull request. Vercel promotion alone leaves GitHub unchanged, so reconcile the code afterward. Retest the public page, API, and any affected order/webhook flows. Retain payment and order records and assess database compatibility separately.

## Baseline checks
Passed JavaScript syntax checks for inline index.html script and both preview functions. All eight canonical shirt image paths resolve to tracked assets. These are static checks only; they do not verify live API credentials, payment behavior, or print accuracy.
