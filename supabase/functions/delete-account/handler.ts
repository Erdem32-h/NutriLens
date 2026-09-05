export interface DeletionDependencies {
  getUser(token: string): Promise<string | null>;
  listPhotos(userId: string): Promise<string[]>;
  removePhotos(paths: string[]): Promise<void>;
  prepareDeletion(userId: string): Promise<void>;
  deleteUser(userId: string): Promise<void>;
}

const json = (body: Record<string, unknown>, status: number) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

export function createDeletionHandler(deps: DeletionDependencies) {
  return async (req: Request): Promise<Response> => {
    if (req.method !== "POST") {
      return json({ error: "Method not allowed" }, 405);
    }
    const token = /^Bearer\s+(\S+)$/i.exec(
      req.headers.get("Authorization") ?? "",
    )?.[1];
    if (!token) return json({ error: "Missing bearer token" }, 401);
    let body: unknown;
    try {
      body = await req.json();
    } catch {
      return json({ error: "Invalid JSON body" }, 400);
    }
    if (
      !body || typeof body !== "object" || !("user_id" in body) ||
      typeof body.user_id !== "string" ||
      !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
        body.user_id,
      )
    ) {
      return json({ error: "Invalid user_id" }, 400);
    }
    try {
      const userId = await deps.getUser(token);
      if (!userId) return json({ error: "Unauthorized" }, 401);
      if (userId !== body.user_id) {
        return json({ error: "Cannot delete another user" }, 403);
      }
      // Read page zero after each removal, including nested/orphan photos.
      for (let page = 0; page < 100; page++) {
        const paths = await deps.listPhotos(userId);
        if (paths.length === 0) {
          await deps.prepareDeletion(userId);
          await deps.deleteUser(userId);
          return json({ status: "ok" }, 200);
        }
        await deps.removePhotos(paths);
      }
      return json({ error: "Photo cleanup incomplete; retry deletion" }, 503);
    } catch {
      // Never return provider errors containing account data or credentials.
      return json({ error: "Account deletion failed; retry deletion" }, 503);
    }
  };
}
