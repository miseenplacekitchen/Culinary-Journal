-- PF-02: Pantry unknown ingredient/unit submission loop
-- PF-08: Recipe suggestions from pantry names (v1 name matching)

-- Ensure table exists (live DB may predate admin_rpcs.sql)
CREATE TABLE IF NOT EXISTS public.pending_ingredients (
  id              bigserial PRIMARY KEY,
  ingredient_name text NOT NULL,
  submitted_by    uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  recipe_id       uuid,
  status          text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','added','dismissed')),
  created_at      timestamptz NOT NULL DEFAULT NOW()
);

-- Live fix: submitted_by was sometimes created as text — policies need uuid
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
     WHERE table_schema = 'public'
       AND table_name = 'pending_ingredients'
       AND column_name = 'submitted_by'
       AND udt_name = 'text'
  ) THEN
    UPDATE public.pending_ingredients
       SET submitted_by = NULL
     WHERE submitted_by IS NOT NULL
       AND trim(submitted_by) !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';
    ALTER TABLE public.pending_ingredients
      ALTER COLUMN submitted_by TYPE uuid
      USING NULLIF(trim(submitted_by::text), '')::uuid;
  END IF;
END $$;

ALTER TABLE public.pending_ingredients
  ADD COLUMN IF NOT EXISTS unit_name text,
  ADD COLUMN IF NOT EXISTS submission_type text NOT NULL DEFAULT 'ingredient',
  ADD COLUMN IF NOT EXISTS category text,
  ADD COLUMN IF NOT EXISTS notes text;

-- Users may submit pending items (admins manage via existing policy)
DROP POLICY IF EXISTS "users submit pending ingredients" ON public.pending_ingredients;
CREATE POLICY "users submit pending ingredients" ON public.pending_ingredients
  FOR INSERT TO authenticated
  WITH CHECK (submitted_by::uuid = auth.uid());

DROP FUNCTION IF EXISTS public.submit_pending_ingredient(text, text, text, text, text);
CREATE OR REPLACE FUNCTION public.submit_pending_ingredient(
  p_name     text,
  p_type     text DEFAULT 'ingredient',
  p_category text DEFAULT NULL,
  p_unit     text DEFAULT NULL,
  p_notes    text DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id   bigint;
  v_name text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  v_name := trim(COALESCE(p_name, ''));
  IF v_name = '' THEN RAISE EXCEPTION 'name_required'; END IF;
  IF p_type NOT IN ('ingredient', 'unit') THEN RAISE EXCEPTION 'invalid_type'; END IF;
  IF EXISTS (
    SELECT 1 FROM public.pending_ingredients
     WHERE submitted_by::uuid = auth.uid()
       AND status = 'pending'
       AND lower(ingredient_name) = lower(v_name)
       AND COALESCE(submission_type, 'ingredient') = p_type
  ) THEN
    RAISE EXCEPTION 'already_pending';
  END IF;
  INSERT INTO public.pending_ingredients (
    ingredient_name, submitted_by, submission_type, category, unit_name, notes, status
  ) VALUES (
    v_name, auth.uid(), p_type, p_category, p_unit, p_notes, 'pending'
  )
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.submit_pending_ingredient(text, text, text, text, text) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_get_pending_ingredients();
CREATE OR REPLACE FUNCTION public.admin_get_pending_ingredients()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  RETURN COALESCE(
    (SELECT jsonb_agg(p ORDER BY p.created_at ASC) FROM (
      SELECT pi.id,
             pi.ingredient_name,
             pi.status,
             pi.created_at,
             COALESCE(pi.submission_type, 'ingredient') AS submission_type,
             pi.unit_name,
             pi.category,
             pi.notes,
             prof.username AS submitted_by_username
        FROM public.pending_ingredients pi
        LEFT JOIN public.profiles prof ON prof.id = pi.submitted_by::uuid
       WHERE pi.status = 'pending'
    ) p),
    '[]'::jsonb
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_get_pending_ingredients() TO authenticated;

DROP FUNCTION IF EXISTS public.admin_resolve_pending_ingredient(int, text);
CREATE OR REPLACE FUNCTION public.admin_resolve_pending_ingredient(p_id int, p_action text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_row public.pending_ingredients%ROWTYPE;
  v_msg text;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_action NOT IN ('added', 'dismissed') THEN RAISE EXCEPTION 'invalid_action'; END IF;
  SELECT * INTO v_row FROM public.pending_ingredients WHERE id = p_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'not_found'; END IF;
  UPDATE public.pending_ingredients SET status = p_action WHERE id = p_id;
  IF v_row.submitted_by IS NOT NULL THEN
    v_msg := CASE
      WHEN p_action = 'added' THEN
        'Your ' || COALESCE(v_row.submission_type, 'ingredient') || ' submission "' ||
        v_row.ingredient_name || '" was added to the database.'
      ELSE
        'Your submission "' || v_row.ingredient_name || '" was reviewed. Contact us if you have questions.'
    END;
    INSERT INTO public.notifications (user_id, type, message)
    VALUES (
      v_row.submitted_by,
      CASE WHEN p_action = 'added' THEN 'ingredient_approved' ELSE 'ingredient_dismissed' END,
      v_msg
    );
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_resolve_pending_ingredient(int, text) TO authenticated;

-- PF-08 v1: name-based recipe matching for pantry items
DROP FUNCTION IF EXISTS public.search_recipes_by_pantry_names(text[], int);
CREATE OR REPLACE FUNCTION public.search_recipes_by_pantry_names(
  p_names text[],
  p_limit int DEFAULT 24
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_names IS NULL OR array_length(p_names, 1) IS NULL THEN
    RETURN '[]'::jsonb;
  END IF;
  RETURN COALESCE(
    (SELECT jsonb_agg(row_to_json(t)::jsonb) FROM (
      SELECT
        sr.id,
        sr.recipe_name,
        sr.category,
        sr.image_url,
        (
          SELECT jsonb_agg(DISTINCT pn)
          FROM unnest(p_names) AS pn
          WHERE EXISTS (
            SELECT 1
              FROM jsonb_array_elements(COALESCE(sr.ingredients, '[]'::jsonb)) AS sec,
                   jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) AS item
             WHERE lower(trim(COALESCE(item->>'ingredient', item->>'name', ''))) <> ''
               AND (
                 lower(trim(COALESCE(item->>'ingredient', item->>'name', '')))
                   LIKE '%' || lower(trim(pn)) || '%'
                 OR lower(trim(pn))
                   LIKE '%' || lower(trim(COALESCE(item->>'ingredient', item->>'name', ''))) || '%'
               )
          )
        ) AS matched_items,
        (
          SELECT COUNT(DISTINCT pn)::int
          FROM unnest(p_names) AS pn
          WHERE EXISTS (
            SELECT 1
              FROM jsonb_array_elements(COALESCE(sr.ingredients, '[]'::jsonb)) AS sec,
                   jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) AS item
             WHERE lower(trim(COALESCE(item->>'ingredient', item->>'name', ''))) <> ''
               AND (
                 lower(trim(COALESCE(item->>'ingredient', item->>'name', '')))
                   LIKE '%' || lower(trim(pn)) || '%'
                 OR lower(trim(pn))
                   LIKE '%' || lower(trim(COALESCE(item->>'ingredient', item->>'name', ''))) || '%'
               )
          )
        ) AS match_count
      FROM public.submitted_recipes sr
      WHERE sr.status = 'approved'
        AND sr.visibility = 'Public'
        AND sr.ingredients IS NOT NULL
        AND EXISTS (
          SELECT 1
            FROM unnest(p_names) AS pn
           WHERE EXISTS (
             SELECT 1
               FROM jsonb_array_elements(COALESCE(sr.ingredients, '[]'::jsonb)) AS sec,
                    jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) AS item
              WHERE lower(trim(COALESCE(item->>'ingredient', item->>'name', ''))) <> ''
                AND (
                  lower(trim(COALESCE(item->>'ingredient', item->>'name', '')))
                    LIKE '%' || lower(trim(pn)) || '%'
                  OR lower(trim(pn))
                    LIKE '%' || lower(trim(COALESCE(item->>'ingredient', item->>'name', ''))) || '%'
                )
           )
        )
      ORDER BY match_count DESC, sr.recipe_name
      LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 24), 50))
    ) t),
    '[]'::jsonb
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.search_recipes_by_pantry_names(text[], int) TO anon, authenticated;

SELECT pg_notify('pgrst', 'reload schema');
SELECT 'fix-pf02-pf08.sql complete' AS status;
