-- Hotfix: get_public_festivals ORDER BY f.sort_order (run if phase36 batch failed at line 287)
-- Safe to re-run.

ALTER TABLE public.festivals ADD COLUMN IF NOT EXISTS sort_order int DEFAULT 0;
ALTER TABLE public.festivals ADD COLUMN IF NOT EXISTS is_active boolean DEFAULT true;

DROP FUNCTION IF EXISTS public.get_public_festivals();
CREATE FUNCTION public.get_public_festivals()
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(jsonb_agg(row_to_json(f) ORDER BY f.sort_order, f.name), '[]'::jsonb)
  FROM (
    SELECT id, slug, name, emoji, when_label, description, planner_path, tags, sort_order,
      (SELECT count(*)::int FROM public.festival_dishes d WHERE d.festival_id = festivals.id) AS dish_count
    FROM public.festivals WHERE is_active = true ORDER BY sort_order, name
  ) f;
$$;
GRANT EXECUTE ON FUNCTION public.get_public_festivals() TO anon, authenticated;

DROP FUNCTION IF EXISTS public.get_festival_detail(text);
CREATE FUNCTION public.get_festival_detail(p_slug text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fest jsonb; v_dishes jsonb;
BEGIN
  SELECT row_to_json(f)::jsonb INTO v_fest FROM public.festivals f WHERE f.slug = p_slug AND f.is_active = true;
  IF v_fest IS NULL THEN RETURN NULL; END IF;
  SELECT COALESCE(jsonb_agg(row_to_json(d) ORDER BY d.sort_order), '[]'::jsonb) INTO v_dishes
  FROM (
    SELECT fd.id, fd.dish_name, fd.sort_order, fd.is_required, fd.notes,
      COALESCE((
        SELECT jsonb_agg(row_to_json(r) ORDER BY r.is_featured DESC, r.variant_label)
        FROM (
          SELECT fdr.id, fdr.variant_label, fdr.is_featured, fdr.visibility, fdr.approval_status,
                 fdr.recipe_id, sr.recipe_name
          FROM public.festival_dish_recipes fdr
          LEFT JOIN public.submitted_recipes sr ON sr.id = fdr.recipe_id
          WHERE fdr.dish_id = fd.id
            AND (fdr.visibility = 'public' AND fdr.approval_status = 'approved'
                 OR fdr.submitted_by = auth.uid())
        ) r
      ), '[]'::jsonb) AS recipes
    FROM public.festival_dishes fd
    WHERE fd.festival_id = (v_fest->>'id')::uuid
  ) d;
  RETURN v_fest || jsonb_build_object('dishes', v_dishes);
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_festival_detail(text) TO anon, authenticated;

DROP FUNCTION IF EXISTS public.admin_get_festivals();
CREATE FUNCTION public.admin_get_festivals()
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(jsonb_agg(row_to_json(f) ORDER BY f.sort_order, f.name), '[]'::jsonb)
  FROM (
    SELECT *,
      (SELECT count(*)::int FROM festival_dishes d WHERE d.festival_id = festivals.id) AS dish_count
    FROM public.festivals ORDER BY sort_order, name
  ) f;
$$;
GRANT EXECUTE ON FUNCTION public.admin_get_festivals() TO authenticated;

DROP FUNCTION IF EXISTS public.cleanup_recipe_ocr(text);
CREATE FUNCTION public.cleanup_recipe_ocr(p_text text)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE v_lines text[]; v_out text; v_line text;
BEGIN
  IF p_text IS NULL OR btrim(p_text) = '' THEN
    RETURN jsonb_build_object('cleaned', '', 'hints', '[]'::jsonb);
  END IF;
  v_lines := regexp_split_to_array(replace(p_text, E'\r', ''), E'\n');
  v_out := '';
  FOREACH v_line IN ARRAY v_lines LOOP
    v_line := regexp_replace(v_line, '[^\x20-\x7E\u00A0-\u024F\u1E00-\u1EFF]', ' ', 'g');
    v_line := regexp_replace(v_line, '\s{2,}', ' ', 'g');
    v_line := btrim(v_line);
    IF length(v_line) > 0 THEN
      v_out := v_out || v_line || E'\n';
    END IF;
  END LOOP;
  RETURN jsonb_build_object(
    'cleaned', btrim(v_out),
    'hints', jsonb_build_array('Normalized spacing and line breaks. Review fractions and headings before parsing.')
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.cleanup_recipe_ocr(text) TO anon, authenticated;

SELECT 'Phase 36 festivals hotfix ready' AS status;
