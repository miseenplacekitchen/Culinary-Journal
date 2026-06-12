-- =============================================================================
-- THE CULINARY JOURNAL — GARDEN v3 (Platform Data Model v3)
-- Paste entire file in Supabase SQL Editor after code deploy.
-- Additive only. Safe to re-run.
-- =============================================================================


-- ########## BEGIN: garden-v3-01-foundation.sql ##########
-- garden-v3-01-foundation.sql
-- Platform Data Model v3 — §1 Foundation. Additive only. Safe to re-run.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Controlled vocabularies
CREATE TABLE IF NOT EXISTS public.cat_high_level (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  name text NOT NULL,
  definition text
);

CREATE TABLE IF NOT EXISTS public.cat_main (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  name text NOT NULL,
  definition text
);

CREATE TABLE IF NOT EXISTS public.garden_layers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  name text NOT NULL,
  description text
);

CREATE TABLE IF NOT EXISTS public.growth_habits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  name text NOT NULL,
  description text
);

CREATE TABLE IF NOT EXISTS public.lifecycles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  name text NOT NULL,
  traits text
);

CREATE TABLE IF NOT EXISTS public.soil_types (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  name text NOT NULL,
  ph_low numeric,
  ph_high numeric
);

CREATE TABLE IF NOT EXISTS public.sunlight_levels (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  name text NOT NULL,
  hours text
);

CREATE TABLE IF NOT EXISTS public.seed_saving_groups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  grp smallint UNIQUE NOT NULL,
  name text NOT NULL,
  notes text
);

CREATE TABLE IF NOT EXISTS public.ease_ratings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  score smallint UNIQUE NOT NULL,
  name text NOT NULL,
  definition text
);

-- Location cascade
CREATE TABLE IF NOT EXISTS public.climate_zones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  name text NOT NULL
);

CREATE TABLE IF NOT EXISTS public.regions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  name text NOT NULL,
  climate_zone_id uuid REFERENCES public.climate_zones(id) ON DELETE SET NULL,
  is_active boolean NOT NULL DEFAULT true
);

-- Media (garden-media bucket)
CREATE TABLE IF NOT EXISTS public.media (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bucket_path text NOT NULL,
  alt_text text,
  credit text,
  license text,
  entity_type text,
  entity_id uuid,
  is_primary boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Tags / cross-links
CREATE TABLE IF NOT EXISTS public.tags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  name text NOT NULL
);

CREATE TABLE IF NOT EXISTS public.entity_tags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tag_id uuid NOT NULL REFERENCES public.tags(id) ON DELETE CASCADE,
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  UNIQUE (tag_id, entity_type, entity_id)
);

SELECT 'garden-v3-01-foundation ready' AS status;
-- ########## END: garden-v3-01-foundation.sql ##########

-- ########## BEGIN: garden-v3-02-plants-ecosystem.sql ##########
-- garden-v3-02-plants-ecosystem.sql
-- Platform Data Model v3 — §2 Garden grow, §3 design, §4 ecosystem.

CREATE TABLE IF NOT EXISTS public.plants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  -- S1 identity
  common_name text NOT NULL,
  botanical_name text,
  subspecies text,
  taxonomic_authority text,
  plant_family text,
  plant_type text,
  genetic_lineage_type text,
  variety_cultivar text,
  origin text,
  size_height text,
  size_spread text,
  high_level_category_id uuid REFERENCES public.cat_high_level(id) ON DELETE SET NULL,
  main_category_id uuid REFERENCES public.cat_main(id) ON DELETE SET NULL,
  growth_habit_id uuid REFERENCES public.growth_habits(id) ON DELETE SET NULL,
  garden_layer_id uuid REFERENCES public.garden_layers(id) ON DELETE SET NULL,
  -- S2 lifecycle
  root_invasiveness text,
  senescence_behaviour text,
  suckering_behaviour text,
  growth_rate text,
  lifecycle_id uuid REFERENCES public.lifecycles(id) ON DELETE SET NULL,
  ease_rating_id uuid REFERENCES public.ease_ratings(id) ON DELETE SET NULL,
  -- S5 propagation
  pollination_requirements text,
  pollination_type text,
  flowering_season text,
  propagation_details text,
  propagation_methods text,
  propagation_timing text,
  propagation_depth text,
  sowing_notes text,
  transplanting_notes text,
  germination_time text,
  rootstock text,
  years_to_first_harvest text,
  time_to_harvest text,
  planting_windows text,
  pollination_isolation text,
  seed_purity_risk text,
  isolation_methods text,
  -- S6 harvest
  harvest_season text,
  harvesting_method text,
  yield_per_plant text,
  storage_methods text,
  shelf_life text,
  seed_storage_procedures text,
  seed_storage_parameters text,
  seed_retest_interval text,
  regeneration_frequency text,
  seed_saving_group_id uuid REFERENCES public.seed_saving_groups(id) ON DELETE SET NULL,
  -- S7 human use
  edible_parts text,
  culinary_applications text,
  medicinal_parts text,
  medicinal_systems text,
  toxic_parts text,
  ayurvedic_classification text,
  functional_uses text,
  cultural_uses text,
  nutritional_composition text,
  -- S8 ecology
  wildlife_attraction text,
  erosion_control text,
  carbon_sequestration text,
  ecological_integration text,
  -- S10 summary
  care_summary text,
  is_published boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

DROP TRIGGER IF EXISTS plants_updated_at ON public.plants;
CREATE TRIGGER plants_updated_at
  BEFORE UPDATE ON public.plants
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TABLE IF NOT EXISTS public.plant_parts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plant_id uuid NOT NULL REFERENCES public.plants(id) ON DELETE CASCADE,
  part text NOT NULL,
  role text CHECK (role IN ('edible','medicinal','toxic','functional','ornamental')),
  notes text
);

CREATE TABLE IF NOT EXISTS public.plant_climate_care (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plant_id uuid NOT NULL REFERENCES public.plants(id) ON DELETE CASCADE,
  climate_zone_id uuid REFERENCES public.climate_zones(id) ON DELETE CASCADE,
  field_key text NOT NULL,
  core text,
  risk text,
  fix text,
  value text,
  UNIQUE (plant_id, climate_zone_id, field_key)
);

CREATE TABLE IF NOT EXISTS public.plant_culture (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plant_id uuid NOT NULL REFERENCES public.plants(id) ON DELETE CASCADE,
  region_id uuid REFERENCES public.regions(id) ON DELETE CASCADE,
  local_name text,
  placement_status text,
  beliefs_restrictions text,
  planting_protocol text,
  location_cautions text,
  symbolism text,
  modern_context text,
  UNIQUE (plant_id, region_id)
);

CREATE TABLE IF NOT EXISTS public.plant_companions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plant_id uuid NOT NULL REFERENCES public.plants(id) ON DELETE CASCADE,
  other_plant_id uuid NOT NULL REFERENCES public.plants(id) ON DELETE CASCADE,
  relationship text NOT NULL CHECK (relationship IN ('companion','incompatible')),
  reason text,
  UNIQUE (plant_id, other_plant_id)
);

CREATE TABLE IF NOT EXISTS public.plant_calendar (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plant_id uuid NOT NULL REFERENCES public.plants(id) ON DELETE CASCADE,
  climate_zone_id uuid REFERENCES public.climate_zones(id) ON DELETE CASCADE,
  activity text NOT NULL CHECK (activity IN ('sow','transplant','plant','harvest','prune')),
  month_start smallint CHECK (month_start BETWEEN 1 AND 12),
  month_end smallint CHECK (month_end BETWEEN 1 AND 12),
  notes text
);

-- §3 Design & map
CREATE TABLE IF NOT EXISTS public.guilds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  name text NOT NULL,
  description text,
  is_published boolean NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.guild_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  guild_id uuid NOT NULL REFERENCES public.guilds(id) ON DELETE CASCADE,
  plant_id uuid NOT NULL REFERENCES public.plants(id) ON DELETE CASCADE,
  role text
);

CREATE TABLE IF NOT EXISTS public.zone_definitions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  zone smallint UNIQUE NOT NULL,
  name text NOT NULL,
  description text
);

-- §4 Ecosystem
CREATE TABLE IF NOT EXISTS public.organisms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  name text NOT NULL,
  scientific_name text,
  kind text NOT NULL CHECK (kind IN ('pest','disease','beneficial','pollinator','fungus','soil_life')),
  description text,
  is_published boolean NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.plant_organisms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plant_id uuid NOT NULL REFERENCES public.plants(id) ON DELETE CASCADE,
  organism_id uuid NOT NULL REFERENCES public.organisms(id) ON DELETE CASCADE,
  relationship text NOT NULL CHECK (relationship IN ('pest_of','disease_of','attracts','controlled_by')),
  notes text,
  UNIQUE (plant_id, organism_id, relationship)
);

-- §5 Hinge — plant ↔ kitchen
CREATE TABLE IF NOT EXISTS public.plant_ingredients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plant_id uuid NOT NULL REFERENCES public.plants(id) ON DELETE CASCADE,
  ingredient_id integer NOT NULL REFERENCES public.ingredients("ID") ON DELETE CASCADE,
  part text,
  is_primary boolean NOT NULL DEFAULT true,
  UNIQUE (plant_id, ingredient_id, part)
);

SELECT 'garden-v3-02-plants-ecosystem ready' AS status;
-- ########## END: garden-v3-02-plants-ecosystem.sql ##########

-- ########## BEGIN: garden-v3-03-kitchen-learning.sql ##########
-- garden-v3-03-kitchen-learning.sql
-- Platform Data Model v3 — §6 Kitchen & drinks, §7 Learning layer.

CREATE TABLE IF NOT EXISTS public.preservation_methods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  name text NOT NULL,
  description text,
  safety_notes text,
  is_published boolean NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.ingredient_preservation (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ingredient_id integer NOT NULL REFERENCES public.ingredients("ID") ON DELETE CASCADE,
  method_id uuid NOT NULL REFERENCES public.preservation_methods(id) ON DELETE CASCADE,
  notes text
);

CREATE TABLE IF NOT EXISTS public.drinks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  name text NOT NULL,
  kind text NOT NULL CHECK (kind IN ('cocktail','wine','spirit','infusion','tea','cordial','juice')),
  body text,
  is_published boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.drink_ingredients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  drink_id uuid NOT NULL REFERENCES public.drinks(id) ON DELETE CASCADE,
  ingredient_id integer NOT NULL REFERENCES public.ingredients("ID") ON DELETE CASCADE,
  amount text
);

CREATE TABLE IF NOT EXISTS public.pairings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  drink_id uuid NOT NULL REFERENCES public.drinks(id) ON DELETE CASCADE,
  recipe_id uuid REFERENCES public.submitted_recipes(id) ON DELETE SET NULL,
  note text
);

CREATE TABLE IF NOT EXISTS public.topics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  name text NOT NULL,
  summary text,
  parent_topic_id uuid REFERENCES public.topics(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS public.lessons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  title text NOT NULL,
  body text,
  topic_id uuid REFERENCES public.topics(id) ON DELETE SET NULL,
  chapter_ref text,
  difficulty text CHECK (difficulty IN ('start','core','deep')),
  is_published boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.learning_paths (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL,
  title text NOT NULL,
  description text,
  is_published boolean NOT NULL DEFAULT false
);

CREATE TABLE IF NOT EXISTS public.path_steps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  path_id uuid NOT NULL REFERENCES public.learning_paths(id) ON DELETE CASCADE,
  lesson_id uuid NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
  step_order smallint NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS public.lesson_links (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id uuid NOT NULL REFERENCES public.lessons(id) ON DELETE CASCADE,
  entity_type text NOT NULL,
  entity_id uuid NOT NULL
);

SELECT 'garden-v3-03-kitchen-learning ready' AS status;
-- ########## END: garden-v3-03-kitchen-learning.sql ##########

-- ########## BEGIN: garden-v3-04-personal-trust.sql ##########
-- garden-v3-04-personal-trust.sql
-- Platform Data Model v3 — §8 Personalisation, §9 Trust & safety.

CREATE TABLE IF NOT EXISTS public.user_plants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plant_id uuid NOT NULL REFERENCES public.plants(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'planned' CHECK (status IN ('planned','growing','harvesting','done')),
  planted_at date,
  bed_label text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, plant_id)
);

DO $$ BEGIN
  ALTER TABLE public.user_plants
    ADD CONSTRAINT user_plants_user_plant_unique UNIQUE (user_id, plant_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DROP TRIGGER IF EXISTS user_plants_updated_at ON public.user_plants;
CREATE TRIGGER user_plants_updated_at
  BEFORE UPDATE ON public.user_plants
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TABLE IF NOT EXISTS public.user_regions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  region_id uuid NOT NULL REFERENCES public.regions(id) ON DELETE CASCADE,
  UNIQUE (user_id)
);

CREATE TABLE IF NOT EXISTS public.garden_journal (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  entry_date date NOT NULL DEFAULT CURRENT_DATE,
  body text,
  user_plant_id uuid REFERENCES public.user_plants(id) ON DELETE SET NULL,
  media_id uuid REFERENCES public.media(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.content_review (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','in_review','verified','flagged')),
  reviewer_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  verified_at timestamptz,
  note text,
  UNIQUE (entity_type, entity_id)
);

CREATE TABLE IF NOT EXISTS public.sources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  title text,
  author text,
  url text
);

CREATE TABLE IF NOT EXISTS public.safety_flags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  flag text NOT NULL,
  message text
);

SELECT 'garden-v3-04-personal-trust ready' AS status;
-- ########## END: garden-v3-04-personal-trust.sql ##########

-- ########## BEGIN: garden-v3-05-rls-grants.sql ##########
-- garden-v3-05-rls-grants.sql
-- RLS + grants — public reads published content; admins manage; users own personal rows.

-- Lookup tables: world-readable, admin writes
DO $$ DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'cat_high_level','cat_main','garden_layers','growth_habits','lifecycles',
    'soil_types','sunlight_levels','seed_saving_groups','ease_ratings',
    'climate_zones','regions','zone_definitions','tags'
  ]
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS "garden lookup read" ON public.%I', t);
    EXECUTE format('CREATE POLICY "garden lookup read" ON public.%I FOR SELECT TO anon, authenticated USING (true)', t);
    EXECUTE format('DROP POLICY IF EXISTS "garden lookup admin" ON public.%I', t);
    EXECUTE format('CREATE POLICY "garden lookup admin" ON public.%I FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin())', t);
    EXECUTE format('GRANT SELECT ON public.%I TO anon, authenticated', t);
    EXECUTE format('GRANT INSERT, UPDATE, DELETE ON public.%I TO authenticated', t);
  END LOOP;
END $$;

-- Published content tables
DO $$ DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['plants','guilds','organisms','drinks','lessons','learning_paths','preservation_methods']
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS "garden published read" ON public.%I', t);
    EXECUTE format('CREATE POLICY "garden published read" ON public.%I FOR SELECT TO anon, authenticated USING (is_published = true)', t);
    EXECUTE format('DROP POLICY IF EXISTS "garden published admin" ON public.%I', t);
    EXECUTE format('CREATE POLICY "garden published admin" ON public.%I FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin())', t);
    EXECUTE format('GRANT SELECT ON public.%I TO anon, authenticated', t);
    EXECUTE format('GRANT INSERT, UPDATE, DELETE ON public.%I TO authenticated', t);
  END LOOP;
END $$;

-- Child / link tables: readable when parent published (simplified — authenticated read + admin write)
DO $$ DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'plant_parts','plant_climate_care','plant_culture','plant_companions','plant_calendar',
    'plant_organisms','plant_ingredients','guild_members',
    'ingredient_preservation','drink_ingredients','pairings',
    'topics','path_steps','lesson_links','entity_tags','media','sources','safety_flags','content_review'
  ]
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS "garden child read" ON public.%I', t);
    EXECUTE format('CREATE POLICY "garden child read" ON public.%I FOR SELECT TO anon, authenticated USING (true)', t);
    EXECUTE format('DROP POLICY IF EXISTS "garden child admin" ON public.%I', t);
    EXECUTE format('CREATE POLICY "garden child admin" ON public.%I FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin())', t);
    EXECUTE format('GRANT SELECT ON public.%I TO anon, authenticated', t);
    EXECUTE format('GRANT INSERT, UPDATE, DELETE ON public.%I TO authenticated', t);
  END LOOP;
END $$;

-- User-owned rows
ALTER TABLE public.user_plants ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "user_plants own" ON public.user_plants;
CREATE POLICY "user_plants own" ON public.user_plants FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_plants TO authenticated;

ALTER TABLE public.user_regions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "user_regions own" ON public.user_regions;
CREATE POLICY "user_regions own" ON public.user_regions FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_regions TO authenticated;

ALTER TABLE public.garden_journal ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "garden_journal own" ON public.garden_journal;
CREATE POLICY "garden_journal own" ON public.garden_journal FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.garden_journal TO authenticated;

-- Storage bucket garden-media
INSERT INTO storage.buckets (id, name, public)
VALUES ('garden-media', 'garden-media', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Admin uploads garden media" ON storage.objects;
CREATE POLICY "Admin uploads garden media"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'garden-media' AND is_admin());

DROP POLICY IF EXISTS "Admin updates garden media" ON storage.objects;
CREATE POLICY "Admin updates garden media"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'garden-media' AND is_admin());

DROP POLICY IF EXISTS "Anyone reads garden media" ON storage.objects;
CREATE POLICY "Anyone reads garden media"
  ON storage.objects FOR SELECT TO anon, authenticated
  USING (bucket_id = 'garden-media');

SELECT 'garden-v3-05-rls-grants ready' AS status;
-- ########## END: garden-v3-05-rls-grants.sql ##########

-- ########## BEGIN: garden-v3-06-rpcs.sql ##########
-- garden-v3-06-rpcs.sql
-- Platform Data Model v3 — §10 seasonal engine + browse RPCs.

-- Published plants directory
DROP FUNCTION IF EXISTS public.get_published_plants(text, integer, integer);
CREATE OR REPLACE FUNCTION public.get_published_plants(
  p_search text DEFAULT NULL,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS SETOF json
LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public
AS $$
BEGIN
  p_limit := GREATEST(1, LEAST(COALESCE(p_limit, 50), 100));
  p_offset := GREATEST(0, COALESCE(p_offset, 0));
  RETURN QUERY
    SELECT json_build_object(
      'id', p.id,
      'slug', p.slug,
      'common_name', p.common_name,
      'botanical_name', p.botanical_name,
      'care_summary', p.care_summary,
      'plant_family', p.plant_family,
      'ease_rating', er.name
    )
    FROM public.plants p
    LEFT JOIN public.ease_ratings er ON er.id = p.ease_rating_id
    WHERE p.is_published = true
      AND (p_search IS NULL OR p_search = ''
           OR p.common_name ILIKE '%' || p_search || '%'
           OR p.botanical_name ILIKE '%' || p_search || '%'
           OR p.slug ILIKE '%' || p_search || '%')
    ORDER BY p.common_name
    LIMIT p_limit OFFSET p_offset;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_published_plants(text, integer, integer) TO anon, authenticated;

-- Plant detail by slug
DROP FUNCTION IF EXISTS public.get_plant_by_slug(text);
CREATE OR REPLACE FUNCTION public.get_plant_by_slug(p_slug text)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v json;
BEGIN
  SELECT id INTO v_id FROM public.plants WHERE slug = p_slug AND is_published = true LIMIT 1;
  IF v_id IS NULL THEN RETURN NULL; END IF;
  SELECT json_build_object(
    'plant', row_to_json(p.*),
    'parts', COALESCE((
      SELECT json_agg(row_to_json(pp.*) ORDER BY pp.part)
      FROM public.plant_parts pp WHERE pp.plant_id = v_id
    ), '[]'::json),
    'calendar', COALESCE((
      SELECT json_agg(json_build_object(
        'activity', pc.activity, 'month_start', pc.month_start, 'month_end', pc.month_end,
        'notes', pc.notes, 'climate_zone', cz.name
      ) ORDER BY pc.month_start)
      FROM public.plant_calendar pc
      LEFT JOIN public.climate_zones cz ON cz.id = pc.climate_zone_id
      WHERE pc.plant_id = v_id
    ), '[]'::json),
    'ingredients', COALESCE((
      SELECT json_agg(json_build_object(
        'ingredient_id', pi.ingredient_id,
        'ingredient_name', i."Ingredient Name",
        'part', pi.part,
        'is_primary', pi.is_primary
      ))
      FROM public.plant_ingredients pi
      JOIN public.ingredients i ON i."ID" = pi.ingredient_id
      WHERE pi.plant_id = v_id
    ), '[]'::json),
    'companions', COALESCE((
      SELECT json_agg(json_build_object(
        'relationship', c.relationship,
        'reason', c.reason,
        'other_slug', op.slug,
        'other_name', op.common_name
      ))
      FROM public.plant_companions c
      JOIN public.plants op ON op.id = c.other_plant_id
      WHERE c.plant_id = v_id
    ), '[]'::json),
    'safety_flags', COALESCE((
      SELECT json_agg(row_to_json(sf.*))
      FROM public.safety_flags sf
      WHERE sf.entity_type = 'plant' AND sf.entity_id = v_id
    ), '[]'::json)
  ) INTO v
  FROM public.plants p WHERE p.id = v_id;
  RETURN v;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_plant_by_slug(text) TO anon, authenticated;

-- §10 "What now, here?" — seasonal activities for user's garden
DROP FUNCTION IF EXISTS public.garden_what_now(smallint);
DROP FUNCTION IF EXISTS public.garden_what_now(integer);
CREATE OR REPLACE FUNCTION public.garden_what_now(p_month smallint DEFAULT NULL)
RETURNS SETOF json
LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public
AS $$
DECLARE
  v_month smallint;
  v_zone uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  v_month := COALESCE(p_month, EXTRACT(MONTH FROM CURRENT_DATE)::smallint);
  SELECT ur.region_id INTO v_zone
    FROM public.user_regions ur WHERE ur.user_id = auth.uid() LIMIT 1;
  RETURN QUERY
    SELECT json_build_object(
      'plant_slug', p.slug,
      'plant_name', p.common_name,
      'activity', pc.activity,
      'month_start', pc.month_start,
      'month_end', pc.month_end,
      'notes', pc.notes,
      'user_status', up.status,
      'bed_label', up.bed_label
    )
    FROM public.user_plants up
    JOIN public.plants p ON p.id = up.plant_id AND p.is_published = true
    JOIN public.plant_calendar pc ON pc.plant_id = p.id
    LEFT JOIN public.regions r ON r.id = v_zone
    WHERE up.user_id = auth.uid()
      AND up.status IN ('planned','growing','harvesting')
      AND v_month BETWEEN pc.month_start AND pc.month_end
      AND (pc.climate_zone_id IS NULL OR pc.climate_zone_id = r.climate_zone_id OR v_zone IS NULL)
    ORDER BY pc.activity, p.common_name;
END;
$$;
GRANT EXECUTE ON FUNCTION public.garden_what_now(smallint) TO authenticated;

-- User garden CRUD helpers
DROP FUNCTION IF EXISTS public.get_my_garden_plants();
CREATE OR REPLACE FUNCTION public.get_my_garden_plants()
RETURNS SETOF json
LANGUAGE plpgsql SECURITY DEFINER STABLE SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  RETURN QUERY
    SELECT json_build_object(
      'id', up.id,
      'status', up.status,
      'planted_at', up.planted_at,
      'bed_label', up.bed_label,
      'notes', up.notes,
      'plant_slug', p.slug,
      'plant_name', p.common_name,
      'care_summary', p.care_summary
    )
    FROM public.user_plants up
    JOIN public.plants p ON p.id = up.plant_id
    WHERE up.user_id = auth.uid()
    ORDER BY up.updated_at DESC;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_my_garden_plants() TO authenticated;

DROP FUNCTION IF EXISTS public.upsert_my_garden_plant(uuid, text, date, text, text);
CREATE OR REPLACE FUNCTION public.upsert_my_garden_plant(
  p_plant_id uuid,
  p_status text DEFAULT 'planned',
  p_planted_at date DEFAULT NULL,
  p_bed_label text DEFAULT NULL,
  p_notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.plants WHERE id = p_plant_id AND is_published = true) THEN
    RAISE EXCEPTION 'plant_not_found';
  END IF;
  INSERT INTO public.user_plants (user_id, plant_id, status, planted_at, bed_label, notes)
  VALUES (auth.uid(), p_plant_id, COALESCE(p_status, 'planned'), p_planted_at, p_bed_label, p_notes)
  ON CONFLICT (user_id, plant_id) DO NOTHING
  RETURNING id INTO v_id;
  IF v_id IS NULL THEN
    SELECT id INTO v_id FROM public.user_plants
    WHERE user_id = auth.uid() AND plant_id = p_plant_id LIMIT 1;
    UPDATE public.user_plants SET
      status = COALESCE(p_status, status),
      planted_at = COALESCE(p_planted_at, planted_at),
      bed_label = COALESCE(p_bed_label, bed_label),
      notes = COALESCE(p_notes, notes),
      updated_at = now()
    WHERE id = v_id;
  END IF;
  RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.upsert_my_garden_plant(uuid, text, date, text, text) TO authenticated;

DROP FUNCTION IF EXISTS public.set_my_garden_region(uuid);
CREATE OR REPLACE FUNCTION public.set_my_garden_region(p_region_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  INSERT INTO public.user_regions (user_id, region_id)
  VALUES (auth.uid(), p_region_id)
  ON CONFLICT (user_id) DO UPDATE SET region_id = EXCLUDED.region_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.set_my_garden_region(uuid) TO authenticated;

NOTIFY pgrst, 'reload schema';
SELECT 'garden-v3-06-rpcs ready' AS status;
-- ########## END: garden-v3-06-rpcs.sql ##########

-- ########## BEGIN: garden-v3-07-seed-slice1.sql ##########
-- garden-v3-07-seed-slice1.sql
-- One plant end-to-end: Tomato — lookups, profile, hinge, calendar, lesson. Safe to re-run.

-- Lookups
INSERT INTO public.cat_high_level (slug, name, definition) VALUES
  ('vegetable', 'Vegetable', 'Edible plants grown for leaves, roots, stems, or fruits.')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.cat_main (slug, name, definition) VALUES
  ('fruiting-veg', 'Fruiting vegetables', 'Plants grown for their fruiting bodies.')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.growth_habits (slug, name, description) VALUES
  ('climbing', 'Climbing / vining', 'Needs support — trellis, cage, or stake.')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.garden_layers (slug, name, description) VALUES
  ('herbaceous', 'Herbaceous layer', 'Non-woody annuals and perennials.')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.lifecycles (slug, name, traits) VALUES
  ('annual', 'Annual', 'Completes life cycle in one growing season.')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.ease_ratings (score, name, definition) VALUES
  (3, 'Moderate', 'Some care needed — staking, feeding, or pest watch.')
ON CONFLICT (score) DO NOTHING;

INSERT INTO public.seed_saving_groups (grp, name, notes) VALUES
  (5, 'Group 5 — self-pollinated', 'Tomato, bean, pea — minimal crossing risk.')
ON CONFLICT (grp) DO NOTHING;

INSERT INTO public.climate_zones (slug, name) VALUES
  ('warm-temperate', 'Warm temperate', 'Mild winters, long frost-free growing season.')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.regions (slug, name, climate_zone_id, is_active) VALUES
  ('au-southeast', 'Southeast Australia',
   (SELECT id FROM public.climate_zones WHERE slug = 'warm-temperate' LIMIT 1), true)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.zone_definitions (zone, name, description) VALUES
  (0, 'Zone 0', 'Home / intensive kitchen garden'),
  (1, 'Zone 1', 'Most visited — herbs, salad, daily harvest'),
  (2, 'Zone 2', 'Perennials and small orchards'),
  (3, 'Zone 3', 'Main crops and larger plantings'),
  (4, 'Zone 4', 'Semi-wild forage and timber'),
  (5, 'Zone 5', 'Wild / observation only')
ON CONFLICT (zone) DO NOTHING;

INSERT INTO public.tags (slug, name) VALUES
  ('summer-crop', 'Summer crop'),
  ('kitchen-garden', 'Kitchen garden staple')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.topics (slug, name, summary) VALUES
  ('growing-basics', 'Growing basics', 'Soil, sun, water, and seasonal timing.')
ON CONFLICT (slug) DO NOTHING;

-- Tomato plant
INSERT INTO public.plants (
  slug, common_name, botanical_name, plant_family, plant_type, variety_cultivar, origin,
  size_height, size_spread, care_summary, is_published,
  high_level_category_id, main_category_id, growth_habit_id, garden_layer_id,
  lifecycle_id, ease_rating_id, seed_saving_group_id,
  pollination_type, flowering_season, propagation_methods, germination_time,
  time_to_harvest, harvest_season, harvesting_method, yield_per_plant,
  edible_parts, culinary_applications, toxic_parts, wildlife_attraction,
  growth_rate, planting_windows
) VALUES (
  'tomato',
  'Tomato',
  'Solanum lycopersicum',
  'Solanaceae',
  'Fruiting vegetable',
  'Cherry / salad / sauce cultivars',
  'Andean South America',
  '1–2 m with support',
  '45–60 cm',
  'Full sun, consistent water, stake or cage, feed when fruit sets. Pinch laterals on indeterminate types.',
  true,
  (SELECT id FROM public.cat_high_level WHERE slug = 'vegetable' LIMIT 1),
  (SELECT id FROM public.cat_main WHERE slug = 'fruiting-veg' LIMIT 1),
  (SELECT id FROM public.growth_habits WHERE slug = 'climbing' LIMIT 1),
  (SELECT id FROM public.garden_layers WHERE slug = 'herbaceous' LIMIT 1),
  (SELECT id FROM public.lifecycles WHERE slug = 'annual' LIMIT 1),
  (SELECT id FROM public.ease_ratings WHERE score = 3 LIMIT 1),
  (SELECT id FROM public.seed_saving_groups WHERE grp = 5 LIMIT 1),
  'Self-pollinating (flowers)',
  'Spring–summer',
  'Seed, transplant',
  '5–10 days at 21–27°C',
  '12–16 weeks from transplant',
  'Late spring through autumn',
  'Twist ripe fruit; cut trusses for sauce types',
  '3–15 kg per plant (cultivar dependent)',
  'Fruit (ripe), sometimes green fruit for pickles',
  'Fresh salads, sauces, passata, drying, roasting',
  'Leaves and green parts contain solanine — not for eating',
  'Bees visit flowers; ripe fruit attracts birds if unnetted',
  'Fast once established',
  'Transplant after last frost; successive sowing indoors 6–8 weeks ahead'
)
ON CONFLICT (slug) DO UPDATE SET
  common_name = EXCLUDED.common_name,
  botanical_name = EXCLUDED.botanical_name,
  care_summary = EXCLUDED.care_summary,
  is_published = EXCLUDED.is_published,
  updated_at = now();

-- Parts
INSERT INTO public.plant_parts (plant_id, part, role, notes)
SELECT p.id, v.part, v.role, v.notes
FROM public.plants p
CROSS JOIN (VALUES
  ('fruit', 'edible', 'Eat when fully coloured and slightly soft'),
  ('leaf', 'toxic', 'Solanine — decorative only'),
  ('flower', 'functional', 'Self-fertile; light shake helps in greenhouses')
) AS v(part, role, notes)
WHERE p.slug = 'tomato'
  AND NOT EXISTS (
    SELECT 1 FROM public.plant_parts pp
    WHERE pp.plant_id = p.id AND pp.part = v.part AND pp.role = v.role
  );

-- Climate care (warm temperate)
INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
SELECT p.id, cz.id, v.field_key, v.core, v.risk, v.fix
FROM public.plants p
JOIN public.climate_zones cz ON cz.slug = 'warm-temperate'
CROSS JOIN (VALUES
  ('sunlight', '6–8 hours direct sun', 'Less than 6h — leggy plants, poor fruit', 'Choose sunniest bed or pot'),
  ('water', 'Deep, even moisture; avoid wet leaves', 'Blossom end rot, splitting', 'Mulch; water at soil level mornings'),
  ('frost', 'Frost tender below ~2°C', 'Blackened foliage after cold nights', 'Cover or delay transplant until stable'),
  ('soil', 'Rich, well-drained, pH 6.0–6.8', 'Heavy clay — root rot', 'Compost + raised mound or large pot'),
  ('pest_mgmt', 'Inspect undersides weekly', 'Aphids, whitefly, caterpillars', 'Hose blast; remove hornworms by hand')
) AS v(field_key, core, risk, fix)
WHERE p.slug = 'tomato'
ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
  core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;

-- Calendar (Southern hemisphere warm-temperate months)
INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
SELECT p.id, cz.id, v.activity, v.m_start, v.m_end, v.notes
FROM public.plants p
JOIN public.climate_zones cz ON cz.slug = 'warm-temperate'
CROSS JOIN (VALUES
  ('sow', 8::smallint, 9::smallint, 'Indoors or heat mat; pot up before planting out'),
  ('transplant', 10::smallint, 11::smallint, 'After frost risk; bury stem deep for extra roots'),
  ('harvest', 12::smallint, 4::smallint, 'Pick at breaker stage for storage; fully ripe for eating'),
  ('prune', 11::smallint, 2::smallint, 'Remove lower leaves touching soil; pinch laterals on cordon types')
) AS v(activity, m_start, m_end, notes)
WHERE p.slug = 'tomato'
  AND NOT EXISTS (
    SELECT 1 FROM public.plant_calendar pc
    WHERE pc.plant_id = p.id AND pc.activity = v.activity
      AND pc.month_start = v.m_start AND pc.month_end = v.m_end
  );

-- Hinge → governed Tomato ingredient
INSERT INTO public.plant_ingredients (plant_id, ingredient_id, part, is_primary)
SELECT p.id, sub.ing_id, 'fruit', true
FROM public.plants p
CROSS JOIN LATERAL (
  SELECT "ID" AS ing_id FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) IN ('tomato', 'tomatoes')
     OR lower("Ingredient Name") LIKE '%tomato%'
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) IN ('tomato','tomatoes') THEN 0 ELSE 1 END, "ID"
  LIMIT 1
) sub
WHERE p.slug = 'tomato' AND sub.ing_id IS NOT NULL
ON CONFLICT (plant_id, ingredient_id, part) DO NOTHING;

-- Pest organism
INSERT INTO public.organisms (slug, name, scientific_name, kind, description, is_published) VALUES
  ('tomato-hornworm', 'Tomato hornworm', 'Manduca quinquemaculata', 'pest',
   'Large green caterpillar that strips foliage fast.', true)
ON CONFLICT (slug) DO UPDATE SET is_published = EXCLUDED.is_published;

INSERT INTO public.plant_organisms (plant_id, organism_id, relationship, notes)
SELECT p.id, o.id, 'pest_of', 'Hand-pick at dusk; check for parasitic wasp cocoons before removing.'
FROM public.plants p, public.organisms o
WHERE p.slug = 'tomato' AND o.slug = 'tomato-hornworm'
ON CONFLICT (plant_id, organism_id, relationship) DO NOTHING;

-- Lesson
INSERT INTO public.lessons (slug, title, body, topic_id, difficulty, is_published) VALUES
  ('first-tomato-harvest',
   'Your first tomato harvest',
   'Tomatoes signal ripeness with colour, gentle give, and aroma at the stem. Harvest in the cool of morning, store stem-side up, and never refrigerate fully ripe fruit if you want best flavour.',
   (SELECT id FROM public.topics WHERE slug = 'growing-basics' LIMIT 1),
   'start',
   true)
ON CONFLICT (slug) DO UPDATE SET is_published = EXCLUDED.is_published;

INSERT INTO public.lesson_links (lesson_id, entity_type, entity_id)
SELECT l.id, 'plant', p.id
FROM public.lessons l, public.plants p
WHERE l.slug = 'first-tomato-harvest' AND p.slug = 'tomato'
  AND NOT EXISTS (
    SELECT 1 FROM public.lesson_links ll
    WHERE ll.lesson_id = l.id AND ll.entity_type = 'plant' AND ll.entity_id = p.id
  );

-- Tags + review + safety
INSERT INTO public.entity_tags (tag_id, entity_type, entity_id)
SELECT t.id, 'plant', p.id
FROM public.tags t, public.plants p
WHERE t.slug IN ('summer-crop', 'kitchen-garden') AND p.slug = 'tomato'
ON CONFLICT (tag_id, entity_type, entity_id) DO NOTHING;

INSERT INTO public.content_review (entity_type, entity_id, status, note)
SELECT 'plant', p.id, 'verified', 'Slice 1 seed — tomato E2E'
FROM public.plants p WHERE p.slug = 'tomato'
ON CONFLICT (entity_type, entity_id) DO UPDATE SET status = EXCLUDED.status;

INSERT INTO public.safety_flags (entity_type, entity_id, flag, message)
SELECT 'plant', p.id, 'toxic-foliage', 'Tomato leaves are not edible — solanine content.'
FROM public.plants p
WHERE p.slug = 'tomato'
  AND NOT EXISTS (
    SELECT 1 FROM public.safety_flags sf
    WHERE sf.entity_type = 'plant' AND sf.entity_id = p.id AND sf.flag = 'toxic-foliage'
  );

SELECT slug, common_name, is_published,
  (SELECT count(*) FROM public.plant_ingredients pi WHERE pi.plant_id = plants.id) AS ingredient_links
FROM public.plants WHERE slug = 'tomato';
-- ########## END: garden-v3-07-seed-slice1.sql ##########

-- ########## BEGIN: garden-v3-08-site-pages.sql ##########
-- garden-v3-08-site-pages.sql
-- Register Garden pages as hidden/staging. Betty toggles visibility in Site Management.

INSERT INTO public.site_pages (name, path, visibility, sort_order, min_tier) VALUES
  ('Garden Directory', 'garden-directory.html', 'hidden', 130, 'free'),
  ('Plant Profile', 'garden-plant.html', 'hidden', 131, 'free'),
  ('My Garden', 'my-garden.html', 'hidden', 132, 'free')
ON CONFLICT (path) DO UPDATE SET
  name = EXCLUDED.name,
  sort_order = EXCLUDED.sort_order,
  min_tier = EXCLUDED.min_tier;

SELECT path, name, visibility FROM public.site_pages
WHERE path IN ('garden-directory.html','garden-plant.html','my-garden.html')
ORDER BY sort_order;
-- ########## END: garden-v3-08-site-pages.sql ##########
