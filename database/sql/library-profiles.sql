-- ══════════════════════════════════════════════════════════════════════
-- The Library — Content Profile Tables
-- Five profile types: ingredient, spice, tool, cut, preservation
-- All admin-controlled with visibility and status flags.
-- ══════════════════════════════════════════════════════════════════════

-- ── Shared helper ─────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$;

-- ── 1. INGREDIENT PROFILES ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.ingredient_profiles (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  slug              text        UNIQUE NOT NULL,
  name              text        NOT NULL,
  also_known_as     text,
  local_names       jsonb       DEFAULT '[]',
  category          text,
  subcategory       text,
  image_url         text,
  origin_story      text,
  history           text,
  flavour_profile   text,
  how_to_buy        text,
  how_to_store      text,
  how_to_prep       text,
  when_to_add       text,
  common_mistakes   text,
  nutrition_notes   text,
  allergen          text,
  vegan             boolean     DEFAULT false,
  vegetarian        boolean     DEFAULT false,
  substitutes       text,
  chefs_notes       text,
  recommended_brand text,
  seasonality       text,
  science_notes     text,
  cultural_use      text,
  baby_notes        text,
  pairings          text,
  preservation_notes text,
  did_you_know      text,
  status            text        NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published')),
  visibility        text        NOT NULL DEFAULT 'public' CHECK (visibility IN ('public','members','paid')),
  created_by        uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at        timestamptz NOT NULL DEFAULT NOW(),
  updated_at        timestamptz NOT NULL DEFAULT NOW()
);
DROP TRIGGER IF EXISTS ingredient_profiles_updated_at ON public.ingredient_profiles;
CREATE TRIGGER ingredient_profiles_updated_at BEFORE UPDATE ON public.ingredient_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ── 2. SPICE PROFILES ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.spice_profiles (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  slug              text        UNIQUE NOT NULL,
  name              text        NOT NULL,
  also_known_as     text,
  local_names       jsonb       DEFAULT '[]',
  image_url         text,
  origin_story      text,
  history           text,
  flavour_wheel     text,
  heat_level        integer     CHECK (heat_level BETWEEN 0 AND 5),
  whole_vs_ground   text,
  how_to_toast      text,
  blends            text,
  when_to_add       text,
  science_notes     text,
  cultural_use      text,
  chefs_notes       text,
  recommended_brand text,
  pairings          text,
  substitutes       text,
  did_you_know      text,
  status            text        NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published')),
  visibility        text        NOT NULL DEFAULT 'public' CHECK (visibility IN ('public','members','paid')),
  created_by        uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at        timestamptz NOT NULL DEFAULT NOW(),
  updated_at        timestamptz NOT NULL DEFAULT NOW()
);
DROP TRIGGER IF EXISTS spice_profiles_updated_at ON public.spice_profiles;
CREATE TRIGGER spice_profiles_updated_at BEFORE UPDATE ON public.spice_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ── 3. TOOL & APPLIANCE PROFILES ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.tool_profiles (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  slug              text        UNIQUE NOT NULL,
  name              text        NOT NULL,
  also_known_as     text,
  tool_category     text,
  image_url         text,
  what_its_for      text,
  how_to_use        text,
  how_to_care       text,
  common_mistakes   text,
  what_to_look_for  text,
  price_range       text,
  recommended_brand text,
  chefs_notes       text,
  did_you_know      text,
  status            text        NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published')),
  visibility        text        NOT NULL DEFAULT 'public' CHECK (visibility IN ('public','members','paid')),
  created_by        uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at        timestamptz NOT NULL DEFAULT NOW(),
  updated_at        timestamptz NOT NULL DEFAULT NOW()
);
DROP TRIGGER IF EXISTS tool_profiles_updated_at ON public.tool_profiles;
CREATE TRIGGER tool_profiles_updated_at BEFORE UPDATE ON public.tool_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ── 4. CUT PROFILES (Meat & Seafood) ─────────────────────────────────
CREATE TABLE IF NOT EXISTS public.cut_profiles (
  id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  slug                text        UNIQUE NOT NULL,
  name                text        NOT NULL,
  also_known_as       text,
  international_names jsonb       DEFAULT '[]',
  protein_type        text        CHECK (protein_type IN ('beef','lamb','pork','chicken','duck','fish','seafood','other')),
  image_url           text,
  location_on_animal  text,
  characteristics     text,
  how_to_clean        text,
  how_to_prep         text,
  best_cooking_methods text,
  chefs_notes         text,
  did_you_know        text,
  status              text        NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published')),
  visibility          text        NOT NULL DEFAULT 'public' CHECK (visibility IN ('public','members','paid')),
  created_by          uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at          timestamptz NOT NULL DEFAULT NOW(),
  updated_at          timestamptz NOT NULL DEFAULT NOW()
);
DROP TRIGGER IF EXISTS cut_profiles_updated_at ON public.cut_profiles;
CREATE TRIGGER cut_profiles_updated_at BEFORE UPDATE ON public.cut_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ── 5. PRESERVATION PROFILES ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.preservation_profiles (
  id                uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  slug              text        UNIQUE NOT NULL,
  name              text        NOT NULL,
  technique_type    text        CHECK (technique_type IN ('canning','fermenting','pickling','drying','smoking','freezing','curing','other')),
  image_url         text,
  what_it_is        text,
  history           text,
  best_for          text,
  equipment_needed  text,
  step_by_step      jsonb       DEFAULT '[]',
  safety_notes      text,
  shelf_life        text,
  chefs_notes       text,
  did_you_know      text,
  status            text        NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published')),
  visibility        text        NOT NULL DEFAULT 'public' CHECK (visibility IN ('public','members','paid')),
  created_by        uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at        timestamptz NOT NULL DEFAULT NOW(),
  updated_at        timestamptz NOT NULL DEFAULT NOW()
);
DROP TRIGGER IF EXISTS preservation_profiles_updated_at ON public.preservation_profiles;
CREATE TRIGGER preservation_profiles_updated_at BEFORE UPDATE ON public.preservation_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ── RLS for all five tables ────────────────────────────────────────────
DO $$ DECLARE t text;
BEGIN FOR t IN SELECT unnest(ARRAY['ingredient_profiles','spice_profiles','tool_profiles','cut_profiles','preservation_profiles'])
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS "public reads published" ON public.%I', t);
    EXECUTE format('CREATE POLICY "public reads published" ON public.%I FOR SELECT TO anon, authenticated USING (status = ''published'' AND visibility = ''public'')', t);
    EXECUTE format('DROP POLICY IF EXISTS "members read" ON public.%I', t);
    EXECUTE format('CREATE POLICY "members read" ON public.%I FOR SELECT TO authenticated USING (status = ''published'' AND visibility IN (''public'',''members''))', t);
    EXECUTE format('DROP POLICY IF EXISTS "admin manages all" ON public.%I', t);
    EXECUTE format('CREATE POLICY "admin manages all" ON public.%I FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin())', t);
  END LOOP;
END $$;

-- ── Public RPCs ────────────────────────────────────────────────────────
-- Get directory listing for any profile type
DROP FUNCTION IF EXISTS public.get_library_directory(text, text, int, int);
CREATE FUNCTION public.get_library_directory(
  p_type     text,
  p_search   text    DEFAULT NULL,
  p_limit    int     DEFAULT 24,
  p_offset   int     DEFAULT 0
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_sql text; v_result jsonb;
BEGIN
  v_sql := format(
    'SELECT COALESCE(jsonb_agg(p ORDER BY p.name ASC), ''[]''::jsonb)
     FROM (
       SELECT id, slug, name, also_known_as, image_url, %s AS type_extra,
              status, visibility, created_at
       FROM %I
       WHERE status = ''published''
         AND ($1 IS NULL OR name ILIKE ''%%'' || $1 || ''%%'' OR also_known_as ILIKE ''%%'' || $1 || ''%%'')
       ORDER BY name LIMIT $2 OFFSET $3
     ) p',
    CASE p_type
      WHEN 'ingredient'   THEN 'category'
      WHEN 'spice'        THEN 'heat_level::text'
      WHEN 'tool'         THEN 'tool_category'
      WHEN 'cut'          THEN 'protein_type'
      WHEN 'preservation' THEN 'technique_type'
      ELSE '''''' END,
    p_type || '_profiles'
  );
  EXECUTE v_sql INTO v_result USING p_search, p_limit, p_offset;
  RETURN COALESCE(v_result, '[]'::jsonb);
END; $$;
REVOKE ALL ON FUNCTION public.get_library_directory(text,text,int,int) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_library_directory(text,text,int,int) TO anon, authenticated;

-- Get single profile by slug
DROP FUNCTION IF EXISTS public.get_library_profile(text, text);
CREATE FUNCTION public.get_library_profile(p_type text, p_slug text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_result jsonb;
BEGIN
  EXECUTE format(
    'SELECT row_to_json(p)::jsonb FROM %I p WHERE slug = $1 AND status = ''published''',
    p_type || '_profiles'
  ) INTO v_result USING p_slug;
  RETURN v_result;
END; $$;
REVOKE ALL ON FUNCTION public.get_library_profile(text,text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_library_profile(text,text) TO anon, authenticated;

-- ── Admin RPCs ─────────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_library_profiles(text, text, int, int);
CREATE FUNCTION public.admin_get_library_profiles(
  p_type   text,
  p_status text    DEFAULT NULL,
  p_limit  int     DEFAULT 50,
  p_offset int     DEFAULT 0
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_result jsonb;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  EXECUTE format(
    'SELECT COALESCE(jsonb_agg(p ORDER BY p.updated_at DESC), ''[]''::jsonb)
     FROM (SELECT id, slug, name, image_url, status, visibility, updated_at
           FROM %I
           WHERE ($1 IS NULL OR status = $1)
           ORDER BY updated_at DESC LIMIT $2 OFFSET $3) p',
    p_type || '_profiles'
  ) INTO v_result USING p_status, p_limit, p_offset;
  RETURN COALESCE(v_result, '[]'::jsonb);
END; $$;
REVOKE ALL ON FUNCTION public.admin_get_library_profiles(text,text,int,int) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_get_library_profiles(text,text,int,int) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_publish_library_profile(text, uuid, text, text);
CREATE FUNCTION public.admin_publish_library_profile(
  p_type       text,
  p_id         uuid,
  p_status     text DEFAULT 'published',
  p_visibility text DEFAULT 'public'
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  EXECUTE format('UPDATE %I SET status=$1, visibility=$2, updated_at=NOW() WHERE id=$3',
    p_type||'_profiles') USING p_status, p_visibility, p_id;
END; $$;
REVOKE ALL ON FUNCTION public.admin_publish_library_profile(text,uuid,text,text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_publish_library_profile(text,uuid,text,text) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_delete_library_profile(text, uuid);
CREATE FUNCTION public.admin_delete_library_profile(p_type text, p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  EXECUTE format('DELETE FROM %I WHERE id=$1', p_type||'_profiles') USING p_id;
END; $$;
REVOKE ALL ON FUNCTION public.admin_delete_library_profile(text,uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_delete_library_profile(text,uuid) TO authenticated;

SELECT 'Library profiles ready' AS status;

-- ── Supabase Storage bucket for library images ──────────────────────
-- Run this in the Supabase SQL editor after enabling Storage in your project.
-- NOTE: The bucket itself must be created in the Supabase Dashboard →
--       Storage → New bucket → Name: library-images → Public: ON
-- These policies then restrict who can upload.

INSERT INTO storage.buckets (id, name, public)
VALUES ('library-images', 'library-images', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Admin uploads library images" ON storage.objects;
CREATE POLICY "Admin uploads library images"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'library-images'
    AND is_admin()
  );

DROP POLICY IF EXISTS "Admin updates library images" ON storage.objects;
CREATE POLICY "Admin updates library images"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'library-images' AND is_admin());

DROP POLICY IF EXISTS "Anyone reads library images" ON storage.objects;
CREATE POLICY "Anyone reads library images"
  ON storage.objects FOR SELECT TO anon, authenticated
  USING (bucket_id = 'library-images');

SELECT 'library-images storage bucket ready' AS status;
