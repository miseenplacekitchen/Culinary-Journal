-- garden-v3-01-foundation.sql
-- Platform Data Model v3 — §1 Foundation. Additive only. Safe to re-run.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Prerequisite for updated_at triggers (also in library-profiles.sql)
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

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
