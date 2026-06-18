-- Website recipe sources — admin toggle, dedup, attribution (Betty ops)
-- Run in Supabase SQL Editor after sync-submitted-recipes-columns.sql

-- ── Source registry ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.recipe_website_sources (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  host         text NOT NULL,
  display_name text NOT NULL DEFAULT '',
  chef_name    text NOT NULL DEFAULT '',
  base_url     text NOT NULL DEFAULT '',
  is_active    boolean NOT NULL DEFAULT true,
  sort_order   integer NOT NULL DEFAULT 0,
  notes        text NOT NULL DEFAULT '',
  created_at   timestamptz NOT NULL DEFAULT now(),
  updated_at   timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT recipe_website_sources_host_key UNIQUE (host)
);

ALTER TABLE public.recipe_website_sources ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public read active website sources" ON public.recipe_website_sources;
CREATE POLICY "Public read active website sources"
  ON public.recipe_website_sources FOR SELECT TO anon, authenticated
  USING (true);

DROP POLICY IF EXISTS "Admins manage website sources" ON public.recipe_website_sources;
CREATE POLICY "Admins manage website sources"
  ON public.recipe_website_sources FOR ALL TO authenticated
  USING (is_admin()) WITH CHECK (is_admin());

GRANT SELECT ON public.recipe_website_sources TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.recipe_website_sources TO authenticated;
GRANT ALL ON public.recipe_website_sources TO service_role;

-- ── submitted_recipes attribution + dedup ─────────────────────────────────────
ALTER TABLE public.submitted_recipes
  ADD COLUMN IF NOT EXISTS import_source_host text;

CREATE INDEX IF NOT EXISTS submitted_recipes_import_source_host_idx
  ON public.submitted_recipes (import_source_host)
  WHERE import_source_host IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS submitted_recipes_import_source_url_uidx
  ON public.submitted_recipes (import_source_url)
  WHERE import_source_url IS NOT NULL AND btrim(import_source_url) <> '';

-- Drink taxonomy: fix-sips-stories-taxonomy.sql (J1–J9). Do not seed legacy drink subs here.

-- ── Helpers ─────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.normalize_website_host(p_url text)
RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT lower(regexp_replace(
    split_part(regexp_replace(coalesce(p_url, ''), '^https?://', ''), '/', 1),
    '^www\.', ''
  ));
$$;

-- ── Admin RPCs ──────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_list_website_sources()
RETURNS TABLE (
  id           uuid,
  host         text,
  display_name text,
  chef_name    text,
  base_url     text,
  is_active    boolean,
  sort_order   integer,
  notes        text,
  recipe_count bigint,
  updated_at   timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN QUERY
  SELECT
    ws.id,
    ws.host,
    ws.display_name,
    ws.chef_name,
    ws.base_url,
    ws.is_active,
    ws.sort_order,
    ws.notes,
    (SELECT count(*)::bigint FROM public.submitted_recipes sr
      WHERE sr.import_source_host = ws.host
        AND sr.import_path IN ('website-batch', 'website-scrape')) AS recipe_count,
    ws.updated_at
  FROM public.recipe_website_sources ws
  ORDER BY ws.sort_order, ws.display_name;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_list_website_sources() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_upsert_website_source(
  p_host         text,
  p_display_name text DEFAULT '',
  p_chef_name    text DEFAULT '',
  p_base_url     text DEFAULT '',
  p_notes        text DEFAULT '',
  p_sort_order   integer DEFAULT 0
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_host text := normalize_website_host(coalesce(p_base_url, p_host));
  v_id   uuid;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF v_host IS NULL OR v_host = '' THEN RAISE EXCEPTION 'Invalid host'; END IF;

  INSERT INTO public.recipe_website_sources (host, display_name, chef_name, base_url, notes, sort_order)
  VALUES (
    v_host,
    coalesce(nullif(btrim(p_display_name), ''), v_host),
    coalesce(btrim(p_chef_name), ''),
    coalesce(nullif(btrim(p_base_url), ''), 'https://' || v_host),
    coalesce(btrim(p_notes), ''),
    coalesce(p_sort_order, 0)
  )
  ON CONFLICT (host) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    chef_name      = EXCLUDED.chef_name,
    base_url       = EXCLUDED.base_url,
    notes          = EXCLUDED.notes,
    sort_order     = EXCLUDED.sort_order,
    updated_at     = now()
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_upsert_website_source(text, text, text, text, text, integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_set_website_source_active(
  p_host    text,
  p_active  boolean
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_host text := normalize_website_host(p_host);
  v_hidden int := 0;
  v_shown  int := 0;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;

  UPDATE public.recipe_website_sources
     SET is_active = coalesce(p_active, true),
         updated_at = now()
   WHERE host = v_host;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Website source not found: %', v_host;
  END IF;

  IF coalesce(p_active, true) THEN
    UPDATE public.submitted_recipes
       SET visibility = 'Public',
           import_warnings = array_remove(
             coalesce(import_warnings, '{}'::text[]),
             'Source website disabled by admin — recipe hidden from public browse'
           )
     WHERE import_source_host = v_host
       AND import_path IN ('website-batch', 'website-scrape')
       AND visibility = 'Private';
    GET DIAGNOSTICS v_shown = ROW_COUNT;
  ELSE
    UPDATE public.submitted_recipes
       SET visibility = 'Private',
           import_warnings = CASE
             WHEN coalesce(import_warnings, '{}'::text[]) @> ARRAY['Source website disabled by admin — recipe hidden from public browse']
             THEN import_warnings
             ELSE array_append(
               coalesce(import_warnings, '{}'::text[]),
               'Source website disabled by admin — recipe hidden from public browse'
             )
           END
     WHERE import_source_host = v_host
       AND import_path IN ('website-batch', 'website-scrape')
       AND status = 'approved'
       AND visibility = 'Public';
    GET DIAGNOSTICS v_hidden = ROW_COUNT;
  END IF;

  RETURN jsonb_build_object(
    'host', v_host,
    'is_active', coalesce(p_active, true),
    'recipes_hidden', v_hidden,
    'recipes_restored', v_shown
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_set_website_source_active(text, boolean) TO authenticated;

-- Seed Betty's current website list (safe to re-run)
INSERT INTO public.recipe_website_sources (host, display_name, chef_name, base_url, sort_order) VALUES
  ('10.com.au',              '10 MasterChef Recipes',     'MasterChef Australia', 'https://10.com.au/masterchef/recipes', 1),
  ('curryworld.me',          'Veena''s Curry World',      'Veena',                'https://curryworld.me', 2),
  ('malayali.me',            'Malayali.me',               'Malayali.me',          'https://malayali.me/', 3),
  ('mariasmenu.com',         'Maria''s Menu',             'Maria',                'https://mariasmenu.com/', 4),
  ('poulef.com',             'Poulef',                    'Poulef',               'https://poulef.com/', 5),
  ('sandhyahariharan.co.uk', 'Sandhya Hariharan',         'Sandhya Hariharan',     'https://sandhyahariharan.co.uk/', 6),
  ('thewanderlustkitchen.com','The Wanderlust Kitchen',    'The Wanderlust Kitchen','https://thewanderlustkitchen.com/', 7),
  ('villagecookingkerala.com','Village Cooking Kerala',   'Village Cooking Kerala','https://villagecookingkerala.com/', 8),
  ('allrecipes.com',         'Allrecipes',                'Allrecipes',           'https://www.allrecipes.com/', 9),
  ('kevinandamanda.com',     'Kevin & Amanda',            'Kevin & Amanda',       'https://www.kevinandamanda.com/all-recipes/', 10),
  ('kothiyavunu.com',        'Kothiyavunu',               'Shnunni',              'https://www.kothiyavunu.com/', 11),
  ('philly.com.au',          'Philly Australia',          'Philly',               'https://www.philly.com.au/', 12),
  ('taste.com.au',           'Taste.com.au',              'Taste',                'https://www.taste.com.au/', 13),
  ('vegrecipesofindia.com',  'Veg Recipes of India',      'Dassana',              'https://www.vegrecipesofindia.com/', 14),
  ('yummyntasty.com',        'Yummy N Tasty',             'Yummy N Tasty',        'https://www.yummyntasty.com/', 15),
  ('yummytummyaarthi.com',   'Yummy Tummy Aarthi',        'Aarthi',               'https://www.yummytummyaarthi.com/', 16),
  ('woolworths.com.au',      'Woolworths Recipes',        'Woolworths',           'https://www.woolworths.com.au/shop/recipes', 17),
  ('coles.com.au',           'Coles Recipes',             'Coles',                'https://www.coles.com.au/recipes-inspiration', 18)
ON CONFLICT (host) DO UPDATE SET
  display_name = EXCLUDED.display_name,
  chef_name    = COALESCE(NULLIF(EXCLUDED.chef_name, ''), recipe_website_sources.chef_name),
  base_url     = EXCLUDED.base_url,
  sort_order   = EXCLUDED.sort_order,
  updated_at   = now();

SELECT 'fix-website-sources.sql complete' AS status;
