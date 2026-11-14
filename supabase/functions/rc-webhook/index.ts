import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { createWebhookHandler } from "./handler.ts";
import { adminKey } from "../_shared/keys.ts";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  adminKey()!,
  { auth: { persistSession: false, autoRefreshToken: false } },
);

Deno.serve(createWebhookHandler({
  authKey: Deno.env.get("RC_WEBHOOK_AUTH_KEY"),
  async setSubscription(userId, tier, expiresAt) {
    const { error } = await admin
      .from("user_profiles")
      .update({
        subscription_tier: tier,
        subscription_expires_at: expiresAt,
        updated_at: new Date().toISOString(),
      })
      .eq("id", userId);
    if (error) throw error;
  },
}));
