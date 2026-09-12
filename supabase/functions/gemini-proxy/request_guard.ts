export const publicActions = new Set([
  "meal_analysis",
  "recalc_nutrition",
  "ocr_ingredients_image",
  "ocr_nutrition_image",
]);
const actions = new Set([
  ...publicActions,
  "ocr_ingredients",
  "ocr_nutrition",
  "food_recognition",
  "classify_category",
]);
const imageActions = new Set([
  "meal_analysis",
  "ocr_ingredients_image",
  "ocr_nutrition_image",
  "food_recognition",
]);
// 6 MiB covers the existing resized/base64 camera payload with headroom.
export const maxBodyBytes = 6 * 1024 * 1024;

export class RequestError extends Error {
  constructor(public status: number, message: string) {
    super(message);
  }
}

export async function readBody(req: Request): Promise<unknown> {
  const length = Number(req.headers.get("content-length"));
  if (length > maxBodyBytes) throw new RequestError(413, "Request too large");
  if (!req.body) throw new RequestError(400, "Missing body");
  const reader = req.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > maxBodyBytes) {
        await reader.cancel();
        throw new RequestError(413, "Request too large");
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  try {
    return JSON.parse(new TextDecoder().decode(bytes));
  } catch {
    throw new RequestError(400, "Invalid JSON");
  }
}

export function validateBody(
  body: unknown,
): { action: string; payload: Record<string, string> } {
  if (
    !body || typeof body !== "object" || !("action" in body) ||
    !("payload" in body) ||
    typeof body.action !== "string" || !actions.has(body.action) ||
    !body.payload ||
    typeof body.payload !== "object" || Array.isArray(body.payload)
  ) {
    throw new RequestError(400, "Invalid action or payload");
  }
  const payload = body.payload as Record<string, unknown>;
  for (const [key, value] of Object.entries(payload)) {
    if (
      typeof value !== "string" ||
      value.length > (key === "image_base64" ? maxBodyBytes - 1024 : 20000)
    ) {
      throw new RequestError(400, "Invalid payload field");
    }
  }
  if (
    publicActions.has(body.action) &&
    (typeof payload.device_hash !== "string" ||
      !/^[0-9a-f]{64}$/.test(payload.device_hash))
  ) {
    throw new RequestError(400, "Invalid device_hash");
  }
  const required = imageActions.has(body.action)
    ? "image_base64"
    : body.action === "recalc_nutrition"
    ? "ingredients_text"
    : body.action === "classify_category"
    ? "product_name"
    : "text";
  if (typeof payload[required] !== "string" || !payload[required].trim()) {
    throw new RequestError(400, `Missing ${required}`);
  }
  if (
    imageActions.has(body.action) &&
    !/^[A-Za-z0-9+/]+={0,2}$/.test(payload.image_base64 as string)
  ) {
    throw new RequestError(400, "Invalid image_base64");
  }
  return { action: body.action, payload: payload as Record<string, string> };
}

export async function authorizeAndConsume(
  authorization: string | null,
  body: { action: string; payload: Record<string, string> },
  deps: {
    anonKey: string;
    /// Second accepted anon key. The runtime injects SUPABASE_ANON_KEY as the
    /// project's *publishable* key (sb_publishable_...), but every shipped app
    /// build sends the legacy anon JWT — matching on one value alone 401s
    /// every guest. Both are public by design; accepting both is what keeps
    /// old and new builds working through an API-key rotation.
    legacyAnonKey?: string;
    getUser(token: string): Promise<string | null>;
    consume(subject: string): Promise<boolean>;
  },
): Promise<void> {
  const token = /^Bearer\s+(\S+)$/i.exec(authorization ?? "")?.[1];
  if (!token) throw new RequestError(401, "Missing bearer token");
  let subject: string;
  if (
    (deps.anonKey && token === deps.anonKey) ||
    (deps.legacyAnonKey && token === deps.legacyAnonKey)
  ) {
    if (!publicActions.has(body.action)) {
      throw new RequestError(401, "Not signed in");
    }
    subject = `dev:${body.payload.device_hash}`;
  } else {
    const userId = await deps.getUser(token);
    if (!userId) throw new RequestError(401, "Session expired");
    subject = `user:${userId}`;
  }
  // Caller-controlled hash is NOT attestation. Global budget bounds rotation;
  // business scan tickets require a separate versioned mobile rollout.
  if (!await deps.consume(subject)) {
    throw new RequestError(429, "AI request limit reached");
  }
}
