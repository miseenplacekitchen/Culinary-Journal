-- ══════════════════════════════════════════════════════════════════════
-- fix-phase3-batch.sql — Phase 3 surfaces (non-AI). Safe to re-run.
-- Chef of the Month, recipe-of-week clear fix, email queue on approve/reject.
-- ══════════════════════════════════════════════════════════════════════

-- ── Chef of the Month (profiles) ───────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_chef_of_month       boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS chef_of_month_at       timestamptz,
  ADD COLUMN IF NOT EXISTS chef_of_month_expires  timestamptz;

DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT p.oid::regprocedure AS sig FROM pg_proc p
           JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = 'public'
             AND p.proname IN ('admin_set_chef_of_month', 'get_chef_of_month', 'admin_set_recipe_of_week')
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.admin_set_chef_of_month(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.profiles
     SET is_chef_of_month = false, chef_of_month_at = NULL, chef_of_month_expires = NULL
   WHERE is_chef_of_month = true;
  IF p_user_id IS NOT NULL THEN
    UPDATE public.profiles SET
      is_chef_of_month = true,
      chef_of_month_at = now(),
      chef_of_month_expires = now() + interval '30 days'
    WHERE id = p_user_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'user_not_found'; END IF;
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_set_chef_of_month(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_chef_of_month()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_row jsonb;
BEGIN
  SELECT jsonb_build_object(
    'id', p.id,
    'username', p.username,
    'full_name', p.full_name,
    'avatar_url', p.avatar_url,
    'chef_of_month_at', p.chef_of_month_at,
    'chef_of_month_expires', p.chef_of_month_expires,
    'recipe_count', (
      SELECT COUNT(*)::int FROM public.submitted_recipes r
       WHERE r.user_id = p.id AND r.status = 'approved' AND r.visibility = 'Public'
    )
  ) INTO v_row
  FROM public.profiles p
  WHERE p.is_chef_of_month = true
    AND (p.chef_of_month_expires IS NULL OR p.chef_of_month_expires > now())
  LIMIT 1;
  RETURN COALESCE(v_row, 'null'::jsonb);
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_chef_of_month() TO anon, authenticated;

-- Recipe of the Week — allow clearing with NULL id
CREATE OR REPLACE FUNCTION public.admin_set_recipe_of_week(p_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.submitted_recipes
     SET is_recipe_of_week = false, recipe_of_week_at = NULL, recipe_of_week_expires = NULL
   WHERE is_recipe_of_week = true;
  IF p_id IS NOT NULL THEN
    UPDATE public.submitted_recipes SET
      is_recipe_of_week = true,
      recipe_of_week_at = now(),
      recipe_of_week_expires = now() + interval '7 days'
    WHERE id = p_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'recipe_not_found'; END IF;
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_set_recipe_of_week(uuid) TO authenticated;

-- ── Email queue on approve/reject (best-effort if table exists) ────
CREATE OR REPLACE FUNCTION public.admin_review_recipe(
  p_id uuid, p_status text, p_notes text DEFAULT ''
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id   uuid;
  v_name      text;
  v_msg       text;
  v_email     text;
  v_username  text;
  v_site      text := 'https://www.theculinaryjournal.site';
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_status NOT IN ('approved','rejected','pending') THEN
    RAISE EXCEPTION 'Invalid status: %', p_status;
  END IF;

  SELECT user_id, recipe_name INTO v_user_id, v_name
    FROM public.submitted_recipes WHERE id = p_id;

  UPDATE public.submitted_recipes
     SET status = p_status, reviewer_notes = p_notes, reviewed_at = now()
   WHERE id = p_id;

  IF v_user_id IS NOT NULL AND p_status IN ('approved', 'rejected') THEN
    v_msg := CASE p_status
      WHEN 'approved' THEN 'Your recipe "' || COALESCE(v_name, 'submission') || '" was approved and is now live!'
      ELSE 'Your recipe "' || COALESCE(v_name, 'submission') || '" needs updates.'
           || CASE WHEN COALESCE(p_notes, '') <> '' THEN ' ' || p_notes ELSE '' END
    END;
    INSERT INTO public.notifications (user_id, type, recipe_id, recipe_name, message)
    VALUES (
      v_user_id,
      CASE WHEN p_status = 'approved' THEN 'recipe_approved' ELSE 'recipe_rejected' END,
      p_id, v_name, v_msg
    );

    IF EXISTS (SELECT 1 FROM information_schema.tables
               WHERE table_schema = 'public' AND table_name = 'email_queue') THEN
      SELECT COALESCE(u.email, p.email), COALESCE(p.username, p.full_name, 'Member')
        INTO v_email, v_username
        FROM public.profiles p
        LEFT JOIN auth.users u ON u.id = p.id
       WHERE p.id = v_user_id;
      IF v_email IS NOT NULL AND v_email <> '' THEN
        INSERT INTO public.email_queue (template_key, to_email, to_name, variables, status)
        VALUES (
          CASE WHEN p_status = 'approved' THEN 'recipe_approved' ELSE 'recipe_rejected' END,
          v_email,
          v_username,
          jsonb_build_object(
            'name', v_username,
            'recipe_name', COALESCE(v_name, 'your recipe'),
            'recipe_id', p_id::text,
            'recipe_url', v_site || '/recipe-page.html?id=' || p_id::text,
            'site_url', v_site,
            'rejection_reason', COALESCE(p_notes, ''),
            'reviewer_notes', COALESCE(p_notes, '')
          ),
          'pending'
        );
      END IF;
    END IF;
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_review_recipe(uuid, text, text) TO authenticated;

SELECT pg_notify('pgrst', 'reload schema');
SELECT 'fix-phase3-batch.sql complete' AS status;
