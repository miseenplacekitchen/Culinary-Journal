-- ══════════════════════════════════════════════════════════════════════
-- Account Deactivation RPCs — The Culinary Journal
-- Matches exact dashboard.html call signatures:
--   admin_deactivate_user(p_user_id, p_type, p_days, p_reason)
--   admin_reactivate_user(p_user_id)
--   deactivate_my_account()
-- ══════════════════════════════════════════════════════════════════════

-- Add required columns to profiles if they don't exist
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_name='profiles' AND column_name='deactivated_at') THEN
    ALTER TABLE profiles ADD COLUMN deactivated_at timestamptz;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_name='profiles' AND column_name='deactivation_reason') THEN
    ALTER TABLE profiles ADD COLUMN deactivation_reason text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_name='profiles' AND column_name='deactivation_type') THEN
    ALTER TABLE profiles ADD COLUMN deactivation_type text; -- 'permanent' or 'temporary'
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_name='profiles' AND column_name='reactivate_at') THEN
    ALTER TABLE profiles ADD COLUMN reactivate_at timestamptz; -- NULL for permanent
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_name='profiles' AND column_name='reactivated_at') THEN
    ALTER TABLE profiles ADD COLUMN reactivated_at timestamptz;
  END IF;
END; $$;

-- ── deactivate_my_account() — user deactivates their own account ──────
DROP FUNCTION IF EXISTS deactivate_my_account();
CREATE FUNCTION deactivate_my_account()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  UPDATE profiles SET
    is_active          = false,
    deactivated_at     = NOW(),
    deactivation_type  = 'permanent',
    deactivation_reason = 'Self-deactivated'
  WHERE id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'Profile not found'; END IF;
END;
$$;

-- ── admin_deactivate_user(p_user_id, p_type, p_days, p_reason) ────────
-- p_type: 'permanent' or 'temporary'
-- p_days: number of days for temporary (NULL for permanent)
-- Matches dashboard.html call exactly
-- ── admin_reactivate_user(p_user_id) ─────────────────────────────────
SELECT 'Deactivation system ready' AS status;
