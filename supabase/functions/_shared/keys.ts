// Supabase admin key for Edge Functions.
//
// The legacy `SUPABASE_SERVICE_ROLE_KEY` (a JWT) stops working at the end of
// 2026. The runtime also injects `SUPABASE_SECRET_KEYS`, a JSON object of the
// project's new `sb_secret_...` keys keyed by name. Prefer the `default`
// secret key and fall back to the legacy one, so a deploy is safe before and
// after the legacy keys are deactivated.
// See https://supabase.com/docs/guides/getting-started/migrating-to-new-api-keys

export function adminKey(
  env: (name: string) => string | undefined = (n) => Deno.env.get(n),
): string | undefined {
  const raw = env("SUPABASE_SECRET_KEYS");
  if (raw) {
    try {
      const key = (JSON.parse(raw) as Record<string, unknown>)["default"];
      if (typeof key === "string" && key) return key;
    } catch {
      // Malformed value: fall through to the legacy key.
    }
  }
  return env("SUPABASE_SERVICE_ROLE_KEY") || undefined;
}
