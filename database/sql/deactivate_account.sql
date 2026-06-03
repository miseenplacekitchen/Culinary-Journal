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
DROP FUNCTION IF EXISTS admin_deactivate_user(uuid, text, integer, text);
CREATE FUNCTION admin_deactivate_user(
  p_user_id uuid,
  p_type    text    DEFAULT 'permanent',
  p_days    integer DEFAULT NULL,
  p_reason  text    DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_reactivate_at timestamptz := NULL;
  v_email         text;
  v_name          text;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;
  IF p_user_id = auth.uid() THEN
    RAISE EXCEPTION 'Admins cannot deactivate themselves';
  END IF;

  -- Calculate reactivation date for temporary deactivations
  IF p_type = 'temporary' AND p_days IS NOT NULL AND p_days > 0 THEN
    v_reactivate_at := NOW() + (p_days || ' days')::interval;
  END IF;

  SELECT email, full_name INTO v_email, v_name
  FROM profiles WHERE id = p_user_id;

  UPDATE profiles SET
    is_active           = false,
    deactivated_at      = NOW(),
    deactivation_type   = COALESCE(p_type, 'permanent'),
    deactivation_reason = p_reason,
    reactivate_at       = v_reactivate_at,
    reactivated_at      = NULL
  WHERE id = p_user_id;

  IF NOT FOUND THEN RAISE EXCEPTION 'User not found'; END IF;

  -- Queue deactivation email only if both table and function exist
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'email_queue')
  AND EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
              WHERE p.proname = 'queue_email' AND n.nspname = 'public') THEN
    PERFORM queue_email(
      'account_deactivated', v_email, v_name,
      jsonb_build_object(
        'name',   COALESCE(v_name, 'Member'),
        'reason', COALESCE(p_reason, 'No reason provided')
      )
    );
  END IF;
END;
$$;

-- ── admin_reactivate_user(p_user_id) ─────────────────────────────────
DROP FUNCTION IF EXISTS admin_reactivate_user(uuid);
CREATE FUNCTION admin_reactivate_user(p_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;
  UPDATE profiles SET
    is_active           = true,
    deactivated_at      = NULL,
    deactivation_type   = NULL,
    deactivation_reason = NULL,
    reactivate_at       = NULL,
    reactivated_at      = NOW()
  WHERE id = p_user_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'User not found'; END IF;
END;
$$;

SELECT 'Deactivation system ready' AS status;
