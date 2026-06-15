-- ══════════════════════════════════════════════════════════════════════
-- fix-phase6-batch.sql — Onboarding flag, recipe taxonomy, email queue admin.
-- Safe to re-run. Run after fix-phase5-batch.sql.
-- ══════════════════════════════════════════════════════════════════════

-- ── Onboarding ───────────────────────────────────────────────────────
-- NULL or true = skip wizard (legacy members). false = show onboarding.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS onboarding_completed boolean;

UPDATE public.profiles SET onboarding_completed = true WHERE onboarding_completed IS NULL;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, username, full_name, email, onboarding_completed)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.raw_user_meta_data->>'name', ''),
    NEW.email,
    false
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- ── Recipe taxonomy ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.recipe_subcategories (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category    text NOT NULL,
  name        text NOT NULL,
  sort_order  int  NOT NULL DEFAULT 0,
  is_active   boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (category, name)
);

CREATE TABLE IF NOT EXISTS public.recipe_divisions (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category           text NOT NULL,
  subcategory        text,
  name               text NOT NULL,
  emoji              text DEFAULT '🍽',
  subtitle           text,
  description        text,
  also_known_as      text[] DEFAULT '{}',
  tags               text[] DEFAULT '{}',
  section_visibility jsonb DEFAULT '{"description":true,"tags":true,"also_known_as":true}'::jsonb,
  sort_order         int NOT NULL DEFAULT 0,
  is_active          boolean NOT NULL DEFAULT true,
  created_at         timestamptz NOT NULL DEFAULT now(),
  UNIQUE (category, subcategory, name)
);

ALTER TABLE public.recipe_subcategories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recipe_divisions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone reads active recipe subcategories" ON public.recipe_subcategories;
CREATE POLICY "Anyone reads active recipe subcategories"
  ON public.recipe_subcategories FOR SELECT TO anon, authenticated
  USING (is_active = true);

DROP POLICY IF EXISTS "Admins manage recipe subcategories" ON public.recipe_subcategories;
CREATE POLICY "Admins manage recipe subcategories"
  ON public.recipe_subcategories FOR ALL TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "Anyone reads active recipe divisions" ON public.recipe_divisions;
CREATE POLICY "Anyone reads active recipe divisions"
  ON public.recipe_divisions FOR SELECT TO anon, authenticated
  USING (is_active = true);

DROP POLICY IF EXISTS "Admins manage recipe divisions" ON public.recipe_divisions;
CREATE POLICY "Admins manage recipe divisions"
  ON public.recipe_divisions FOR ALL TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

GRANT SELECT ON public.recipe_subcategories TO anon, authenticated;
GRANT SELECT ON public.recipe_divisions TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.recipe_subcategories TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.recipe_divisions TO authenticated;

ALTER TABLE public.submitted_recipes
  ADD COLUMN IF NOT EXISTS sub_category text,
  ADD COLUMN IF NOT EXISTS division text;

INSERT INTO public.recipe_subcategories (category, name, sort_order) VALUES
  ('Garden & Earth', 'Vegetables', 1),
  ('Garden & Earth', 'Fruits', 2),
  ('Garden & Earth', 'Herbs & Greens', 3),
  ('Garden & Earth', 'Legumes & Pulses', 4),
  ('Rise & Shine', 'Breakfast', 1),
  ('Rise & Shine', 'Brunch', 2),
  ('The Evening Table', 'Mains', 1),
  ('The Evening Table', 'Sides', 2),
  ('Meat & Fire', 'Beef', 1),
  ('Meat & Fire', 'Poultry', 2),
  ('Meat & Fire', 'Lamb', 3),
  ('Ocean & River', 'Fish', 1),
  ('Ocean & River', 'Shellfish', 2),
  ('Sweet Serenades', 'Cakes', 1),
  ('Sweet Serenades', 'Pastries', 2),
  ('Little Ones', 'Baby Food', 1),
  ('Little Ones', 'Family Favourites', 2)
ON CONFLICT (category, name) DO NOTHING;

INSERT INTO public.recipe_divisions (category, subcategory, name, emoji, subtitle, description, sort_order) VALUES
  ('Garden & Earth', 'Vegetables', 'Root Vegetables', '🥕', 'Earth-grown staples', 'Carrots, potatoes, beets and other roots.', 1),
  ('Garden & Earth', 'Vegetables', 'Leafy Greens', '🥬', 'Salads & sautés', 'Spinach, kale, lettuce and tender greens.', 2),
  ('Garden & Earth', 'Fruits', 'Stone Fruit', '🍑', 'Seasonal sweetness', 'Peaches, plums, cherries and apricots.', 1),
  ('Meat & Fire', 'Poultry', 'Roast Chicken', '🍗', 'Sunday classic', 'Whole bird and joint roasts.', 1),
  ('Ocean & River', 'Fish', 'White Fish', '🐟', 'Mild & flaky', 'Cod, snapper, barramundi and similar.', 1)
ON CONFLICT (category, subcategory, name) DO NOTHING;

-- ── Drop overloaded RPCs ─────────────────────────────────────────────
DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT p.oid::regprocedure AS sig FROM pg_proc p
           JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = 'public'
             AND p.proname IN (
               'get_my_profile',
               'complete_my_onboarding',
               'get_recipe_taxonomy',
               'admin_upsert_recipe_subcategory',
               'admin_delete_recipe_subcategory',
               'admin_upsert_recipe_division',
               'admin_delete_recipe_division',
               'admin_get_email_queue',
               'admin_reset_failed_emails'
             )
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.get_my_profile()
RETURNS TABLE (
  id uuid, full_name text, username text, email text,
  is_active boolean, is_admin boolean, theme_preference text,
  dietary_preferences text[], allergies text[], health_conditions text[],
  cooking_style text, font_size text, avatar_url text,
  created_at timestamptz, last_seen timestamptz,
  onboarding_completed boolean
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  RETURN QUERY
    SELECT p.id,
           p.full_name::text, p.username::text, u.email::text,
           p.is_active, p.is_admin, p.theme_preference::text,
           COALESCE(p.dietary_preferences, '{}')::text[],
           COALESCE(p.allergies, '{}')::text[],
           COALESCE(p.health_conditions, '{}')::text[],
           COALESCE(p.cooking_style, '')::text,
           COALESCE(p.font_size, 'medium')::text,
           p.avatar_url::text,
           u.created_at, p.last_seen,
           COALESCE(p.onboarding_completed, true)
    FROM public.profiles p
    JOIN auth.users u ON u.id = p.id
    WHERE p.id = auth.uid();
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_my_profile() TO authenticated;

CREATE OR REPLACE FUNCTION public.complete_my_onboarding(
  p_dietary_preferences text[] DEFAULT '{}',
  p_allergies           text[] DEFAULT '{}',
  p_health_conditions   text[] DEFAULT '{}',
  p_cooking_style       text DEFAULT ''
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  UPDATE public.profiles SET
    dietary_preferences   = COALESCE(p_dietary_preferences, '{}'),
    allergies             = COALESCE(p_allergies, '{}'),
    health_conditions     = COALESCE(p_health_conditions, '{}'),
    cooking_style         = COALESCE(NULLIF(trim(p_cooking_style), ''), cooking_style, ''),
    onboarding_completed  = true
  WHERE id = auth.uid();
END;
$$;
GRANT EXECUTE ON FUNCTION public.complete_my_onboarding(text[],text[],text[],text) TO authenticated;

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
GRANT EXECUTE ON FUNCTION public.get_recipe_taxonomy(text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.admin_upsert_recipe_subcategory(
  p_id uuid, p_category text, p_name text, p_sort_order int DEFAULT 0
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_id IS NULL THEN
    INSERT INTO public.recipe_subcategories (category, name, sort_order)
    VALUES (p_category, p_name, COALESCE(p_sort_order, 0))
    ON CONFLICT (category, name) DO UPDATE SET sort_order = EXCLUDED.sort_order, is_active = true
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.recipe_subcategories SET
      category = p_category, name = p_name, sort_order = COALESCE(p_sort_order, sort_order)
    WHERE id = p_id RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_upsert_recipe_subcategory(uuid,text,text,int) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_delete_recipe_subcategory(p_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.recipe_subcategories SET is_active = false WHERE id = p_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_delete_recipe_subcategory(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_upsert_recipe_division(
  p_id uuid, p_category text, p_subcategory text, p_name text,
  p_emoji text DEFAULT '🍽', p_subtitle text DEFAULT NULL,
  p_description text DEFAULT NULL, p_tags text[] DEFAULT '{}',
  p_sort_order int DEFAULT 0
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_id IS NULL THEN
    INSERT INTO public.recipe_divisions (category, subcategory, name, emoji, subtitle, description, tags, sort_order)
    VALUES (p_category, p_subcategory, p_name, COALESCE(p_emoji, '🍽'), p_subtitle, p_description, COALESCE(p_tags, '{}'), COALESCE(p_sort_order, 0))
    ON CONFLICT (category, subcategory, name) DO UPDATE SET
      emoji = EXCLUDED.emoji, subtitle = EXCLUDED.subtitle, description = EXCLUDED.description,
      tags = EXCLUDED.tags, sort_order = EXCLUDED.sort_order, is_active = true
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.recipe_divisions SET
      category = p_category, subcategory = p_subcategory, name = p_name,
      emoji = COALESCE(p_emoji, emoji), subtitle = p_subtitle, description = p_description,
      tags = COALESCE(p_tags, tags), sort_order = COALESCE(p_sort_order, sort_order)
    WHERE id = p_id RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_upsert_recipe_division(uuid,text,text,text,text,text,text,text[],int) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_delete_recipe_division(p_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.recipe_divisions SET is_active = false WHERE id = p_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_delete_recipe_division(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_get_email_queue(
  p_status text DEFAULT NULL,
  p_limit int DEFAULT 50
)
RETURNS TABLE (
  id uuid, template_key text, to_email text, to_name text,
  status text, attempts int, created_at timestamptz,
  sent_at timestamptz, error_msg text
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN QUERY
    SELECT eq.id, eq.template_key, eq.to_email, eq.to_name,
           eq.status, COALESCE(eq.attempts, 0), eq.created_at,
           eq.sent_at, eq.error_msg
      FROM public.email_queue eq
     WHERE (p_status IS NULL OR eq.status = p_status)
     ORDER BY eq.created_at DESC
     LIMIT LEAST(COALESCE(p_limit, 50), 200);
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_get_email_queue(text,int) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_reset_failed_emails()
RETURNS int
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_count int;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.email_queue SET status = 'pending', error_msg = NULL
   WHERE status = 'failed';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_reset_failed_emails() TO authenticated;

INSERT INTO public.email_templates (key, name, subject, body, updated_at) VALUES
('follow_new_recipe',
 'Follow — New Recipe',
 '{{author}} published a new recipe',
 '<h2 style="font-family:Cormorant Garamond,serif;color:#C4973B">New from {{author}}</h2><p>Hi {{name}}, <strong>{{recipe_name}}</strong> is now live. <a href="{{recipe_url}}">View recipe →</a></p>',
 NOW())
ON CONFLICT (key) DO UPDATE SET
  name = EXCLUDED.name, subject = EXCLUDED.subject, body = EXCLUDED.body, updated_at = NOW();

SELECT pg_notify('pgrst', 'reload schema');
SELECT 'fix-phase6-batch.sql complete' AS status;
