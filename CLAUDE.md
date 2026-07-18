# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Horizon — a French-language (Quebec) Flutter app for couples doing Zero-Based Budgeting. Partners form a "Foyer" (household), connect banks via Plaid, then swipe transactions Tinder-style into three buckets: `Solo_A`, `Common`, `Solo_B`. The server maintains per-bucket "safe-to-spend" balances and an internal debt ledger between partners. Monetization: free tier vs Premium (RevenueCat). An AI coach (Anthropic API) writes budget advice from server-computed aggregates.

**All UI strings, code comments, commit messages, and legal docs are in French — keep it that way.**

## Commands

```bash
# Flutter app (dev project = horizon-dbba0, Plaid sandbox)
flutter pub get
flutter run -d chrome --web-port=5000
flutter analyze                      # must stay at 0 issues
flutter test                         # pure-logic unit tests only (no Firebase mocks)
flutter test test/validators_test.dart   # single test file

# Cloud Functions (TypeScript, Node 20)
cd functions
npm install
npx tsc --noEmit                     # typecheck
npm run build                        # compiles to lib/ (gitignored)

# Deploy (Firebase CLI is authenticated on this machine; project: horizon-dbba0)
firebase deploy --only "firestore:rules,firestore:indexes" --project horizon-dbba0
firebase deploy --only functions --project horizon-dbba0
```

Prod builds use `--dart-define=APP_ENV=prod` (see `PRODUCTION_CHECKLIST.md` — the authoritative list of manual production steps; keep it updated when adding config that needs console/account work).

## Architecture — the parts that span multiple files

### Server is the authority; the client only flips two fields

The ONLY transaction fields a client may write are `assigned_to_bucket` and `category` (enforced in `firestore.rules`). Everything financial flows through Cloud Functions:

- **Ledger**: `functions/src/ledger.ts` — the Firestore trigger `onTransactionAssigned` fires on bucket changes and updates household `safe_to_spend_*` + `internal_debt_balance` transactionally. It reverses the old bucket's effect before applying the new one, which is what makes client-side "undo" and re-categorization safe: the client just writes the new bucket value and the trigger reconciles.
- **Membership**: `createHousehold` / `joinHousehold` (`households.ts`) — clients can never write `household_id`, `role`, `user_A_id/B_id`, `join_code`, or `subscription_tier` (rules forbid them; functions use Admin SDK which bypasses rules).
- **Plaid**: `plaid.ts` — access tokens live in `bank_connections` (rules: deny-all). Sync uses `/transactions/sync` with a cursor per connection; Plaid transaction IDs are the Firestore doc IDs (idempotency). Pending transactions are skipped. Webhooks are JWT-verified (ES256).
- **Subscriptions**: `subscription_tier` on users/households is written only by `revenueCatWebhook` (`billing.ts`). Server-side gating: free tier = 1 bank connection (checked in `exchangePublicToken`).
- **Reports**: `reports.ts` computes deterministic aggregates into `households/{id}/reports/{periodId}` (`2026-07` monthly, `2026-W29` ISO-weekly). The AI coach (`coach.ts`) reads ONLY these aggregates — never raw transactions or identifiers — and writes `ai_advice` back onto the report doc. **Numbers must always come from the deterministic engine, never from the AI.**

### Security invariants (do not weaken)

- Email verification is enforced in THREE layers: `AuthRouter` (client gate), `requireAuth()` in every callable (`security.ts`), and `isVerified()` in `firestore.rules`. New callables must call `requireAuth()` + `enforceRateLimit()` and validate inputs with `assertString`/patterns.
- App Check is soft-enforced via `ENFORCE_APP_CHECK` in `functions/.env` (committed, non-secret). Secrets (PLAID_CLIENT_ID, PLAID_SECRET, REVENUECAT_WEBHOOK_AUTH, ANTHROPIC_API_KEY) live in Google Secret Manager and are declared via `runWith({ secrets: [...] })`.
- Feature flags in `functions/.env`: `PLAID_ENV` (sandbox/production), `AI_COACH_REQUIRE_PREMIUM` (false in dev so the coach is testable without a subscription), `PLAID_SKIP_WEBHOOK_VERIFICATION` (emulator only).

### Client structure

- Firestore uses `snake_case` fields; Dart models (`lib/models/`) are typed camelCase wrappers with defensive `(x as num?)?.toDouble()` casts (Firestore returns ints for whole numbers). `Household` has a back-compat fallback: `user_A_id ?? created_by`.
- `lib/widgets/household_loader.dart` is the shared user-doc → household-doc stream chain used by Home/History/Bilan/Settings — use it instead of duplicating the StreamBuilder nesting.
- `lib/utils/categories.dart` is the category referential: keys are Plaid `personal_finance_category.primary` values (e.g. `FOOD_AND_DRINK`). Reports aggregate by these keys and `category_budgets` (envelopes) reference them, so renaming a key breaks aggregation continuity.
- Currency/input formatting is locale-aware fr-CA without the intl package: `formatCurrency`/`parseAmount` in `lib/utils/formatters.dart` (NBSP thousands separator, comma decimals). Amount inputs must use `parseAmount`, never bare `double.tryParse`.
- New Firestore queries usually need a composite index in `firestore.indexes.json` — deploy it or the query fails at runtime with `failed-precondition`.

### Anthropic API usage

`coach.ts` uses `@anthropic-ai/sdk` with model `claude-opus-4-8`, a French system prompt with strict output structure, and a 250-word cap. Rate-limited 5/day/user. If the secret is the `REPLACE_ME` placeholder, the function returns a clear failed-precondition. Any expansion of the payload sent to the API requires updating the privacy policy (`assets/legal/privacy.md` §3 — Loi 25 disclosure).

### Testing

Tests are pure-Dart unit tests (`test/`): validators, formatters, BudgetCalculator ("magic months" — pay-period math in UTC to avoid DST bugs), categories. There is no Firebase emulator setup; don't write widget tests that require Firebase initialization. CI (`.github/workflows/ci.yml`) runs `flutter analyze` + `flutter test` + functions `tsc` build.
