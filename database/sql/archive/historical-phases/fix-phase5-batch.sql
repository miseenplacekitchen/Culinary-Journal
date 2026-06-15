-- ══════════════════════════════════════════════════════════════════════
-- fix-phase5-batch.sql — Follower notifications on approve, link check fields.
-- Safe to re-run. Run after fix-phase4-batch.sql.
-- ══════════════════════════════════════════════════════════════════════

ALTER TABLE public.submitted_recipes
  ADD COLUMN IF NOT EXISTS source_link_status text,
  ADD COLUMN IF NOT EXISTS source_link_checked_at timestamptz;

DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT p.oid::regprocedure AS sig FROM pg_proc p
           JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = 'public'
             AND p.proname IN ('admin_review_recipe', 'record_source_link_check')
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.record_source_link_check(
  p_recipe_id uuid,
  p_status text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF p_recipe_id IS NULL OR p_status NOT IN ('ok', 'dead', 'unknown') THEN RETURN; END IF;
  UPDATE public.submitted_recipes
     SET source_link_status = p_status,
         source_link_checked_at = now()
   WHERE id = p_recipe_id
     AND (user_id = auth.uid() OR is_admin() OR status = 'approved');
END;
$$;
GRANT EXECUTE ON FUNCTION public.record_source_link_check(uuid, text) TO anon, authenticated;

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
  v_author    text;
  v_vis       text;
  v_site      text := 'https://www.theculinaryjournal.site';
  v_follower  record;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_status NOT IN ('approved','rejected','pending') THEN
    RAISE EXCEPTION 'Invalid status: %', p_status;
  END IF;

  SELECT user_id, recipe_name, visibility INTO v_user_id, v_name, v_vis
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
          v_email, v_username,
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

    -- Notify followers when a public recipe is newly approved
    IF p_status = 'approved' AND COALESCE(v_vis, 'Public') IN ('Public', 'Friends') THEN
      SELECT COALESCE(username, full_name, 'A contributor') INTO v_author
        FROM public.profiles WHERE id = v_user_id;
      FOR v_follower IN
        SELECT cf.follower_id AS uid
          FROM public.contributor_follows cf
         WHERE cf.following_id = v_user_id
      LOOP
        INSERT INTO public.notifications (user_id, type, recipe_id, recipe_name, message)
        VALUES (
          v_follower.uid,
          'follow_new_recipe',
          p_id,
          v_name,
          COALESCE(v_author, 'A contributor you follow') || ' published: ' || COALESCE(v_name, 'a new recipe')
        );
      END LOOP;
    END IF;
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_review_recipe(uuid, text, text) TO authenticated;

SELECT pg_notify('pgrst', 'reload schema');
SELECT 'fix-phase5-batch.sql complete' AS status;
