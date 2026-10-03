# Owner financial reporting

Open /owner.html → Shop finances & margins. Only shop owners can read reports or record entries. Revenue is derived from paid USD orders; the browser cannot edit revenue. Actual Printful invoices, supplier credits, Stripe fees, and operating expenses currently require manual entry. No automatic supplier or payment-fee import is included.

## Definitions

Revenue before refunds = customer total minus customer sales tax, including shipping revenue and excluding discounts and redeemed store credit. Revenue refunded = refund total minus refunded customer tax. Net revenue = revenue before refunds minus revenue refunded.

Gross profit = net revenue minus actual garment/printing, supplier shipping, nonrecoverable supplier tax, packaging and other fulfillment costs. Gross margin = gross profit / net revenue, only when revenue is positive. Contribution = gross profit minus actual payment fees. After operating expenses = contribution minus actual dated operating expenses. Outstanding store credit is the all-time sum of positive per-customer USD balances; it is separate from margin.

Costs remain incomplete until an owner confirms all actual fulfillment costs and/or payment fees are recorded. Incomplete costs produce unavailable profit totals rather than treating missing costs as zero. Adding or reversing an actual cost clears the relevant review. Estimates remain separate from actual costs; reverse obsolete estimates when actual invoices arrive. Zero costs require explicit owner review.

Full refunds use the original tax amount. Partial refunds initially allocate refunded tax proportionally and label profit provisional. The owner can record the exact refunded-tax amount; the saved split is invalidated if the order's refund total changes. Recording a split does not issue a refund.

## Period and scope

Dates select orders created during the chosen period in America/Chicago. Their current lifetime refunds and costs are included. Operating expenses use their own occurrence dates. This is an operational order-cohort report, not a cash-flow, bank balance, tax statement or accrual accounting system. USD only. It does not yet track payout reconciliation, accounts payable, inventory assets, advertising attribution or recoverable supplier tax.

## Integrity and security

Additive migrations 20261003174125 and 20261003174828 introduce private financial entries, order reviews and review audit events. Raw tables and the metrics view are unavailable to authenticated/anonymous clients. Scoped RPCs recheck authenticated owner membership, with empty search_path on security-definer functions. The API also checks membership. No service-role credential is required for these pages. Preview writes retain the existing isolated-environment guard.

Supported APIs never overwrite or delete entries. Corrections append one equal-and-opposite reversal, preserving originals. Request keys make retries idempotent. Per-order transaction locks serialize entries and reviews. Entry paging has deterministic date/time/UUID ordering. The actor and timestamp are retained for entries and reviews. Database administrators retain privileged access.

## Verification and rollback

Build and 19 unit tests pass. The transaction-and-rollback SQL suite covers revenue, discounts, redeemed credit, tax, unknown costs, estimates, actual costs, idempotency, reversals, partial/exact/full refunds, expenses, owner checks and privilege denial. Test fixtures are rolled back. Browser tests cover financial pages, cents conversion, cost reviews, refunds, expenses, owner denial and narrow mobile layouts.

Supabase security advisors show only expected informational notices for private RLS tables without client policies; the pre-existing leaked-password-protection warning remains unchanged: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

Previous application commit: c783f4dfbb6ed1e58e85f2ae165c3bc54484c4bb. Revert this feature's GitHub PR to restore the prior application while leaving the additive financial records intact. Do not drop financial tables when rolling back the UI.
