-- ══════════════════════════════════════════════════════════════════════
-- fix-library-management.sql
-- Canonical Library Management RPCs: search, pagination, bulk actions,
-- single-profile fetch, governed-link preview. Run after library-profiles.sql.
-- Also ensures mise-image columns + image RPCs from fix-library-mise-images.sql.
-- Safe to re-run.
-- ══════════════════════════════════════════════════════════════════════

-- ── Mise image columns (idempotent) ───────────────────────────────────
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['ingredient','spice','tool','cut','preservation'] LOOP
    EXECUTE format(
      'ALTER TABLE public.%I_profiles
         ADD COLUMN IF NOT EXISTS mise_image_url text,
         ADD COLUMN IF NOT EXISTS image_status text NOT NULL DEFAULT ''missing''',
      t
    );
    BEGIN
      EXECUTE format(
        'ALTER TABLE public.%I_profiles DROP CONSTRAINT IF EXISTS %I_image_status_check',
        t, t
      );
      EXECUTE format(
        'ALTER TABLE public.%I_profiles ADD CONSTRAINT %I_image_status_check
           CHECK (image_status IN (''missing'',''draft'',''approved''))',
        t, t
      );
    EXCEPTION WHEN others THEN NULL;
    END;
    EXECUTE format(
      'UPDATE public.%I_profiles
       SET image_status = CASE
         WHEN mise_image_url IS NOT NULL AND btrim(mise_image_url) <> '''' THEN ''draft''
         ELSE ''missing''
       END
       WHERE image_status = ''missing'' AND mise_image_url IS NOT NULL AND btrim(mise_image_url) <> ''''',
      t
    );
  END LOOP;
END $$;

-- ── Drop ambiguous admin_get_library_profiles overloads ─────────────────
DROP FUNCTION IF EXISTS public.admin_get_library_profiles(text, text, int, int);
DROP FUNCTION IF EXISTS public.admin_get_library_profiles(text, text, int, int, text);
DROP FUNCTION IF EXISTS public.admin_get_library_profiles(text, text, int, int, text, text, text);

CREATE FUNCTION public.admin_get_library_profiles(
  p_type          text,
  p_status        text    DEFAULT NULL,
  p_limit         int     DEFAULT 50,
  p_offset        int     DEFAULT 0,
  p_image_status  text    DEFAULT NULL,
  p_search        text    DEFAULT NULL,
  p_sort          text    DEFAULT 'updated_desc'
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_items jsonb;
  v_total int;
  v_extra text;
  v_img_filter text;
  v_search_filter text;
  v_order text;
  v_table text;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_type NOT IN ('ingredient','spice','tool','cut','preservation') THEN
    RAISE EXCEPTION 'Invalid profile type';
  END IF;

  v_table := p_type || '_profiles';
  v_extra := CASE WHEN p_type = 'ingredient' THEN ', governed_ingredient_id' ELSE '' END;

  v_img_filter := CASE p_image_status
    WHEN 'missing'  THEN ' AND (mise_image_url IS NULL OR btrim(mise_image_url) = '''')'
    WHEN 'draft'    THEN ' AND mise_image_url IS NOT NULL AND btrim(mise_image_url) <> '''' AND image_status = ''draft'''
    WHEN 'approved' THEN ' AND image_status = ''approved'''
    ELSE ''
  END;

  v_search_filter := CASE
    WHEN p_search IS NULL OR btrim(p_search) = '' THEN ''
    ELSE ' AND (name ILIKE ''%'' || $2 || ''%'' OR also_known_as ILIKE ''%'' || $2 || ''%'' OR slug ILIKE ''%'' || $2 || ''%'')'
  END;

  v_order := CASE p_sort
    WHEN 'name_asc'     THEN 'name ASC'
    WHEN 'name_desc'    THEN 'name DESC'
    WHEN 'updated_asc'  THEN 'updated_at ASC'
    WHEN 'status_asc'   THEN 'status ASC, name ASC'
    ELSE 'updated_at DESC'
  END;

  EXECUTE format(
    'SELECT count(*)::int FROM %I WHERE ($1 IS NULL OR status = $1)%s%s',
    v_table, v_img_filter, v_search_filter
  ) INTO v_total USING p_status, p_search;

  v_search_filter := CASE
    WHEN p_search IS NULL OR btrim(p_search) = '' THEN ''
    ELSE ' AND (name ILIKE ''%'' || $4 || ''%'' OR also_known_as ILIKE ''%'' || $4 || ''%'' OR slug ILIKE ''%'' || $4 || ''%'')'
  END;

  EXECUTE format(
    'SELECT COALESCE(jsonb_agg(p ORDER BY %s), ''[]''::jsonb)
     FROM (
       SELECT id, slug, name, image_url, mise_image_url, image_status, status, visibility, updated_at%s
       FROM %I
       WHERE ($1 IS NULL OR status = $1)%s%s
       ORDER BY %s
       LIMIT $2 OFFSET $3
     ) p',
    CASE p_sort
      WHEN 'name_asc'     THEN 'p.name ASC'
      WHEN 'name_desc'    THEN 'p.name DESC'
      WHEN 'updated_asc'  THEN 'p.updated_at ASC'
      WHEN 'status_asc'   THEN 'p.status ASC, p.name ASC'
      ELSE 'p.updated_at DESC'
    END,
    v_extra, v_table, v_img_filter, v_search_filter, v_order
  ) INTO v_items USING p_status, p_limit, p_offset, p_search;

  RETURN jsonb_build_object('items', COALESCE(v_items, '[]'::jsonb), 'total', COALESCE(v_total, 0));
END; $$;
REVOKE ALL ON FUNCTION public.admin_get_library_profiles(text,text,int,int,text,text,text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_get_library_profiles(text,text,int,int,text,text,text) TO authenticated;

-- ── Single profile for in-panel editor ────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_library_profile(text, uuid);
CREATE FUNCTION public.admin_get_library_profile(p_type text, p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_result jsonb;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_type NOT IN ('ingredient','spice','tool','cut','preservation') THEN
    RAISE EXCEPTION 'Invalid profile type';
  END IF;
  EXECUTE format('SELECT to_jsonb(p) FROM %I p WHERE id = $1', p_type || '_profiles')
    INTO v_result USING p_id;
  IF v_result IS NULL THEN RAISE EXCEPTION 'Profile not found'; END IF;
  RETURN v_result;
END; $$;
REVOKE ALL ON FUNCTION public.admin_get_library_profile(text,uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_get_library_profile(text,uuid) TO authenticated;

-- ── Mise image stats ──────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_library_image_stats(text);
CREATE FUNCTION public.admin_get_library_image_stats(p_type text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_result jsonb;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  EXECUTE format(
    'SELECT jsonb_build_object(
       ''total'', count(*)::int,
       ''missing'', count(*) FILTER (WHERE mise_image_url IS NULL OR btrim(mise_image_url) = '''')::int,
       ''draft'', count(*) FILTER (WHERE mise_image_url IS NOT NULL AND btrim(mise_image_url) <> '''' AND image_status = ''draft'')::int,
       ''approved'', count(*) FILTER (WHERE image_status = ''approved'')::int
     ) FROM %I',
    p_type || '_profiles'
  ) INTO v_result;
  RETURN COALESCE(v_result, '{"total":0,"missing":0,"draft":0,"approved":0}'::jsonb);
END; $$;
REVOKE ALL ON FUNCTION public.admin_get_library_image_stats(text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_get_library_image_stats(text) TO authenticated;

-- ── Set mise image status ─────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_set_library_image_status(text, uuid, text);
CREATE FUNCTION public.admin_set_library_image_status(
  p_type   text,
  p_id     uuid,
  p_status text
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_status NOT IN ('missing','draft','approved') THEN
    RAISE EXCEPTION 'Invalid image_status';
  END IF;
  EXECUTE format(
    'UPDATE %I SET image_status = $1, updated_at = NOW() WHERE id = $2',
    p_type || '_profiles'
  ) USING p_status, p_id;
END; $$;
REVOKE ALL ON FUNCTION public.admin_set_library_image_status(text,uuid,text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_set_library_image_status(text,uuid,text) TO authenticated;

-- ── Bulk actions ──────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_bulk_library_profiles(text, uuid[], text, text);
CREATE FUNCTION public.admin_bulk_library_profiles(
  p_type   text,
  p_ids    uuid[],
  p_action text,
  p_value  text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_table text; v_n int := 0;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_ids IS NULL OR array_length(p_ids, 1) IS NULL THEN
    RETURN jsonb_build_object('updated', 0);
  END IF;
  IF p_type NOT IN ('ingredient','spice','tool','cut','preservation') THEN
    RAISE EXCEPTION 'Invalid profile type';
  END IF;
  v_table := p_type || '_profiles';

  CASE p_action
    WHEN 'publish' THEN
      EXECUTE format('UPDATE %I SET status = ''published'', updated_at = NOW() WHERE id = ANY($1)', v_table)
        USING p_ids;
    WHEN 'unpublish' THEN
      EXECUTE format('UPDATE %I SET status = ''draft'', updated_at = NOW() WHERE id = ANY($1)', v_table)
        USING p_ids;
    WHEN 'approve_image' THEN
      EXECUTE format(
        'UPDATE %I SET image_status = ''approved'', updated_at = NOW()
         WHERE id = ANY($1) AND mise_image_url IS NOT NULL AND btrim(mise_image_url) <> ''''',
        v_table
      ) USING p_ids;
    WHEN 'set_visibility' THEN
      IF p_value NOT IN ('public','members','paid') THEN
        RAISE EXCEPTION 'Invalid visibility';
      END IF;
      EXECUTE format('UPDATE %I SET visibility = $2, updated_at = NOW() WHERE id = ANY($1)', v_table)
        USING p_ids, p_value;
    WHEN 'delete' THEN
      EXECUTE format('DELETE FROM %I WHERE id = ANY($1)', v_table) USING p_ids;
    ELSE
      RAISE EXCEPTION 'Unknown action: %', p_action;
  END CASE;

  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN jsonb_build_object('updated', v_n);
END; $$;
REVOKE ALL ON FUNCTION public.admin_bulk_library_profiles(text,uuid[],text,text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_bulk_library_profiles(text,uuid[],text,text) TO authenticated;

-- ── Governed ingredient link (validated) ──────────────────────────────
DROP FUNCTION IF EXISTS public.admin_link_library_ingredient(uuid, integer);
CREATE FUNCTION public.admin_link_library_ingredient(p_profile_id uuid, p_ingredient_id integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_name text;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_ingredient_id IS NULL OR p_ingredient_id < 1 THEN
    RAISE EXCEPTION 'Invalid ingredient ID';
  END IF;
  SELECT "Ingredient Name" INTO v_name FROM public.ingredients WHERE "ID" = p_ingredient_id;
  IF v_name IS NULL THEN
    RAISE EXCEPTION 'Ingredient ID % not found in governed ingredients table', p_ingredient_id;
  END IF;
  UPDATE public.ingredient_profiles
  SET governed_ingredient_id = p_ingredient_id, updated_at = now()
  WHERE id = p_profile_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Ingredient profile not found'; END IF;
  RETURN jsonb_build_object('ingredient_id', p_ingredient_id, 'ingredient_name', v_name);
END; $$;
REVOKE ALL ON FUNCTION public.admin_link_library_ingredient(uuid,integer) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_link_library_ingredient(uuid,integer) TO authenticated;

-- ── Governed link preview (recipe badge count) ────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_library_governed_preview(uuid);
CREATE FUNCTION public.admin_get_library_governed_preview(p_profile_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_ing_id int;
  v_ing_name text;
  v_profile_name text;
  v_count int := 0;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  SELECT governed_ingredient_id, name INTO v_ing_id, v_profile_name
  FROM public.ingredient_profiles WHERE id = p_profile_id;
  IF v_ing_id IS NULL THEN
    RETURN jsonb_build_object('linked', false, 'profile_name', v_profile_name);
  END IF;
  SELECT "Ingredient Name" INTO v_ing_name FROM public.ingredients WHERE "ID" = v_ing_id;
  IF v_ing_name IS NULL THEN
    RETURN jsonb_build_object(
      'linked', true, 'valid', false,
      'ingredient_id', v_ing_id, 'profile_name', v_profile_name
    );
  END IF;
  SELECT count(*)::int INTO v_count
  FROM public.submitted_recipes sr
  WHERE sr.status = 'approved'
    AND sr.ingredients IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM jsonb_array_elements(sr.ingredients) sec,
           jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
      WHERE lower(trim(item->>'ingredient')) = lower(trim(v_ing_name))
    );
  RETURN jsonb_build_object(
    'linked', true, 'valid', true,
    'ingredient_id', v_ing_id,
    'ingredient_name', v_ing_name,
    'recipe_count', v_count,
    'profile_name', v_profile_name
  );
END; $$;
REVOKE ALL ON FUNCTION public.admin_get_library_governed_preview(uuid) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_get_library_governed_preview(uuid) TO authenticated;

SELECT 'Library management RPCs ready' AS status;
SELECT pg_notify('pgrst', 'reload schema');
