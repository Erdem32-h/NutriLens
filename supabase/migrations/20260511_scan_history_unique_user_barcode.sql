-- The client invokes scan_history.upsert(onConflict: 'user_id,barcode'),
-- which requires a matching unique constraint on the server. Without it
-- the upsert raises "there is no unique or exclusion constraint matching
-- the ON CONFLICT specification" and the silent catch in
-- addScanToHistory drops the write — visible symptom: scan_count = 0
-- on Supabase even though local Drift recorded the scan fine.

-- Safety: dedupe any pre-existing (user_id, barcode) pairs first so the
-- constraint can be created without violations. Keep the most recent.
DELETE FROM public.scan_history a
USING public.scan_history b
WHERE a.user_id = b.user_id
  AND a.barcode  = b.barcode
  AND a.scanned_at < b.scanned_at;

ALTER TABLE public.scan_history
  ADD CONSTRAINT scan_history_user_barcode_unique
  UNIQUE (user_id, barcode);
