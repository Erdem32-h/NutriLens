# P0 hardening — account deletion and AI admission

Status: implemented locally, NOT deployed. No production user was deleted.

## Account deletion

- Server verifies bearer with Auth.getUser and matches requested user.
- Private meal photos are paginated via service-only SQL and deleted through
  Storage API (including nested/orphan objects). Storage failures stop deletion.
- Shared community products remain; author FK is cleared. User reports and
  attributed analytics are removed. Public product photo ownership is detached.
- Auth deletion cascades profiles, meals, history, favorites and blacklist.
- Client waits for confirmed server success before deleting local data.
- Local cleanup includes user_metrics and thumbnail files; another user's rows
  and shared file references remain. A persisted marker resumes local cleanup
  after a restart if remote deletion succeeded but local cleanup failed.
- Existing public product image filenames can contain historical user UUIDs.
  Ownership removal is not full filename anonymization; a separate copy/URL
  migration is needed before claiming complete anonymization of public images.
- Cross-service Storage/Auth deletion is not atomic. If photo cleanup succeeds
  and Auth fails, retry resumes remaining work. Lost success responses remain
  an edge case: server-side deletion receipts are not implemented in this patch.

## AI admission

- Existing guest API shape preserved (SHA-256 device hash and anon bearer).
- Arbitrary bearer rejected; signed-in callers checked via Auth.getUser.
- Persistent atomic 30 requests/hour per verified user or guest device hash.
- A global UTC daily request cap bounds hash rotation across Edge instances.
- `AI_GLOBAL_DAILY_LIMIT` MUST be configured before deploying the new proxy.
  No silent default: missing/invalid config or quota DB failure returns 503.
- Bound request body to 6 MiB while streaming, validate action/payload before
  quota consumption. Internal model listing is no longer exposed.
- This is abuse admission, NOT business scan accounting or device attestation.
  It does not make guest device hashes unforgeable. Global budget exhaustion can
  deny legitimate users. Keep OpenRouter monetary cap/alerts; choose operational
  budget using real request volume. Versioned signed scan tickets and device
  attestation remain follow-up work, not a solved claim.
- Subject rows older than two days are pruned during successful admission.

## Validation

Local validation completed: 661 Flutter tests passed; Flutter analyze clean;
23 Deno handler/guard tests passed; both Edge entrypoints type-check; changed
Dart files pass format check; SQL regression and both concurrent admission
scenarios passed (60 same-subject requests, 30 rotating-subject requests).
Disposable test containers were removed. No hosted deployment was performed.

Run from repository root:

```powershell
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
npx --yes deno check supabase/functions/delete-account/index.ts supabase/functions/gemini-proxy/index.ts
npx --yes deno test supabase/functions/delete-account/handler_test.ts supabase/functions/gemini-proxy/request_guard_test.ts
pwsh -NoProfile -File scripts/test_p0_database.ps1
```

SQL harness creates/removes its own disposable Docker container. Minimal
production-shaped schema fixtures are NOT production migrations. It tests
privileges, scoped cleanup, hourly/daily refill, 60 simultaneous requests on one
subject and 30 rotating subjects against a global cap. Full hosted Storage/Auth
integration and real-device account deletion still require a dedicated test user.

## Deployment gate and order

1. Review migrations independently; do NOT blindly push old migration history
   (repository has legacy numbering and production schema drift).
2. Apply account preparation migration, then deploy delete-account only.
3. With a dedicated test account, verify >100 photos, a community contribution,
   product report, deletion, no cross-user changes and no orphan private photos.
4. Confirm global daily AI budget; configure AI_GLOBAL_DAILY_LIMIT, apply quota
   migration, then deploy gemini-proxy. Without configuration it fails closed.
5. Smoke guest + registered meal/OCR, 401/429/503 handling on old/new apps.
   Signed-in old app versions do not refresh expired JWT on public AI actions;
   the Flutter patch fixes this, so test rollout compatibility before deployment.
6. Release Flutter changes. Monitor deletion failures and AI 401/429/503 rates.

Never validate deletion against real customer accounts. Never log secrets or
provider error bodies with user data. Webhook, camera/navigation and conversion
work from the audit remain separate subsequent tasks.