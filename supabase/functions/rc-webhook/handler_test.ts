import {
  createWebhookHandler,
  type SubscriptionTier,
  type WebhookDependencies,
} from "./handler.ts";

const uid = "11111111-1111-4111-8111-111111111111";
const secret = "s3cret";
const expiryMs = 1800000000000;
const expiryIso = new Date(expiryMs).toISOString();

function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`${JSON.stringify(actual)} != ${JSON.stringify(expected)}`);
  }
}

type Call = [string, SubscriptionTier, string | null];

function fixture(config: { authKey?: string } = { authKey: secret }) {
  const calls: Call[] = [];
  const deps: WebhookDependencies = {
    authKey: config.authKey,
    setSubscription: (userId, tier, expiresAt) => {
      calls.push([userId, tier, expiresAt]);
      return Promise.resolve();
    },
  };
  const request = (
    body: unknown,
    header: string | null = `Bearer ${secret}`,
    method = "POST",
  ) =>
    new Request("http://local/rc-webhook", {
      method,
      headers: header === null ? {} : { Authorization: header },
      body: method === "GET"
        ? undefined
        : typeof body === "string"
        ? body
        : JSON.stringify(body),
    });
  const event = (e: Record<string, unknown>) => request({ event: e });
  return { calls, deps, request, event };
}

Deno.test("GET is rejected with 405", async () => {
  const f = fixture();
  const res = await createWebhookHandler(f.deps)(f.request(null, undefined, "GET"));
  equal(res.status, 405);
  equal(await res.json(), { error: "Method not allowed" });
  equal(f.calls, []);
});

Deno.test("missing secret config fails closed with Bearer undefined", async () => {
  const f = fixture({});
  const res = await createWebhookHandler(f.deps)(
    f.request({ event: { type: "RENEWAL", app_user_id: uid } }, "Bearer undefined"),
  );
  equal(res.status, 503);
  equal(await res.json(), { error: "Webhook auth is not configured" });
  equal(f.calls, []);
});

Deno.test("empty secret config fails closed", async () => {
  const f = fixture({ authKey: "" });
  const res = await createWebhookHandler(f.deps)(
    f.request({ event: { type: "RENEWAL", app_user_id: uid } }, "Bearer "),
  );
  equal(res.status, 503);
  equal(f.calls, []);
});

Deno.test("wrong secret is 401", async () => {
  const f = fixture();
  const res = await createWebhookHandler(f.deps)(
    f.request({ event: { type: "RENEWAL", app_user_id: uid } }, "Bearer nope"),
  );
  equal(res.status, 401);
  equal(await res.json(), { error: "Unauthorized" });
  equal(f.calls, []);
});

Deno.test("missing Authorization header is 401", async () => {
  const f = fixture();
  const res = await createWebhookHandler(f.deps)(
    f.request({ event: { type: "RENEWAL", app_user_id: uid } }, null),
  );
  equal(res.status, 401);
  equal(f.calls, []);
});

Deno.test("non-JSON body is 400", async () => {
  const f = fixture();
  const res = await createWebhookHandler(f.deps)(f.request("{"));
  equal(res.status, 400);
  equal(await res.json(), { error: "Invalid JSON body" });
  equal(f.calls, []);
});

Deno.test("body without event is 400", async () => {
  const f = fixture();
  const res = await createWebhookHandler(f.deps)(f.request({}));
  equal(res.status, 400);
  equal(await res.json(), { error: "Missing event" });
  equal(f.calls, []);
});

Deno.test("INITIAL_PURCHASE grants premium with expiry", async () => {
  const f = fixture();
  const res = await createWebhookHandler(f.deps)(f.event({
    type: "INITIAL_PURCHASE",
    app_user_id: uid,
    expiration_at_ms: expiryMs,
  }));
  equal(res.status, 200);
  equal(await res.json(), { status: "ok", tier: "premium", appUserId: uid });
  equal(f.calls, [[uid, "premium", expiryIso]]);
});

Deno.test("RENEWAL without expiry stores null", async () => {
  const f = fixture();
  await createWebhookHandler(f.deps)(
    f.event({ type: "RENEWAL", app_user_id: uid }),
  );
  equal(f.calls, [[uid, "premium", null]]);
});

Deno.test("CANCELLATION stays premium until expiry", async () => {
  const f = fixture();
  await createWebhookHandler(f.deps)(f.event({
    type: "CANCELLATION",
    app_user_id: uid,
    expiration_at_ms: expiryMs,
  }));
  equal(f.calls, [[uid, "premium", expiryIso]]);
});

Deno.test("non-numeric expiration_at_ms becomes null", async () => {
  const f = fixture();
  const res = await createWebhookHandler(f.deps)(f.event({
    type: "INITIAL_PURCHASE",
    app_user_id: uid,
    expiration_at_ms: "soon",
  }));
  equal(res.status, 200);
  equal(f.calls, [[uid, "premium", null]]);
});

Deno.test("EXPIRATION downgrades to free", async () => {
  const f = fixture();
  await createWebhookHandler(f.deps)(
    f.event({ type: "EXPIRATION", app_user_id: uid }),
  );
  equal(f.calls, [[uid, "free", null]]);
});

Deno.test("BILLING_ISSUE does not change the tier", async () => {
  const f = fixture();
  const res = await createWebhookHandler(f.deps)(
    f.event({ type: "BILLING_ISSUE", app_user_id: uid }),
  );
  equal(res.status, 200);
  equal(await res.json(), { status: "ignored", reason: "event_type" });
  equal(f.calls, []);
});

Deno.test("TRANSFER without app_user_id is ignored", async () => {
  const f = fixture();
  const res = await createWebhookHandler(f.deps)(f.event({ type: "TRANSFER" }));
  equal(res.status, 200);
  equal(await res.json(), { status: "ignored", reason: "event_type" });
  equal(f.calls, []);
});

Deno.test("anonymous RevenueCat id is ignored with 200", async () => {
  const f = fixture();
  const res = await createWebhookHandler(f.deps)(
    f.event({ type: "RENEWAL", app_user_id: "$RCAnonymousID:abc123" }),
  );
  equal(res.status, 200);
  equal(await res.json(), { status: "ignored", reason: "app_user_id" });
  equal(f.calls, []);
});

Deno.test("database failure returns 500 without leaking details", async () => {
  const f = fixture();
  f.deps.setSubscription = () => Promise.reject(new Error("secret db detail"));
  const res = await createWebhookHandler(f.deps)(
    f.event({ type: "RENEWAL", app_user_id: uid }),
  );
  equal(res.status, 500);
  const text = await res.text();
  equal(JSON.parse(text), { error: "Update failed" });
  equal(text.includes("secret db detail"), false);
});
