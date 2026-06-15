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
