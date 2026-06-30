-- fix-recipe-name-library.sql — Recipe Management → Dish Index (Phase 1 base install).
-- Run once in Supabase SQL Editor. Safe to re-run.
-- After this, run fix-dish-index-columns.sql for full Submit-a-Recipe metadata columns.

CREATE TABLE IF NOT EXISTS public.recipe_name_library (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_name text NOT NULL,
  native_name text DEFAULT '',
  alternate_names text[] DEFAULT '{}',
  category text DEFAULT '',
  sub_category text DEFAULT '',
  division text DEFAULT '',
  origin_continent text DEFAULT '',
  origin_country text DEFAULT '',
  origin_state text DEFAULT '',
  origin_locality text DEFAULT '',
  primary_ingredients text[] DEFAULT '{}',
  dietary_tags text[] DEFAULT '{}',
  meal_type_tags text[] DEFAULT '{}',
  occasion_tags text[] DEFAULT '{}',
  style_tags text[] DEFAULT '{}',
  source_notes text DEFAULT '',
  research_status text DEFAULT 'idea_only',
  content_status text DEFAULT 'not_started',
  linked_recipe_id uuid REFERENCES public.submitted_recipes(id) ON DELETE SET NULL,
  notes text DEFAULT '',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.recipe_name_library ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_recipe_name_library_name
  ON public.recipe_name_library (lower(recipe_name));
CREATE INDEX IF NOT EXISTS idx_recipe_name_library_taxonomy
  ON public.recipe_name_library (category, sub_category, division);
CREATE INDEX IF NOT EXISTS idx_recipe_name_library_status
  ON public.recipe_name_library (research_status, content_status);
CREATE INDEX IF NOT EXISTS idx_recipe_name_library_linked
  ON public.recipe_name_library (linked_recipe_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.recipe_name_library TO authenticated;

DROP POLICY IF EXISTS "Admins manage recipe name library" ON public.recipe_name_library;
CREATE POLICY "Admins manage recipe name library"
  ON public.recipe_name_library
  FOR ALL TO authenticated
  USING (is_admin())
  WITH CHECK (is_admin());

CREATE OR REPLACE FUNCTION public.recipe_name_library_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql SET search_path = public
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_recipe_name_library_updated_at ON public.recipe_name_library;
CREATE TRIGGER trg_recipe_name_library_updated_at
BEFORE UPDATE ON public.recipe_name_library
FOR EACH ROW EXECUTE FUNCTION public.recipe_name_library_touch_updated_at();

CREATE OR REPLACE FUNCTION public.rnl_text_array(p_value jsonb)
RETURNS text[]
LANGUAGE sql IMMUTABLE SET search_path = public
AS $$
  SELECT CASE
    WHEN p_value IS NULL OR p_value = 'null'::jsonb THEN '{}'::text[]
    WHEN jsonb_typeof(p_value) = 'array' THEN (
      SELECT COALESCE(array_agg(NULLIF(btrim(value), '') ORDER BY ord), '{}'::text[])
      FROM jsonb_array_elements_text(p_value) WITH ORDINALITY AS x(value, ord)
      WHERE NULLIF(btrim(value), '') IS NOT NULL
    )
    ELSE (
      SELECT COALESCE(array_agg(NULLIF(btrim(part), '')), '{}'::text[])
      FROM regexp_split_to_table(p_value #>> '{}', '[[:space:]]*[;,][[:space:]]*') AS part
      WHERE NULLIF(btrim(part), '') IS NOT NULL
    )
  END;
$$;

DROP FUNCTION IF EXISTS public.admin_list_recipe_name_library(int, int, text, text, text, text, text, text, text);
CREATE OR REPLACE FUNCTION public.admin_list_recipe_name_library(
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0,
  p_search text DEFAULT NULL,
  p_research_status text DEFAULT NULL,
  p_content_status text DEFAULT NULL,
  p_linked text DEFAULT NULL,
  p_category text DEFAULT NULL,
  p_sort_col text DEFAULT 'recipe_name',
  p_sort_dir text DEFAULT 'asc'
)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_total bigint;
  v_rows json;
  v_order_col text;
  v_order_dir text;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;

  v_order_col := CASE p_sort_col
    WHEN 'native_name' THEN 'native_name'
    WHEN 'category' THEN 'category'
    WHEN 'sub_category' THEN 'sub_category'
    WHEN 'division' THEN 'division'
    WHEN 'origin_country' THEN 'origin_country'
    WHEN 'research_status' THEN 'research_status'
    WHEN 'content_status' THEN 'content_status'
    WHEN 'updated_at' THEN 'updated_at'
    WHEN 'created_at' THEN 'created_at'
    ELSE 'recipe_name'
  END;
  v_order_dir := CASE WHEN lower(COALESCE(p_sort_dir, 'asc')) = 'desc' THEN 'DESC' ELSE 'ASC' END;

  SELECT count(*) INTO v_total
    FROM public.recipe_name_library rnl
   WHERE (p_search IS NULL OR btrim(p_search) = ''
          OR rnl.recipe_name ILIKE '%' || p_search || '%'
          OR rnl.native_name ILIKE '%' || p_search || '%'
          OR rnl.origin_country ILIKE '%' || p_search || '%'
          OR EXISTS (SELECT 1 FROM unnest(COALESCE(rnl.alternate_names, '{}')) a WHERE a ILIKE '%' || p_search || '%'))
     AND (p_research_status IS NULL OR btrim(p_research_status) = '' OR rnl.research_status = p_research_status)
     AND (p_content_status IS NULL OR btrim(p_content_status) = '' OR rnl.content_status = p_content_status)
     AND (p_category IS NULL OR btrim(p_category) = '' OR rnl.category = p_category)
     AND (p_linked IS NULL OR btrim(p_linked) = ''
          OR (p_linked = 'linked' AND rnl.linked_recipe_id IS NOT NULL)
          OR (p_linked = 'unlinked' AND rnl.linked_recipe_id IS NULL));

  EXECUTE format($SQL$
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json)
      FROM (
        SELECT rnl.*,
               sr.recipe_name AS linked_recipe_name,
               sr.recipe_code AS linked_recipe_code,
               sr.status AS linked_recipe_status
          FROM public.recipe_name_library rnl
          LEFT JOIN public.submitted_recipes sr ON sr.id = rnl.linked_recipe_id
         WHERE ($1 IS NULL OR btrim($1) = ''
                OR rnl.recipe_name ILIKE '%%' || $1 || '%%'
                OR rnl.native_name ILIKE '%%' || $1 || '%%'
                OR rnl.origin_country ILIKE '%%' || $1 || '%%'
                OR EXISTS (SELECT 1 FROM unnest(COALESCE(rnl.alternate_names, '{}')) a WHERE a ILIKE '%%' || $1 || '%%'))
           AND ($2 IS NULL OR btrim($2) = '' OR rnl.research_status = $2)
           AND ($3 IS NULL OR btrim($3) = '' OR rnl.content_status = $3)
           AND ($4 IS NULL OR btrim($4) = '' OR rnl.category = $4)
           AND ($5 IS NULL OR btrim($5) = ''
                OR ($5 = 'linked' AND rnl.linked_recipe_id IS NOT NULL)
                OR ($5 = 'unlinked' AND rnl.linked_recipe_id IS NULL))
         ORDER BY rnl.%I %s, rnl.recipe_name ASC
         LIMIT LEAST(GREATEST(COALESCE($6, 50), 1), 500)
        OFFSET GREATEST(COALESCE($7, 0), 0)
      ) t
  $SQL$, v_order_col, v_order_dir)
  INTO v_rows
  USING p_search, p_research_status, p_content_status, p_category, p_linked, p_limit, p_offset;

  RETURN json_build_object('total', v_total, 'rows', COALESCE(v_rows, '[]'::json));
END;
$$;
REVOKE ALL ON FUNCTION public.admin_list_recipe_name_library(int, int, text, text, text, text, text, text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_list_recipe_name_library(int, int, text, text, text, text, text, text, text) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_upsert_recipe_name_library(jsonb);
CREATE OR REPLACE FUNCTION public.admin_upsert_recipe_name_library(p_row jsonb)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_id uuid;
  v_recipe_id uuid;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF NULLIF(btrim(p_row->>'recipe_name'), '') IS NULL THEN
    RAISE EXCEPTION 'Recipe name is required';
  END IF;

  IF NULLIF(p_row->>'id', '') IS NOT NULL THEN
    v_id := (p_row->>'id')::uuid;
  END IF;
  IF NULLIF(p_row->>'linked_recipe_id', '') IS NOT NULL THEN
    v_recipe_id := (p_row->>'linked_recipe_id')::uuid;
  END IF;

  IF v_id IS NULL THEN
    SELECT id INTO v_id
      FROM public.recipe_name_library
     WHERE lower(btrim(recipe_name)) = lower(btrim(p_row->>'recipe_name'))
       AND COALESCE(NULLIF(btrim(origin_country), ''), '') = COALESCE(NULLIF(btrim(p_row->>'origin_country'), ''), '')
     LIMIT 1;
  END IF;

  IF v_id IS NULL THEN
    INSERT INTO public.recipe_name_library (
      recipe_name, native_name, alternate_names,
      category, sub_category, division,
      origin_continent, origin_country, origin_state, origin_locality,
      primary_ingredients, dietary_tags, meal_type_tags, occasion_tags, style_tags,
      source_notes, research_status, content_status, linked_recipe_id, notes
    ) VALUES (
      btrim(p_row->>'recipe_name'), COALESCE(NULLIF(btrim(p_row->>'native_name'), ''), ''),
      public.rnl_text_array(p_row->'alternate_names'),
      COALESCE(NULLIF(btrim(p_row->>'category'), ''), ''), COALESCE(NULLIF(btrim(p_row->>'sub_category'), ''), ''), COALESCE(NULLIF(btrim(p_row->>'division'), ''), ''),
      COALESCE(NULLIF(btrim(p_row->>'origin_continent'), ''), ''), COALESCE(NULLIF(btrim(p_row->>'origin_country'), ''), ''), COALESCE(NULLIF(btrim(p_row->>'origin_state'), ''), ''), COALESCE(NULLIF(btrim(p_row->>'origin_locality'), ''), ''),
      public.rnl_text_array(p_row->'primary_ingredients'), public.rnl_text_array(p_row->'dietary_tags'), public.rnl_text_array(p_row->'meal_type_tags'), public.rnl_text_array(p_row->'occasion_tags'), public.rnl_text_array(p_row->'style_tags'),
      COALESCE(NULLIF(btrim(p_row->>'source_notes'), ''), ''), COALESCE(NULLIF(btrim(p_row->>'research_status'), ''), 'idea_only'), COALESCE(NULLIF(btrim(p_row->>'content_status'), ''), 'not_started'), v_recipe_id, COALESCE(NULLIF(btrim(p_row->>'notes'), ''), '')
    )
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.recipe_name_library SET
      recipe_name = btrim(p_row->>'recipe_name'),
      native_name = COALESCE(NULLIF(btrim(p_row->>'native_name'), ''), ''),
      alternate_names = public.rnl_text_array(p_row->'alternate_names'),
      category = COALESCE(NULLIF(btrim(p_row->>'category'), ''), ''),
      sub_category = COALESCE(NULLIF(btrim(p_row->>'sub_category'), ''), ''),
      division = COALESCE(NULLIF(btrim(p_row->>'division'), ''), ''),
      origin_continent = COALESCE(NULLIF(btrim(p_row->>'origin_continent'), ''), ''),
      origin_country = COALESCE(NULLIF(btrim(p_row->>'origin_country'), ''), ''),
      origin_state = COALESCE(NULLIF(btrim(p_row->>'origin_state'), ''), ''),
      origin_locality = COALESCE(NULLIF(btrim(p_row->>'origin_locality'), ''), ''),
      primary_ingredients = public.rnl_text_array(p_row->'primary_ingredients'),
      dietary_tags = public.rnl_text_array(p_row->'dietary_tags'),
      meal_type_tags = public.rnl_text_array(p_row->'meal_type_tags'),
      occasion_tags = public.rnl_text_array(p_row->'occasion_tags'),
      style_tags = public.rnl_text_array(p_row->'style_tags'),
      source_notes = COALESCE(NULLIF(btrim(p_row->>'source_notes'), ''), ''),
      research_status = COALESCE(NULLIF(btrim(p_row->>'research_status'), ''), 'idea_only'),
      content_status = COALESCE(NULLIF(btrim(p_row->>'content_status'), ''), 'not_started'),
      linked_recipe_id = COALESCE(v_recipe_id, linked_recipe_id),
      notes = COALESCE(NULLIF(btrim(p_row->>'notes'), ''), '')
    WHERE id = v_id
    RETURNING id INTO v_id;
  END IF;

  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_upsert_recipe_name_library(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_upsert_recipe_name_library(jsonb) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_import_recipe_name_library(jsonb);
CREATE OR REPLACE FUNCTION public.admin_import_recipe_name_library(p_rows jsonb)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  r jsonb;
  v_id uuid;
  v_inserted int := 0;
  v_updated int := 0;
  v_skipped int := 0;
  v_exists boolean;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_rows IS NULL OR jsonb_typeof(p_rows) <> 'array' THEN
    RAISE EXCEPTION 'Rows must be a JSON array';
  END IF;

  FOR r IN SELECT * FROM jsonb_array_elements(p_rows) LOOP
    IF NULLIF(btrim(COALESCE(r->>'recipe_name', r->>'Recipe Name', r->>'Name')), '') IS NULL THEN
      v_skipped := v_skipped + 1;
      CONTINUE;
    END IF;
    r := jsonb_build_object(
      'id', COALESCE(r->>'id', r->>'ID'),
      'recipe_name', COALESCE(r->>'recipe_name', r->>'Recipe Name', r->>'Name'),
      'native_name', COALESCE(r->>'native_name', r->>'Native Name'),
      'alternate_names', COALESCE(r->'alternate_names', to_jsonb(COALESCE(r->>'Alternate Names', ''))),
      'category', COALESCE(r->>'category', r->>'Category'),
      'sub_category', COALESCE(r->>'sub_category', r->>'Sub-category', r->>'Sub Category'),
      'division', COALESCE(r->>'division', r->>'Division'),
      'origin_continent', COALESCE(r->>'origin_continent', r->>'Continent'),
      'origin_country', COALESCE(r->>'origin_country', r->>'Country'),
      'origin_state', COALESCE(r->>'origin_state', r->>'State'),
      'origin_locality', COALESCE(r->>'origin_locality', r->>'Locality'),
      'primary_ingredients', COALESCE(r->'primary_ingredients', to_jsonb(COALESCE(r->>'Primary Ingredients', ''))),
      'dietary_tags', COALESCE(r->'dietary_tags', to_jsonb(COALESCE(r->>'Dietary Tags', ''))),
      'meal_type_tags', COALESCE(r->'meal_type_tags', to_jsonb(COALESCE(r->>'Meal Type Tags', ''))),
      'occasion_tags', COALESCE(r->'occasion_tags', to_jsonb(COALESCE(r->>'Occasion Tags', ''))),
      'style_tags', COALESCE(r->'style_tags', to_jsonb(COALESCE(r->>'Style Tags', ''))),
      'source_notes', COALESCE(r->>'source_notes', r->>'Source Notes'),
      'research_status', COALESCE(r->>'research_status', r->>'Research Status'),
      'content_status', COALESCE(r->>'content_status', r->>'Content Status'),
      'linked_recipe_id', COALESCE(r->>'linked_recipe_id', r->>'Linked Recipe ID'),
      'notes', COALESCE(r->>'notes', r->>'Notes')
    );

    SELECT EXISTS (
      SELECT 1 FROM public.recipe_name_library
      WHERE lower(btrim(recipe_name)) = lower(btrim(r->>'recipe_name'))
        AND COALESCE(NULLIF(btrim(origin_country), ''), '') = COALESCE(NULLIF(btrim(r->>'origin_country'), ''), '')
    ) INTO v_exists;
    v_id := public.admin_upsert_recipe_name_library(r);
    IF v_exists THEN v_updated := v_updated + 1; ELSE v_inserted := v_inserted + 1; END IF;
  END LOOP;

  RETURN json_build_object('inserted', v_inserted, 'updated', v_updated, 'skipped', v_skipped);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_import_recipe_name_library(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_import_recipe_name_library(jsonb) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_delete_recipe_name_library(uuid);
CREATE OR REPLACE FUNCTION public.admin_delete_recipe_name_library(p_id uuid)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  DELETE FROM public.recipe_name_library WHERE id = p_id;
  RETURN FOUND;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_delete_recipe_name_library(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_delete_recipe_name_library(uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_link_recipe_name_library(uuid, uuid);
CREATE OR REPLACE FUNCTION public.admin_link_recipe_name_library(p_id uuid, p_recipe_id uuid)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.recipe_name_library
     SET linked_recipe_id = p_recipe_id,
         content_status = CASE WHEN p_recipe_id IS NULL THEN content_status ELSE 'linked' END
   WHERE id = p_id;
  RETURN FOUND;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_link_recipe_name_library(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_link_recipe_name_library(uuid, uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_create_recipe_from_name_library(uuid);
CREATE OR REPLACE FUNCTION public.admin_create_recipe_from_name_library(p_id uuid)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  r public.recipe_name_library%ROWTYPE;
  v_recipe_id uuid;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;

  SELECT * INTO r FROM public.recipe_name_library WHERE id = p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Recipe name library row not found'; END IF;
  IF r.linked_recipe_id IS NOT NULL THEN RETURN r.linked_recipe_id; END IF;

  INSERT INTO public.submitted_recipes (
    user_id, recipe_name, native_title, category, sub_category, division,
    origin_continent, origin_country, origin_state, origin_locality,
    dietary_tags, meal_type_tags, occasion_tags, style_tags,
    ingredients, method, source_type, visibility, status, introduction, description, personal_notes
  ) VALUES (
    auth.uid(), r.recipe_name, COALESCE(r.native_name, ''),
    NULLIF(r.category, ''), NULLIF(r.sub_category, ''), NULLIF(r.division, ''),
    NULLIF(r.origin_continent, ''), NULLIF(r.origin_country, ''), NULLIF(r.origin_state, ''), NULLIF(r.origin_locality, ''),
    COALESCE(r.dietary_tags, '{}'), COALESCE(r.meal_type_tags, '{}'), COALESCE(r.occasion_tags, '{}'), COALESCE(r.style_tags, '{}'),
    '[]'::jsonb, '[]'::jsonb, 'Original', 'Private', 'pending',
    COALESCE(r.source_notes, ''), COALESCE(r.notes, ''), 'Created from Recipe Name Library'
  )
  RETURNING id INTO v_recipe_id;

  UPDATE public.recipe_name_library
     SET linked_recipe_id = v_recipe_id,
         content_status = 'draft_created'
   WHERE id = p_id;

  RETURN v_recipe_id;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_create_recipe_from_name_library(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_create_recipe_from_name_library(uuid) TO authenticated;
