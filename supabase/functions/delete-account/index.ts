import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { createDeletionHandler } from "./handler.ts";

const admin = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false, autoRefreshToken: false } },
);

Deno.serve(createDeletionHandler({
  async getUser(token) {
    const { data, error } = await admin.auth.getUser(token);
    if (error) return null;
    return data.user?.id ?? null;
  },
  async listPhotos(userId) {
    const { data, error } = await admin.rpc("list_account_meal_photos", {
      p_user_id: userId,
    });
    if (error) throw error;
    return (data as { name: string }[]).map((row) => row.name);
  },
  async removePhotos(paths) {
    const { error } = await admin.storage.from("meal-photos").remove(paths);
    if (error) throw error;
  },
  async prepareDeletion(userId) {
    const { error } = await admin.rpc("prepare_account_deletion", {
      p_user_id: userId,
    });
    if (error) throw error;
  },
  async deleteUser(userId) {
    const { error } = await admin.auth.admin.deleteUser(userId);
    if (error) throw error;
  },
}));
