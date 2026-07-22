# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Horizon — a Quebec Flutter app (bilingual UI: French default, English optional) for couples doing Zero-Based Budgeting. Partners form a "Foyer" (household), connect banks via Plaid, then swipe transactions Tinder-style into three buckets: `Solo_A`, `Common`, `Solo_B`. The server maintains per-bucket "safe-to-spend" balances and an internal debt ledger between partners. Monetization: free tier vs Premium (RevenueCat). An AI coach (Anthropic API) writes budget advice from server-computed aggregates.

**Code comments, commit messages and the authoritative legal docs are in French — keep it that way.** The UI is bilingual (fr default, en optional): every user-facing string lives in `lib/l10n/app_fr.arb` (template) + `app_en.arb`, generated into `lib/l10n/app_localizations*.dart` by `flutter gen-l10n` (runs automatically on `flutter pub get`). Never hardcode a UI string — add a key to BOTH ARB files. The language choice is persisted by `lib/utils/locale_controller.dart` (SharedPreferences; also syncs `currencyLanguageCode` for money formatting) and exposed in Settings.

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

Prod builds use `--dart-define=APP_ENV=prod` (see `PRODUCTION_CHECKLIST.md` — the authoritative list of manual production steps; keep it updated when adding config that needs console/account work). `SECURITY_POLICY.md` is the formal security policy (annual review; update it when security-relevant architecture changes). New callables must keep `npm audit --audit-level=high` green — it gates CI.

## Architecture — the parts that span multiple files

### Server is the authority; the client only flips two fields

The ONLY transaction fields a client may write are `assigned_to_bucket` and `category` (enforced in `firestore.rules`). Everything financial flows through Cloud Functions:

- **Ledger**: `functions/src/ledger.ts` — the Firestore trigger `onTransactionAssigned` fires on bucket changes and updates household `safe_to_spend_*` + `internal_debt_balance` transactionally. It reverses the old bucket's effect before applying the new one, which is what makes client-side "undo" and re-categorization safe: the client just writes the new bucket value and the trigger reconciles.
- **Membership**: `createHousehold` / `joinHousehold` (`households.ts`) — clients can never write `household_id`, `role`, `user_A_id/B_id`, `join_code`, `subscription_tier`, or `household_mode` (rules forbid them; functions use Admin SDK which bypasses rules).
- **Solo vs couple**: `createHousehold` takes a `mode` (`solo`|`couple`, default `couple`) stored as `household_mode`; `joinHousehold` flips it to `couple` when a partner joins. `Household.isSolo` (= mode is solo AND `user_B_id == null`) drives the UI: two pots instead of three, no invite banner, no internal-debt banner, no Solo B in filters/menus, single income + no split slider in the budget, and `Common`/`Solo_A` displayed as "Essentiel"/"Perso" (stored values are unchanged). **Solo households must exclude Solo B from alert calculations** — an empty pot always reads as "below threshold" and would show a permanent false alert. The coach receives `mode` and, in solo, a payload without Solo B or internal debt.
- **Plaid**: `plaid.ts` — access tokens live in `bank_connections` (rules: deny-all). Sync uses `/transactions/sync` with a cursor per connection; Plaid transaction IDs are the Firestore doc IDs (idempotency). Pending transactions are skipped. Webhooks are JWT-verified (ES256).
- **Subscriptions**: `subscription_tier` on users/households is written only by `revenueCatWebhook` (`billing.ts`). Server-side gating: free tier = 1 bank connection (checked in `exchangePublicToken`).
- **Reports**: `reports.ts` computes deterministic aggregates into `households/{id}/reports/{periodId}` (`2026-07` monthly, `2026-W29` ISO-weekly). The AI coach (`coach.ts`) reads ONLY these aggregates — never raw transactions or identifiers — and writes `ai_advice` back onto the report doc. **Numbers must always come from the deterministic engine, never from the AI.**

### Security invariants (do not weaken)

- Email verification is enforced in THREE layers: `AuthRouter` (client gate), `requireAuth()` in every callable (`security.ts`), and `isVerified()` in `firestore.rules`. New callables must call `requireAuth()` + `enforceRateLimit()` and validate inputs with `assertString`/patterns.
- **MFA (TOTP) is mandatory for every user account** — enforced server-side by Identity Platform. `AuthRouter` chains gates in this order and the order is load-bearing: signed in → **email verified** → **MFA factor enrolled** → household → home. Email verification MUST stay before the MFA gate: Firebase refuses to enroll a second factor on an unverified email. Sign-in raises `FirebaseAuthMultiFactorException` (caught in `login_screen.dart` — its `on` clause must precede `FirebaseAuthException`, its parent class) and resolves via `MfaChallengeScreen`. The `_MfaGate` fails **closed**: on error reading enrolled factors it shows the enrollment screen rather than letting the user through.
- MFA recovery is deliberately NOT in the app (a deployed admin callable would be an internet-exposed backdoor): `functions/scripts/mfa-admin.js` runs locally with Google admin credentials and is excluded from deploys via `firebase.json`. See `SECURITY_POLICY.md` §6bis.
- App Check is soft-enforced via `ENFORCE_APP_CHECK` in `functions/.env` (committed, non-secret). Secrets (PLAID_CLIENT_ID, PLAID_SECRET, REVENUECAT_WEBHOOK_AUTH, ANTHROPIC_API_KEY) live in Google Secret Manager and are declared via `runWith({ secrets: [...] })`.
- Feature flags in `functions/.env`: `PLAID_ENV` (sandbox/production), `AI_COACH_REQUIRE_PREMIUM` (false in dev so the coach is testable without a subscription), `PLAID_SKIP_WEBHOOK_VERIFICATION` (emulator only).

### Client structure

- Firestore uses `snake_case` fields; Dart models (`lib/models/`) are typed camelCase wrappers with defensive `(x as num?)?.toDouble()` casts (Firestore returns ints for whole numbers). `Household` has a back-compat fallback: `user_A_id ?? created_by`.
- `lib/widgets/household_loader.dart` is the shared user-doc → household-doc stream chain used by Home/History/Bilan/Settings — use it instead of duplicating the StreamBuilder nesting.
- `lib/utils/categories.dart` is the category referential: keys are Plaid `personal_finance_category.primary` values (e.g. `FOOD_AND_DRINK`). Reports aggregate by these keys and `category_budgets` (envelopes) reference them, so renaming a key breaks aggregation continuity. Display labels are bilingual via `TxCategory.labelFor(languageCode)`.
- Currency/input formatting is bilingual without the intl package: `formatCurrency`/`parseAmount` in `lib/utils/formatters.dart` (fr: NBSP thousands + comma decimals `1 234,56 $`; en: `$1,234.56`; default follows `currencyLanguageCode`, kept in sync by `LocaleController`). Amount inputs must use `parseAmount`, never bare `double.tryParse` — it accepts both decimal conventions.
- i18n gotchas: validators take an optional `AppLocalizations` (French fallback keeps tests pure); `Household.bucketLabel(bucket, l10n)` needs the l10n; stored DATA values stay French for continuity (`pay_frequency` values `Mensuel/Bi-hebdomadaire/Hebdomadaire` that `BudgetCalculator` switches on, and the server's `frequency_label`) — only their display is translated (maps in `budget_setup_screen.dart` / `bilan_screen.dart`). Legal docs: `assets/legal/*.md` French authoritative + `*_en.md` courtesy translations picked by `showLegalDocument`. The SAME policies are published publicly at https://horizon-dbba0.web.app/privacy via Firebase Hosting (`hosting/*.html`, `firebase deploy --only hosting`) — any edit to `assets/legal/*.md` must be mirrored in `hosting/*.html` and redeployed.
- New Firestore queries usually need a composite index in `firestore.indexes.json` — deploy it or the query fails at runtime with `failed-precondition`.

### Anthropic API usage

`coach.ts` uses `@anthropic-ai/sdk` with model `claude-opus-4-8`, adaptive thinking (`thinking: {type: "adaptive"}`), and two financial-planner system prompts (fr/en, chosen by the callable's `language` input; 350-word cap, fixed markdown sections). The persona may cite general benchmarks (50/30/20, emergency fund) but household amounts must come ONLY from the JSON payload. The payload includes report aggregates plus monthly budget context (total income, fixed expenses, envelope targets) — any expansion of it requires updating BOTH privacy policies (`assets/legal/privacy.md` §3 and `privacy_en.md` — Loi 25 disclosure). Rate-limited 5/day/user. If the secret is the `REPLACE_ME` placeholder, the function returns a clear failed-precondition.

### Testing

Tests are pure-Dart unit tests (`test/`): validators, formatters, BudgetCalculator ("magic months" — pay-period math in UTC to avoid DST bugs), categories. There is no Firebase emulator setup; don't write widget tests that require Firebase initialization. CI (`.github/workflows/ci.yml`) runs `flutter analyze` + `flutter test` + functions `tsc` build.
