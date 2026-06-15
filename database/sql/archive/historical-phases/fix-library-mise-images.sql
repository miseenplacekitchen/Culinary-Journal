-- ══════════════════════════════════════════════════════════════════════
-- Library Mise images — circular prep-board photos per profile
-- Run in Supabase SQL editor after library-profiles.sql
-- ══════════════════════════════════════════════════════════════════════

-- ── Columns on all five profile tables ────────────────────────────────
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['ingredient','spice','tool','cut','preservation'] LOOP
    EXECUTE format(
      'ALTER TABLE public.%I_profiles
         ADD COLUMN IF NOT EXISTS mise_image_url text,
         ADD COLUMN IF NOT EXISTS image_status text NOT NULL DEFAULT ''missing''
           CHECK (image_status IN (''missing'',''draft'',''approved''))',
      t
    );
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

-- ── Public directory listing (includes mise fields) ───────────────────
DROP FUNCTION IF EXISTS public.get_library_directory(text, text, int, int);
CREATE FUNCTION public.get_library_directory(
  p_type     text,
  p_search   text    DEFAULT NULL,
  p_limit    int     DEFAULT 24,
  p_offset   int     DEFAULT 0
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_sql text; v_result jsonb;
BEGIN
  v_sql := format(
    'SELECT COALESCE(jsonb_agg(p ORDER BY p.name ASC), ''[]''::jsonb)
     FROM (
       SELECT id, slug, name, also_known_as, image_url, mise_image_url, image_status, %s AS type_extra,
              status, visibility, created_at
       FROM %I
       WHERE status = ''published''
         AND ($1 IS NULL OR name ILIKE ''%%'' || $1 || ''%%'' OR also_known_as ILIKE ''%%'' || $1 || ''%%'')
       ORDER BY name LIMIT $2 OFFSET $3
     ) p',
    CASE p_type
      WHEN 'ingredient'   THEN 'category'
      WHEN 'spice'        THEN 'heat_level::text'
      WHEN 'tool'         THEN 'tool_category'
      WHEN 'cut'          THEN 'protein_type'
      WHEN 'preservation' THEN 'technique_type'
      ELSE '''''' END,
    p_type || '_profiles'
  );
  EXECUTE v_sql INTO v_result USING p_search, p_limit, p_offset;
  RETURN COALESCE(v_result, '[]'::jsonb);
END; $$;
REVOKE ALL ON FUNCTION public.get_library_directory(text,text,int,int) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_library_directory(text,text,int,int) TO anon, authenticated;

-- ── Recipe → library links (mise image for print board) ───────────────
DROP FUNCTION IF EXISTS public.get_library_links_for_ingredients(integer[]);
CREATE FUNCTION public.get_library_links_for_ingredients(p_ids integer[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_ids IS NULL OR array_length(p_ids, 1) IS NULL THEN RETURN '{}'::jsonb; END IF;
  RETURN COALESCE((
    SELECT jsonb_object_agg(
      governed_ingredient_id::text,
      jsonb_build_object(
        'slug', slug,
        'name', name,
        'mise_image_url', mise_image_url,
        'image_status', image_status
      )
    )
    FROM public.ingredient_profiles
    WHERE governed_ingredient_id = ANY(p_ids) AND status = 'published'
  ), '{}'::jsonb);
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_library_links_for_ingredients(integer[]) TO anon, authenticated;

-- ── Admin listing with image-status filter ────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_library_profiles(text, text, int, int);
DROP FUNCTION IF EXISTS public.admin_get_library_profiles(text, text, int, int, text);
CREATE FUNCTION public.admin_get_library_profiles(
  p_type          text,
  p_status        text    DEFAULT NULL,
  p_limit         int     DEFAULT 50,
  p_offset        int     DEFAULT 0,
  p_image_status  text    DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_result jsonb; v_extra text; v_img_filter text;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  v_extra := CASE WHEN p_type = 'ingredient' THEN ', governed_ingredient_id' ELSE '' END;
  v_img_filter := CASE p_image_status
    WHEN 'missing'  THEN ' AND (mise_image_url IS NULL OR btrim(mise_image_url) = '''')'
    WHEN 'draft'    THEN ' AND mise_image_url IS NOT NULL AND btrim(mise_image_url) <> '''' AND image_status = ''draft'''
    WHEN 'approved' THEN ' AND image_status = ''approved'''
    ELSE ''
  END;
  EXECUTE format(
    'SELECT COALESCE(jsonb_agg(p ORDER BY p.updated_at DESC), ''[]''::jsonb)
     FROM (SELECT id, slug, name, image_url, mise_image_url, image_status, status, visibility, updated_at%s
           FROM %I
           WHERE ($1 IS NULL OR status = $1)%s
           ORDER BY updated_at DESC LIMIT $2 OFFSET $3) p',
    v_extra, p_type || '_profiles', v_img_filter
  ) INTO v_result USING p_status, p_limit, p_offset;
  RETURN COALESCE(v_result, '[]'::jsonb);
END; $$;
REVOKE ALL ON FUNCTION public.admin_get_library_profiles(text,text,int,int,text) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.admin_get_library_profiles(text,text,int,int,text) TO authenticated;

-- ── Admin: mise image coverage stats ──────────────────────────────────
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

-- ── Admin: approve / reset mise image status ──────────────────────────
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

SELECT 'Library mise images ready' AS status;
