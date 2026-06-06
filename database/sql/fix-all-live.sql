-- ══════════════════════════════════════════════════════════════════════
-- THE CULINARY JOURNAL — fix-all-live.sql
-- One script for Supabase SQL Editor. Safe to re-run.
--
-- What it does:
--   • Adds missing columns (IF NOT EXISTS only — no data loss)
--   • Removes stale duplicate function signatures
--   • Replaces broken/missing RPCs with canonical versions
--
-- What it does NOT do:
--   • Drop tables, truncate data, or run 00-drop-functions.sql
-- ══════════════════════════════════════════════════════════════════════


-- ── 1. Remove stale duplicate signatures ─────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_recipes(text);
DROP FUNCTION IF EXISTS public.admin_bulk_update_field(uuid[], text, text);

DO $$ DECLARE r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN ('admin_deactivate_user', 'admin_bulk_update_field', 'admin_get_recipes')
      AND pg_get_function_identity_arguments(p.oid) NOT IN (
        'p_user_id uuid, p_type text, p_days integer, p_reason text',
        'p_ids integer[], p_field text, p_value text',
        'p_status text, p_search text, p_category text, p_limit integer, p_offset integer'
      )
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig;
  END LOOP;
END $$;

-- ── 2. Safe column additions ───────────────────────────────────────
ALTER TABLE public.submitted_recipes
  ADD COLUMN IF NOT EXISTS is_featured            BOOLEAN   NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS featured_at            TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS is_recipe_of_week      BOOLEAN   NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS recipe_of_week_at      TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS recipe_of_week_expires TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS native_title           TEXT,
  ADD COLUMN IF NOT EXISTS introduction           TEXT,
  ADD COLUMN IF NOT EXISTS cooking_notes          TEXT,
  ADD COLUMN IF NOT EXISTS photo_url              TEXT;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='deactivation_type') THEN
    ALTER TABLE public.profiles ADD COLUMN deactivation_type text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='deactivation_expires_at') THEN
    ALTER TABLE public.profiles ADD COLUMN deactivation_expires_at timestamptz;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='deactivation_reason') THEN
    ALTER TABLE public.profiles ADD COLUMN deactivation_reason text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='profiles' AND column_name='avatar_url') THEN
    ALTER TABLE public.profiles ADD COLUMN avatar_url text;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='ingredients' AND column_name='extra_fields') THEN
    ALTER TABLE public.ingredients ADD COLUMN extra_fields jsonb DEFAULT '{}'::jsonb;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND is_admin = true
  );
$$;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- ── Profile RPCs ──
DO $$ DECLARE r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'get_my_profile'
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig;
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.get_my_profile()
RETURNS TABLE (
  id                  uuid,
  full_name           text,
  username            text,
  email               text,
  is_active           boolean,
  is_admin            boolean,
  theme_preference    text,
  dietary_preferences text[],
  allergies           text[],
  health_conditions   text[],
  cooking_style       text,
  font_size           text,
  avatar_url          text,
  created_at          timestamptz,
  last_seen           timestamptz
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  RETURN QUERY
    SELECT p.id,
           p.full_name::text,
           p.username::text,
           u.email::text,
           p.is_active,
           p.is_admin,
           p.theme_preference::text,
           COALESCE(p.dietary_preferences, '{}')::text[],
           COALESCE(p.allergies, '{}')::text[],
           COALESCE(p.health_conditions, '{}')::text[],
           COALESCE(p.cooking_style, '')::text,
           COALESCE(p.font_size, 'medium')::text,
           p.avatar_url::text,
           u.created_at,
           p.last_seen
    FROM public.profiles p
    JOIN auth.users u ON u.id = p.id
    WHERE p.id = auth.uid();
END;
$$;

CREATE OR REPLACE FUNCTION public.update_avatar_url(p_url text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  UPDATE public.profiles SET avatar_url = p_url, last_seen = now() WHERE id = auth.uid();
END;
$$;

UPDATE public.profiles
   SET username = 'miseenplacekitchen',
       full_name = 'miseenplacekitchen'
 WHERE email = 'miseenplacekitchen.official@gmail.com';

-- ── Recipe admin RPCs ──
DROP FUNCTION IF EXISTS public.admin_get_recipes(text, text, text, integer, integer);
CREATE OR REPLACE FUNCTION public.admin_get_recipes(
  p_status   text DEFAULT NULL,
  p_search   text DEFAULT NULL,
  p_category text DEFAULT NULL,
  p_limit    integer DEFAULT 50,
  p_offset   integer DEFAULT 0
)
RETURNS SETOF json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  RETURN QUERY
    SELECT json_build_object(
      'id',                    r.id,
      'recipe_name',           r.recipe_name,
      'native_title',          r.native_title,
      'category',              r.category,
      'spice_level',           r.spice_level,
      'origin_continent',      r.origin_continent,
      'origin_country',        r.origin_country,
      'origin_state',          r.origin_state,
      'status',                r.status,
      'submitted_at',          r.submitted_at,
      'reviewed_at',           r.reviewed_at,
      'reviewer_notes',        r.reviewer_notes,
      'introduction',          r.introduction,
      'cooking_notes',         r.cooking_notes,
      'servings',              r.servings,
      'image_url',             r.image_url,
      'username',              p.username,
      'full_name',             p.full_name,
      'featured',              COALESCE(r.is_featured, false),
      'is_featured',           COALESCE(r.is_featured, false),
      'recipe_of_week',        COALESCE(r.is_recipe_of_week, false),
      'is_recipe_of_week',     COALESCE(r.is_recipe_of_week, false),
      'recipe_of_week_at',     r.recipe_of_week_at,
      'recipe_of_week_expires', r.recipe_of_week_expires
    )
    FROM public.submitted_recipes r
    LEFT JOIN public.profiles p ON p.id = r.user_id
    WHERE (p_status IS NULL OR r.status = p_status)
      AND (p_search IS NULL OR r.recipe_name ILIKE '%' || p_search || '%'
           OR COALESCE(p.username, '') ILIKE '%' || p_search || '%')
      AND (p_category IS NULL OR r.category = p_category)
    ORDER BY r.submitted_at DESC
    LIMIT p_limit OFFSET p_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_get_recipes(text, text, text, integer, integer) TO authenticated;

-- ── Ingredient sort RPC ──
DROP FUNCTION IF EXISTS public.admin_get_ingredients(text, text, int, int, text, text);
CREATE OR REPLACE FUNCTION public.admin_get_ingredients(
  p_search text DEFAULT NULL, p_category text DEFAULT NULL,
  p_limit int DEFAULT 50, p_offset int DEFAULT 0,
  p_sort_col text DEFAULT 'Ingredient Name', p_sort_dir text DEFAULT 'asc'
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_rows jsonb;
  v_col  text;
  v_dir  text;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  v_col := CASE WHEN p_sort_col IN (
      'ID','Ingredient Name','Also Known As','Category','Sub Category',
      'Standard Qty','Standard Weight (g or ml)','Unit','Liquid (Yes/No)',
      'CJ Recommended Brand','Allergen','Vegan (Yes/No)','Vegetarian (Yes/No)','Notes')
    THEN p_sort_col ELSE 'Ingredient Name' END;
  v_dir := CASE WHEN lower(p_sort_dir) = 'desc' THEN 'DESC' ELSE 'ASC' END;
  IF v_col = 'ID' THEN
    EXECUTE format(
      'SELECT jsonb_agg(to_jsonb(i)) FROM (
         SELECT * FROM ingredients
         WHERE ($1 IS NULL OR "Ingredient Name" ILIKE ''%%''||$1||''%%'')
           AND ($2 IS NULL OR "Category" = $2)
         ORDER BY "ID" %s
         LIMIT $3 OFFSET $4
       ) i', v_dir)
    INTO v_rows USING p_search, p_category, p_limit, p_offset;
  ELSIF v_col = 'Standard Weight (g or ml)' THEN
    EXECUTE format(
      'SELECT jsonb_agg(to_jsonb(i)) FROM (
         SELECT * FROM ingredients
         WHERE ($1 IS NULL OR "Ingredient Name" ILIKE ''%%''||$1||''%%'')
           AND ($2 IS NULL OR "Category" = $2)
         ORDER BY NULLIF(regexp_replace("Standard Weight (g or ml)", ''[^0-9.\-]'', '''', ''g''), '''')::numeric %s NULLS LAST
         LIMIT $3 OFFSET $4
       ) i', v_dir)
    INTO v_rows USING p_search, p_category, p_limit, p_offset;
  ELSE
    EXECUTE format(
      'SELECT jsonb_agg(to_jsonb(i)) FROM (
         SELECT * FROM ingredients
         WHERE ($1 IS NULL OR "Ingredient Name" ILIKE ''%%''||$1||''%%'')
           AND ($2 IS NULL OR "Category" = $2)
         ORDER BY %I %s NULLS LAST
         LIMIT $3 OFFSET $4
       ) i', v_col, v_dir)
    INTO v_rows USING p_search, p_category, p_limit, p_offset;
  END IF;
  RETURN COALESCE(v_rows, '[]'::jsonb);
END; $$;

GRANT EXECUTE ON FUNCTION public.admin_get_ingredients(text, text, int, int, text, text) TO authenticated;

-- ── CSV import RPC ──
DROP FUNCTION IF EXISTS public.admin_bulk_upsert_ingredients(jsonb);
CREATE OR REPLACE FUNCTION public.admin_bulk_upsert_ingredients(p_rows jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  r           jsonb;
  v_name      text;
  v_csv_id    int;
  v_target_id int;
  v_name_id   int;
  v_inserted  int := 0;
  v_updated   int := 0;
  v_skipped   int := 0;
  v_extra     jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;

  FOR r IN SELECT * FROM jsonb_array_elements(p_rows) LOOP
    v_name := NULLIF(TRIM(r->>'Ingredient Name'), '');
    v_csv_id := NULL;
    v_target_id := NULL;
    v_name_id := NULL;

    IF v_name IS NULL THEN
      v_skipped := v_skipped + 1;
      CONTINUE;
    END IF;

    IF (r->>'ID') IS NOT NULL AND BTRIM(r->>'ID') ~ '^\d+$' THEN
      v_csv_id := BTRIM(r->>'ID')::int;
    END IF;

    SELECT "ID" INTO v_name_id
    FROM ingredients
    WHERE LOWER(TRIM("Ingredient Name")) = LOWER(v_name)
    LIMIT 1;

    IF v_name_id IS NOT NULL THEN
      v_target_id := v_name_id;
    ELSIF v_csv_id IS NOT NULL THEN
      SELECT "ID" INTO v_target_id FROM ingredients WHERE "ID" = v_csv_id;
      IF v_target_id IS NOT NULL AND EXISTS (
        SELECT 1 FROM ingredients
        WHERE LOWER(TRIM("Ingredient Name")) = LOWER(v_name)
          AND "ID" <> v_target_id
      ) THEN
        SELECT "ID" INTO v_target_id
        FROM ingredients
        WHERE LOWER(TRIM("Ingredient Name")) = LOWER(v_name)
        LIMIT 1;
      END IF;
    END IF;

    v_extra := r->'extra_fields';
    IF v_extra IS NULL OR v_extra = 'null'::jsonb THEN
      v_extra := NULL;
    END IF;

    IF v_target_id IS NOT NULL THEN
      UPDATE ingredients SET
        "Ingredient Name"          = v_name,
        "Also Known As"            = COALESCE(NULLIF(r->>'Also Known As',''),       "Also Known As"),
        "Category"                 = COALESCE(NULLIF(r->>'Category',''),            "Category"),
        "Sub Category"             = COALESCE(NULLIF(r->>'Sub Category',''),        "Sub Category"),
        "Standard Qty"             = COALESCE(NULLIF(r->>'Standard Qty',''),        "Standard Qty"),
        "Standard Weight (g or ml)"= COALESCE(
          CASE WHEN r->>'Standard Weight (g or ml)' ~ '^\d+(\.\d+)?$'
               THEN (r->>'Standard Weight (g or ml)')::float8 END,
          "Standard Weight (g or ml)"),
        "Unit"                     = COALESCE(NULLIF(r->>'Unit',''),                "Unit"),
        "Liquid (Yes/No)"          = COALESCE(NULLIF(r->>'Liquid (Yes/No)',''),     "Liquid (Yes/No)"),
        "CJ Recommended Brand"     = COALESCE(NULLIF(r->>'CJ Recommended Brand',''),"CJ Recommended Brand"),
        "Allergen"                 = COALESCE(NULLIF(r->>'Allergen',''),            "Allergen"),
        "Vegan (Yes/No)"           = COALESCE(NULLIF(r->>'Vegan (Yes/No)',''),     "Vegan (Yes/No)"),
        "Vegetarian (Yes/No)"      = COALESCE(NULLIF(r->>'Vegetarian (Yes/No)',''),"Vegetarian (Yes/No)"),
        "Notes"                    = COALESCE(NULLIF(r->>'Notes',''),               "Notes"),
        extra_fields               = CASE
          WHEN v_extra IS NOT NULL THEN COALESCE(extra_fields, '{}'::jsonb) || v_extra
          ELSE extra_fields
        END
      WHERE "ID" = v_target_id;
      v_updated := v_updated + 1;
    ELSE
      INSERT INTO ingredients (
        "Ingredient Name","Also Known As","Category","Sub Category","Standard Qty",
        "Standard Weight (g or ml)","Unit","Liquid (Yes/No)","CJ Recommended Brand",
        "Allergen","Vegan (Yes/No)","Vegetarian (Yes/No)","Notes","extra_fields"
      ) VALUES (
        v_name,
        NULLIF(r->>'Also Known As',''),
        NULLIF(r->>'Category',''),
        NULLIF(r->>'Sub Category',''),
        NULLIF(r->>'Standard Qty',''),
        CASE WHEN r->>'Standard Weight (g or ml)' ~ '^\d+(\.\d+)?$'
             THEN (r->>'Standard Weight (g or ml)')::float8 END,
        NULLIF(r->>'Unit',''),
        NULLIF(r->>'Liquid (Yes/No)',''),
        NULLIF(r->>'CJ Recommended Brand',''),
        NULLIF(r->>'Allergen',''),
        NULLIF(r->>'Vegan (Yes/No)',''),
        NULLIF(r->>'Vegetarian (Yes/No)',''),
        NULLIF(r->>'Notes',''),
        COALESCE(v_extra, '{}'::jsonb)
      );
      v_inserted := v_inserted + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('inserted', v_inserted, 'updated', v_updated, 'skipped', v_skipped);
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_bulk_upsert_ingredients(jsonb) TO authenticated;

-- ── CJ-006 recipe pipeline ──
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS cooking_style text;

ALTER TABLE public.submitted_recipes
  ADD COLUMN IF NOT EXISTS additional_time_minutes integer,
  ADD COLUMN IF NOT EXISTS servings_unit            text DEFAULT 'people',
  ADD COLUMN IF NOT EXISTS shelf_life_value         text,
  ADD COLUMN IF NOT EXISTS shelf_life_unit          text DEFAULT 'months',
  ADD COLUMN IF NOT EXISTS shelf_life_storage       text,
  ADD COLUMN IF NOT EXISTS after_open_value         text,
  ADD COLUMN IF NOT EXISTS after_open_unit          text DEFAULT 'weeks',
  ADD COLUMN IF NOT EXISTS unknown_ingredients      text[];

DROP POLICY IF EXISTS "Users can update own submissions" ON public.submitted_recipes;
CREATE POLICY "Users can update own submissions"
  ON public.submitted_recipes FOR UPDATE TO authenticated
  USING (auth.uid() = user_id::uuid AND status IN ('pending', 'rejected'))
  WITH CHECK (auth.uid() = user_id::uuid AND status = 'pending');

DROP FUNCTION IF EXISTS public.get_public_recipe(uuid);

CREATE OR REPLACE FUNCTION public.get_public_recipe(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_row   public.submitted_recipes%ROWTYPE;
  v_user  text;
  v_uid   uuid;
BEGIN
  IF p_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT * INTO v_row
    FROM public.submitted_recipes
   WHERE id = p_id;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  SELECT username INTO v_user
    FROM public.profiles
   WHERE id = v_row.user_id;

  v_uid := auth.uid();

  IF is_admin()
     OR (v_uid IS NOT NULL AND v_row.user_id = v_uid)
     OR (v_row.status = 'approved' AND v_row.visibility = 'Public')
  THEN
    RETURN to_jsonb(v_row) || jsonb_build_object('username', v_user);
  END IF;

  RETURN NULL;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_public_recipe(uuid) TO anon, authenticated;


SELECT 'fix-cj006-pipeline.sql complete' AS status;

-- ── Phase 2 batch ──
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS origin_locality text;

CREATE OR REPLACE FUNCTION public.admin_review_recipe(
  p_id uuid, p_status text, p_notes text DEFAULT ''
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id   uuid;
  v_name      text;
  v_msg       text;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_status NOT IN ('approved','rejected','pending') THEN
    RAISE EXCEPTION 'Invalid status: %', p_status;
  END IF;

  SELECT user_id, recipe_name INTO v_user_id, v_name
    FROM public.submitted_recipes WHERE id = p_id;

  UPDATE public.submitted_recipes
     SET status = p_status, reviewer_notes = p_notes, reviewed_at = now()
   WHERE id = p_id;

  IF v_user_id IS NOT NULL AND p_status IN ('approved', 'rejected') THEN
    v_msg := CASE p_status
      WHEN 'approved' THEN 'Your recipe "' || COALESCE(v_name, 'submission') || '" was approved and is now live!'
      ELSE 'Your recipe "' || COALESCE(v_name, 'submission') || '" needs updates.'
           || CASE WHEN COALESCE(p_notes, '') <> '' THEN ' ' || p_notes ELSE '' END
    END;
    INSERT INTO public.notifications (user_id, type, recipe_id, recipe_name, message)
    VALUES (
      v_user_id,
      CASE WHEN p_status = 'approved' THEN 'recipe_approved' ELSE 'recipe_rejected' END,
      p_id,
      v_name,
      v_msg
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_review_recipe(uuid, text, text) TO authenticated;


SELECT 'fix-phase2-batch.sql complete' AS status;

-- ── PF-02 / PF-08 pantry ──
CREATE TABLE IF NOT EXISTS public.pending_ingredients (
  id              bigserial PRIMARY KEY,
  ingredient_name text NOT NULL,
  submitted_by    uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  recipe_id       uuid,
  status          text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','added','dismissed')),
  created_at      timestamptz NOT NULL DEFAULT NOW()
);

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

SELECT 'fix-pf02-pf08.sql complete' AS status;

-- ── Family baby food stage ──
ALTER TABLE public.family_profiles
  ADD COLUMN IF NOT EXISTS baby_food_stage text;

DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT oid::regprocedure AS sig FROM pg_proc
           WHERE proname = 'upsert_family_profile' AND pronamespace = 'public'::regnamespace
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.upsert_family_profile(
  p_id                uuid    DEFAULT NULL,
  p_name              text    DEFAULT '',
  p_relationship      text    DEFAULT 'guest',
  p_age_group         text    DEFAULT 'adult',
  p_allergies         jsonb   DEFAULT '[]',
  p_spice_preference  text    DEFAULT 'medium',
  p_dietary_needs     jsonb   DEFAULT '[]',
  p_health_conditions text[]  DEFAULT '{}',
  p_notes             text    DEFAULT '',
  p_baby_food_stage   text    DEFAULT NULL
)
RETURNS public.family_profiles
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE result public.family_profiles;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF p_id IS NULL THEN
    INSERT INTO public.family_profiles (
      user_id, name, relationship, age_group, allergies, spice_preference,
      dietary_needs, health_conditions, notes, baby_food_stage
    ) VALUES (
      auth.uid(), p_name, p_relationship, p_age_group, p_allergies, p_spice_preference,
      p_dietary_needs, p_health_conditions, p_notes, p_baby_food_stage
    ) RETURNING * INTO result;
  ELSE
    UPDATE public.family_profiles SET
      name = p_name, relationship = p_relationship, age_group = p_age_group,
      allergies = p_allergies, spice_preference = p_spice_preference,
      dietary_needs = p_dietary_needs, health_conditions = p_health_conditions,
      notes = p_notes, baby_food_stage = p_baby_food_stage
    WHERE id = p_id AND user_id = auth.uid()
    RETURNING * INTO result;
  END IF;
  RETURN result;
END;
$$;
GRANT EXECUTE ON FUNCTION public.upsert_family_profile(
  uuid, text, text, text, jsonb, text, jsonb, text[], text, text
) TO authenticated;

SELECT 'fix-family-food-stage.sql complete' AS status;

-- ── Admin stats, review & bulk field ──
CREATE OR REPLACE FUNCTION public.admin_get_stats()
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE result json;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  SELECT json_build_object(
    'pending',  COUNT(*) FILTER (WHERE status = 'pending'),
    'approved', COUNT(*) FILTER (WHERE status = 'approved'),
    'rejected', COUNT(*) FILTER (WHERE status = 'rejected'),
    'featured', COUNT(*) FILTER (WHERE is_featured = true),
    'total',    COUNT(*)
  ) INTO result FROM public.submitted_recipes;
  RETURN result;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_get_stats() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_review_recipe(
  p_id uuid, p_status text, p_notes text DEFAULT ''
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_name    text;
  v_msg     text;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_status NOT IN ('approved','rejected','pending') THEN
    RAISE EXCEPTION 'Invalid status: %', p_status;
  END IF;
  SELECT user_id, recipe_name INTO v_user_id, v_name
    FROM public.submitted_recipes WHERE id = p_id;
  UPDATE public.submitted_recipes
     SET status = p_status, reviewer_notes = p_notes, reviewed_at = now()
   WHERE id = p_id;
  IF v_user_id IS NOT NULL AND p_status IN ('approved', 'rejected') THEN
    v_msg := CASE p_status
      WHEN 'approved' THEN 'Your recipe "' || COALESCE(v_name, 'submission') || '" was approved and is now live!'
      ELSE 'Your recipe "' || COALESCE(v_name, 'submission') || '" needs updates.'
           || CASE WHEN COALESCE(p_notes, '') <> '' THEN ' ' || p_notes ELSE '' END
    END;
    INSERT INTO public.notifications (user_id, type, recipe_id, recipe_name, message)
    VALUES (
      v_user_id,
      CASE WHEN p_status = 'approved' THEN 'recipe_approved' ELSE 'recipe_rejected' END,
      p_id, v_name, v_msg
    );
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_review_recipe(uuid, text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_bulk_update_field(
  p_ids int[], p_field text, p_value text
)
RETURNS int
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  allowed text[] := ARRAY['Category','Sub Category','Vegan (Yes/No)','Vegetarian (Yes/No)',
                          'Allergen','Liquid (Yes/No)','CJ Recommended Brand','Unit','Notes'];
  affected int;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF NOT (p_field = ANY(allowed)) THEN RAISE EXCEPTION 'Field not allowed: %', p_field; END IF;
  EXECUTE format('UPDATE public.ingredients SET %I = $1 WHERE "ID" = ANY($2)', p_field)
    USING p_value, p_ids;
  GET DIAGNOSTICS affected = ROW_COUNT;
  RETURN affected;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_bulk_update_field(int[], text, text) TO authenticated;

-- ── User deactivation ──
CREATE OR REPLACE FUNCTION public.deactivate_my_account()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  UPDATE public.profiles SET is_active = false WHERE id = auth.uid();
END;
$$;
GRANT EXECUTE ON FUNCTION public.deactivate_my_account() TO authenticated;

DROP FUNCTION IF EXISTS public.admin_deactivate_user(uuid, text, integer, text);
CREATE OR REPLACE FUNCTION public.admin_deactivate_user(
  p_user_id uuid, p_type text, p_days int DEFAULT NULL, p_reason text DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.profiles SET
    is_active               = false,
    deactivation_type       = p_type,
    deactivation_expires_at = CASE
      WHEN p_type = 'temporary' AND p_days IS NOT NULL
      THEN now() + (p_days || ' days')::interval ELSE NULL END,
    deactivation_reason     = p_reason
  WHERE id = p_user_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_deactivate_user(uuid, text, integer, text) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_reactivate_user(uuid);
CREATE OR REPLACE FUNCTION public.admin_reactivate_user(p_user_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.profiles SET
    is_active = true, deactivation_type = NULL,
    deactivation_expires_at = NULL, deactivation_reason = NULL
  WHERE id = p_user_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_reactivate_user(uuid) TO authenticated;

-- ── Diary & culinary delete ──
-- Diary + culinary life delete (returns json so the UI can confirm success)
GRANT SELECT, INSERT, UPDATE, DELETE ON public.diary_entries TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.cooking_events TO authenticated;

DROP POLICY IF EXISTS "Users manage own diary" ON public.diary_entries;
CREATE POLICY "Users manage own diary"
  ON public.diary_entries FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users manage own cooking events" ON public.cooking_events;
CREATE POLICY "Users manage own cooking events"
  ON public.cooking_events FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DO $$ DECLARE r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname IN ('delete_diary_entry', 'delete_cooking_event')
  LOOP
    EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig;
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.delete_diary_entry(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_count int;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF p_id IS NULL THEN RAISE EXCEPTION 'missing_id'; END IF;
  DELETE FROM public.diary_entries WHERE id = p_id AND user_id = auth.uid();
  GET DIAGNOSTICS v_count = ROW_COUNT;
  IF v_count = 0 THEN RAISE EXCEPTION 'diary_entry_not_found'; END IF;
  RETURN jsonb_build_object('deleted', v_count);
END;
$$;
REVOKE ALL ON FUNCTION public.delete_diary_entry(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_diary_entry(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.delete_cooking_event(p_id uuid)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_count int;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF p_id IS NULL THEN RAISE EXCEPTION 'missing_id'; END IF;
  DELETE FROM public.cooking_events WHERE id = p_id AND user_id = auth.uid();
  GET DIAGNOSTICS v_count = ROW_COUNT;
  IF v_count = 0 THEN RAISE EXCEPTION 'cooking_event_not_found'; END IF;
  RETURN jsonb_build_object('deleted', v_count);
END;
$$;
REVOKE ALL ON FUNCTION public.delete_cooking_event(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_cooking_event(uuid) TO authenticated;

-- ── Reload PostgREST schema cache ──────────────────────────────────
SELECT pg_notify('pgrst', 'reload schema');

SELECT 'fix-all-live.sql complete' AS status;
