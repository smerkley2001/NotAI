# Personal photo preview

The editor offers “See it on me” inside the existing preview panel. Sign-in and a completed profile are required. Users confirm they are adults and the photo is their own, then send it to OpenAI for an illustrative preview. This does not predict fit or replace a print proof.

Photos are resized to at most 1024 pixels and re-encoded as JPEG in the browser, stripping metadata. The original and result are not stored in application storage or the database. References are held in page memory and cleared on navigation/removal. Provider retention policies still apply. Results can be downloaded explicitly.

The API validates authentication, consent, fields, image signatures and request size. It reserves an attempt before calling the provider. Database locks enforce three attempts per user per rolling 24 hours and thirty globally per hour; failed attempts count. Only attempt metadata is retained. Migration: 20261003024058_image_preview_allowance.

Configuration: OPENAI_API_KEY in production; optional NOTAI_IMAGE_MODEL override. GET /api/generate-preview reports configuration presence without a paid generation. Preview environments remain isolated by the existing database write guard.

Validation: build, 14 unit tests, editor/demo/customer browser flows, 320/390px overflow checks, and transactional SQL quota/ownership/anonymous access tests passed. Provider generation was mocked, so paid generation and likeness quality have not been verified.

Rollback: revert this feature PR or restore production commit 88a0888c7127a50ef883f6e28f9b6b48b49656f4. Leave the additive quota migration in place; no customer data deletion is needed.

Existing Auth follow-up: Supabase security advisor reports leaked-password protection disabled. Enable it in Auth settings alongside the previously deferred email confirmation branding/redirect work. No Auth settings were changed for this feature.
