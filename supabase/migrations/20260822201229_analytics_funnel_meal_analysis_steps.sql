-- Extends the activation funnel with the "orta huni" (middle funnel) steps
-- that shipped in 1.2.2+12 but were never added to analytics_funnel_steps:
-- scan_photo_captured, meal_analysis_started, meal_analysis_succeeded.
--
-- Without this, a device that opened the camera and then took a photo that
-- never finished analysing collapses into the same "stalled at camera_ready"
-- bucket as a device that never took a photo at all — exactly the "kamera
-- geldi, hiçbir şey yapmadı" (27% of devices) blindness described in
-- wiki/04-problems-open.md. This is the fix.
--
-- Two deliberate modelling choices:
--
-- 1. scan_barcode_detected and scan_photo_captured share one step
--    (content_captured) rather than getting separate step_orders. They are
--    alternative paths at the same funnel depth, not sequential — the same
--    pattern already used for step 3 (session_started: guest/login/register
--    are alternatives too). Giving them different step numbers would make
--    the photo path look "deeper" than the barcode path for no real reason.
--
-- 2. meal_analysis_failed is deliberately NOT added as a step. A failure is
--    a terminal outcome, not forward progress — folding it into the
--    monotonic step ladder would make a failed analysis look like more
--    progress than a successful one where the user simply hasn't saved yet.
--    It stays fully queryable directly off analytics_events (reason ×
--    abandoned × duration_ms, as already used in the sprint notes) without
--    needing a slot in this funnel.
--
-- step_order is computed from the VALUES list on every query (not stored
-- per-event), so renumbering the tail (old 6/7/8 -> new 9/10) here is safe
-- and touches no existing data.

create or replace view public.analytics_funnel_steps as
select * from (
  values
    (1,  'app_opened',          array['app_opened']),
    (2,  'onboarding_shown',    array['onboarding_shown']),
    (3,  'session_started',     array['guest_started', 'login_succeeded', 'register_succeeded']),
    (4,  'scanner_opened',      array['scanner_opened']),
    (5,  'camera_ready',        array['scan_camera_ready']),
    (6,  'content_captured',    array['scan_barcode_detected', 'scan_photo_captured']),
    (7,  'analysis_started',    array['meal_analysis_started']),
    (8,  'analysis_succeeded',  array['meal_analysis_succeeded']),
    (9,  'product_viewed',      array['product_viewed']),
    (10, 'activated',           array['favorite_added', 'meal_added', 'product_shared'])
) as t(step_order, step, event_names);

-- create or replace view preserves the existing ACL when the column set is
-- unchanged, but re-asserting the revoke is cheap and makes the "never
-- exposed to clients" invariant explicit at every migration that touches
-- this view, not just the one that first created it.
revoke all on public.analytics_funnel_steps from anon, authenticated;
