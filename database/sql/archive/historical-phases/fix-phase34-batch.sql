-- ══════════════════════════════════════════════════════════════════════
-- fix-phase34-batch.sql — Admin batch: duplicates, ROTW expiry, owner analytics
-- Safe to re-run. Run after fix-phase33-batch.sql.
-- Also run schedule-rotw-expiry-cron.sql (Betty ops) for daily auto-clear.
-- ══════════════════════════════════════════════════════════════════════

-- ── 1. Find likely duplicate recipes ───────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_find_duplicate_recipes(int);
CREATE FUNCTION public.admin_find_duplicate_recipes(p_limit int DEFAULT 40)
RETURNS TABLE (
  group_key text,
  recipe_ids uuid[],
  recipe_names text[],
  credit_names text[],
  statuses text[],
  match_score int
) LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN QUERY
  WITH norm AS (
    SELECT
      r.id,
      r.recipe_name,
      r.credit_name,
      r.status,
      lower(regexp_replace(trim(COALESCE(r.recipe_name, '')), '[^a-z0-9]+', ' ', 'g')) AS norm_name,
      lower(trim(COALESCE(r.credit_name, ''))) AS norm_credit
    FROM public.submitted_recipes r
    WHERE COALESCE(r.recipe_name, '') <> ''
  ),
  groups AS (
    SELECT
      norm_name AS gkey,
      array_agg(id ORDER BY submitted_at NULLS LAST) AS ids,
      array_agg(recipe_name ORDER BY submitted_at NULLS LAST) AS names,
      array_agg(COALESCE(credit_name, '') ORDER BY submitted_at NULLS LAST) AS credits,
      array_agg(status ORDER BY submitted_at NULLS LAST) AS sts,
      count(*)::int AS cnt
    FROM norm
    WHERE norm_name <> ''
    GROUP BY norm_name
    HAVING count(*) > 1
  )
  SELECT
    g.gkey,
    g.ids,
    g.names,
    g.credits,
    g.sts,
    g.cnt
  FROM groups g
  ORDER BY g.cnt DESC, g.gkey
  LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 40), 100));
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_find_duplicate_recipes(int) TO authenticated;

-- ── 2. Auto-expire Recipe of the Week ──────────────────────────────────
DROP FUNCTION IF EXISTS public.expire_recipe_of_week();
CREATE FUNCTION public.expire_recipe_of_week()
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE n int;
BEGIN
  UPDATE public.submitted_recipes
  SET is_recipe_of_week = false,
      recipe_of_week_at = NULL,
      recipe_of_week_expires = NULL
  WHERE is_recipe_of_week = true
    AND recipe_of_week_expires IS NOT NULL
    AND recipe_of_week_expires < now();
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END;
$$;
GRANT EXECUTE ON FUNCTION public.expire_recipe_of_week() TO authenticated;

-- ── 3. Owner analytics dashboard RPC ───────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_owner_analytics();
CREATE FUNCTION public.admin_get_owner_analytics()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  out jsonb := '{}'::jsonb;
  top_saved jsonb := '[]'::jsonb;
  lib_counts jsonb := '{}'::jsonb;
  cat_counts jsonb := '[]'::jsonb;
  sub_counts jsonb := '[]'::jsonb;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;

  PERFORM public.expire_recipe_of_week();

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', r.id, 'recipe_name', r.recipe_name, 'save_count', c.cnt
  ) ORDER BY c.cnt DESC), '[]'::jsonb) INTO top_saved
  FROM (
    SELECT recipe_id, count(*)::int AS cnt
    FROM public.recipe_engagement
    GROUP BY recipe_id
    ORDER BY cnt DESC
    LIMIT 8
  ) c
  JOIN public.submitted_recipes r ON r.id = c.recipe_id;

  SELECT jsonb_build_object(
    'ingredient', (SELECT count(*) FROM public.ingredient_profiles WHERE status = 'published'),
    'spice', (SELECT count(*) FROM public.spice_profiles WHERE status = 'published'),
    'tool', (SELECT count(*) FROM public.tool_profiles WHERE status = 'published'),
    'cut', (SELECT count(*) FROM public.cut_profiles WHERE status = 'published'),
    'preservation', (SELECT count(*) FROM public.preservation_profiles WHERE status = 'published')
  ) INTO lib_counts;

  SELECT COALESCE(jsonb_agg(jsonb_build_object('category', category, 'count', cnt) ORDER BY cnt DESC), '[]'::jsonb)
  INTO cat_counts
  FROM (
    SELECT category, count(*)::int AS cnt
    FROM public.submitted_recipes
    WHERE status = 'approved' AND category IS NOT NULL AND btrim(category) <> ''
    GROUP BY category
  ) x;

  SELECT COALESCE(jsonb_agg(jsonb_build_object('status', status, 'count', cnt)), '[]'::jsonb)
  INTO sub_counts
  FROM (
    SELECT status, count(*)::int AS cnt FROM public.submitted_recipes GROUP BY status
  ) s;

  out := jsonb_build_object(
    'recipes', jsonb_build_object(
      'total', (SELECT count(*) FROM public.submitted_recipes),
      'pending', (SELECT count(*) FROM public.submitted_recipes WHERE status = 'pending'),
      'approved', (SELECT count(*) FROM public.submitted_recipes WHERE status = 'approved'),
      'rejected', (SELECT count(*) FROM public.submitted_recipes WHERE status = 'rejected'),
      'featured', (SELECT count(*) FROM public.submitted_recipes WHERE is_featured = true),
      'rotw', (SELECT count(*) FROM public.submitted_recipes WHERE is_recipe_of_week = true),
      'submitted_7d', (SELECT count(*) FROM public.submitted_recipes WHERE submitted_at >= now() - interval '7 days'),
      'submitted_30d', (SELECT count(*) FROM public.submitted_recipes WHERE submitted_at >= now() - interval '30 days'),
      'missing_taxonomy', (SELECT count(*) FROM public.submitted_recipes WHERE status = 'approved' AND (sub_category IS NULL OR btrim(sub_category) = '' OR division IS NULL OR btrim(division) = '')),
      'oldest_pending_days', COALESCE((
        SELECT EXTRACT(day FROM now() - min(submitted_at))::int
        FROM public.submitted_recipes WHERE status = 'pending'
      ), 0),
      'by_status', sub_counts,
      'by_category', cat_counts
    ),
    'members', jsonb_build_object(
      'total', (SELECT count(*) FROM public.profiles),
      'new_7d', (SELECT count(*) FROM public.profiles WHERE created_at >= now() - interval '7 days'),
      'new_30d', (SELECT count(*) FROM public.profiles WHERE created_at >= now() - interval '30 days'),
      'households', (SELECT count(*) FROM public.households),
      'deactivated', (SELECT count(*) FROM public.profiles WHERE is_active = false)
    ),
    'engagement', jsonb_build_object(
      'total_saves', (SELECT count(*) FROM public.recipe_engagement),
      'saves_7d', (SELECT count(*) FROM public.recipe_engagement WHERE created_at >= now() - interval '7 days'),
      'top_saved', top_saved
    ),
    'library', lib_counts,
    'pipeline', jsonb_build_object(
      'pending_library_submissions', (SELECT count(*) FROM public.library_profile_submissions WHERE status = 'pending'),
      'email_queue_pending', (SELECT count(*) FROM public.email_queue WHERE status = 'pending')
    )
  );
  RETURN out;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_get_owner_analytics() TO authenticated;

-- ── 4. Pipeline hardening — review sets approved_at when column exists ─
CREATE OR REPLACE FUNCTION public.admin_review_recipe(
  p_id uuid, p_status text, p_notes text DEFAULT ''
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_user_id uuid;
  v_name text;
  v_msg text;
  v_email text;
  v_username text;
  v_site text := 'https://www.theculinaryjournal.site';
  v_has_approved_at boolean;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_status NOT IN ('approved','rejected','pending') THEN
    RAISE EXCEPTION 'Invalid status: %', p_status;
  END IF;

  SELECT user_id, recipe_name INTO v_user_id, v_name
  FROM public.submitted_recipes WHERE id = p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'recipe_not_found'; END IF;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'submitted_recipes' AND column_name = 'approved_at'
  ) INTO v_has_approved_at;

  IF v_has_approved_at THEN
    UPDATE public.submitted_recipes
    SET status = p_status,
        reviewer_notes = p_notes,
        reviewed_at = now(),
        approved_at = CASE WHEN p_status = 'approved' THEN now() ELSE approved_at END
    WHERE id = p_id;
  ELSE
    UPDATE public.submitted_recipes
    SET status = p_status, reviewer_notes = p_notes, reviewed_at = now()
    WHERE id = p_id;
  END IF;

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
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'email_queue') THEN
      SELECT COALESCE(u.email, p.email), COALESCE(p.username, p.full_name, 'Member')
      INTO v_email, v_username
      FROM public.profiles p
      LEFT JOIN auth.users u ON u.id = p.id
      WHERE p.id = v_user_id;
      IF v_email IS NOT NULL AND btrim(v_email) <> '' THEN
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
  END IF;
END;
$$;

SELECT 'fix-phase34-batch.sql complete' AS status;
