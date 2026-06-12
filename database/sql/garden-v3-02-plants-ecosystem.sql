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
