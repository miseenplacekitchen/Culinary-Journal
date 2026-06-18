-- fix-category-cleanup-v3.sql — Post A–K category migration cleanup.
-- Run once in Supabase SQL Editor after fix-categories-v2.sql.
-- Safe to re-run.

-- ── 1. Baby browse — tags, not retired Little Ones category ───────────────
DROP FUNCTION IF EXISTS public.get_baby_browse_recipes(int, int);
CREATE OR REPLACE FUNCTION public.get_baby_browse_recipes(
  p_limit  int DEFAULT 48,
  p_offset int DEFAULT 0
)
RETURNS TABLE (
  id              uuid,
  recipe_name     text,
  category        text,
  origin_country  text,
  image_url       text,
  dietary_tags    text[],
  occasion_tags   text[],
  health_tags     text[],
  ingredients     jsonb
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  p_limit  := GREATEST(1, LEAST(COALESCE(p_limit, 48), 100));
  p_offset := GREATEST(0, COALESCE(p_offset, 0));

  RETURN QUERY
  SELECT sr.id, sr.recipe_name, sr.category, sr.origin_country, sr.image_url,
         sr.dietary_tags, sr.occasion_tags, sr.health_tags, sr.ingredients
    FROM public.submitted_recipes sr
   WHERE sr.status = 'approved'
     AND sr.visibility = 'Public'
     AND (
       'Baby Friendly' = ANY(COALESCE(sr.health_tags, '{}'))
       OR 'Kid Friendly' = ANY(COALESCE(sr.health_tags, '{}'))
       OR COALESCE(sr.occasion_tags, '{}') && ARRAY[
         '4-6 Months', '6-8 Months', '8-12 Months', '12 Months+'
       ]::text[]
       OR sr.category = 'Little Ones'
     )
   ORDER BY sr.submitted_at DESC
   LIMIT p_limit OFFSET p_offset;
END;
$$;
REVOKE ALL ON FUNCTION public.get_baby_browse_recipes(int, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_baby_browse_recipes(int, int) TO anon, authenticated;

-- ── 2. Canonical get_recipe_taxonomy (fold from phase-6 deploy) ───────────
DROP FUNCTION IF EXISTS public.get_recipe_taxonomy(text);
CREATE OR REPLACE FUNCTION public.get_recipe_taxonomy(p_category text DEFAULT NULL)
RETURNS TABLE (
  subcategory_id uuid, subcategory_name text, subcategory_category text,
  division_id uuid, division_name text, division_emoji text,
  division_subtitle text, division_description text
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT sc.id, sc.name, sc.category,
         d.id, d.name, d.emoji, d.subtitle, d.description
    FROM public.recipe_subcategories sc
    LEFT JOIN public.recipe_divisions d
      ON d.category = sc.category AND d.subcategory = sc.name AND d.is_active = true
   WHERE sc.is_active = true
     AND (p_category IS NULL OR sc.category = p_category)
   ORDER BY sc.category, sc.sort_order, sc.name, d.sort_order, d.name;
$$;
REVOKE ALL ON FUNCTION public.get_recipe_taxonomy(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_recipe_taxonomy(text) TO anon, authenticated;

-- ── 3. Stripe subscription apply — idempotent on session id ─────────────────
DROP FUNCTION IF EXISTS public.apply_stripe_subscription(uuid, text, text, text);
CREATE OR REPLACE FUNCTION public.apply_stripe_subscription(
  p_user_id uuid,
  p_tier text,
  p_stripe_session_id text DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_tier NOT IN ('daily','weekly','monthly','yearly','premium','event') THEN
    RAISE EXCEPTION 'Invalid tier';
  END IF;

  IF p_stripe_session_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM public.stripe_checkout_sessions
      WHERE stripe_session_id = p_stripe_session_id AND status = 'completed'
    ) THEN
      RETURN;
    END IF;
    IF EXISTS (
      SELECT 1 FROM public.member_subscriptions
      WHERE source = 'stripe'
        AND notes IS NOT NULL
        AND notes = COALESCE(p_notes, p_stripe_session_id)
    ) THEN
      UPDATE public.stripe_checkout_sessions
         SET status = 'completed', completed_at = COALESCE(completed_at, now())
       WHERE stripe_session_id = p_stripe_session_id;
      RETURN;
    END IF;
  END IF;

  UPDATE public.profiles SET subscription_tier = p_tier WHERE id = p_user_id;

  INSERT INTO public.member_subscriptions (user_id, tier, status, source, notes)
  VALUES (p_user_id, p_tier, 'active', 'stripe', COALESCE(p_notes, p_stripe_session_id));

  IF p_stripe_session_id IS NOT NULL THEN
    UPDATE public.stripe_checkout_sessions
       SET status = 'completed', completed_at = now()
     WHERE stripe_session_id = p_stripe_session_id;
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.apply_stripe_subscription(uuid, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.apply_stripe_subscription(uuid, text, text, text) TO service_role;

-- ── 4. Backfill user-friendly tags on legacy rows (optional, idempotent) ──
UPDATE public.submitted_recipes sr
SET health_tags = (
  SELECT ARRAY(SELECT DISTINCT unnest(
    COALESCE(sr.health_tags, '{}') || ARRAY['Baby Friendly']::text[]
  ))
)
WHERE sr.category = 'Little Ones'
  AND NOT ('Baby Friendly' = ANY(COALESCE(sr.health_tags, '{}')));

UPDATE public.submitted_recipes sr
SET meal_type_tags = (
  SELECT ARRAY(SELECT DISTINCT unnest(
    COALESCE(sr.meal_type_tags, '{}') || ARRAY['Breakfast']::text[]
  ))
)
WHERE sr.category IN ('Rise & Shine', 'Curds, Creams & Eggs')
  AND NOT ('Breakfast' = ANY(COALESCE(sr.meal_type_tags, '{}')));

UPDATE public.submitted_recipes sr
SET health_tags = (
  SELECT ARRAY(SELECT DISTINCT unnest(
    COALESCE(sr.health_tags, '{}') || ARRAY['Recovery Food']::text[]
  ))
)
WHERE sr.category = 'Nourish & Heal'
  AND NOT ('Recovery Food' = ANY(COALESCE(sr.health_tags, '{}')));

SELECT 'fix-category-cleanup-v3 applied' AS status,
  (SELECT count(*) FROM public.submitted_recipes
   WHERE 'Baby Friendly' = ANY(COALESCE(health_tags, '{}'))) AS baby_tagged,
  (SELECT count(*) FROM public.submitted_recipes
   WHERE 'Recovery Food' = ANY(COALESCE(health_tags, '{}'))) AS recovery_tagged;
