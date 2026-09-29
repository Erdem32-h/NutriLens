import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { adminKey } from "./keys.ts";

const envOf = (vars: Record<string, string>) => (n: string) => vars[n];

Deno.test("prefers the default secret key", () => {
  assertEquals(
    adminKey(envOf({
      SUPABASE_SECRET_KEYS: '{"default":"sb_secret_new","billing":"x"}',
      SUPABASE_SERVICE_ROLE_KEY: "legacy-jwt",
    })),
    "sb_secret_new",
  );
});

Deno.test("falls back to the legacy key when no secret keys exist", () => {
  assertEquals(
    adminKey(envOf({ SUPABASE_SERVICE_ROLE_KEY: "legacy-jwt" })),
    "legacy-jwt",
  );
});

Deno.test("falls back when SUPABASE_SECRET_KEYS is malformed or lacks default", () => {
  for (const raw of ["not json", '{"billing":"x"}']) {
    assertEquals(
      adminKey(envOf({
        SUPABASE_SECRET_KEYS: raw,
        SUPABASE_SERVICE_ROLE_KEY: "legacy-jwt",
      })),
      "legacy-jwt",
    );
  }
});

Deno.test("undefined when neither key exists", () => {
  assertEquals(adminKey(envOf({})), undefined);
});
