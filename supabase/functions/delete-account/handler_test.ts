import { createDeletionHandler, type DeletionDependencies } from "./handler.ts";

const uid = "11111111-1111-4111-8111-111111111111";
function equal(actual: unknown, expected: unknown) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(`${actual} != ${expected}`);
  }
}
function fixture() {
  const calls: string[] = [];
  let photos = Array.from({ length: 205 }, (_, i) => `${uid}/${i}.jpg`);
  const deps: DeletionDependencies = {
    receiptCompleted: () => Promise.resolve(false),
    beginReceipt: () => Promise.resolve(),
    getUser: () => Promise.resolve(uid),
    listPhotos: () => Promise.resolve(photos.slice(0, 100)),
    removePhotos: (paths) => {
      calls.push(`photos:${paths.length}`);
      photos = photos.filter((p) => !paths.includes(p));
      return Promise.resolve();
    },
    prepareDeletion: () => {
      calls.push("prepare");
      return Promise.resolve();
    },
    deleteUser: () => {
      calls.push("delete");
      return Promise.resolve();
    },
  };
  const request = (id = uid, token = "Bearer valid") =>
    new Request("http://local/delete-account", {
      method: "POST",
      headers: { Authorization: token },
      body: JSON.stringify({ user_id: id }),
    });
  return { calls, deps, request };
}

Deno.test("deletion removes all photo pages before deleting account", async () => {
  const f = fixture();
  const result = await createDeletionHandler(f.deps)(f.request());
  equal(result.status, 200);
  equal(await result.json(), { status: "ok" });
  equal(f.calls, ["photos:100", "photos:100", "photos:5", "prepare", "delete"]);
});
for (
  const [name, id, token, expected] of [
    ["cross-user", "22222222-2222-4222-8222-222222222222", "Bearer valid", 403],
    ["missing bearer", uid, "invalid", 401],
    ["invalid uuid", "../other", "Bearer valid", 400],
  ] as const
) {
  Deno.test(`deletion rejects ${name} before mutations`, async () => {
    const f = fixture();
    equal(
      (await createDeletionHandler(f.deps)(f.request(id, token))).status,
      expected,
    );
    equal(f.calls, []);
  });
}
Deno.test("invalid session cannot delete", async () => {
  const f = fixture();
  f.deps.getUser = () => Promise.resolve(null);
  equal((await createDeletionHandler(f.deps)(f.request())).status, 401);
  equal(f.calls, []);
});
Deno.test("storage failure keeps account and supports retry", async () => {
  const f = fixture();
  const remove = f.deps.removePhotos;
  f.deps.removePhotos = () =>
    Promise.reject(new Error("private upstream detail"));
  const response = await createDeletionHandler(f.deps)(f.request());
  equal(response.status, 503);
  equal((await response.text()).includes("private upstream detail"), false);
  equal(f.calls, []);
  f.deps.removePhotos = remove;
  equal((await createDeletionHandler(f.deps)(f.request())).status, 200);
});
Deno.test("preparation failure never deletes auth user", async () => {
  const f = fixture();
  f.deps.prepareDeletion = () => Promise.reject(new Error("db"));
  equal((await createDeletionHandler(f.deps)(f.request())).status, 503);
  equal(f.calls.includes("delete"), false);
});
Deno.test("malformed JSON and wrong method rejected", async () => {
  const f = fixture();
  const handler = createDeletionHandler(f.deps);
  equal((await handler(new Request("http://local"))).status, 405);
  equal(
    (await handler(
      new Request("http://local", {
        method: "POST",
        headers: { Authorization: "Bearer valid" },
        body: "{",
      }),
    )).status,
    400,
  );
  equal(f.calls, []);
});

Deno.test("lost response can be confirmed without a valid session", async () => {
  const f = fixture();
  const secret = "33333333-3333-4333-8333-333333333333";
  let storedHash = "";
  let completed = false;
  f.deps.beginReceipt = (_, hash) => {
    storedHash = hash;
    return Promise.resolve();
  };
  f.deps.receiptCompleted = (userId, hash) =>
    Promise.resolve(userId === uid && completed && hash === storedHash);
  f.deps.deleteUser = () => {
    completed = true;
    return Promise.resolve();
  };
  const req = (requestToken = secret, receiptOnly = false) =>
    new Request("http://local", {
      method: "POST",
      headers: { Authorization: "Bearer token" },
      body: JSON.stringify({
        user_id: uid,
        request_token: requestToken,
        receipt_only: receiptOnly,
      }),
    });
  const handler = createDeletionHandler(f.deps);
  equal((await handler(req())).status, 200);
  equal(storedHash.length, 64);
  equal(storedHash === secret, false);
  f.deps.getUser = () => Promise.resolve(null);
  equal((await handler(req())).status, 200);
  equal(
    (await handler(req("44444444-4444-4444-8444-444444444444"))).status,
    401,
  );
});

Deno.test("receipt-only request can never start deletion", async () => {
  const f = fixture();
  const response = await createDeletionHandler(f.deps)(
    new Request("http://local", {
      method: "POST",
      headers: { Authorization: "Bearer valid" },
      body: JSON.stringify({
        user_id: uid,
        request_token: "33333333-3333-4333-8333-333333333333",
        receipt_only: true,
      }),
    }),
  );
  equal(await response.json(), { status: "unconfirmed" });
  equal(f.calls, []);
});
