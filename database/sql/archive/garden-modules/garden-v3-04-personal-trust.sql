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
