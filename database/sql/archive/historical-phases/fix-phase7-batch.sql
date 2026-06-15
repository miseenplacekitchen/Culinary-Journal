-- ══════════════════════════════════════════════════════════════════════
-- fix-phase7-batch.sql — Taxonomy on browse RPC, welcome email on onboarding.
-- Safe to re-run. Run after fix-phase6-batch.sql.
-- ══════════════════════════════════════════════════════════════════════

DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT p.oid::regprocedure AS sig FROM pg_proc p
           JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = 'public'
             AND p.proname IN ('get_approved_recipes', 'complete_my_onboarding')
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.get_approved_recipes(
  p_category     text DEFAULT NULL,
  p_spice        text DEFAULT NULL,
  p_dietary      text DEFAULT NULL,
  p_search       text DEFAULT NULL,
  p_sub_category text DEFAULT NULL,
  p_division     text DEFAULT NULL,
  p_limit        int  DEFAULT 50,
  p_offset       int  DEFAULT 0
)
RETURNS TABLE (
  id             uuid,
  recipe_name    text,
  native_title   text,
  category       text,
  sub_category   text,
  division       text,
  spice_level    text,
  dietary_tags   text[],
  origin_country text,
  image_url      text,
  credit_name    text,
  credit_handle  text,
  submitted_at   timestamptz,
  username       text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN QUERY
  SELECT sr.id, sr.recipe_name, sr.native_title, sr.category,
         sr.sub_category, sr.division,
         sr.spice_level, sr.dietary_tags, sr.origin_country,
         sr.image_url, sr.credit_name, sr.credit_handle,
         sr.submitted_at, p.username
    FROM public.submitted_recipes sr
    LEFT JOIN public.profiles p ON p.id = sr.user_id
   WHERE sr.status = 'approved'
     AND (
       sr.visibility = 'Public'
       OR (
         sr.visibility = 'Friends'
         AND auth.uid() IS NOT NULL
         AND EXISTS (
           SELECT 1 FROM public.contributor_follows cf
            WHERE cf.follower_id = auth.uid() AND cf.following_id = sr.user_id
         )
       )
     )
     AND (p_category     IS NULL OR sr.category = p_category)
     AND (p_spice        IS NULL OR sr.spice_level = p_spice)
     AND (p_dietary      IS NULL OR p_dietary = ANY(sr.dietary_tags))
     AND (p_search       IS NULL OR sr.recipe_name ILIKE '%' || p_search || '%')
     AND (p_sub_category IS NULL OR sr.sub_category = p_sub_category)
     AND (p_division     IS NULL OR sr.division = p_division)
   ORDER BY sr.submitted_at DESC
   LIMIT p_limit OFFSET p_offset;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_approved_recipes(text,text,text,text,text,text,int,int) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.complete_my_onboarding(
  p_dietary_preferences text[] DEFAULT '{}',
  p_allergies           text[] DEFAULT '{}',
  p_health_conditions   text[] DEFAULT '{}',
  p_cooking_style       text DEFAULT ''
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_email text;
  v_name  text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;

  UPDATE public.profiles SET
    dietary_preferences   = COALESCE(p_dietary_preferences, '{}'),
    allergies             = COALESCE(p_allergies, '{}'),
    health_conditions     = COALESCE(p_health_conditions, '{}'),
    cooking_style         = COALESCE(NULLIF(trim(p_cooking_style), ''), cooking_style, ''),
    onboarding_completed  = true
  WHERE id = auth.uid();

  IF EXISTS (SELECT 1 FROM information_schema.tables
             WHERE table_schema = 'public' AND table_name = 'email_queue') THEN
    SELECT u.email, COALESCE(p.full_name, p.username, 'Member')
      INTO v_email, v_name
      FROM public.profiles p
      JOIN auth.users u ON u.id = p.id
     WHERE p.id = auth.uid();

    IF v_email IS NOT NULL AND v_email <> '' AND NOT EXISTS (
      SELECT 1 FROM public.email_queue
       WHERE to_email = v_email AND template_key = 'welcome'
         AND status IN ('pending', 'sending', 'sent')
    ) THEN
      INSERT INTO public.email_queue (template_key, to_email, to_name, variables, status)
      VALUES (
        'welcome',
        v_email,
        v_name,
        jsonb_build_object(
          'name', v_name,
          'site_url', 'https://www.theculinaryjournal.site',
          'recipes_url', 'https://www.theculinaryjournal.site/recipes.html'
        ),
        'pending'
      );
    END IF;
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.complete_my_onboarding(text[],text[],text[],text) TO authenticated;

SELECT pg_notify('pgrst', 'reload schema');
SELECT 'fix-phase7-batch.sql complete' AS status;
