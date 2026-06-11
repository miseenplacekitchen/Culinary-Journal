-- ══════════════════════════════════════════════════════════════════════
-- fix-library-unified.sql
-- Consolidates five *_profiles tables into library_profiles (type + details jsonb).
-- Replaces per-type RPC branching. Includes coverage + CSV bulk upsert.
-- Run after fix-library-management.sql (or standalone). Safe to re-run.
-- Legacy tables are NOT dropped — writes go to library_profiles only.
-- ══════════════════════════════════════════════════════════════════════

-- ── Unified table ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.library_profiles (
  id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_type          text        NOT NULL CHECK (profile_type IN ('ingredient','spice','tool','cut','preservation')),
  slug                  text        NOT NULL,
  name                  text        NOT NULL,
  also_known_as         text,
  local_names           jsonb       NOT NULL DEFAULT '[]'::jsonb,
  image_url             text,
  mise_image_url        text,
  image_status          text        NOT NULL DEFAULT 'missing' CHECK (image_status IN ('missing','draft','approved')),
  chefs_notes           text,
  recommended_brand     text,
  did_you_know          text,
  status                text        NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published')),
  visibility            text        NOT NULL DEFAULT 'public' CHECK (visibility IN ('public','members','paid')),
  governed_ingredient_id integer,
  internal_notes        text,
  details               jsonb       NOT NULL DEFAULT '{}'::jsonb,
  created_by            uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (profile_type, slug)
);

CREATE INDEX IF NOT EXISTS idx_library_profiles_type_status ON public.library_profiles(profile_type, status);
CREATE INDEX IF NOT EXISTS idx_library_profiles_type_updated ON public.library_profiles(profile_type, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_library_profiles_governed ON public.library_profiles(governed_ingredient_id)
  WHERE governed_ingredient_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_library_profiles_details ON public.library_profiles USING gin (details);

DROP TRIGGER IF EXISTS library_profiles_updated_at ON public.library_profiles;
CREATE TRIGGER library_profiles_updated_at BEFORE UPDATE ON public.library_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

ALTER TABLE public.library_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "public reads published library" ON public.library_profiles;
CREATE POLICY "public reads published library" ON public.library_profiles
  FOR SELECT TO anon, authenticated
  USING (status = 'published' AND visibility = 'public');
DROP POLICY IF EXISTS "members read library" ON public.library_profiles;
CREATE POLICY "members read library" ON public.library_profiles
  FOR SELECT TO authenticated
  USING (status = 'published' AND visibility IN ('public','members'));
DROP POLICY IF EXISTS "admin manages library" ON public.library_profiles;
CREATE POLICY "admin manages library" ON public.library_profiles
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

-- ── Ensure mise columns on legacy tables (for migration SELECT) ───────
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['ingredient','spice','tool','cut','preservation'] LOOP
    EXECUTE format(
      'ALTER TABLE public.%I_profiles ADD COLUMN IF NOT EXISTS mise_image_url text,
       ADD COLUMN IF NOT EXISTS image_status text DEFAULT ''missing''',
      t
    );
  END LOOP;
END $$;

ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS material text;
ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS capacity_notes text;
ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS heat_compatibility text;
ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS skill_level text;
ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS swap_if_missing text;
ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS care_schedule text;
ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS pairs_well_with text;
ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS best_for text;

-- ── Migrate legacy rows (preserve UUIDs) ──────────────────────────────
INSERT INTO public.library_profiles (
  id, profile_type, slug, name, also_known_as, local_names, image_url, mise_image_url, image_status,
  chefs_notes, recommended_brand, did_you_know, status, visibility, governed_ingredient_id,
  created_by, created_at, updated_at, details
)
SELECT
  ip.id, 'ingredient', ip.slug, ip.name, ip.also_known_as, COALESCE(ip.local_names, '[]'::jsonb),
  ip.image_url, ip.mise_image_url, COALESCE(ip.image_status, 'missing'),
  ip.chefs_notes, ip.recommended_brand, ip.did_you_know, ip.status, ip.visibility, ip.governed_ingredient_id,
  ip.created_by, ip.created_at, ip.updated_at,
  jsonb_strip_nulls(jsonb_build_object(
    'category', ip.category, 'subcategory', ip.subcategory, 'allergen', ip.allergen,
    'vegan', ip.vegan, 'vegetarian', ip.vegetarian, 'origin_story', ip.origin_story,
    'history', ip.history, 'cultural_use', ip.cultural_use, 'flavour_profile', ip.flavour_profile,
    'how_to_buy', ip.how_to_buy, 'how_to_store', ip.how_to_store, 'how_to_prep', ip.how_to_prep,
    'when_to_add', ip.when_to_add, 'common_mistakes', ip.common_mistakes, 'science_notes', ip.science_notes,
    'pairings', ip.pairings, 'preservation_notes', ip.preservation_notes, 'baby_notes', ip.baby_notes,
    'substitutes', ip.substitutes, 'nutrition_notes', ip.nutrition_notes, 'seasonality', ip.seasonality
  ))
FROM public.ingredient_profiles ip
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, status = EXCLUDED.status, visibility = EXCLUDED.visibility,
  governed_ingredient_id = EXCLUDED.governed_ingredient_id,
  image_url = EXCLUDED.image_url, mise_image_url = EXCLUDED.mise_image_url, image_status = EXCLUDED.image_status,
  details = EXCLUDED.details, updated_at = now();

INSERT INTO public.library_profiles (
  id, profile_type, slug, name, also_known_as, local_names, image_url, mise_image_url, image_status,
  chefs_notes, recommended_brand, did_you_know, status, visibility,
  created_by, created_at, updated_at, details
)
SELECT
  sp.id, 'spice', sp.slug, sp.name, sp.also_known_as, COALESCE(sp.local_names, '[]'::jsonb),
  sp.image_url, sp.mise_image_url, COALESCE(sp.image_status, 'missing'),
  sp.chefs_notes, sp.recommended_brand, sp.did_you_know, sp.status, sp.visibility,
  sp.created_by, sp.created_at, sp.updated_at,
  jsonb_strip_nulls(jsonb_build_object(
    'origin_story', sp.origin_story, 'history', sp.history, 'cultural_use', sp.cultural_use,
    'flavour_wheel', sp.flavour_wheel, 'heat_level', sp.heat_level, 'whole_vs_ground', sp.whole_vs_ground,
    'how_to_toast', sp.how_to_toast, 'blends', sp.blends, 'when_to_add', sp.when_to_add,
    'science_notes', sp.science_notes, 'pairings', sp.pairings, 'substitutes', sp.substitutes
  ))
FROM public.spice_profiles sp
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, status = EXCLUDED.status, details = EXCLUDED.details, updated_at = now();

INSERT INTO public.library_profiles (
  id, profile_type, slug, name, also_known_as, local_names, image_url, mise_image_url, image_status,
  chefs_notes, recommended_brand, did_you_know, status, visibility,
  created_by, created_at, updated_at, details
)
SELECT
  tp.id, 'tool', tp.slug, tp.name, tp.also_known_as, '[]'::jsonb,
  tp.image_url, tp.mise_image_url, COALESCE(tp.image_status, 'missing'),
  tp.chefs_notes, tp.recommended_brand, tp.did_you_know, tp.status, tp.visibility,
  tp.created_by, tp.created_at, tp.updated_at,
  jsonb_strip_nulls(jsonb_build_object(
    'tool_category', tp.tool_category, 'what_its_for', tp.what_its_for, 'how_to_use', tp.how_to_use,
    'how_to_care', tp.how_to_care, 'common_mistakes', tp.common_mistakes,
    'what_to_look_for', tp.what_to_look_for, 'price_range', tp.price_range,
    'material', tp.material, 'capacity_notes', tp.capacity_notes,
    'heat_compatibility', tp.heat_compatibility, 'skill_level', tp.skill_level,
    'swap_if_missing', tp.swap_if_missing, 'care_schedule', tp.care_schedule,
    'pairs_well_with', tp.pairs_well_with, 'best_for', tp.best_for
  ))
FROM public.tool_profiles tp
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, status = EXCLUDED.status, details = EXCLUDED.details, updated_at = now();

INSERT INTO public.library_profiles (
  id, profile_type, slug, name, also_known_as, local_names, image_url, mise_image_url, image_status,
  chefs_notes, recommended_brand, did_you_know, status, visibility,
  created_by, created_at, updated_at, details
)
SELECT
  cp.id, 'cut', cp.slug, cp.name, cp.also_known_as, '[]'::jsonb,
  cp.image_url, cp.mise_image_url, COALESCE(cp.image_status, 'missing'),
  cp.chefs_notes, NULL::text, cp.did_you_know, cp.status, cp.visibility,
  cp.created_by, cp.created_at, cp.updated_at,
  jsonb_strip_nulls(jsonb_build_object(
    'international_names', cp.international_names, 'protein_type', cp.protein_type,
    'location_on_animal', cp.location_on_animal, 'characteristics', cp.characteristics,
    'how_to_clean', cp.how_to_clean, 'how_to_prep', cp.how_to_prep,
    'best_cooking_methods', cp.best_cooking_methods
  ))
FROM public.cut_profiles cp
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, status = EXCLUDED.status, details = EXCLUDED.details, updated_at = now();

INSERT INTO public.library_profiles (
  id, profile_type, slug, name, also_known_as, local_names, image_url, mise_image_url, image_status,
  chefs_notes, recommended_brand, did_you_know, status, visibility,
  created_by, created_at, updated_at, details
)
SELECT
  pp.id, 'preservation', pp.slug, pp.name, NULL::text, '[]'::jsonb,
  pp.image_url, pp.mise_image_url, COALESCE(pp.image_status, 'missing'),
  pp.chefs_notes, NULL::text, pp.did_you_know, pp.status, pp.visibility,
  pp.created_by, pp.created_at, pp.updated_at,
  jsonb_strip_nulls(jsonb_build_object(
    'technique_type', pp.technique_type, 'what_it_is', pp.what_it_is, 'history', pp.history,
    'best_for', pp.best_for, 'equipment_needed', pp.equipment_needed, 'step_by_step', pp.step_by_step,
    'safety_notes', pp.safety_notes, 'shelf_life', pp.shelf_life
  ))
FROM public.preservation_profiles pp
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, status = EXCLUDED.status, details = EXCLUDED.details, updated_at = now();

-- ── Flat JSON helper (API compatibility) ──────────────────────────────
CREATE OR REPLACE FUNCTION public.library_profile_flat(p_row public.library_profiles)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT (to_jsonb(p_row) - 'details' - 'internal_notes')
    || COALESCE(p_row.details, '{}'::jsonb);
$$;

-- ── Directory type_extra from details ───────────────────────────────────
CREATE OR REPLACE FUNCTION public.library_type_extra(p_row public.library_profiles)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_row.profile_type
    WHEN 'ingredient'   THEN p_row.details->>'category'
    WHEN 'spice'        THEN p_row.details->>'heat_level'
    WHEN 'tool'         THEN p_row.details->>'tool_category'
    WHEN 'cut'          THEN p_row.details->>'protein_type'
    WHEN 'preservation' THEN p_row.details->>'technique_type'
    ELSE NULL END;
$$;

-- ── Public: directory ─────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_library_directory(text, text, int, int);
CREATE FUNCTION public.get_library_directory(
  p_type text, p_search text DEFAULT NULL, p_limit int DEFAULT 24, p_offset int DEFAULT 0
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'id', lp.id, 'slug', lp.slug, 'name', lp.name, 'also_known_as', lp.also_known_as,
      'image_url', lp.image_url, 'mise_image_url', lp.mise_image_url, 'image_status', lp.image_status,
      'type_extra', library_type_extra(lp), 'status', lp.status, 'visibility', lp.visibility,
      'created_at', lp.created_at
    ) ORDER BY lp.name)
    FROM public.library_profiles lp
    WHERE lp.profile_type = p_type AND lp.status = 'published'
      AND (p_search IS NULL OR btrim(p_search) = ''
        OR lp.name ILIKE '%' || p_search || '%'
        OR lp.also_known_as ILIKE '%' || p_search || '%')
    LIMIT GREATEST(1, LEAST(p_limit, 100)) OFFSET GREATEST(0, p_offset)
  ), '[]'::jsonb);
END; $$;
REVOKE ALL ON FUNCTION public.get_library_directory(text,text,int,int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_library_directory(text,text,int,int) TO anon, authenticated;

-- ── Public: single profile by slug ────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_library_profile(text, text);
CREATE FUNCTION public.get_library_profile(p_type text, p_slug text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_row public.library_profiles%ROWTYPE;
BEGIN
  SELECT * INTO v_row FROM public.library_profiles
  WHERE profile_type = p_type AND slug = p_slug AND status = 'published';
  IF NOT FOUND THEN RETURN NULL; END IF;
  RETURN library_profile_flat(v_row);
END; $$;
REVOKE ALL ON FUNCTION public.get_library_profile(text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_library_profile(text,text) TO anon, authenticated;

-- ── Recipe → library links (ingredients) ──────────────────────────────
DROP FUNCTION IF EXISTS public.get_library_links_for_ingredients(integer[]);
CREATE FUNCTION public.get_library_links_for_ingredients(p_ids integer[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_ids IS NULL OR array_length(p_ids, 1) IS NULL THEN RETURN '{}'::jsonb; END IF;
  RETURN COALESCE((
    SELECT jsonb_object_agg(
      governed_ingredient_id::text,
      jsonb_build_object('slug', slug, 'name', name, 'mise_image_url', mise_image_url, 'image_status', image_status)
    )
    FROM public.library_profiles
    WHERE profile_type = 'ingredient' AND governed_ingredient_id = ANY(p_ids) AND status = 'published'
  ), '{}'::jsonb);
END; $$;
GRANT EXECUTE ON FUNCTION public.get_library_links_for_ingredients(integer[]) TO anon, authenticated;

-- ── Split flat payload into row columns ───────────────────────────────
CREATE OR REPLACE FUNCTION public._library_split_payload(p_type text, p_payload jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
  v_shared_keys text[] := ARRAY[
    'slug','name','also_known_as','local_names','image_url','mise_image_url','image_status',
    'chefs_notes','recommended_brand','did_you_know','status','visibility',
    'governed_ingredient_id','internal_notes'
  ];
  v_key text;
  v_shared jsonb := '{}'::jsonb;
  v_details jsonb := '{}'::jsonb;
BEGIN
  IF p_payload IS NULL THEN p_payload := '{}'::jsonb; END IF;
  FOR v_key IN SELECT jsonb_object_keys(p_payload) LOOP
    IF v_key = ANY(v_shared_keys) THEN
      v_shared := v_shared || jsonb_build_object(v_key, p_payload->v_key);
    ELSIF v_key NOT IN ('profile_type','id','created_by','created_at','updated_at') THEN
      v_details := v_details || jsonb_build_object(v_key, p_payload->v_key);
    END IF;
  END LOOP;
  RETURN jsonb_build_object('shared', v_shared, 'details', v_details);
END; $$;

-- ── Admin upsert (editor + CSV) ───────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_upsert_library_profile(text, uuid, jsonb);
CREATE FUNCTION public.admin_upsert_library_profile(
  p_type text, p_id uuid DEFAULT NULL, p_payload jsonb DEFAULT '{}'::jsonb
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_split jsonb; v_shared jsonb; v_details jsonb; v_id uuid; v_slug text;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_type NOT IN ('ingredient','spice','tool','cut','preservation') THEN
    RAISE EXCEPTION 'Invalid profile type';
  END IF;
  v_split := _library_split_payload(p_type, p_payload);
  v_shared := v_split->'shared';
  v_details := COALESCE(v_split->'details', '{}'::jsonb);
  v_slug := COALESCE(NULLIF(trim(v_shared->>'slug'), ''),
    lower(regexp_replace(COALESCE(v_shared->>'name', 'profile'), '[^a-z0-9]+', '-', 'g')) || '-' || floor(extract(epoch from now()))::text);

  IF p_id IS NOT NULL THEN
    UPDATE public.library_profiles SET
      slug = COALESCE(NULLIF(v_shared->>'slug',''), slug),
      name = COALESCE(v_shared->>'name', name),
      also_known_as = v_shared->>'also_known_as',
      local_names = CASE WHEN v_shared ? 'local_names' THEN COALESCE(v_shared->'local_names','[]'::jsonb) ELSE local_names END,
      image_url = COALESCE(v_shared->>'image_url', image_url),
      mise_image_url = v_shared->>'mise_image_url',
      image_status = COALESCE(v_shared->>'image_status', image_status),
      chefs_notes = v_shared->>'chefs_notes',
      recommended_brand = v_shared->>'recommended_brand',
      did_you_know = v_shared->>'did_you_know',
      status = COALESCE(v_shared->>'status', status),
      visibility = COALESCE(v_shared->>'visibility', visibility),
      governed_ingredient_id = CASE WHEN v_shared ? 'governed_ingredient_id'
        THEN NULLIF(v_shared->>'governed_ingredient_id','')::int ELSE governed_ingredient_id END,
      internal_notes = COALESCE(v_shared->>'internal_notes', internal_notes),
      details = CASE WHEN v_details = '{}'::jsonb THEN details ELSE details || v_details END,
      updated_at = now()
    WHERE id = p_id AND profile_type = p_type
    RETURNING id INTO v_id;
    IF v_id IS NULL THEN RAISE EXCEPTION 'Profile not found'; END IF;
    RETURN v_id;
  END IF;

  IF COALESCE(v_shared->>'name','') = '' THEN RAISE EXCEPTION 'name is required'; END IF;
  INSERT INTO public.library_profiles (
    profile_type, slug, name, also_known_as, local_names, image_url, mise_image_url, image_status,
    chefs_notes, recommended_brand, did_you_know, status, visibility, governed_ingredient_id,
    internal_notes, details
  ) VALUES (
    p_type, v_slug, v_shared->>'name', v_shared->>'also_known_as',
    CASE WHEN v_shared ? 'local_names' THEN COALESCE(v_shared->'local_names','[]'::jsonb) ELSE '[]'::jsonb END,
    v_shared->>'image_url', v_shared->>'mise_image_url', COALESCE(v_shared->>'image_status','missing'),
    v_shared->>'chefs_notes', v_shared->>'recommended_brand', v_shared->>'did_you_know',
    COALESCE(v_shared->>'status','draft'), COALESCE(v_shared->>'visibility','public'),
    NULLIF(v_shared->>'governed_ingredient_id','')::int, v_shared->>'internal_notes', v_details
  )
  ON CONFLICT (profile_type, slug) DO UPDATE SET
    name = EXCLUDED.name, image_url = EXCLUDED.image_url, details = library_profiles.details || EXCLUDED.details,
    updated_at = now()
  RETURNING id INTO v_id;
  RETURN v_id;
END; $$;
REVOKE ALL ON FUNCTION public.admin_upsert_library_profile(text,uuid,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_upsert_library_profile(text,uuid,jsonb) TO authenticated;

-- ── Admin bulk CSV upsert ───────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_bulk_upsert_library_profiles(text, jsonb);
CREATE FUNCTION public.admin_bulk_upsert_library_profiles(p_type text, p_rows jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_row jsonb; v_inserted int := 0; v_updated int := 0; v_id uuid; v_existed boolean;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_rows IS NULL OR jsonb_typeof(p_rows) <> 'array' THEN
    RETURN jsonb_build_object('inserted', 0, 'updated', 0);
  END IF;
  FOR v_row IN SELECT value FROM jsonb_array_elements(p_rows) LOOP
    SELECT id INTO v_id FROM public.library_profiles
    WHERE profile_type = p_type
      AND (slug = v_row->>'slug' OR (v_row->>'slug' IS NULL AND lower(name) = lower(v_row->>'name')))
    LIMIT 1;
    v_existed := v_id IS NOT NULL;
    v_id := admin_upsert_library_profile(p_type, v_id, v_row);
    IF v_existed THEN v_updated := v_updated + 1; ELSE v_inserted := v_inserted + 1; END IF;
  END LOOP;
  RETURN jsonb_build_object('inserted', v_inserted, 'updated', v_updated);
END; $$;
REVOKE ALL ON FUNCTION public.admin_bulk_upsert_library_profiles(text,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_bulk_upsert_library_profiles(text,jsonb) TO authenticated;

-- ── Recipe match count for a profile ──────────────────────────────────
CREATE OR REPLACE FUNCTION public._library_recipe_count(p_type text, p_name text, p_governed_id int)
RETURNS int LANGUAGE plpgsql STABLE SET search_path = public AS $$
DECLARE v_match_name text; v_count int := 0;
BEGIN
  IF p_type = 'ingredient' AND p_governed_id IS NOT NULL THEN
    SELECT "Ingredient Name" INTO v_match_name FROM public.ingredients WHERE "ID" = p_governed_id;
  END IF;
  v_match_name := COALESCE(v_match_name, p_name);
  IF v_match_name IS NULL OR btrim(v_match_name) = '' THEN RETURN 0; END IF;
  SELECT count(*)::int INTO v_count
  FROM public.submitted_recipes sr
  WHERE sr.status = 'approved' AND sr.ingredients IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM jsonb_array_elements(sr.ingredients) sec,
           jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
      WHERE lower(trim(item->>'ingredient')) = lower(trim(v_match_name))
    );
  RETURN v_count;
END; $$;

-- ── Admin listing (unified) ───────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_library_profiles(text, text, int, int);
DROP FUNCTION IF EXISTS public.admin_get_library_profiles(text, text, int, int, text);
DROP FUNCTION IF EXISTS public.admin_get_library_profiles(text, text, int, int, text, text, text);

CREATE FUNCTION public.admin_get_library_profiles(
  p_type text, p_status text DEFAULT NULL, p_limit int DEFAULT 50, p_offset int DEFAULT 0,
  p_image_status text DEFAULT NULL, p_search text DEFAULT NULL, p_sort text DEFAULT 'updated_desc'
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_items jsonb; v_total int; v_where text := 'profile_type = $5';
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_status IS NOT NULL THEN v_where := v_where || ' AND status = $1'; END IF;
  IF p_image_status = 'missing' THEN
    v_where := v_where || ' AND (mise_image_url IS NULL OR btrim(mise_image_url) = '''')';
  ELSIF p_image_status = 'draft' THEN
    v_where := v_where || ' AND mise_image_url IS NOT NULL AND btrim(mise_image_url) <> '''' AND image_status = ''draft''';
  ELSIF p_image_status = 'approved' THEN
    v_where := v_where || ' AND image_status = ''approved''';
  END IF;
  IF p_search IS NOT NULL AND btrim(p_search) <> '' THEN
    v_where := v_where || ' AND (name ILIKE ''%'' || $6 || ''%'' OR also_known_as ILIKE ''%'' || $6 || ''%'' OR slug ILIKE ''%'' || $6 || ''%'')';
  END IF;

  EXECUTE 'SELECT count(*)::int FROM public.library_profiles WHERE ' || v_where
    INTO v_total USING p_status, p_limit, p_offset, p_image_status, p_type, p_search;

  EXECUTE format(
    'SELECT COALESCE(jsonb_agg(row_to_json(sub)::jsonb ORDER BY %s), ''[]''::jsonb) FROM (
       SELECT id, slug, name, image_url, mise_image_url, image_status, status, visibility, updated_at,
              governed_ingredient_id
       FROM public.library_profiles WHERE %s
       ORDER BY %s LIMIT $2 OFFSET $3
     ) sub',
    CASE p_sort
      WHEN 'name_asc' THEN 'sub.name ASC'
      WHEN 'name_desc' THEN 'sub.name DESC'
      WHEN 'updated_asc' THEN 'sub.updated_at ASC'
      WHEN 'status_asc' THEN 'sub.status ASC, sub.name ASC'
      ELSE 'sub.updated_at DESC'
    END,
    v_where,
    CASE p_sort
      WHEN 'name_asc' THEN 'name ASC'
      WHEN 'name_desc' THEN 'name DESC'
      WHEN 'updated_asc' THEN 'updated_at ASC'
      WHEN 'status_asc' THEN 'status ASC, name ASC'
      ELSE 'updated_at DESC'
    END
  ) INTO v_items USING p_status, p_limit, p_offset, p_image_status, p_type, p_search;

  RETURN jsonb_build_object('items', COALESCE(v_items, '[]'::jsonb), 'total', COALESCE(v_total, 0));
END; $$;
REVOKE ALL ON FUNCTION public.admin_get_library_profiles(text,text,int,int,text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_get_library_profiles(text,text,int,int,text,text,text) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_get_library_profile(text, uuid);
CREATE FUNCTION public.admin_get_library_profile(p_type text, p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_row public.library_profiles%ROWTYPE;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  SELECT * INTO v_row FROM public.library_profiles WHERE id = p_id AND profile_type = p_type;
  IF NOT FOUND THEN RAISE EXCEPTION 'Profile not found'; END IF;
  RETURN library_profile_flat(v_row) || jsonb_build_object('internal_notes', v_row.internal_notes);
END; $$;
REVOKE ALL ON FUNCTION public.admin_get_library_profile(text,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_get_library_profile(text,uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_get_library_image_stats(text);
CREATE FUNCTION public.admin_get_library_image_stats(p_type text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_result jsonb;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  SELECT jsonb_build_object(
    'total', count(*)::int,
    'missing', count(*) FILTER (WHERE mise_image_url IS NULL OR btrim(mise_image_url) = '')::int,
    'draft', count(*) FILTER (WHERE mise_image_url IS NOT NULL AND btrim(mise_image_url) <> '' AND image_status = 'draft')::int,
    'approved', count(*) FILTER (WHERE image_status = 'approved')::int
  ) INTO v_result FROM public.library_profiles WHERE profile_type = p_type;
  RETURN COALESCE(v_result, '{"total":0,"missing":0,"draft":0,"approved":0}'::jsonb);
END; $$;
REVOKE ALL ON FUNCTION public.admin_get_library_image_stats(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_get_library_image_stats(text) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_set_library_image_status(text, uuid, text);
CREATE FUNCTION public.admin_set_library_image_status(p_type text, p_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_status NOT IN ('missing','draft','approved') THEN RAISE EXCEPTION 'Invalid image_status'; END IF;
  UPDATE public.library_profiles SET image_status = p_status, updated_at = now()
  WHERE id = p_id AND profile_type = p_type;
END; $$;
REVOKE ALL ON FUNCTION public.admin_set_library_image_status(text,uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_set_library_image_status(text,uuid,text) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_bulk_library_profiles(text, uuid[], text, text);
CREATE FUNCTION public.admin_bulk_library_profiles(
  p_type text, p_ids uuid[], p_action text, p_value text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_n int := 0;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_ids IS NULL OR array_length(p_ids, 1) IS NULL THEN RETURN jsonb_build_object('updated', 0); END IF;
  CASE p_action
    WHEN 'publish' THEN
      UPDATE public.library_profiles SET status = 'published', updated_at = now()
      WHERE profile_type = p_type AND id = ANY(p_ids);
    WHEN 'unpublish' THEN
      UPDATE public.library_profiles SET status = 'draft', updated_at = now()
      WHERE profile_type = p_type AND id = ANY(p_ids);
    WHEN 'approve_image' THEN
      UPDATE public.library_profiles SET image_status = 'approved', updated_at = now()
      WHERE profile_type = p_type AND id = ANY(p_ids)
        AND mise_image_url IS NOT NULL AND btrim(mise_image_url) <> '';
    WHEN 'set_visibility' THEN
      IF p_value NOT IN ('public','members','paid') THEN RAISE EXCEPTION 'Invalid visibility'; END IF;
      UPDATE public.library_profiles SET visibility = p_value, updated_at = now()
      WHERE profile_type = p_type AND id = ANY(p_ids);
    WHEN 'delete' THEN
      DELETE FROM public.library_profiles WHERE profile_type = p_type AND id = ANY(p_ids);
    ELSE RAISE EXCEPTION 'Unknown action: %', p_action;
  END CASE;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN jsonb_build_object('updated', v_n);
END; $$;
REVOKE ALL ON FUNCTION public.admin_bulk_library_profiles(text,uuid[],text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_bulk_library_profiles(text,uuid[],text,text) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_publish_library_profile(text, uuid, text, text);
CREATE FUNCTION public.admin_publish_library_profile(
  p_type text, p_id uuid, p_status text DEFAULT 'published', p_visibility text DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  UPDATE public.library_profiles SET
    status = COALESCE(p_status, status),
    visibility = COALESCE(p_visibility, visibility),
    updated_at = now()
  WHERE id = p_id AND profile_type = p_type;
END; $$;
REVOKE ALL ON FUNCTION public.admin_publish_library_profile(text,uuid,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_publish_library_profile(text,uuid,text,text) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_delete_library_profile(text, uuid);
CREATE FUNCTION public.admin_delete_library_profile(p_type text, p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  DELETE FROM public.library_profiles WHERE id = p_id AND profile_type = p_type;
END; $$;
REVOKE ALL ON FUNCTION public.admin_delete_library_profile(text,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_delete_library_profile(text,uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_link_library_ingredient(uuid, integer);
CREATE FUNCTION public.admin_link_library_ingredient(p_profile_id uuid, p_ingredient_id integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_name text;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_ingredient_id IS NULL OR p_ingredient_id < 1 THEN RAISE EXCEPTION 'Invalid ingredient ID'; END IF;
  SELECT "Ingredient Name" INTO v_name FROM public.ingredients WHERE "ID" = p_ingredient_id;
  IF v_name IS NULL THEN RAISE EXCEPTION 'Ingredient ID % not found', p_ingredient_id; END IF;
  UPDATE public.library_profiles SET governed_ingredient_id = p_ingredient_id, updated_at = now()
  WHERE id = p_profile_id AND profile_type = 'ingredient';
  IF NOT FOUND THEN RAISE EXCEPTION 'Ingredient profile not found'; END IF;
  RETURN jsonb_build_object('ingredient_id', p_ingredient_id, 'ingredient_name', v_name);
END; $$;
REVOKE ALL ON FUNCTION public.admin_link_library_ingredient(uuid,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_link_library_ingredient(uuid,integer) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_get_library_governed_preview(uuid);
CREATE FUNCTION public.admin_get_library_governed_preview(p_profile_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_row public.library_profiles%ROWTYPE;
  v_ing_name text; v_count int;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  SELECT * INTO v_row FROM public.library_profiles WHERE id = p_profile_id AND profile_type = 'ingredient';
  IF NOT FOUND THEN RAISE EXCEPTION 'Profile not found'; END IF;
  IF v_row.governed_ingredient_id IS NULL THEN
    RETURN jsonb_build_object('linked', false, 'profile_name', v_row.name);
  END IF;
  SELECT "Ingredient Name" INTO v_ing_name FROM public.ingredients WHERE "ID" = v_row.governed_ingredient_id;
  IF v_ing_name IS NULL THEN
    RETURN jsonb_build_object('linked', true, 'valid', false, 'ingredient_id', v_row.governed_ingredient_id, 'profile_name', v_row.name);
  END IF;
  v_count := _library_recipe_count('ingredient', v_row.name, v_row.governed_ingredient_id);
  RETURN jsonb_build_object(
    'linked', true, 'valid', true, 'ingredient_id', v_row.governed_ingredient_id,
    'ingredient_name', v_ing_name, 'recipe_count', v_count, 'profile_name', v_row.name
  );
END; $$;
REVOKE ALL ON FUNCTION public.admin_get_library_governed_preview(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_get_library_governed_preview(uuid) TO authenticated;

-- ── Coverage panel ──────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_library_coverage(text, int);
CREATE FUNCTION public.admin_get_library_coverage(p_type text, p_limit int DEFAULT 40)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_zero jsonb; v_gaps jsonb; v_top jsonb;
  v_published int; v_with_recipes int; v_zero_count int;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_type NOT IN ('ingredient','spice','tool','cut','preservation') THEN
    RAISE EXCEPTION 'Invalid profile type';
  END IF;

  SELECT count(*)::int INTO v_published FROM public.library_profiles
  WHERE profile_type = p_type AND status = 'published';

  SELECT count(*)::int INTO v_zero_count
  FROM public.library_profiles lp
  WHERE lp.profile_type = p_type AND lp.status = 'published'
    AND _library_recipe_count(p_type, lp.name, lp.governed_ingredient_id) = 0;
  v_with_recipes := GREATEST(0, v_published - v_zero_count);

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', z.id, 'name', z.name, 'slug', z.slug, 'governed_ingredient_id', z.governed_ingredient_id
  ) ORDER BY z.name), '[]'::jsonb)
  INTO v_zero
  FROM (
    SELECT lp.id, lp.name, lp.slug, lp.governed_ingredient_id
    FROM public.library_profiles lp
    WHERE lp.profile_type = p_type AND lp.status = 'published'
      AND _library_recipe_count(p_type, lp.name, lp.governed_ingredient_id) = 0
    ORDER BY lp.name
    LIMIT GREATEST(1, LEAST(p_limit, 200))
  ) z;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', lp.id, 'name', lp.name, 'slug', lp.slug,
    'recipe_count', _library_recipe_count(p_type, lp.name, lp.governed_ingredient_id)
  ) ORDER BY _library_recipe_count(p_type, lp.name, lp.governed_ingredient_id) DESC), '[]'::jsonb)
  INTO v_top
  FROM public.library_profiles lp
  WHERE lp.profile_type = p_type AND lp.status = 'published'
  LIMIT GREATEST(1, LEAST(p_limit, 50));

  v_gaps := '[]'::jsonb;
  IF p_type = 'ingredient' THEN
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'ingredient_id', g.ing_id, 'ingredient_name', g.ing_name, 'recipe_count', g.cnt
    ) ORDER BY g.cnt DESC), '[]'::jsonb)
    INTO v_gaps
    FROM (
      SELECT i."ID" AS ing_id, i."Ingredient Name" AS ing_name, count(*)::int AS cnt
      FROM public.submitted_recipes sr
      CROSS JOIN LATERAL jsonb_array_elements(sr.ingredients) sec
      CROSS JOIN LATERAL jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
      JOIN public.ingredients i ON lower(trim(i."Ingredient Name")) = lower(trim(item->>'ingredient'))
      WHERE sr.status = 'approved'
        AND NOT EXISTS (
          SELECT 1 FROM public.library_profiles lp
          WHERE lp.profile_type = 'ingredient' AND lp.status = 'published'
            AND lp.governed_ingredient_id = i."ID"
        )
      GROUP BY i."ID", i."Ingredient Name"
      ORDER BY count(*) DESC
      LIMIT GREATEST(1, LEAST(p_limit, 100))
    ) g;
  END IF;

  RETURN jsonb_build_object(
    'summary', jsonb_build_object(
      'published', v_published,
      'with_recipes', v_with_recipes,
      'zero_recipes', v_zero_count,
      'ingredient_gaps', CASE WHEN p_type = 'ingredient' THEN jsonb_array_length(v_gaps) ELSE 0 END
    ),
    'zero_recipe_profiles', v_zero,
    'top_profiles', v_top,
    'ingredient_gaps', v_gaps
  );
END; $$;
REVOKE ALL ON FUNCTION public.admin_get_library_coverage(text,int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_get_library_coverage(text,int) TO authenticated;

-- ── Submission publish → unified table ────────────────────────────────
CREATE OR REPLACE FUNCTION public._publish_library_submission(sub public.library_profile_submissions)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid; p jsonb; slug text;
BEGIN
  p := COALESCE(sub.payload, '{}');
  slug := COALESCE(NULLIF(trim(sub.slug), ''), NULLIF(trim(p->>'slug'), ''),
    lower(regexp_replace(COALESCE(p->>'name', 'profile'), '[^a-z0-9]+', '-', 'g')));
  p := p || jsonb_build_object('slug', slug, 'status', 'published', 'created_by', sub.user_id::text);
  v_id := admin_upsert_library_profile(sub.profile_type, NULL, p);
  UPDATE public.library_profiles SET created_by = sub.user_id WHERE id = v_id;
  RETURN v_id;
END; $$;

DROP FUNCTION IF EXISTS public.admin_review_library_submission(uuid, text, text);
CREATE OR REPLACE FUNCTION public.admin_review_library_submission(
  p_id uuid, p_action text, p_notes text DEFAULT NULL
) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE sub public.library_profile_submissions%ROWTYPE; pub_id uuid;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'not_admin'; END IF;
  SELECT * INTO sub FROM library_profile_submissions WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'not_found'; END IF;
  IF p_action = 'reject' THEN
    UPDATE library_profile_submissions SET status = 'rejected', reviewer_notes = p_notes, reviewed_at = now() WHERE id = p_id;
    RETURN true;
  ELSIF p_action = 'approve' THEN
    pub_id := public._publish_library_submission(sub);
    UPDATE library_profile_submissions SET status = 'approved', reviewer_notes = p_notes, reviewed_at = now(),
      payload = sub.payload || jsonb_build_object('published_profile_id', pub_id::text)
    WHERE id = p_id;
    RETURN true;
  END IF;
  RAISE EXCEPTION 'invalid_action';
END; $$;
GRANT EXECUTE ON FUNCTION public.admin_review_library_submission(uuid, text, text) TO authenticated;

SELECT 'library_profiles unified — ' || count(*)::text || ' rows' AS status FROM public.library_profiles;
SELECT pg_notify('pgrst', 'reload schema');
