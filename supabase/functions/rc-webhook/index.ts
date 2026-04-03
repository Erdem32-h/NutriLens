import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const RC_WEBHOOK_AUTH_KEY = Deno.env.get("RC_WEBHOOK_AUTH_KEY")!;

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  // Verify webhook auth
  const authHeader = req.headers.get("Authorization");
  if (authHeader !== `Bearer ${RC_WEBHOOK_AUTH_KEY}`) {
    return new Response("Unauthorized", { status: 401 });
  }

  const body = await req.json();
  const event = body.event;
  const appUserId = event?.app_user_id;

  if (!appUserId) {
    return new Response("Missing app_user_id", { status: 400 });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  const eventType = event.type;
  const expiresAt = event.expiration_at_ms
    ? new Date(event.expiration_at_ms).toISOString()
    : null;

  let tier = "free";
  let expiresDate: string | null = null;

  switch (eventType) {
    case "INITIAL_PURCHASE":
    case "RENEWAL":
    case "PRODUCT_CHANGE":
    case "UNCANCELLATION":
      tier = "premium";
      expiresDate = expiresAt;
      break;
    case "CANCELLATION":
      // Still premium until expiration
      tier = "premium";
      expiresDate = expiresAt;
      break;
    case "EXPIRATION":
    case "BILLING_ISSUE":
      tier = "free";
      expiresDate = null;
      break;
    default:
      return new Response(JSON.stringify({ status: "ignored", eventType }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
  }

  const { error } = await supabase
    .from("user_profiles")
    .update({
      subscription_tier: tier,
      subscription_expires_at: expiresDate,
      updated_at: new Date().toISOString(),
    })
    .eq("id", appUserId);

  if (error) {
    console.error("Update error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(
    JSON.stringify({ status: "ok", tier, appUserId }),
    { status: 200, headers: { "Content-Type": "application/json" } }
  );
});
