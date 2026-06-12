-- garden-v4-01-varieties.sql — cultivar layer (species + varieties + climate suitability + kitchen hinges)
-- Requires Garden v3. Additive only. Safe to re-run.

CREATE TABLE IF NOT EXISTS public.plant_varieties (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plant_id uuid NOT NULL REFERENCES public.plants(id) ON DELETE CASCADE,
  slug text NOT NULL,
  name text NOT NULL,
  lineage_type text CHECK (lineage_type IN ('heirloom','open_pollinated','hybrid','indigenous')),
  origin text,
  traits text,
  flesh_fruit text,
  yield_notes text,
  growing_notes text,
  availability text,
  sort_order smallint NOT NULL DEFAULT 0,
  is_published boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (plant_id, slug)
);

DROP TRIGGER IF EXISTS plant_varieties_updated_at ON public.plant_varieties;
CREATE TRIGGER plant_varieties_updated_at
  BEFORE UPDATE ON public.plant_varieties
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TABLE IF NOT EXISTS public.variety_climate_suitability (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  variety_id uuid NOT NULL REFERENCES public.plant_varieties(id) ON DELETE CASCADE,
  climate_zone_id uuid NOT NULL REFERENCES public.climate_zones(id) ON DELETE CASCADE,
  suitability text NOT NULL DEFAULT 'recommended',
  climate_notes text,
  UNIQUE (variety_id, climate_zone_id)
);

-- Per-variety kitchen hinge (when cultivar maps to a distinct governed ingredient)
CREATE TABLE IF NOT EXISTS public.variety_ingredients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  variety_id uuid NOT NULL REFERENCES public.plant_varieties(id) ON DELETE CASCADE,
  ingredient_id integer NOT NULL REFERENCES public.ingredients("ID") ON DELETE CASCADE,
  part text NOT NULL DEFAULT '',
  is_primary boolean NOT NULL DEFAULT true,
  notes text,
  UNIQUE (variety_id, ingredient_id, part)
);

-- Optional: track which cultivar a member is growing
ALTER TABLE public.user_plants
  ADD COLUMN IF NOT EXISTS variety_id uuid REFERENCES public.plant_varieties(id) ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION public.garden_lineage_label(p_type text)
RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_type
    WHEN 'heirloom' THEN 'Heirloom'
    WHEN 'open_pollinated' THEN 'Open-pollinated'
    WHEN 'hybrid' THEN 'Hybrid (F1)'
    WHEN 'indigenous' THEN 'Indigenous / regional'
    ELSE NULL
  END;
$$;

SELECT 'garden-v4-01-varieties ready' AS status;
