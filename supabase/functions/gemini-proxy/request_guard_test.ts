import {
  authorizeAndConsume,
  maxBodyBytes,
  readBody,
  RequestError,
  validateBody,
} from "./request_guard.ts";
const device = "a".repeat(64);
const body = () =>
  validateBody({
    action: "meal_analysis",
    payload: { device_hash: device, image_base64: "YWJj" },
  });
function equal(a: unknown, b: unknown) {
  if (a !== b) throw new Error(`${a} != ${b}`);
}
async function rejects(action: () => unknown, status: number) {
  try {
    await action();
  } catch (e) {
    if (e instanceof RequestError) {
      equal(e.status, status);
      return;
    }
    throw e;
  }
  throw new Error("Expected rejection");
}
Deno.test("valid legacy guest passes with persistent device quota", async () => {
  let subject = "";
  await authorizeAndConsume("Bearer public-key", body(), {
    anonKey: "public-key",
    getUser: () => {
      throw new Error("guest needs no auth fetch");
    },
    consume: (s) => {
      subject = s;
      return Promise.resolve(true);
    },
  });
  equal(subject, `dev:${device}`);
});
Deno.test("arbitrary authorization never consumes quota", async () => {
  await rejects(() =>
    authorizeAndConsume("Bearer fake", body(), {
      anonKey: "public-key",
      getUser: () => Promise.resolve(null),
      consume: () => {
        throw new Error("must not debit");
      },
    }), 401);
});
Deno.test("signed-in quota uses verified identity instead of rotating hash", async () => {
  let subject = "";
  await authorizeAndConsume("Bearer jwt", body(), {
    anonKey: "public-key",
    getUser: () => Promise.resolve("user-id"),
    consume: (s) => {
      subject = s;
      return Promise.resolve(true);
    },
  });
  equal(subject, "user:user-id");
});
Deno.test("exhausted quota fails before provider call", async () => {
  await rejects(() =>
    authorizeAndConsume("Bearer public-key", body(), {
      anonKey: "public-key",
      getUser: () => Promise.resolve(null),
      consume: () => Promise.resolve(false),
    }), 429);
});
Deno.test("guest cannot call authenticated-only actions", async () => {
  const parsed = validateBody({
    action: "ocr_nutrition",
    payload: { text: "nutrition" },
  });
  await rejects(() =>
    authorizeAndConsume("Bearer public-key", parsed, {
      anonKey: "public-key",
      getUser: () => Promise.resolve(null),
      consume: () => {
        throw new Error("no quota");
      },
    }), 401);
});
for (
  const value of [null, [], {}, { action: "list_models", payload: {} }, {
    action: "meal_analysis",
    payload: { device_hash: "fake", image_base64: "YWJj" },
  }, {
    action: "meal_analysis",
    payload: { device_hash: device, image_base64: "https://example.com" },
  }, {
    action: "recalc_nutrition",
    payload: { device_hash: device, ingredients_text: " " },
  }]
) {
  Deno.test(`invalid payload ${JSON.stringify(value)}`, () =>
    rejects(() => validateBody(value), 400));
}
Deno.test("bounded reader handles valid JSON and rejects malformed input", async () => {
  const req = (text: string) =>
    new Request("http://local", { method: "POST", body: text });
  equal((await readBody(req('{"ok":true}')) as { ok: boolean }).ok, true);
  await rejects(() => readBody(req("{")), 400);
});
Deno.test("chunked oversized body rejected without content-length", async () => {
  await rejects(() =>
    readBody(
      new Request("http://local", {
        method: "POST",
        body: new Uint8Array(maxBodyBytes + 1),
      }),
    ), 413);
});
Deno.test("oversized content-length rejected before body read", async () => {
  await rejects(() =>
    readBody(
      new Request("http://local", {
        method: "POST",
        headers: { "content-length": String(maxBodyBytes + 1) },
        body: "{}",
      }),
    ), 413);
});
