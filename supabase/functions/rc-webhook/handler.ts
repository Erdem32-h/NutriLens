export type SubscriptionTier = "free" | "premium";

export interface WebhookDependencies {
  /** Value of RC_WEBHOOK_AUTH_KEY; undefined or "" means not configured. */
  authKey: string | undefined;
  /** Writes the tier for one user. Must throw on any database error. */
  setSubscription(
    userId: string,
    tier: SubscriptionTier,
    expiresAt: string | null,
  ): Promise<void>;
}

const json = (body: Record<string, unknown>, status: number) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

function safeEqual(a: string, b: string): boolean {
  const x = new TextEncoder().encode(a);
  const y = new TextEncoder().encode(b);
  if (x.length !== y.length) return false;
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
}

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function createWebhookHandler(
  deps: WebhookDependencies,
): (req: Request) => Promise<Response> {
  return async (req: Request): Promise<Response> => {
    if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
    if (!deps.authKey) {
      return json({ error: "Webhook auth is not configured" }, 503);
    }
    const header = req.headers.get("Authorization") ?? "";
    if (!safeEqual(header, `Bearer ${deps.authKey}`)) {
      return json({ error: "Unauthorized" }, 401);
    }
    let body: unknown;
    try {
      body = await req.json();
    } catch {
      return json({ error: "Invalid JSON body" }, 400);
    }
    const event = body && typeof body === "object" && "event" in body
      ? (body as { event: unknown }).event
      : undefined;
    if (!event || typeof event !== "object") {
      return json({ error: "Missing event" }, 400);
    }
    const e = event as Record<string, unknown>;

    let tier: SubscriptionTier;
    let expiresAt: string | null = null;
    switch (e.type) {
      case "INITIAL_PURCHASE":
      case "RENEWAL":
      case "PRODUCT_CHANGE":
      case "UNCANCELLATION":
      case "CANCELLATION": // Still premium until expiration
        tier = "premium";
        if (
          typeof e.expiration_at_ms === "number" &&
          Number.isFinite(e.expiration_at_ms)
        ) {
          const d = new Date(e.expiration_at_ms);
          expiresAt = Number.isNaN(d.getTime()) ? null : d.toISOString();
        }
        break;
      case "EXPIRATION":
        tier = "free";
        break;
      default:
        // BILLING_ISSUE is ignored on purpose: the charge failed but the
        // entitlement may still be active; EXPIRATION follows when access ends.
        return json({ status: "ignored", reason: "event_type" }, 200);
    }

    // RevenueCat anonymous ids are not our users; a non-200 would make
    // RevenueCat retry an event that can never succeed.
    const appUserId = e.app_user_id;
    if (typeof appUserId !== "string" || !UUID_RE.test(appUserId)) {
      return json({ status: "ignored", reason: "app_user_id" }, 200);
    }

    try {
      await deps.setSubscription(appUserId, tier, expiresAt);
    } catch (error) {
      console.error("rc-webhook update failed:", error);
      return json({ error: "Update failed" }, 500);
    }
    return json({ status: "ok", tier, appUserId }, 200);
  };
}
