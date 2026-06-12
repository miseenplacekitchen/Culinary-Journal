-- =============================================================================
-- THE CULINARY JOURNAL — COPY THIS ENTIRE FILE INTO SUPABASE SQL EDITOR
-- 1. Open this file in Cursor or Notepad
-- 2. Ctrl+A (select all) → Ctrl+C (copy)
-- 3. Supabase → SQL Editor → New query → Ctrl+V → Run
-- Safe to re-run.
-- =============================================================================


-- ########## BEGIN: fix-all-live.sql ##########
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

-- ── Signup: is_username_taken (login.html sends uname) ─────────────
DROP FUNCTION IF EXISTS public.is_username_taken(text);
CREATE OR REPLACE FUNCTION public.is_username_taken(uname text)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE LOWER(username) = LOWER(TRIM(uname))
  );
END;
$$;
REVOKE ALL ON FUNCTION public.is_username_taken(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_username_taken(text) TO anon, authenticated;

-- ── Tier 2 surfaces: notifications + dietary-card guest links ────
CREATE TABLE IF NOT EXISTS public.notifications (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  type        text NOT NULL,
  recipe_id   uuid,
  recipe_name text,
  message     text,
  read        boolean DEFAULT false,
  created_at  timestamptz DEFAULT now()
);
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users see own notifications" ON public.notifications;
CREATE POLICY "Users see own notifications"
  ON public.notifications FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT p.oid::regprocedure AS sig FROM pg_proc p
           JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = 'public'
             AND p.proname IN (
               'get_notification_count',
               'get_my_notifications',
               'mark_notification_read',
               'mark_all_notifications_read',
               'get_guest_card',
               'submit_guest_dietary'
             )
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.get_notification_count()
RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RETURN 0; END IF;
  RETURN (SELECT COUNT(*) FROM public.notifications
          WHERE user_id = auth.uid() AND read = false);
END; $$;
GRANT EXECUTE ON FUNCTION public.get_notification_count() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_my_notifications()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  RETURN COALESCE(
    (SELECT jsonb_agg(n ORDER BY n.created_at DESC)
     FROM (SELECT * FROM public.notifications WHERE user_id = auth.uid()
           ORDER BY created_at DESC LIMIT 50) n),
    '[]'::jsonb
  );
END; $$;
GRANT EXECUTE ON FUNCTION public.get_my_notifications() TO authenticated;

CREATE OR REPLACE FUNCTION public.mark_notification_read(p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  UPDATE public.notifications SET read = true WHERE id = p_id AND user_id = auth.uid();
END; $$;
GRANT EXECUTE ON FUNCTION public.mark_notification_read(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.mark_all_notifications_read()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  UPDATE public.notifications SET read = true WHERE user_id = auth.uid() AND read = false;
END; $$;
GRANT EXECUTE ON FUNCTION public.mark_all_notifications_read() TO authenticated;

CREATE TABLE IF NOT EXISTS public.events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  event_type text,
  event_date date,
  venue_name text,
  notes text,
  layout jsonb NOT NULL DEFAULT '{"tables":[]}',
  created_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW()
);
ALTER TABLE public.events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users manage own events" ON public.events;
CREATE POLICY "users manage own events" ON public.events FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

CREATE TABLE IF NOT EXISTS public.event_guests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id uuid NOT NULL REFERENCES public.events(id) ON DELETE CASCADE,
  name text NOT NULL,
  dietary_requirements jsonb NOT NULL DEFAULT '[]',
  dietary_submitted boolean DEFAULT false,
  dietary_submitted_at timestamptz,
  rsvp_status text DEFAULT 'pending',
  group_name text,
  plus_one boolean NOT NULL DEFAULT false,
  plus_one_name text,
  seat text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT NOW()
);
ALTER TABLE public.event_guests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users manage own event guests" ON public.event_guests;
CREATE POLICY "users manage own event guests" ON public.event_guests FOR ALL TO authenticated
  USING (EXISTS (SELECT 1 FROM public.events e WHERE e.id = event_id AND e.user_id = auth.uid()))
  WITH CHECK (EXISTS (SELECT 1 FROM public.events e WHERE e.id = event_id AND e.user_id = auth.uid()));

CREATE OR REPLACE FUNCTION public.get_guest_card(p_token uuid)
RETURNS TABLE (
  guest_name text, event_name text, event_date date, event_type text,
  dietary_requirements jsonb, already_submitted boolean
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN QUERY
    SELECT g.name, e.name, e.event_date, e.event_type,
           COALESCE(g.dietary_requirements, '[]'::jsonb),
           COALESCE(g.dietary_submitted, false)
    FROM public.event_guests g
    JOIN public.events e ON e.id = g.event_id
    WHERE g.id = p_token;
END; $$;
GRANT EXECUTE ON FUNCTION public.get_guest_card(uuid) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.submit_guest_dietary(p_token uuid, p_dietary jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.event_guests SET
    dietary_requirements = COALESCE(p_dietary, '[]'::jsonb),
    dietary_submitted = true,
    dietary_submitted_at = now()
  WHERE id = p_token;
  IF NOT FOUND THEN RAISE EXCEPTION 'guest_not_found'; END IF;
END; $$;
GRANT EXECUTE ON FUNCTION public.submit_guest_dietary(uuid, jsonb) TO anon, authenticated;

-- ── Reload PostgREST schema cache ──────────────────────────────────
SELECT pg_notify('pgrst', 'reload schema');

SELECT 'fix-all-live.sql complete' AS status;
-- ########## END: fix-all-live.sql ##########

-- ########## BEGIN: fix-library-unified.sql ##########
-- ══════════════════════════════════════════════════════════════════════
-- fix-library-unified.sql
-- Consolidates five *_profiles tables into library_profiles (type + details jsonb).
-- Replaces per-type RPC branching. Includes coverage + CSV bulk upsert.
-- Run after fix-library-management.sql (or standalone). Safe to re-run.
-- Legacy tables are NOT dropped — writes go to library_profiles only.
-- ══════════════════════════════════════════════════════════════════════

-- ── Unified table ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.library_profiles (
  id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_type          text        NOT NULL CHECK (profile_type IN ('ingredient','spice','tool','cut','preservation')),
  slug                  text        NOT NULL,
  name                  text        NOT NULL,
  also_known_as         text,
  local_names           jsonb       NOT NULL DEFAULT '[]'::jsonb,
  image_url             text,
  mise_image_url        text,
  image_status          text        NOT NULL DEFAULT 'missing' CHECK (image_status IN ('missing','draft','approved')),
  chefs_notes           text,
  recommended_brand     text,
  did_you_know          text,
  status                text        NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','published')),
  visibility            text        NOT NULL DEFAULT 'public' CHECK (visibility IN ('public','members','paid')),
  governed_ingredient_id integer,
  internal_notes        text,
  details               jsonb       NOT NULL DEFAULT '{}'::jsonb,
  created_by            uuid        REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (profile_type, slug)
);

CREATE INDEX IF NOT EXISTS idx_library_profiles_type_status ON public.library_profiles(profile_type, status);
CREATE INDEX IF NOT EXISTS idx_library_profiles_type_updated ON public.library_profiles(profile_type, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_library_profiles_governed ON public.library_profiles(governed_ingredient_id)
  WHERE governed_ingredient_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_library_profiles_details ON public.library_profiles USING gin (details);

DROP TRIGGER IF EXISTS library_profiles_updated_at ON public.library_profiles;
CREATE TRIGGER library_profiles_updated_at BEFORE UPDATE ON public.library_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

ALTER TABLE public.library_profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "public reads published library" ON public.library_profiles;
CREATE POLICY "public reads published library" ON public.library_profiles
  FOR SELECT TO anon, authenticated
  USING (status = 'published' AND visibility = 'public');
DROP POLICY IF EXISTS "members read library" ON public.library_profiles;
CREATE POLICY "members read library" ON public.library_profiles
  FOR SELECT TO authenticated
  USING (status = 'published' AND visibility IN ('public','members'));
DROP POLICY IF EXISTS "admin manages library" ON public.library_profiles;
CREATE POLICY "admin manages library" ON public.library_profiles
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

-- ── Ensure mise columns on legacy tables (for migration SELECT) ───────
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['ingredient','spice','tool','cut','preservation'] LOOP
    EXECUTE format(
      'ALTER TABLE public.%I_profiles ADD COLUMN IF NOT EXISTS mise_image_url text,
       ADD COLUMN IF NOT EXISTS image_status text DEFAULT ''missing''',
      t
    );
  END LOOP;
END $$;

ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS material text;
ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS capacity_notes text;
ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS heat_compatibility text;
ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS skill_level text;
ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS swap_if_missing text;
ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS care_schedule text;
ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS pairs_well_with text;
ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS best_for text;

-- ── Migrate legacy rows (preserve UUIDs) ──────────────────────────────
INSERT INTO public.library_profiles (
  id, profile_type, slug, name, also_known_as, local_names, image_url, mise_image_url, image_status,
  chefs_notes, recommended_brand, did_you_know, status, visibility, governed_ingredient_id,
  created_by, created_at, updated_at, details
)
SELECT
  ip.id, 'ingredient', ip.slug, ip.name, ip.also_known_as, COALESCE(ip.local_names, '[]'::jsonb),
  ip.image_url, ip.mise_image_url, COALESCE(ip.image_status, 'missing'),
  ip.chefs_notes, ip.recommended_brand, ip.did_you_know, ip.status, ip.visibility, ip.governed_ingredient_id,
  ip.created_by, ip.created_at, ip.updated_at,
  jsonb_strip_nulls(jsonb_build_object(
    'category', ip.category, 'subcategory', ip.subcategory, 'allergen', ip.allergen,
    'vegan', ip.vegan, 'vegetarian', ip.vegetarian, 'origin_story', ip.origin_story,
    'history', ip.history, 'cultural_use', ip.cultural_use, 'flavour_profile', ip.flavour_profile,
    'how_to_buy', ip.how_to_buy, 'how_to_store', ip.how_to_store, 'how_to_prep', ip.how_to_prep,
    'when_to_add', ip.when_to_add, 'common_mistakes', ip.common_mistakes, 'science_notes', ip.science_notes,
    'pairings', ip.pairings, 'preservation_notes', ip.preservation_notes, 'baby_notes', ip.baby_notes,
    'substitutes', ip.substitutes, 'nutrition_notes', ip.nutrition_notes, 'seasonality', ip.seasonality
  ))
FROM public.ingredient_profiles ip
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name, status = EXCLUDED.status, visibility = EXCLUDED.visibility,
  governed_ingredient_id = EXCLUDED.governed_ingredient_id,
  image_url = EXCLUDED.image_url, mise_image_url = EXCLUDED.mise_image_url, image_status = EXCLUDED.image_status,
  details = EXCLUDED.details, updated_at = now();

INSERT INTO public.library_profiles (
  id, profile_type, slug, name, also_known_as, local_names, image_url, mise_image_url, image_status,
  chefs_notes, recommended_brand, did_you_know, status, visibility,
  created_by, created_at, updated_at, details
)
SELECT
  sp.id, 'spice', sp.slug, sp.name, sp.also_known_as, COALESCE(sp.local_names, '[]'::jsonb),
  sp.image_url, sp.mise_image_url, COALESCE(sp.image_status, 'missing'),
  sp.chefs_notes, sp.recommended_brand, sp.did_you_know, sp.status, sp.visibility,
  sp.created_by, sp.created_at, sp.updated_at,
  jsonb_strip_nulls(jsonb_build_object(
    'origin_story', sp.origin_story, 'history', sp.history, 'cultural_use', sp.cultural_use,
    'flavour_wheel', sp.flavour_wheel, 'heat_level', sp.heat_level, 'whole_vs_ground', sp.whole_vs_ground,
    'how_to_toast', sp.how_to_toast, 'blends', sp.blends, 'when_to_add', sp.when_to_add,
    'science_notes', sp.science_notes, 'pairings', sp.pairings, 'substitutes', sp.substitutes
  ))
FROM public.spice_profiles sp
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, status = EXCLUDED.status, details = EXCLUDED.details, updated_at = now();

INSERT INTO public.library_profiles (
  id, profile_type, slug, name, also_known_as, local_names, image_url, mise_image_url, image_status,
  chefs_notes, recommended_brand, did_you_know, status, visibility,
  created_by, created_at, updated_at, details
)
SELECT
  tp.id, 'tool', tp.slug, tp.name, tp.also_known_as, '[]'::jsonb,
  tp.image_url, tp.mise_image_url, COALESCE(tp.image_status, 'missing'),
  tp.chefs_notes, tp.recommended_brand, tp.did_you_know, tp.status, tp.visibility,
  tp.created_by, tp.created_at, tp.updated_at,
  jsonb_strip_nulls(jsonb_build_object(
    'tool_category', tp.tool_category, 'what_its_for', tp.what_its_for, 'how_to_use', tp.how_to_use,
    'how_to_care', tp.how_to_care, 'common_mistakes', tp.common_mistakes,
    'what_to_look_for', tp.what_to_look_for, 'price_range', tp.price_range,
    'material', tp.material, 'capacity_notes', tp.capacity_notes,
    'heat_compatibility', tp.heat_compatibility, 'skill_level', tp.skill_level,
    'swap_if_missing', tp.swap_if_missing, 'care_schedule', tp.care_schedule,
    'pairs_well_with', tp.pairs_well_with, 'best_for', tp.best_for
  ))
FROM public.tool_profiles tp
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, status = EXCLUDED.status, details = EXCLUDED.details, updated_at = now();

INSERT INTO public.library_profiles (
  id, profile_type, slug, name, also_known_as, local_names, image_url, mise_image_url, image_status,
  chefs_notes, recommended_brand, did_you_know, status, visibility,
  created_by, created_at, updated_at, details
)
SELECT
  cp.id, 'cut', cp.slug, cp.name, cp.also_known_as, '[]'::jsonb,
  cp.image_url, cp.mise_image_url, COALESCE(cp.image_status, 'missing'),
  cp.chefs_notes, NULL::text, cp.did_you_know, cp.status, cp.visibility,
  cp.created_by, cp.created_at, cp.updated_at,
  jsonb_strip_nulls(jsonb_build_object(
    'international_names', cp.international_names, 'protein_type', cp.protein_type,
    'location_on_animal', cp.location_on_animal, 'characteristics', cp.characteristics,
    'how_to_clean', cp.how_to_clean, 'how_to_prep', cp.how_to_prep,
    'best_cooking_methods', cp.best_cooking_methods
  ))
FROM public.cut_profiles cp
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, status = EXCLUDED.status, details = EXCLUDED.details, updated_at = now();

INSERT INTO public.library_profiles (
  id, profile_type, slug, name, also_known_as, local_names, image_url, mise_image_url, image_status,
  chefs_notes, recommended_brand, did_you_know, status, visibility,
  created_by, created_at, updated_at, details
)
SELECT
  pp.id, 'preservation', pp.slug, pp.name, NULL::text, '[]'::jsonb,
  pp.image_url, pp.mise_image_url, COALESCE(pp.image_status, 'missing'),
  pp.chefs_notes, NULL::text, pp.did_you_know, pp.status, pp.visibility,
  pp.created_by, pp.created_at, pp.updated_at,
  jsonb_strip_nulls(jsonb_build_object(
    'technique_type', pp.technique_type, 'what_it_is', pp.what_it_is, 'history', pp.history,
    'best_for', pp.best_for, 'equipment_needed', pp.equipment_needed, 'step_by_step', pp.step_by_step,
    'safety_notes', pp.safety_notes, 'shelf_life', pp.shelf_life
  ))
FROM public.preservation_profiles pp
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, status = EXCLUDED.status, details = EXCLUDED.details, updated_at = now();

-- ── Flat JSON helper (API compatibility) ──────────────────────────────
CREATE OR REPLACE FUNCTION public.library_profile_flat(p_row public.library_profiles)
RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT (to_jsonb(p_row) - 'details' - 'internal_notes')
    || COALESCE(p_row.details, '{}'::jsonb);
$$;

-- ── Directory type_extra from details ───────────────────────────────────
CREATE OR REPLACE FUNCTION public.library_type_extra(p_row public.library_profiles)
RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE p_row.profile_type
    WHEN 'ingredient'   THEN p_row.details->>'category'
    WHEN 'spice'        THEN p_row.details->>'heat_level'
    WHEN 'tool'         THEN p_row.details->>'tool_category'
    WHEN 'cut'          THEN p_row.details->>'protein_type'
    WHEN 'preservation' THEN p_row.details->>'technique_type'
    ELSE NULL END;
$$;

-- ── Public: directory ─────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_library_directory(text, text, int, int);
CREATE FUNCTION public.get_library_directory(
  p_type text, p_search text DEFAULT NULL, p_limit int DEFAULT 24, p_offset int DEFAULT 0
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN COALESCE((
    SELECT jsonb_agg(jsonb_build_object(
      'id', lp.id, 'slug', lp.slug, 'name', lp.name, 'also_known_as', lp.also_known_as,
      'image_url', lp.image_url, 'mise_image_url', lp.mise_image_url, 'image_status', lp.image_status,
      'type_extra', library_type_extra(lp), 'status', lp.status, 'visibility', lp.visibility,
      'created_at', lp.created_at
    ) ORDER BY lp.name)
    FROM public.library_profiles lp
    WHERE lp.profile_type = p_type AND lp.status = 'published'
      AND (p_search IS NULL OR btrim(p_search) = ''
        OR lp.name ILIKE '%' || p_search || '%'
        OR lp.also_known_as ILIKE '%' || p_search || '%')
    LIMIT GREATEST(1, LEAST(p_limit, 100)) OFFSET GREATEST(0, p_offset)
  ), '[]'::jsonb);
END; $$;
REVOKE ALL ON FUNCTION public.get_library_directory(text,text,int,int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_library_directory(text,text,int,int) TO anon, authenticated;

-- ── Public: single profile by slug ────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_library_profile(text, text);
CREATE FUNCTION public.get_library_profile(p_type text, p_slug text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_row public.library_profiles%ROWTYPE;
BEGIN
  SELECT * INTO v_row FROM public.library_profiles
  WHERE profile_type = p_type AND slug = p_slug AND status = 'published';
  IF NOT FOUND THEN RETURN NULL; END IF;
  RETURN library_profile_flat(v_row);
END; $$;
REVOKE ALL ON FUNCTION public.get_library_profile(text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_library_profile(text,text) TO anon, authenticated;

-- ── Recipe → library links (ingredients) ──────────────────────────────
DROP FUNCTION IF EXISTS public.get_library_links_for_ingredients(integer[]);
CREATE FUNCTION public.get_library_links_for_ingredients(p_ids integer[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_ids IS NULL OR array_length(p_ids, 1) IS NULL THEN RETURN '{}'::jsonb; END IF;
  RETURN COALESCE((
    SELECT jsonb_object_agg(
      governed_ingredient_id::text,
      jsonb_build_object('slug', slug, 'name', name, 'mise_image_url', mise_image_url, 'image_status', image_status)
    )
    FROM public.library_profiles
    WHERE profile_type = 'ingredient' AND governed_ingredient_id = ANY(p_ids) AND status = 'published'
  ), '{}'::jsonb);
END; $$;
GRANT EXECUTE ON FUNCTION public.get_library_links_for_ingredients(integer[]) TO anon, authenticated;

-- ── Split flat payload into row columns ───────────────────────────────
CREATE OR REPLACE FUNCTION public._library_split_payload(p_type text, p_payload jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
  v_shared_keys text[] := ARRAY[
    'slug','name','also_known_as','local_names','image_url','mise_image_url','image_status',
    'chefs_notes','recommended_brand','did_you_know','status','visibility',
    'governed_ingredient_id','internal_notes'
  ];
  v_key text;
  v_shared jsonb := '{}'::jsonb;
  v_details jsonb := '{}'::jsonb;
BEGIN
  IF p_payload IS NULL THEN p_payload := '{}'::jsonb; END IF;
  FOR v_key IN SELECT jsonb_object_keys(p_payload) LOOP
    IF v_key = ANY(v_shared_keys) THEN
      v_shared := v_shared || jsonb_build_object(v_key, p_payload->v_key);
    ELSIF v_key NOT IN ('profile_type','id','created_by','created_at','updated_at') THEN
      v_details := v_details || jsonb_build_object(v_key, p_payload->v_key);
    END IF;
  END LOOP;
  RETURN jsonb_build_object('shared', v_shared, 'details', v_details);
END; $$;

-- ── Admin upsert (editor + CSV) ───────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_upsert_library_profile(text, uuid, jsonb);
CREATE FUNCTION public.admin_upsert_library_profile(
  p_type text, p_id uuid DEFAULT NULL, p_payload jsonb DEFAULT '{}'::jsonb
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_split jsonb; v_shared jsonb; v_details jsonb; v_id uuid; v_slug text;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_type NOT IN ('ingredient','spice','tool','cut','preservation') THEN
    RAISE EXCEPTION 'Invalid profile type';
  END IF;
  v_split := _library_split_payload(p_type, p_payload);
  v_shared := v_split->'shared';
  v_details := COALESCE(v_split->'details', '{}'::jsonb);
  v_slug := COALESCE(NULLIF(trim(v_shared->>'slug'), ''),
    lower(regexp_replace(COALESCE(v_shared->>'name', 'profile'), '[^a-z0-9]+', '-', 'g')) || '-' || floor(extract(epoch from now()))::text);

  IF p_id IS NOT NULL THEN
    UPDATE public.library_profiles SET
      slug = COALESCE(NULLIF(v_shared->>'slug',''), slug),
      name = COALESCE(v_shared->>'name', name),
      also_known_as = v_shared->>'also_known_as',
      local_names = CASE WHEN v_shared ? 'local_names' THEN COALESCE(v_shared->'local_names','[]'::jsonb) ELSE local_names END,
      image_url = COALESCE(v_shared->>'image_url', image_url),
      mise_image_url = v_shared->>'mise_image_url',
      image_status = COALESCE(v_shared->>'image_status', image_status),
      chefs_notes = v_shared->>'chefs_notes',
      recommended_brand = v_shared->>'recommended_brand',
      did_you_know = v_shared->>'did_you_know',
      status = COALESCE(v_shared->>'status', status),
      visibility = COALESCE(v_shared->>'visibility', visibility),
      governed_ingredient_id = CASE WHEN v_shared ? 'governed_ingredient_id'
        THEN NULLIF(v_shared->>'governed_ingredient_id','')::int ELSE governed_ingredient_id END,
      internal_notes = COALESCE(v_shared->>'internal_notes', internal_notes),
      details = CASE WHEN v_details = '{}'::jsonb THEN details ELSE details || v_details END,
      updated_at = now()
    WHERE id = p_id AND profile_type = p_type
    RETURNING id INTO v_id;
    IF v_id IS NULL THEN RAISE EXCEPTION 'Profile not found'; END IF;
    RETURN v_id;
  END IF;

  IF COALESCE(v_shared->>'name','') = '' THEN RAISE EXCEPTION 'name is required'; END IF;
  INSERT INTO public.library_profiles (
    profile_type, slug, name, also_known_as, local_names, image_url, mise_image_url, image_status,
    chefs_notes, recommended_brand, did_you_know, status, visibility, governed_ingredient_id,
    internal_notes, details
  ) VALUES (
    p_type, v_slug, v_shared->>'name', v_shared->>'also_known_as',
    CASE WHEN v_shared ? 'local_names' THEN COALESCE(v_shared->'local_names','[]'::jsonb) ELSE '[]'::jsonb END,
    v_shared->>'image_url', v_shared->>'mise_image_url', COALESCE(v_shared->>'image_status','missing'),
    v_shared->>'chefs_notes', v_shared->>'recommended_brand', v_shared->>'did_you_know',
    COALESCE(v_shared->>'status','draft'), COALESCE(v_shared->>'visibility','public'),
    NULLIF(v_shared->>'governed_ingredient_id','')::int, v_shared->>'internal_notes', v_details
  )
  ON CONFLICT (profile_type, slug) DO UPDATE SET
    name = EXCLUDED.name, image_url = EXCLUDED.image_url, details = library_profiles.details || EXCLUDED.details,
    updated_at = now()
  RETURNING id INTO v_id;
  RETURN v_id;
END; $$;
REVOKE ALL ON FUNCTION public.admin_upsert_library_profile(text,uuid,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_upsert_library_profile(text,uuid,jsonb) TO authenticated;

-- ── Admin bulk CSV upsert ───────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_bulk_upsert_library_profiles(text, jsonb);
CREATE FUNCTION public.admin_bulk_upsert_library_profiles(p_type text, p_rows jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_row jsonb; v_inserted int := 0; v_updated int := 0; v_id uuid; v_existed boolean;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_rows IS NULL OR jsonb_typeof(p_rows) <> 'array' THEN
    RETURN jsonb_build_object('inserted', 0, 'updated', 0);
  END IF;
  FOR v_row IN SELECT value FROM jsonb_array_elements(p_rows) LOOP
    SELECT id INTO v_id FROM public.library_profiles
    WHERE profile_type = p_type
      AND (slug = v_row->>'slug' OR (v_row->>'slug' IS NULL AND lower(name) = lower(v_row->>'name')))
    LIMIT 1;
    v_existed := v_id IS NOT NULL;
    v_id := admin_upsert_library_profile(p_type, v_id, v_row);
    IF v_existed THEN v_updated := v_updated + 1; ELSE v_inserted := v_inserted + 1; END IF;
  END LOOP;
  RETURN jsonb_build_object('inserted', v_inserted, 'updated', v_updated);
END; $$;
REVOKE ALL ON FUNCTION public.admin_bulk_upsert_library_profiles(text,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_bulk_upsert_library_profiles(text,jsonb) TO authenticated;

-- ── Recipe match count for a profile ──────────────────────────────────
CREATE OR REPLACE FUNCTION public._library_recipe_count(p_type text, p_name text, p_governed_id int)
RETURNS int LANGUAGE plpgsql STABLE SET search_path = public AS $$
DECLARE v_match_name text; v_count int := 0;
BEGIN
  IF p_type = 'ingredient' AND p_governed_id IS NOT NULL THEN
    SELECT "Ingredient Name" INTO v_match_name FROM public.ingredients WHERE "ID" = p_governed_id;
  END IF;
  v_match_name := COALESCE(v_match_name, p_name);
  IF v_match_name IS NULL OR btrim(v_match_name) = '' THEN RETURN 0; END IF;
  SELECT count(*)::int INTO v_count
  FROM public.submitted_recipes sr
  WHERE sr.status = 'approved' AND sr.ingredients IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM jsonb_array_elements(sr.ingredients) sec,
           jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
      WHERE lower(trim(item->>'ingredient')) = lower(trim(v_match_name))
    );
  RETURN v_count;
END; $$;

-- ── Admin listing (unified) ───────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_library_profiles(text, text, int, int);
DROP FUNCTION IF EXISTS public.admin_get_library_profiles(text, text, int, int, text);
DROP FUNCTION IF EXISTS public.admin_get_library_profiles(text, text, int, int, text, text, text);

CREATE FUNCTION public.admin_get_library_profiles(
  p_type text, p_status text DEFAULT NULL, p_limit int DEFAULT 50, p_offset int DEFAULT 0,
  p_image_status text DEFAULT NULL, p_search text DEFAULT NULL, p_sort text DEFAULT 'updated_desc'
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_items jsonb; v_total int; v_where text := 'profile_type = $5';
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_status IS NOT NULL THEN v_where := v_where || ' AND status = $1'; END IF;
  IF p_image_status = 'missing' THEN
    v_where := v_where || ' AND (mise_image_url IS NULL OR btrim(mise_image_url) = '''')';
  ELSIF p_image_status = 'draft' THEN
    v_where := v_where || ' AND mise_image_url IS NOT NULL AND btrim(mise_image_url) <> '''' AND image_status = ''draft''';
  ELSIF p_image_status = 'approved' THEN
    v_where := v_where || ' AND image_status = ''approved''';
  END IF;
  IF p_search IS NOT NULL AND btrim(p_search) <> '' THEN
    v_where := v_where || ' AND (name ILIKE ''%'' || $6 || ''%'' OR also_known_as ILIKE ''%'' || $6 || ''%'' OR slug ILIKE ''%'' || $6 || ''%'')';
  END IF;

  EXECUTE 'SELECT count(*)::int FROM public.library_profiles WHERE ' || v_where
    INTO v_total USING p_status, p_limit, p_offset, p_image_status, p_type, p_search;

  EXECUTE format(
    'SELECT COALESCE(jsonb_agg(row_to_json(sub)::jsonb ORDER BY %s), ''[]''::jsonb) FROM (
       SELECT id, slug, name, image_url, mise_image_url, image_status, status, visibility, updated_at,
              governed_ingredient_id
       FROM public.library_profiles WHERE %s
       ORDER BY %s LIMIT $2 OFFSET $3
     ) sub',
    CASE p_sort
      WHEN 'name_asc' THEN 'sub.name ASC'
      WHEN 'name_desc' THEN 'sub.name DESC'
      WHEN 'updated_asc' THEN 'sub.updated_at ASC'
      WHEN 'status_asc' THEN 'sub.status ASC, sub.name ASC'
      ELSE 'sub.updated_at DESC'
    END,
    v_where,
    CASE p_sort
      WHEN 'name_asc' THEN 'name ASC'
      WHEN 'name_desc' THEN 'name DESC'
      WHEN 'updated_asc' THEN 'updated_at ASC'
      WHEN 'status_asc' THEN 'status ASC, name ASC'
      ELSE 'updated_at DESC'
    END
  ) INTO v_items USING p_status, p_limit, p_offset, p_image_status, p_type, p_search;

  RETURN jsonb_build_object('items', COALESCE(v_items, '[]'::jsonb), 'total', COALESCE(v_total, 0));
END; $$;
REVOKE ALL ON FUNCTION public.admin_get_library_profiles(text,text,int,int,text,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_get_library_profiles(text,text,int,int,text,text,text) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_get_library_profile(text, uuid);
CREATE FUNCTION public.admin_get_library_profile(p_type text, p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_row public.library_profiles%ROWTYPE;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  SELECT * INTO v_row FROM public.library_profiles WHERE id = p_id AND profile_type = p_type;
  IF NOT FOUND THEN RAISE EXCEPTION 'Profile not found'; END IF;
  RETURN library_profile_flat(v_row) || jsonb_build_object('internal_notes', v_row.internal_notes);
END; $$;
REVOKE ALL ON FUNCTION public.admin_get_library_profile(text,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_get_library_profile(text,uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_get_library_image_stats(text);
CREATE FUNCTION public.admin_get_library_image_stats(p_type text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_result jsonb;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  SELECT jsonb_build_object(
    'total', count(*)::int,
    'missing', count(*) FILTER (WHERE mise_image_url IS NULL OR btrim(mise_image_url) = '')::int,
    'draft', count(*) FILTER (WHERE mise_image_url IS NOT NULL AND btrim(mise_image_url) <> '' AND image_status = 'draft')::int,
    'approved', count(*) FILTER (WHERE image_status = 'approved')::int
  ) INTO v_result FROM public.library_profiles WHERE profile_type = p_type;
  RETURN COALESCE(v_result, '{"total":0,"missing":0,"draft":0,"approved":0}'::jsonb);
END; $$;
REVOKE ALL ON FUNCTION public.admin_get_library_image_stats(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_get_library_image_stats(text) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_set_library_image_status(text, uuid, text);
CREATE FUNCTION public.admin_set_library_image_status(p_type text, p_id uuid, p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_status NOT IN ('missing','draft','approved') THEN RAISE EXCEPTION 'Invalid image_status'; END IF;
  UPDATE public.library_profiles SET image_status = p_status, updated_at = now()
  WHERE id = p_id AND profile_type = p_type;
END; $$;
REVOKE ALL ON FUNCTION public.admin_set_library_image_status(text,uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_set_library_image_status(text,uuid,text) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_bulk_library_profiles(text, uuid[], text, text);
CREATE FUNCTION public.admin_bulk_library_profiles(
  p_type text, p_ids uuid[], p_action text, p_value text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_n int := 0;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_ids IS NULL OR array_length(p_ids, 1) IS NULL THEN RETURN jsonb_build_object('updated', 0); END IF;
  CASE p_action
    WHEN 'publish' THEN
      UPDATE public.library_profiles SET status = 'published', updated_at = now()
      WHERE profile_type = p_type AND id = ANY(p_ids);
    WHEN 'unpublish' THEN
      UPDATE public.library_profiles SET status = 'draft', updated_at = now()
      WHERE profile_type = p_type AND id = ANY(p_ids);
    WHEN 'approve_image' THEN
      UPDATE public.library_profiles SET image_status = 'approved', updated_at = now()
      WHERE profile_type = p_type AND id = ANY(p_ids)
        AND mise_image_url IS NOT NULL AND btrim(mise_image_url) <> '';
    WHEN 'set_visibility' THEN
      IF p_value NOT IN ('public','members','paid') THEN RAISE EXCEPTION 'Invalid visibility'; END IF;
      UPDATE public.library_profiles SET visibility = p_value, updated_at = now()
      WHERE profile_type = p_type AND id = ANY(p_ids);
    WHEN 'delete' THEN
      DELETE FROM public.library_profiles WHERE profile_type = p_type AND id = ANY(p_ids);
    ELSE RAISE EXCEPTION 'Unknown action: %', p_action;
  END CASE;
  GET DIAGNOSTICS v_n = ROW_COUNT;
  RETURN jsonb_build_object('updated', v_n);
END; $$;
REVOKE ALL ON FUNCTION public.admin_bulk_library_profiles(text,uuid[],text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_bulk_library_profiles(text,uuid[],text,text) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_publish_library_profile(text, uuid, text, text);
CREATE FUNCTION public.admin_publish_library_profile(
  p_type text, p_id uuid, p_status text DEFAULT 'published', p_visibility text DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  UPDATE public.library_profiles SET
    status = COALESCE(p_status, status),
    visibility = COALESCE(p_visibility, visibility),
    updated_at = now()
  WHERE id = p_id AND profile_type = p_type;
END; $$;
REVOKE ALL ON FUNCTION public.admin_publish_library_profile(text,uuid,text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_publish_library_profile(text,uuid,text,text) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_delete_library_profile(text, uuid);
CREATE FUNCTION public.admin_delete_library_profile(p_type text, p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  DELETE FROM public.library_profiles WHERE id = p_id AND profile_type = p_type;
END; $$;
REVOKE ALL ON FUNCTION public.admin_delete_library_profile(text,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_delete_library_profile(text,uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_link_library_ingredient(uuid, integer);
CREATE FUNCTION public.admin_link_library_ingredient(p_profile_id uuid, p_ingredient_id integer)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_name text;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_ingredient_id IS NULL OR p_ingredient_id < 1 THEN RAISE EXCEPTION 'Invalid ingredient ID'; END IF;
  SELECT "Ingredient Name" INTO v_name FROM public.ingredients WHERE "ID" = p_ingredient_id;
  IF v_name IS NULL THEN RAISE EXCEPTION 'Ingredient ID % not found', p_ingredient_id; END IF;
  UPDATE public.library_profiles SET governed_ingredient_id = p_ingredient_id, updated_at = now()
  WHERE id = p_profile_id AND profile_type = 'ingredient';
  IF NOT FOUND THEN RAISE EXCEPTION 'Ingredient profile not found'; END IF;
  RETURN jsonb_build_object('ingredient_id', p_ingredient_id, 'ingredient_name', v_name);
END; $$;
REVOKE ALL ON FUNCTION public.admin_link_library_ingredient(uuid,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_link_library_ingredient(uuid,integer) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_get_library_governed_preview(uuid);
CREATE FUNCTION public.admin_get_library_governed_preview(p_profile_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_row public.library_profiles%ROWTYPE;
  v_ing_name text; v_count int;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  SELECT * INTO v_row FROM public.library_profiles WHERE id = p_profile_id AND profile_type = 'ingredient';
  IF NOT FOUND THEN RAISE EXCEPTION 'Profile not found'; END IF;
  IF v_row.governed_ingredient_id IS NULL THEN
    RETURN jsonb_build_object('linked', false, 'profile_name', v_row.name);
  END IF;
  SELECT "Ingredient Name" INTO v_ing_name FROM public.ingredients WHERE "ID" = v_row.governed_ingredient_id;
  IF v_ing_name IS NULL THEN
    RETURN jsonb_build_object('linked', true, 'valid', false, 'ingredient_id', v_row.governed_ingredient_id, 'profile_name', v_row.name);
  END IF;
  v_count := _library_recipe_count('ingredient', v_row.name, v_row.governed_ingredient_id);
  RETURN jsonb_build_object(
    'linked', true, 'valid', true, 'ingredient_id', v_row.governed_ingredient_id,
    'ingredient_name', v_ing_name, 'recipe_count', v_count, 'profile_name', v_row.name
  );
END; $$;
REVOKE ALL ON FUNCTION public.admin_get_library_governed_preview(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_get_library_governed_preview(uuid) TO authenticated;

-- ── Coverage panel ──────────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_get_library_coverage(text, int);
CREATE FUNCTION public.admin_get_library_coverage(p_type text, p_limit int DEFAULT 40)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_zero jsonb; v_gaps jsonb; v_top jsonb;
  v_published int; v_with_recipes int; v_zero_count int;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_type NOT IN ('ingredient','spice','tool','cut','preservation') THEN
    RAISE EXCEPTION 'Invalid profile type';
  END IF;

  SELECT count(*)::int INTO v_published FROM public.library_profiles
  WHERE profile_type = p_type AND status = 'published';

  SELECT count(*)::int INTO v_zero_count
  FROM public.library_profiles lp
  WHERE lp.profile_type = p_type AND lp.status = 'published'
    AND _library_recipe_count(p_type, lp.name, lp.governed_ingredient_id) = 0;
  v_with_recipes := GREATEST(0, v_published - v_zero_count);

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', z.id, 'name', z.name, 'slug', z.slug, 'governed_ingredient_id', z.governed_ingredient_id
  ) ORDER BY z.name), '[]'::jsonb)
  INTO v_zero
  FROM (
    SELECT lp.id, lp.name, lp.slug, lp.governed_ingredient_id
    FROM public.library_profiles lp
    WHERE lp.profile_type = p_type AND lp.status = 'published'
      AND _library_recipe_count(p_type, lp.name, lp.governed_ingredient_id) = 0
    ORDER BY lp.name
    LIMIT GREATEST(1, LEAST(p_limit, 200))
  ) z;

  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', lp.id, 'name', lp.name, 'slug', lp.slug,
    'recipe_count', _library_recipe_count(p_type, lp.name, lp.governed_ingredient_id)
  ) ORDER BY _library_recipe_count(p_type, lp.name, lp.governed_ingredient_id) DESC), '[]'::jsonb)
  INTO v_top
  FROM public.library_profiles lp
  WHERE lp.profile_type = p_type AND lp.status = 'published'
  LIMIT GREATEST(1, LEAST(p_limit, 50));

  v_gaps := '[]'::jsonb;
  IF p_type = 'ingredient' THEN
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'ingredient_id', g.ing_id, 'ingredient_name', g.ing_name, 'recipe_count', g.cnt
    ) ORDER BY g.cnt DESC), '[]'::jsonb)
    INTO v_gaps
    FROM (
      SELECT i."ID" AS ing_id, i."Ingredient Name" AS ing_name, count(*)::int AS cnt
      FROM public.submitted_recipes sr
      CROSS JOIN LATERAL jsonb_array_elements(sr.ingredients) sec
      CROSS JOIN LATERAL jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
      JOIN public.ingredients i ON lower(trim(i."Ingredient Name")) = lower(trim(item->>'ingredient'))
      WHERE sr.status = 'approved'
        AND NOT EXISTS (
          SELECT 1 FROM public.library_profiles lp
          WHERE lp.profile_type = 'ingredient' AND lp.status = 'published'
            AND lp.governed_ingredient_id = i."ID"
        )
      GROUP BY i."ID", i."Ingredient Name"
      ORDER BY count(*) DESC
      LIMIT GREATEST(1, LEAST(p_limit, 100))
    ) g;
  END IF;

  RETURN jsonb_build_object(
    'summary', jsonb_build_object(
      'published', v_published,
      'with_recipes', v_with_recipes,
      'zero_recipes', v_zero_count,
      'ingredient_gaps', CASE WHEN p_type = 'ingredient' THEN jsonb_array_length(v_gaps) ELSE 0 END
    ),
    'zero_recipe_profiles', v_zero,
    'top_profiles', v_top,
    'ingredient_gaps', v_gaps
  );
END; $$;
REVOKE ALL ON FUNCTION public.admin_get_library_coverage(text,int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_get_library_coverage(text,int) TO authenticated;

-- ── Submission publish → unified table ────────────────────────────────
CREATE OR REPLACE FUNCTION public._publish_library_submission(sub public.library_profile_submissions)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid; p jsonb; slug text;
BEGIN
  p := COALESCE(sub.payload, '{}');
  slug := COALESCE(NULLIF(trim(sub.slug), ''), NULLIF(trim(p->>'slug'), ''),
    lower(regexp_replace(COALESCE(p->>'name', 'profile'), '[^a-z0-9]+', '-', 'g')));
  p := p || jsonb_build_object('slug', slug, 'status', 'published', 'created_by', sub.user_id::text);
  v_id := admin_upsert_library_profile(sub.profile_type, NULL, p);
  UPDATE public.library_profiles SET created_by = sub.user_id WHERE id = v_id;
  RETURN v_id;
END; $$;

DROP FUNCTION IF EXISTS public.admin_review_library_submission(uuid, text, text);
CREATE OR REPLACE FUNCTION public.admin_review_library_submission(
  p_id uuid, p_action text, p_notes text DEFAULT NULL
) RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE sub public.library_profile_submissions%ROWTYPE; pub_id uuid;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'not_admin'; END IF;
  SELECT * INTO sub FROM library_profile_submissions WHERE id = p_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'not_found'; END IF;
  IF p_action = 'reject' THEN
    UPDATE library_profile_submissions SET status = 'rejected', reviewer_notes = p_notes, reviewed_at = now() WHERE id = p_id;
    RETURN true;
  ELSIF p_action = 'approve' THEN
    pub_id := public._publish_library_submission(sub);
    UPDATE library_profile_submissions SET status = 'approved', reviewer_notes = p_notes, reviewed_at = now(),
      payload = sub.payload || jsonb_build_object('published_profile_id', pub_id::text)
    WHERE id = p_id;
    RETURN true;
  END IF;
  RAISE EXCEPTION 'invalid_action';
END; $$;
GRANT EXECUTE ON FUNCTION public.admin_review_library_submission(uuid, text, text) TO authenticated;

SELECT 'library_profiles unified — ' || count(*)::text || ' rows' AS status FROM public.library_profiles;
SELECT pg_notify('pgrst', 'reload schema');
-- ########## END: fix-library-unified.sql ##########

-- ########## BEGIN: fix-phase36-platform-batch.sql ##########
-- ══════════════════════════════════════════════════════════════════════
-- fix-phase36-platform-batch.sql
-- Food Map counts · Festival Management · Voice of Customer · Recipe import
-- Safe to re-run. Run in Supabase SQL editor.
-- ══════════════════════════════════════════════════════════════════════

-- ── Food by Map: origin recipe counts ─────────────────────────────────
DROP FUNCTION IF EXISTS public.get_recipe_origin_counts(text, text);
CREATE FUNCTION public.get_recipe_origin_counts(
  p_level  text DEFAULT 'continent',
  p_parent text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF p_level = 'continent' THEN
    RETURN COALESCE((
      SELECT jsonb_agg(row_to_json(t) ORDER BY t.name)
      FROM (
        SELECT COALESCE(NULLIF(btrim(origin_continent), ''), 'Unmapped') AS name,
               count(*)::int AS recipe_count
        FROM public.submitted_recipes
        WHERE status = 'approved' AND visibility = 'Public'
        GROUP BY 1
      ) t
    ), '[]'::jsonb);
  ELSIF p_level = 'country' AND p_parent IS NOT NULL THEN
    RETURN COALESCE((
      SELECT jsonb_agg(row_to_json(t) ORDER BY t.name)
      FROM (
        SELECT COALESCE(NULLIF(btrim(origin_country), ''), 'Unspecified') AS name,
               count(*)::int AS recipe_count
        FROM public.submitted_recipes
        WHERE status = 'approved' AND visibility = 'Public'
          AND COALESCE(NULLIF(btrim(origin_continent), ''), 'Unmapped') = p_parent
        GROUP BY 1
      ) t
    ), '[]'::jsonb);
  ELSIF p_level = 'state' AND p_parent IS NOT NULL THEN
    RETURN COALESCE((
      SELECT jsonb_agg(row_to_json(t) ORDER BY t.name)
      FROM (
        SELECT COALESCE(NULLIF(btrim(origin_state), ''), 'Unspecified') AS name,
               count(*)::int AS recipe_count
        FROM public.submitted_recipes
        WHERE status = 'approved' AND visibility = 'Public'
          AND btrim(origin_country) = p_parent
        GROUP BY 1
      ) t
    ), '[]'::jsonb);
  END IF;
  RETURN '[]'::jsonb;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_recipe_origin_counts(text, text) TO anon, authenticated;

DROP FUNCTION IF EXISTS public.get_recipes_by_origin(text, text, text, int);
CREATE FUNCTION public.get_recipes_by_origin(
  p_continent text DEFAULT NULL,
  p_country   text DEFAULT NULL,
  p_state       text DEFAULT NULL,
  p_limit       int  DEFAULT 48
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN COALESCE((
    SELECT jsonb_agg(row_to_json(r) ORDER BY r.recipe_name)
    FROM (
      SELECT id, recipe_name, category, origin_country, origin_state, origin_locality, image_url
      FROM public.submitted_recipes
      WHERE status = 'approved' AND visibility = 'Public'
        AND (p_continent IS NULL OR COALESCE(NULLIF(btrim(origin_continent), ''), 'Unmapped') = p_continent)
        AND (p_country   IS NULL OR btrim(origin_country) = p_country)
        AND (p_state     IS NULL OR COALESCE(NULLIF(btrim(origin_state), ''), 'Unspecified') = p_state)
      ORDER BY recipe_name
      LIMIT p_limit
    ) r
  ), '[]'::jsonb);
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_recipes_by_origin(text, text, text, int) TO anon, authenticated;

-- ── Voice of Customer (extend user_feedback) ──────────────────────────
ALTER TABLE public.user_feedback ADD COLUMN IF NOT EXISTS name  text;
ALTER TABLE public.user_feedback ADD COLUMN IF NOT EXISTS email text;
ALTER TABLE public.user_feedback ADD COLUMN IF NOT EXISTS username text;
ALTER TABLE public.user_feedback ADD COLUMN IF NOT EXISTS source text DEFAULT 'in_app';
ALTER TABLE public.user_feedback ADD COLUMN IF NOT EXISTS sentiment text;
ALTER TABLE public.user_feedback ADD COLUMN IF NOT EXISTS action_required boolean DEFAULT false;
ALTER TABLE public.user_feedback ADD COLUMN IF NOT EXISTS voc_category text;
ALTER TABLE public.user_feedback ADD COLUMN IF NOT EXISTS admin_notes text;

ALTER TABLE public.user_feedback DROP CONSTRAINT IF EXISTS user_feedback_type_check;
ALTER TABLE public.user_feedback ADD CONSTRAINT user_feedback_type_check CHECK (type IN (
  'general','recipe','bug','suggestion','other',
  'kudos','value_story','feature_wish',
  'user_error','vague_vent','known_repeat',
  'system_bug','process_friction','content_issue'
));

DROP FUNCTION IF EXISTS public.submit_user_feedback(text, text, text, text, text, text, text, boolean);
CREATE FUNCTION public.submit_user_feedback(
  p_feedback        text,
  p_type            text    DEFAULT 'general',
  p_name            text    DEFAULT NULL,
  p_email           text    DEFAULT NULL,
  p_voc_category    text    DEFAULT NULL,
  p_sentiment       text    DEFAULT NULL,
  p_source          text    DEFAULT 'in_app',
  p_action_required boolean DEFAULT NULL
) RETURNS bigint LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id bigint;
BEGIN
  IF p_feedback IS NULL OR btrim(p_feedback) = '' THEN
    RAISE EXCEPTION 'Feedback message required';
  END IF;
  INSERT INTO public.user_feedback (
    user_id, feedback, type, name, email, username, source, sentiment,
    action_required, voc_category, status
  ) VALUES (
    auth.uid(),
    btrim(p_feedback),
    COALESCE(NULLIF(p_type, ''), 'general'),
    p_name, p_email,
    (SELECT username FROM public.profiles WHERE id = auth.uid()),
    COALESCE(p_source, 'in_app'),
    p_sentiment,
    COALESCE(p_action_required, p_type IN ('system_bug','process_friction','content_issue','bug')),
    p_voc_category,
    'new'
  ) RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.submit_user_feedback(text,text,text,text,text,text,text,boolean) TO anon, authenticated;

DROP POLICY IF EXISTS "Anyone can submit feedback" ON public.user_feedback;
CREATE POLICY "Anyone can submit feedback" ON public.user_feedback
  FOR INSERT TO anon, authenticated WITH CHECK (true);

DROP FUNCTION IF EXISTS public.admin_get_feedback(text);
DROP FUNCTION IF EXISTS public.admin_get_feedback(text, text, boolean);
CREATE FUNCTION public.admin_get_feedback(
  p_status          text    DEFAULT NULL,
  p_voc_category    text    DEFAULT NULL,
  p_action_required boolean DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_result jsonb;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  SELECT COALESCE(jsonb_agg(row_to_json(f) ORDER BY f.created_at DESC), '[]'::jsonb)
  INTO v_result
  FROM (
    SELECT uf.*, p.username AS profile_username, p.full_name AS profile_name
    FROM public.user_feedback uf
    LEFT JOIN public.profiles p ON p.id = uf.user_id
    WHERE (p_status IS NULL OR uf.status = p_status)
      AND (p_voc_category IS NULL OR uf.voc_category = p_voc_category)
      AND (p_action_required IS NULL OR uf.action_required = p_action_required)
    ORDER BY uf.created_at DESC
    LIMIT 200
  ) f;
  RETURN v_result;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_get_feedback(text, text, boolean) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_update_feedback(bigint, text);
DROP FUNCTION IF EXISTS public.admin_update_feedback(bigint, text, text, text, boolean);
CREATE FUNCTION public.admin_update_feedback(
  p_id              bigint,
  p_status          text    DEFAULT NULL,
  p_admin_notes     text    DEFAULT NULL,
  p_voc_category    text    DEFAULT NULL,
  p_action_required boolean DEFAULT NULL
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  UPDATE public.user_feedback SET
    status          = COALESCE(p_status, status),
    admin_notes     = COALESCE(p_admin_notes, admin_notes),
    voc_category    = COALESCE(p_voc_category, voc_category),
    action_required = COALESCE(p_action_required, action_required)
  WHERE id = p_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_update_feedback(bigint, text, text, text, boolean) TO authenticated;

-- ── Festival Management ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.festivals (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug          text UNIQUE NOT NULL,
  name          text NOT NULL,
  emoji         text DEFAULT '🎉',
  when_label    text,
  description   text,
  planner_path  text,
  tags          text[] DEFAULT '{}',
  sort_order    int DEFAULT 0,
  is_active     boolean DEFAULT true,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.festival_dishes (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  festival_id  uuid NOT NULL REFERENCES public.festivals(id) ON DELETE CASCADE,
  dish_name    text NOT NULL,
  sort_order   int NOT NULL DEFAULT 0,
  is_required  boolean DEFAULT false,
  notes        text
);

CREATE TABLE IF NOT EXISTS public.festival_dish_recipes (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dish_id         uuid NOT NULL REFERENCES public.festival_dishes(id) ON DELETE CASCADE,
  recipe_id       uuid REFERENCES public.submitted_recipes(id) ON DELETE SET NULL,
  variant_label   text NOT NULL DEFAULT 'Classic',
  is_featured     boolean DEFAULT false,
  visibility      text NOT NULL DEFAULT 'public' CHECK (visibility IN ('public','user_private')),
  submitted_by    uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  approval_status text NOT NULL DEFAULT 'approved' CHECK (approval_status IN ('pending','approved','rejected')),
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- Backfill columns when festivals tables pre-exist from a partial run
ALTER TABLE public.festivals ADD COLUMN IF NOT EXISTS emoji text DEFAULT '🎉';
ALTER TABLE public.festivals ADD COLUMN IF NOT EXISTS when_label text;
ALTER TABLE public.festivals ADD COLUMN IF NOT EXISTS description text;
ALTER TABLE public.festivals ADD COLUMN IF NOT EXISTS planner_path text;
ALTER TABLE public.festivals ADD COLUMN IF NOT EXISTS tags text[] DEFAULT '{}';
ALTER TABLE public.festivals ADD COLUMN IF NOT EXISTS sort_order int DEFAULT 0;
ALTER TABLE public.festivals ADD COLUMN IF NOT EXISTS is_active boolean DEFAULT true;
ALTER TABLE public.festivals ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();
ALTER TABLE public.festivals ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

ALTER TABLE public.festival_dishes ADD COLUMN IF NOT EXISTS sort_order int DEFAULT 0;
ALTER TABLE public.festival_dishes ADD COLUMN IF NOT EXISTS is_required boolean DEFAULT false;
ALTER TABLE public.festival_dishes ADD COLUMN IF NOT EXISTS notes text;

ALTER TABLE public.festivals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.festival_dishes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.festival_dish_recipes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "public reads active festivals" ON public.festivals;
CREATE POLICY "public reads active festivals" ON public.festivals
  FOR SELECT TO anon, authenticated USING (is_active = true);
DROP POLICY IF EXISTS "admin manages festivals" ON public.festivals;
CREATE POLICY "admin manages festivals" ON public.festivals
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "public reads festival dishes" ON public.festival_dishes;
CREATE POLICY "public reads festival dishes" ON public.festival_dishes
  FOR SELECT TO anon, authenticated USING (
    EXISTS (SELECT 1 FROM public.festivals f WHERE f.id = festival_id AND f.is_active)
  );
DROP POLICY IF EXISTS "admin manages festival dishes" ON public.festival_dishes;
CREATE POLICY "admin manages festival dishes" ON public.festival_dishes
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

DROP POLICY IF EXISTS "public reads approved festival recipes" ON public.festival_dish_recipes;
CREATE POLICY "public reads approved festival recipes" ON public.festival_dish_recipes
  FOR SELECT TO anon, authenticated USING (
    visibility = 'public' AND approval_status = 'approved'
    OR (submitted_by = auth.uid())
  );
DROP POLICY IF EXISTS "users submit festival recipes" ON public.festival_dish_recipes;
CREATE POLICY "users submit festival recipes" ON public.festival_dish_recipes
  FOR INSERT TO authenticated WITH CHECK (submitted_by = auth.uid());
DROP POLICY IF EXISTS "admin manages festival recipes" ON public.festival_dish_recipes;
CREATE POLICY "admin manages festival recipes" ON public.festival_dish_recipes
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

-- Seed festivals (migrate hardcoded calendar + Onam sadya dishes)
INSERT INTO public.festivals (slug, name, emoji, when_label, description, planner_path, tags, sort_order)
VALUES
  ('onam', 'Onam / Vishu', '🌺', 'Aug–Sep (Malayalam calendar)', 'Traditional sadya on banana leaf.', 'onam-sadya.html', ARRAY['onam','vishu','sadya','kerala'], 1),
  ('eid', 'Eid', '🌙', 'Islamic lunar calendar', 'Feast-day recipes and planner.', 'eid-feast.html', ARRAY['eid','ramadan','iftar','biryani'], 2),
  ('christmas', 'Christmas', '🎄', '25 December', 'Holiday roasts and puddings.', 'christmas-roast.html', ARRAY['christmas','roast','pudding'], 3),
  ('diwali', 'Diwali', '🪔', 'Oct–Nov', 'Sweets and feast dishes.', NULL, ARRAY['diwali','deepavali','mithai'], 4),
  ('easter', 'Easter', '🐣', 'Mar–Apr', 'Spring celebration meals.', NULL, ARRAY['easter','lamb'], 5),
  ('wedding', 'Wedding & celebrations', '💒', 'Year-round', 'Large gatherings and feast menus.', NULL, ARRAY['wedding','celebration','feast'], 6),
  ('thanksgiving', 'Thanksgiving', '🦃', 'Nov (US)', 'Harvest feast.', NULL, ARRAY['thanksgiving','turkey'], 7),
  ('lunar-new-year', 'Lunar New Year', '🧧', 'Jan–Feb', 'Dumplings and spring festival dishes.', NULL, ARRAY['lunar','dumpling'], 8)
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name, emoji = EXCLUDED.emoji, when_label = EXCLUDED.when_label,
  planner_path = EXCLUDED.planner_path, tags = EXCLUDED.tags, sort_order = EXCLUDED.sort_order;

INSERT INTO public.festival_dishes (festival_id, dish_name, sort_order)
SELECT f.id, d.name, d.ord
FROM public.festivals f
CROSS JOIN (VALUES
  ('Upperi / banana chips',1),('Inji curry',2),('Mango pickle',3),('Lime pickle',4),('Pappadam',5),
  ('Banana (ripe)',6),('Salt',7),('Parippu + ghee',8),('Sambar',9),('Rasam',10),('Avial',11),
  ('Thoran',12),('Olan',13),('Kalan',14),('Erissery',15),('Pulisery',16),('Kootu curry',17),
  ('Payasam (first)',18),('Payasam (second)',19),('Rice',20)
) AS d(name, ord)
WHERE f.slug = 'onam'
  AND NOT EXISTS (SELECT 1 FROM public.festival_dishes fd WHERE fd.festival_id = f.id AND fd.dish_name = d.name);

-- ── Festival RPCs ─────────────────────────────────────────────────────
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

-- ── OCR cleanup (rule-based v1; wire AI later) ────────────────────────
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

SELECT 'Phase 36 platform batch ready' AS status;
-- ########## END: fix-phase36-platform-batch.sql ##########

-- ########## BEGIN: fix-phase36-festivals-hotfix.sql ##########
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
-- ########## END: fix-phase36-festivals-hotfix.sql ##########

-- ########## BEGIN: fix-phase37-festival-admin.sql ##########
-- fix-phase37-festival-admin.sql — Festival admin CRUD + dish sections
-- Safe to re-run. Run after fix-phase36-platform-batch.sql

ALTER TABLE public.festival_dishes ADD COLUMN IF NOT EXISTS section_label text;

-- ── Admin: upsert festival ─────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_upsert_festival(uuid, text, text, text, text, text, text, text[], int, boolean);
CREATE FUNCTION public.admin_upsert_festival(
  p_id           uuid    DEFAULT NULL,
  p_slug         text    DEFAULT NULL,
  p_name         text    DEFAULT NULL,
  p_emoji        text    DEFAULT '🎉',
  p_when_label   text    DEFAULT NULL,
  p_description  text    DEFAULT NULL,
  p_planner_path text    DEFAULT NULL,
  p_tags         text[]  DEFAULT '{}',
  p_sort_order   int     DEFAULT 0,
  p_is_active    boolean DEFAULT true
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_slug IS NULL OR btrim(p_slug) = '' OR p_name IS NULL OR btrim(p_name) = '' THEN
    RAISE EXCEPTION 'Slug and name required';
  END IF;
  IF p_id IS NULL THEN
    INSERT INTO public.festivals (slug, name, emoji, when_label, description, planner_path, tags, sort_order, is_active)
    VALUES (btrim(p_slug), btrim(p_name), p_emoji, p_when_label, p_description, p_planner_path,
            COALESCE(p_tags, '{}'), COALESCE(p_sort_order, 0), COALESCE(p_is_active, true))
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.festivals SET
      slug = btrim(p_slug), name = btrim(p_name), emoji = p_emoji, when_label = p_when_label,
      description = p_description, planner_path = p_planner_path, tags = COALESCE(p_tags, tags),
      sort_order = COALESCE(p_sort_order, sort_order), is_active = COALESCE(p_is_active, is_active),
      updated_at = now()
    WHERE id = p_id RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_upsert_festival(uuid,text,text,text,text,text,text,text[],int,boolean) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_toggle_festival(uuid, boolean);
CREATE FUNCTION public.admin_toggle_festival(p_id uuid, p_is_active boolean)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  UPDATE public.festivals SET is_active = p_is_active, updated_at = now() WHERE id = p_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_toggle_festival(uuid, boolean) TO authenticated;

-- ── Admin: dish slots ─────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_upsert_festival_dish(uuid, uuid, text, text, int, boolean, text);
CREATE FUNCTION public.admin_upsert_festival_dish(
  p_id            uuid    DEFAULT NULL,
  p_festival_id   uuid    DEFAULT NULL,
  p_dish_name     text    DEFAULT NULL,
  p_section_label text    DEFAULT NULL,
  p_sort_order    int     DEFAULT 0,
  p_is_required   boolean DEFAULT false,
  p_notes         text    DEFAULT NULL
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_dish_name IS NULL OR btrim(p_dish_name) = '' THEN RAISE EXCEPTION 'Dish name required'; END IF;
  IF p_id IS NULL THEN
    IF p_festival_id IS NULL THEN RAISE EXCEPTION 'Festival required for new dish'; END IF;
    INSERT INTO public.festival_dishes (festival_id, dish_name, section_label, sort_order, is_required, notes)
    VALUES (p_festival_id, btrim(p_dish_name), NULLIF(btrim(p_section_label), ''), COALESCE(p_sort_order, 0),
            COALESCE(p_is_required, false), p_notes)
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.festival_dishes SET
      dish_name = btrim(p_dish_name),
      section_label = NULLIF(btrim(p_section_label), ''),
      sort_order = COALESCE(p_sort_order, sort_order),
      is_required = COALESCE(p_is_required, is_required),
      notes = p_notes
    WHERE id = p_id RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_upsert_festival_dish(uuid,uuid,text,text,int,boolean,text) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_delete_festival_dish(uuid);
CREATE FUNCTION public.admin_delete_festival_dish(p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  DELETE FROM public.festival_dishes WHERE id = p_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_delete_festival_dish(uuid) TO authenticated;

-- ── Admin: link recipe variants ───────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_link_festival_recipe(uuid, uuid, uuid, text, boolean);
CREATE FUNCTION public.admin_link_festival_recipe(
  p_id            uuid    DEFAULT NULL,
  p_dish_id       uuid    DEFAULT NULL,
  p_recipe_id     uuid    DEFAULT NULL,
  p_variant_label text    DEFAULT 'Classic',
  p_is_featured   boolean DEFAULT false
) RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  IF p_dish_id IS NULL OR p_recipe_id IS NULL THEN RAISE EXCEPTION 'Dish and recipe required'; END IF;
  IF p_id IS NULL THEN
    INSERT INTO public.festival_dish_recipes (dish_id, recipe_id, variant_label, is_featured, visibility, approval_status)
    VALUES (p_dish_id, p_recipe_id, COALESCE(NULLIF(btrim(p_variant_label), ''), 'Classic'),
            COALESCE(p_is_featured, false), 'public', 'approved')
    RETURNING id INTO v_id;
  ELSE
    UPDATE public.festival_dish_recipes SET
      recipe_id = p_recipe_id,
      variant_label = COALESCE(NULLIF(btrim(p_variant_label), ''), variant_label),
      is_featured = COALESCE(p_is_featured, is_featured)
    WHERE id = p_id RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_link_festival_recipe(uuid,uuid,uuid,text,boolean) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_unlink_festival_recipe(uuid);
CREATE FUNCTION public.admin_unlink_festival_recipe(p_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  DELETE FROM public.festival_dish_recipes WHERE id = p_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_unlink_festival_recipe(uuid) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_search_recipes(text, int);
CREATE FUNCTION public.admin_search_recipes(p_query text, p_limit int DEFAULT 20)
RETURNS jsonb LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(jsonb_agg(row_to_json(r) ORDER BY r.recipe_name), '[]'::jsonb)
  FROM (
    SELECT id, recipe_name, category, origin_country
    FROM public.submitted_recipes
    WHERE status = 'approved'
      AND (p_query IS NULL OR btrim(p_query) = '' OR recipe_name ILIKE '%' || btrim(p_query) || '%')
    ORDER BY recipe_name
    LIMIT COALESCE(p_limit, 20)
  ) r;
$$;
GRANT EXECUTE ON FUNCTION public.admin_search_recipes(text, int) TO authenticated;

-- Refresh get_festival_detail to expose section_label
DROP FUNCTION IF EXISTS public.get_festival_detail(text);
CREATE FUNCTION public.get_festival_detail(p_slug text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fest jsonb; v_dishes jsonb;
BEGIN
  SELECT row_to_json(f)::jsonb INTO v_fest FROM public.festivals f WHERE f.slug = p_slug AND f.is_active = true;
  IF v_fest IS NULL THEN RETURN NULL; END IF;
  SELECT COALESCE(jsonb_agg(row_to_json(d) ORDER BY d.section_label NULLS LAST, d.sort_order), '[]'::jsonb) INTO v_dishes
  FROM (
    SELECT fd.id, fd.dish_name, fd.section_label, fd.sort_order, fd.is_required, fd.notes,
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

-- Optional: sample Onam sections (only where section_label still null)
UPDATE public.festival_dishes fd SET section_label = v.sec
FROM public.festivals f,
(VALUES
  ('Upperi / banana chips','Starters & Crunch'),
  ('Inji curry','Pickles & Chutneys'),
  ('Mango pickle','Pickles & Chutneys'),
  ('Lime pickle','Pickles & Chutneys'),
  ('Pappadam','Starters & Crunch'),
  ('Banana (ripe)','Sides'),
  ('Salt','Rice & Staples'),
  ('Parippu + ghee','Rice & Staples'),
  ('Sambar','Main Curries'),
  ('Rasam','Main Curries'),
  ('Avial','Vegetable Dishes'),
  ('Thoran','Vegetable Dishes'),
  ('Olan','Vegetable Dishes'),
  ('Kalan','Vegetable Dishes'),
  ('Erissery','Vegetable Dishes'),
  ('Pulisery','Vegetable Dishes'),
  ('Kootu curry','Vegetable Dishes'),
  ('Payasam (first)','Desserts'),
  ('Payasam (second)','Desserts'),
  ('Rice','Rice & Staples')
) AS v(dish, sec)
WHERE f.slug = 'onam' AND fd.festival_id = f.id AND fd.dish_name = v.dish AND fd.section_label IS NULL;

-- Admin detail (includes inactive festivals)
DROP FUNCTION IF EXISTS public.admin_get_festival_detail(text);
CREATE FUNCTION public.admin_get_festival_detail(p_slug text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_fest jsonb; v_dishes jsonb;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  SELECT row_to_json(f)::jsonb INTO v_fest FROM public.festivals f WHERE f.slug = p_slug;
  IF v_fest IS NULL THEN RETURN NULL; END IF;
  SELECT COALESCE(jsonb_agg(row_to_json(d) ORDER BY d.section_label NULLS LAST, d.sort_order), '[]'::jsonb) INTO v_dishes
  FROM (
    SELECT fd.id, fd.dish_name, fd.section_label, fd.sort_order, fd.is_required, fd.notes,
      COALESCE((
        SELECT jsonb_agg(row_to_json(r) ORDER BY r.is_featured DESC, r.variant_label)
        FROM (
          SELECT fdr.id, fdr.variant_label, fdr.is_featured, fdr.recipe_id, sr.recipe_name
          FROM public.festival_dish_recipes fdr
          LEFT JOIN public.submitted_recipes sr ON sr.id = fdr.recipe_id
          WHERE fdr.dish_id = fd.id
        ) r
      ), '[]'::jsonb) AS recipes
    FROM public.festival_dishes fd
    WHERE fd.festival_id = (v_fest->>'id')::uuid
  ) d;
  RETURN v_fest || jsonb_build_object('dishes', v_dishes);
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_get_festival_detail(text) TO authenticated;

SELECT 'Phase 37 festival admin ready' AS status;
-- ########## END: fix-phase37-festival-admin.sql ##########

-- ########## BEGIN: fix-phase37-tools-profiles.sql ##########
-- fix-phase37-tools-profiles.sql — richer Tools & Appliances library fields
-- Safe to re-run.

ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS material text;
ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS capacity_notes text;
ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS heat_compatibility text;
ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS skill_level text;
ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS swap_if_missing text;
ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS care_schedule text;
ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS pairs_well_with text;
ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS best_for text;

UPDATE public.tool_profiles SET
  material = COALESCE(material, 'Cast iron'),
  capacity_notes = COALESCE(capacity_notes, '10–12 inch (25–30 cm) — serves 2–4'),
  heat_compatibility = COALESCE(heat_compatibility, 'Gas · electric · oven-safe · induction (if enamel base)'),
  skill_level = COALESCE(skill_level, 'Beginner-friendly once seasoned'),
  swap_if_missing = COALESCE(swap_if_missing, 'Heavy stainless frying pan — won''t hold heat as evenly'),
  care_schedule = COALESCE(care_schedule, 'After each use: wash, dry, light oil wipe. Monthly: oven re-season if sticky.'),
  pairs_well_with = COALESCE(pairs_well_with, 'Silicone spatula · chain mail scrubber · lid for braising'),
  best_for = COALESCE(best_for, 'Searing · shallow frying · cornbread · stove-to-oven dishes')
WHERE slug = 'cast-iron-skillet' AND status = 'published';

UPDATE public.tool_profiles SET
  material = COALESCE(material, 'High-carbon or stainless steel'),
  capacity_notes = COALESCE(capacity_notes, '20–25 cm blade — all-purpose home size'),
  heat_compatibility = COALESCE(heat_compatibility, 'Hand-wash only · not dishwasher-safe (handles wood)'),
  skill_level = COALESCE(skill_level, 'Intermediate — pinch grip takes practice'),
  swap_if_missing = COALESCE(swap_if_missing, 'Santoku or utility knife for veg; cleaver only for heavy prep'),
  care_schedule = COALESCE(care_schedule, 'Every use: hone on steel. Quarterly: whetstone sharpen. Store on magnetic strip.'),
  pairs_well_with = COALESCE(pairs_well_with, 'Honing steel · cutting board · knife guard'),
  best_for = COALESCE(best_for, 'Mise en place · protein breakdown · fine dice')
WHERE slug = 'chefs-knife' AND status = 'published';

SELECT 'Phase 37 tools profiles ready' AS status;
-- ########## END: fix-phase37-tools-profiles.sql ##########

-- ########## BEGIN: fix-phase38-import-audit.sql ##########
-- ══════════════════════════════════════════════════════════════════════
-- fix-phase38-import-audit.sql — Wave 3 import audit trail (section U)
-- Safe to re-run. Run in Supabase SQL Editor after sync-submitted-recipes-columns.sql
-- ══════════════════════════════════════════════════════════════════════

ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS paste_text              text;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS source_url              text;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS parser_version          text;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS extractor_version       text;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS import_extractor        text;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS import_confidence_score integer;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS import_warnings         jsonb DEFAULT '[]'::jsonb;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS import_paste_snapshot   text;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS import_raw_article_text text;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS imported_at             timestamptz;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS procedure_rewritten     boolean DEFAULT false;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS import_merge_mode       boolean DEFAULT false;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS import_source_url       text;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS import_path             text;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS import_attribution_notice text;
ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS import_page_title       text;

COMMENT ON COLUMN public.submitted_recipes.import_paste_snapshot IS 'Structured paste text immediately after extract/parse pipeline';
COMMENT ON COLUMN public.submitted_recipes.import_raw_article_text IS 'Truncated raw article text from URL fetch (first ~8000 chars)';
COMMENT ON COLUMN public.submitted_recipes.import_warnings IS 'Parser warnings array from confidence gate';

SELECT 'Phase 38 import audit columns ready' AS status;
-- ########## END: fix-phase38-import-audit.sql ##########

-- ########## BEGIN: fix-phase39-data-integrity.sql ##########
-- fix-phase39-data-integrity.sql
-- Data integrity layer: ingredient amend cascade, guarded delete, bulk recipe
-- normalisation, integrity report, performance indexes, ingredient lookup RPC.
-- Safe to re-run. Run in Supabase SQL Editor after fix-library-unified.sql.

-- ── 1. Performance indexes (10k+ recipes) ─────────────────────────────
CREATE INDEX IF NOT EXISTS idx_sr_status_submitted
  ON public.submitted_recipes (status, submitted_at DESC);

CREATE INDEX IF NOT EXISTS idx_sr_approved_public
  ON public.submitted_recipes (submitted_at DESC)
  WHERE status = 'approved' AND visibility = 'Public';

CREATE INDEX IF NOT EXISTS idx_sr_category
  ON public.submitted_recipes (category)
  WHERE status = 'approved';

CREATE INDEX IF NOT EXISTS idx_sr_user_id
  ON public.submitted_recipes (user_id);

CREATE INDEX IF NOT EXISTS idx_ingredients_name_lower
  ON public.ingredients (lower(trim("Ingredient Name")));

-- ── 2. Clean invalid governed links before FK ─────────────────────────
UPDATE public.library_profiles lp
SET governed_ingredient_id = NULL, updated_at = now()
WHERE lp.governed_ingredient_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.ingredients i WHERE i."ID" = lp.governed_ingredient_id
  );

DO $$ BEGIN
  ALTER TABLE public.library_profiles
    ADD CONSTRAINT library_profiles_governed_ingredient_fk
    FOREIGN KEY (governed_ingredient_id) REFERENCES public.ingredients("ID")
    ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ── 3. Rewrite ingredient name across all recipe JSONB ────────────────
CREATE OR REPLACE FUNCTION public._rewrite_recipe_ingredient_name(p_old text, p_new text)
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_rec   record;
  v_secs  jsonb;
  v_sec   jsonb;
  v_items jsonb;
  v_item  jsonb;
  v_new_items jsonb;
  v_changed   boolean;
  v_recipes   int := 0;
BEGIN
  IF p_old IS NULL OR btrim(p_old) = '' OR p_new IS NULL OR btrim(p_new) = '' THEN
    RETURN 0;
  END IF;
  IF lower(btrim(p_old)) = lower(btrim(p_new)) THEN
    RETURN 0;
  END IF;

  FOR v_rec IN
    SELECT id, ingredients
    FROM public.submitted_recipes
    WHERE ingredients IS NOT NULL
      AND EXISTS (
        SELECT 1
        FROM jsonb_array_elements(ingredients) sec,
             jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
        WHERE lower(btrim(item->>'ingredient')) = lower(btrim(p_old))
      )
  LOOP
    v_secs := '[]'::jsonb;
    v_changed := false;

    FOR v_sec IN SELECT value FROM jsonb_array_elements(v_rec.ingredients) AS t(value)
    LOOP
      v_new_items := '[]'::jsonb;
      FOR v_item IN SELECT value FROM jsonb_array_elements(COALESCE(v_sec->'items', '[]'::jsonb)) AS t(value)
      LOOP
        IF lower(btrim(v_item->>'ingredient')) = lower(btrim(p_old)) THEN
          v_item := jsonb_set(v_item, '{ingredient}', to_jsonb(btrim(p_new)));
          v_changed := true;
        END IF;
        v_new_items := v_new_items || jsonb_build_array(v_item);
      END LOOP;
      v_sec := jsonb_set(v_sec, '{items}', v_new_items);
      v_secs := v_secs || jsonb_build_array(v_sec);
    END LOOP;

    IF v_changed THEN
      UPDATE public.submitted_recipes SET ingredients = v_secs WHERE id = v_rec.id;
      v_recipes := v_recipes + 1;
    END IF;
  END LOOP;

  RETURN v_recipes;
END; $$;

-- ── 4. Sync linked library profiles when governed ingredient changes ───
CREATE OR REPLACE FUNCTION public._sync_library_profiles_for_ingredient(
  p_ingredient_id int, p_new_name text, p_old_name text DEFAULT NULL, p_new_aka text DEFAULT NULL
)
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count int;
BEGIN
  UPDATE public.library_profiles
  SET
    name = CASE
      WHEN p_old_name IS NOT NULL
           AND lower(btrim(name)) = lower(btrim(p_old_name))
      THEN btrim(p_new_name)
      ELSE name
    END,
    also_known_as = COALESCE(NULLIF(btrim(p_new_aka), ''), also_known_as),
    updated_at = now()
  WHERE profile_type = 'ingredient'
    AND governed_ingredient_id = p_ingredient_id;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END; $$;

-- ── 5. Preview amend impact ───────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_preview_ingredient_amend(int, text);
CREATE FUNCTION public.admin_preview_ingredient_amend(p_id int, p_new_name text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_old_name text;
  v_recipe_count int := 0;
  v_profile_count int := 0;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  SELECT "Ingredient Name" INTO v_old_name FROM ingredients WHERE "ID" = p_id;
  IF v_old_name IS NULL THEN RAISE EXCEPTION 'Ingredient not found'; END IF;

  IF p_new_name IS NOT NULL AND btrim(p_new_name) <> ''
     AND lower(btrim(p_new_name)) <> lower(btrim(v_old_name)) THEN
    SELECT count(*)::int INTO v_recipe_count
    FROM submitted_recipes sr
    WHERE sr.ingredients IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM jsonb_array_elements(sr.ingredients) sec,
             jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
        WHERE lower(btrim(item->>'ingredient')) = lower(btrim(v_old_name))
      );
  END IF;

  SELECT count(*)::int INTO v_profile_count
  FROM library_profiles
  WHERE profile_type = 'ingredient' AND governed_ingredient_id = p_id;

  RETURN jsonb_build_object(
    'ingredient_id', p_id,
    'old_name', v_old_name,
    'new_name', COALESCE(NULLIF(btrim(p_new_name), ''), v_old_name),
    'name_will_change', (p_new_name IS NOT NULL AND btrim(p_new_name) <> ''
      AND lower(btrim(p_new_name)) <> lower(btrim(v_old_name))),
    'recipes_affected', v_recipe_count,
    'library_profiles_linked', v_profile_count
  );
END; $$;
REVOKE ALL ON FUNCTION public.admin_preview_ingredient_amend(int,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_preview_ingredient_amend(int,text) TO authenticated;

-- ── 6. Enhanced upsert — propagates rename to recipes + library ───────
DROP FUNCTION IF EXISTS public.admin_upsert_ingredient(int, text, text, text, text, text, float8, text, text, text, text, text, text, text, jsonb);
CREATE FUNCTION public.admin_upsert_ingredient(
  p_id integer DEFAULT NULL,
  p_ingredient_name text DEFAULT NULL, p_also_known_as text DEFAULT NULL,
  p_category text DEFAULT NULL, p_sub_category text DEFAULT NULL,
  p_standard_qty text DEFAULT NULL, p_standard_weight float8 DEFAULT NULL,
  p_unit text DEFAULT NULL, p_liquid text DEFAULT NULL,
  p_cj_recommended_brand text DEFAULT NULL, p_allergen text DEFAULT NULL,
  p_vegan text DEFAULT NULL, p_vegetarian text DEFAULT NULL,
  p_notes text DEFAULT NULL, p_extra_fields jsonb DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_id int;
  v_old_name text;
  v_new_name text;
  v_recipes_updated int := 0;
  v_profiles_synced int := 0;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  v_new_name := NULLIF(btrim(p_ingredient_name), '');

  IF p_id IS NOT NULL THEN
    SELECT "Ingredient Name" INTO v_old_name FROM ingredients WHERE "ID" = p_id;
    IF v_old_name IS NULL THEN RAISE EXCEPTION 'Ingredient not found'; END IF;

    UPDATE ingredients SET
      "Ingredient Name"       = COALESCE(v_new_name, "Ingredient Name"),
      "Also Known As"         = COALESCE(NULLIF(btrim(p_also_known_as), ''), "Also Known As"),
      "Category"              = COALESCE(NULLIF(btrim(p_category), ''), "Category"),
      "Sub Category"          = COALESCE(NULLIF(btrim(p_sub_category), ''), "Sub Category"),
      "Standard Qty"          = COALESCE(NULLIF(btrim(p_standard_qty), ''), "Standard Qty"),
      "Standard Weight (g or ml)" = COALESCE(p_standard_weight, "Standard Weight (g or ml)"),
      "Unit"                  = COALESCE(NULLIF(btrim(p_unit), ''), "Unit"),
      "Liquid (Yes/No)"       = COALESCE(NULLIF(btrim(p_liquid), ''), "Liquid (Yes/No)"),
      "CJ Recommended Brand"  = COALESCE(NULLIF(btrim(p_cj_recommended_brand), ''), "CJ Recommended Brand"),
      "Allergen"              = COALESCE(NULLIF(btrim(p_allergen), ''), "Allergen"),
      "Vegan (Yes/No)"        = COALESCE(NULLIF(btrim(p_vegan), ''), "Vegan (Yes/No)"),
      "Vegetarian (Yes/No)"   = COALESCE(NULLIF(btrim(p_vegetarian), ''), "Vegetarian (Yes/No)"),
      "Notes"                 = COALESCE(NULLIF(btrim(p_notes), ''), "Notes"),
      extra_fields            = CASE
        WHEN p_extra_fields IS NOT NULL THEN COALESCE(extra_fields, '{}'::jsonb) || p_extra_fields
        ELSE extra_fields
      END
    WHERE "ID" = p_id RETURNING "ID" INTO v_id;

    IF v_new_name IS NOT NULL AND lower(btrim(v_new_name)) <> lower(btrim(v_old_name)) THEN
      v_recipes_updated := _rewrite_recipe_ingredient_name(v_old_name, v_new_name);
      v_profiles_synced := _sync_library_profiles_for_ingredient(p_id, v_new_name, v_old_name, p_also_known_as);
    END IF;

    RETURN jsonb_build_object(
      'id', v_id, 'action', 'updated',
      'recipes_updated', v_recipes_updated,
      'library_profiles_synced', v_profiles_synced
    );
  ELSE
    IF v_new_name IS NULL THEN RAISE EXCEPTION 'Ingredient name is required'; END IF;
    INSERT INTO ingredients (
      "Ingredient Name","Also Known As","Category","Sub Category","Standard Qty",
      "Standard Weight (g or ml)","Unit","Liquid (Yes/No)","CJ Recommended Brand",
      "Allergen","Vegan (Yes/No)","Vegetarian (Yes/No)","Notes","extra_fields"
    ) VALUES (
      v_new_name, NULLIF(btrim(p_also_known_as), ''),
      NULLIF(btrim(p_category), ''), NULLIF(btrim(p_sub_category), ''),
      NULLIF(btrim(p_standard_qty), ''), p_standard_weight,
      NULLIF(btrim(p_unit), ''), NULLIF(btrim(p_liquid), ''),
      NULLIF(btrim(p_cj_recommended_brand), ''), NULLIF(btrim(p_allergen), ''),
      NULLIF(btrim(p_vegan), ''), NULLIF(btrim(p_vegetarian), ''),
      NULLIF(btrim(p_notes), ''), COALESCE(p_extra_fields, '{}'::jsonb)
    ) RETURNING "ID" INTO v_id;
    RETURN jsonb_build_object('id', v_id, 'action', 'inserted', 'recipes_updated', 0, 'library_profiles_synced', 0);
  END IF;
END; $$;
REVOKE ALL ON FUNCTION public.admin_upsert_ingredient(int,text,text,text,text,text,float8,text,text,text,text,text,text,text,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_upsert_ingredient(int,text,text,text,text,text,float8,text,text,text,text,text,text,text,jsonb) TO authenticated;

-- ── 7. Guarded delete ─────────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_delete_ingredient(int);
DROP FUNCTION IF EXISTS public.admin_delete_ingredient(int, boolean);
CREATE FUNCTION public.admin_delete_ingredient(p_id int, p_force boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_name text;
  v_recipe_count int := 0;
  v_profile_count int := 0;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  SELECT "Ingredient Name" INTO v_name FROM ingredients WHERE "ID" = p_id;
  IF v_name IS NULL THEN RAISE EXCEPTION 'Ingredient not found'; END IF;

  SELECT count(*)::int INTO v_recipe_count
  FROM submitted_recipes sr
  WHERE sr.ingredients IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM jsonb_array_elements(sr.ingredients) sec,
           jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
      WHERE lower(btrim(item->>'ingredient')) = lower(btrim(v_name))
    );

  SELECT count(*)::int INTO v_profile_count
  FROM library_profiles
  WHERE profile_type = 'ingredient' AND governed_ingredient_id = p_id;

  IF NOT p_force AND (v_recipe_count > 0 OR v_profile_count > 0) THEN
    RETURN jsonb_build_object(
      'blocked', true,
      'ingredient_id', p_id,
      'ingredient_name', v_name,
      'recipes_using', v_recipe_count,
      'library_profiles_linked', v_profile_count,
      'message', 'Ingredient is in use. Pass p_force=true to delete anyway (library links will be cleared).'
    );
  END IF;

  DELETE FROM ingredients WHERE "ID" = p_id;
  RETURN jsonb_build_object(
    'blocked', false, 'deleted', true,
    'ingredient_id', p_id, 'ingredient_name', v_name,
    'recipes_had', v_recipe_count, 'profiles_unlinked', v_profile_count
  );
END; $$;
REVOKE ALL ON FUNCTION public.admin_delete_ingredient(int,boolean) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_delete_ingredient(int,boolean) TO authenticated;

-- ── 8. Bulk normalise recipe ingredient spellings (10k migration) ─────
DROP FUNCTION IF EXISTS public.admin_bulk_normalize_recipe_ingredients(int, int);
CREATE FUNCTION public.admin_bulk_normalize_recipe_ingredients(
  p_limit int DEFAULT 100, p_offset int DEFAULT 0
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_rec       record;
  v_secs      jsonb;
  v_sec       jsonb;
  v_items     jsonb;
  v_item      jsonb;
  v_new_items jsonb;
  v_canonical text;
  v_changed   boolean;
  v_recipes   int := 0;
  v_items_fixed int := 0;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;
  p_limit := GREATEST(1, LEAST(COALESCE(p_limit, 100), 500));
  p_offset := GREATEST(0, COALESCE(p_offset, 0));

  FOR v_rec IN
    SELECT id, ingredients
    FROM submitted_recipes
    WHERE ingredients IS NOT NULL
    ORDER BY id
    LIMIT p_limit OFFSET p_offset
  LOOP
    v_secs := '[]'::jsonb;
    v_changed := false;

    FOR v_sec IN SELECT value FROM jsonb_array_elements(v_rec.ingredients) AS t(value)
    LOOP
      v_new_items := '[]'::jsonb;
      FOR v_item IN SELECT value FROM jsonb_array_elements(COALESCE(v_sec->'items', '[]'::jsonb)) AS t(value)
      LOOP
        v_canonical := NULL;
        SELECT i."Ingredient Name" INTO v_canonical
        FROM ingredients i
        WHERE lower(btrim(i."Ingredient Name")) = lower(btrim(v_item->>'ingredient'))
        LIMIT 1;

        IF v_canonical IS NULL THEN
          SELECT i."Ingredient Name" INTO v_canonical
          FROM ingredients i
          WHERE i."Also Known As" IS NOT NULL
            AND lower(btrim(i."Also Known As")) = lower(btrim(v_item->>'ingredient'))
          LIMIT 1;
        END IF;

        IF v_canonical IS NOT NULL AND v_item->>'ingredient' IS DISTINCT FROM v_canonical THEN
          v_item := jsonb_set(v_item, '{ingredient}', to_jsonb(v_canonical));
          v_changed := true;
          v_items_fixed := v_items_fixed + 1;
        END IF;
        v_new_items := v_new_items || jsonb_build_array(v_item);
      END LOOP;
      v_sec := jsonb_set(v_sec, '{items}', v_new_items);
      v_secs := v_secs || jsonb_build_array(v_sec);
    END LOOP;

    IF v_changed THEN
      UPDATE submitted_recipes SET ingredients = v_secs WHERE id = v_rec.id;
      v_recipes := v_recipes + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'recipes_updated', v_recipes,
    'ingredient_lines_fixed', v_items_fixed,
    'batch_limit', p_limit,
    'batch_offset', p_offset
  );
END; $$;
REVOKE ALL ON FUNCTION public.admin_bulk_normalize_recipe_ingredients(int,int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_bulk_normalize_recipe_ingredients(int,int) TO authenticated;

-- ── 9. Full integrity report ──────────────────────────────────────────
DROP FUNCTION IF EXISTS public.admin_data_integrity_report();
CREATE FUNCTION public.admin_data_integrity_report()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_invalid_governed int;
  v_name_mismatch int;
  v_dupes int;
  v_orphan_recipe_names int;
  v_total_recipes int;
  v_total_ingredients int;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;

  SELECT count(*)::int INTO v_total_recipes FROM submitted_recipes;
  SELECT count(*)::int INTO v_total_ingredients FROM ingredients;

  SELECT count(*)::int INTO v_invalid_governed
  FROM library_profiles lp
  WHERE lp.profile_type = 'ingredient'
    AND lp.governed_ingredient_id IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM ingredients i WHERE i."ID" = lp.governed_ingredient_id);

  SELECT count(*)::int INTO v_name_mismatch
  FROM library_profiles lp
  JOIN ingredients i ON i."ID" = lp.governed_ingredient_id
  WHERE lp.profile_type = 'ingredient'
    AND lower(btrim(lp.name)) <> lower(btrim(i."Ingredient Name"));

  SELECT count(*)::int INTO v_dupes
  FROM (
    SELECT lower(btrim("Ingredient Name")) AS n
    FROM ingredients
    WHERE "Ingredient Name" IS NOT NULL AND btrim("Ingredient Name") <> ''
    GROUP BY 1 HAVING count(*) > 1
  ) d;

  SELECT count(DISTINCT x.ing_name)::int INTO v_orphan_recipe_names
  FROM (
    SELECT lower(btrim(item->>'ingredient')) AS ing_name
    FROM submitted_recipes sr,
         jsonb_array_elements(COALESCE(sr.ingredients, '[]'::jsonb)) sec,
         jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
    WHERE sr.status = 'approved'
      AND btrim(COALESCE(item->>'ingredient', '')) <> ''
  ) x
  WHERE NOT EXISTS (
    SELECT 1 FROM ingredients i
    WHERE lower(btrim(i."Ingredient Name")) = x.ing_name
       OR lower(btrim(COALESCE(i."Also Known As", ''))) = x.ing_name
  );

  RETURN jsonb_build_object(
    'totals', jsonb_build_object(
      'recipes', v_total_recipes,
      'ingredients', v_total_ingredients
    ),
    'issues', jsonb_build_object(
      'invalid_governed_links', v_invalid_governed,
      'library_name_mismatches', v_name_mismatch,
      'duplicate_ingredient_names', v_dupes,
      'orphan_recipe_ingredient_names', v_orphan_recipe_names
    ),
    'healthy', (v_invalid_governed = 0 AND v_dupes = 0 AND v_orphan_recipe_names = 0)
  );
END; $$;
REVOKE ALL ON FUNCTION public.admin_data_integrity_report() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_data_integrity_report() TO authenticated;

-- ── 10. Compact ingredient index for client pages (no 500 cap) ────────
DROP FUNCTION IF EXISTS public.get_ingredient_lookup_index();
CREATE FUNCTION public.get_ingredient_lookup_index()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT COALESCE(jsonb_agg(jsonb_build_object(
    'id', i."ID",
    'name', i."Ingredient Name",
    'aka', i."Also Known As",
    'category', i."Category",
    'unit', i."Unit",
    'allergen', i."Allergen",
    'brand', i."CJ Recommended Brand"
  ) ORDER BY i."Ingredient Name"), '[]'::jsonb)
  FROM public.ingredients i
  WHERE i."Ingredient Name" IS NOT NULL AND btrim(i."Ingredient Name") <> '';
$$;
REVOKE ALL ON FUNCTION public.get_ingredient_lookup_index() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_ingredient_lookup_index() TO anon, authenticated;

SELECT 'fix-phase39-data-integrity ready' AS status;
-- ########## END: fix-phase39-data-integrity.sql ##########

-- ########## BEGIN: fix-phase39b-sql-editor-admin.sql ##########
-- fix-phase39b-sql-editor-admin.sql
-- Lets you run integrity + normalise from Supabase SQL Editor (postgres role).
-- Safe to re-run. Run AFTER fix-phase39.

CREATE OR REPLACE FUNCTION public.admin_data_integrity_report_sql()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_invalid_governed int;
  v_name_mismatch int;
  v_dupes int;
  v_orphan_recipe_names int;
  v_total_recipes int;
  v_total_ingredients int;
BEGIN
  IF current_user NOT IN ('postgres', 'supabase_admin', 'service_role')
     AND (auth.uid() IS NULL OR NOT is_admin()) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  SELECT count(*)::int INTO v_total_recipes FROM submitted_recipes;
  SELECT count(*)::int INTO v_total_ingredients FROM ingredients;

  SELECT count(*)::int INTO v_invalid_governed
  FROM library_profiles lp
  WHERE lp.profile_type = 'ingredient'
    AND lp.governed_ingredient_id IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM ingredients i WHERE i."ID" = lp.governed_ingredient_id);

  SELECT count(*)::int INTO v_name_mismatch
  FROM library_profiles lp
  JOIN ingredients i ON i."ID" = lp.governed_ingredient_id
  WHERE lp.profile_type = 'ingredient'
    AND lower(btrim(lp.name)) <> lower(btrim(i."Ingredient Name"));

  SELECT count(*)::int INTO v_dupes
  FROM (
    SELECT lower(btrim("Ingredient Name")) AS n
    FROM ingredients
    WHERE "Ingredient Name" IS NOT NULL AND btrim("Ingredient Name") <> ''
    GROUP BY 1 HAVING count(*) > 1
  ) d;

  SELECT count(DISTINCT x.ing_name)::int INTO v_orphan_recipe_names
  FROM (
    SELECT lower(btrim(item->>'ingredient')) AS ing_name
    FROM submitted_recipes sr,
         jsonb_array_elements(COALESCE(sr.ingredients, '[]'::jsonb)) sec,
         jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
    WHERE sr.status = 'approved'
      AND btrim(COALESCE(item->>'ingredient', '')) <> ''
  ) x
  WHERE NOT EXISTS (
    SELECT 1 FROM ingredients i
    WHERE lower(btrim(i."Ingredient Name")) = x.ing_name
       OR lower(btrim(COALESCE(i."Also Known As", ''))) = x.ing_name
  );

  RETURN jsonb_build_object(
    'totals', jsonb_build_object('recipes', v_total_recipes, 'ingredients', v_total_ingredients),
    'issues', jsonb_build_object(
      'invalid_governed_links', v_invalid_governed,
      'library_name_mismatches', v_name_mismatch,
      'duplicate_ingredient_names', v_dupes,
      'orphan_recipe_ingredient_names', v_orphan_recipe_names
    ),
    'healthy', (v_invalid_governed = 0 AND v_dupes = 0 AND v_orphan_recipe_names = 0)
  );
END; $$;

REVOKE ALL ON FUNCTION public.admin_data_integrity_report_sql() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_data_integrity_report_sql() TO postgres, service_role;

SELECT 'fix-phase39b ready — run: SELECT admin_data_integrity_report_sql();' AS status;
-- ########## END: fix-phase39b-sql-editor-admin.sql ##########

-- ########## BEGIN: fix-phase40-meal-planner-picker.sql ##########
-- fix-phase40-meal-planner-picker.sql
-- Meal planner: search full approved library (name, native title, AKA).
-- Safe to re-run.

ALTER TABLE public.submitted_recipes ADD COLUMN IF NOT EXISTS also_known_as text DEFAULT '';

DROP FUNCTION IF EXISTS public.get_approved_recipes(text, text, text, text, text, text, int, int);

CREATE OR REPLACE FUNCTION public.get_approved_recipes(
  p_category     text DEFAULT NULL,
  p_spice        text DEFAULT NULL,
  p_dietary      text DEFAULT NULL,
  p_search       text DEFAULT NULL,
  p_sub_category text DEFAULT NULL,
  p_division     text DEFAULT NULL,
  p_limit        int  DEFAULT 50,
  p_offset       int  DEFAULT 0
)
RETURNS TABLE (
  id                  uuid,
  recipe_name         text,
  native_title        text,
  also_known_as       text,
  category            text,
  sub_category        text,
  division            text,
  spice_level         text,
  dietary_tags        text[],
  origin_country      text,
  image_url           text,
  credit_name         text,
  credit_handle       text,
  submitted_at        timestamptz,
  username            text,
  prep_time_minutes   int,
  cook_time_minutes   int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  p_limit  := GREATEST(1, LEAST(COALESCE(p_limit, 50), 100));
  p_offset := GREATEST(0, COALESCE(p_offset, 0));

  RETURN QUERY
  SELECT sr.id, sr.recipe_name, sr.native_title, sr.also_known_as, sr.category,
         sr.sub_category, sr.division,
         sr.spice_level, sr.dietary_tags, sr.origin_country,
         sr.image_url, sr.credit_name, sr.credit_handle,
         sr.submitted_at, p.username,
         COALESCE(sr.prep_time_minutes, 0)::int,
         COALESCE(sr.cook_time_minutes, 0)::int
    FROM public.submitted_recipes sr
    LEFT JOIN public.profiles p ON p.id = sr.user_id
   WHERE sr.status = 'approved'
     AND (
       sr.visibility = 'Public'
       OR (
         sr.visibility = 'Friends'
         AND auth.uid() IS NOT NULL
         AND EXISTS (
           SELECT 1 FROM public.contributor_follows cf
            WHERE cf.follower_id = auth.uid() AND cf.following_id = sr.user_id
         )
       )
     )
     AND (p_category     IS NULL OR btrim(p_category) = '' OR sr.category = p_category)
     AND (p_spice        IS NULL OR btrim(p_spice) = '' OR sr.spice_level = p_spice)
     AND (p_dietary      IS NULL OR btrim(p_dietary) = '' OR p_dietary = ANY(sr.dietary_tags))
     AND (
       p_search IS NULL OR btrim(p_search) = ''
       OR sr.recipe_name ILIKE '%' || btrim(p_search) || '%'
       OR sr.native_title ILIKE '%' || btrim(p_search) || '%'
       OR sr.also_known_as ILIKE '%' || btrim(p_search) || '%'
     )
     AND (p_sub_category IS NULL OR btrim(p_sub_category) = '' OR sr.sub_category = p_sub_category)
     AND (p_division     IS NULL OR btrim(p_division) = '' OR sr.division = p_division)
   ORDER BY
     CASE WHEN p_search IS NOT NULL AND btrim(p_search) <> '' THEN
       CASE WHEN lower(sr.recipe_name) = lower(btrim(p_search)) THEN 0
            WHEN sr.recipe_name ILIKE btrim(p_search) || '%' THEN 1
            ELSE 2 END
     ELSE 2 END,
     sr.submitted_at DESC
   LIMIT p_limit OFFSET p_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_approved_recipes(text,text,text,text,text,text,int,int) TO anon, authenticated;

SELECT 'fix-phase40-meal-planner-picker ready' AS status;
-- ########## END: fix-phase40-meal-planner-picker.sql ##########

-- ########## BEGIN: fix-phase41-browse-pagination.sql ##########
-- fix-phase41-browse-pagination.sql
-- Server-side contributor filter + paginated public browse/search.
-- Safe to re-run.

DROP FUNCTION IF EXISTS public.get_approved_recipes(text, text, text, text, text, text, int, int);

CREATE OR REPLACE FUNCTION public.get_approved_recipes(
  p_category     text DEFAULT NULL,
  p_spice        text DEFAULT NULL,
  p_dietary      text DEFAULT NULL,
  p_search       text DEFAULT NULL,
  p_sub_category text DEFAULT NULL,
  p_division     text DEFAULT NULL,
  p_username     text DEFAULT NULL,
  p_credit_name  text DEFAULT NULL,
  p_limit        int  DEFAULT 48,
  p_offset       int  DEFAULT 0
)
RETURNS TABLE (
  id                  uuid,
  recipe_name         text,
  native_title        text,
  also_known_as       text,
  category            text,
  sub_category        text,
  division            text,
  spice_level         text,
  dietary_tags        text[],
  origin_country      text,
  image_url           text,
  credit_name         text,
  credit_handle       text,
  submitted_at        timestamptz,
  username            text,
  prep_time_minutes   int,
  cook_time_minutes   int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  p_limit  := GREATEST(1, LEAST(COALESCE(p_limit, 48), 100));
  p_offset := GREATEST(0, COALESCE(p_offset, 0));

  RETURN QUERY
  SELECT sr.id, sr.recipe_name, sr.native_title, sr.also_known_as, sr.category,
         sr.sub_category, sr.division,
         sr.spice_level, sr.dietary_tags, sr.origin_country,
         sr.image_url, sr.credit_name, sr.credit_handle,
         sr.submitted_at, p.username,
         COALESCE(sr.prep_time_minutes, 0)::int,
         COALESCE(sr.cook_time_minutes, 0)::int
    FROM public.submitted_recipes sr
    LEFT JOIN public.profiles p ON p.id = sr.user_id
   WHERE sr.status = 'approved'
     AND (
       sr.visibility = 'Public'
       OR (
         sr.visibility = 'Friends'
         AND auth.uid() IS NOT NULL
         AND EXISTS (
           SELECT 1 FROM public.contributor_follows cf
            WHERE cf.follower_id = auth.uid() AND cf.following_id = sr.user_id
         )
       )
     )
     AND (p_category     IS NULL OR btrim(p_category) = '' OR sr.category = p_category)
     AND (p_spice        IS NULL OR btrim(p_spice) = '' OR sr.spice_level = p_spice)
     AND (p_dietary      IS NULL OR btrim(p_dietary) = '' OR p_dietary = ANY(sr.dietary_tags))
     AND (
       p_search IS NULL OR btrim(p_search) = ''
       OR sr.recipe_name ILIKE '%' || btrim(p_search) || '%'
       OR sr.native_title ILIKE '%' || btrim(p_search) || '%'
       OR sr.also_known_as ILIKE '%' || btrim(p_search) || '%'
       OR sr.category ILIKE '%' || btrim(p_search) || '%'
       OR sr.origin_country ILIKE '%' || btrim(p_search) || '%'
     )
     AND (p_sub_category IS NULL OR btrim(p_sub_category) = '' OR sr.sub_category = p_sub_category)
     AND (p_division     IS NULL OR btrim(p_division) = '' OR sr.division = p_division)
     AND (
       p_username IS NULL OR btrim(p_username) = ''
       OR lower(p.username) = lower(btrim(p_username))
     )
     AND (
       p_credit_name IS NULL OR btrim(p_credit_name) = ''
       OR lower(btrim(sr.credit_name)) = lower(btrim(p_credit_name))
     )
   ORDER BY
     CASE WHEN p_search IS NOT NULL AND btrim(p_search) <> '' THEN
       CASE WHEN lower(sr.recipe_name) = lower(btrim(p_search)) THEN 0
            WHEN sr.recipe_name ILIKE btrim(p_search) || '%' THEN 1
            ELSE 2 END
     ELSE 2 END,
     sr.submitted_at DESC
   LIMIT p_limit OFFSET p_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_approved_recipes(text,text,text,text,text,text,text,text,int,int) TO anon, authenticated;

-- Ingredient search pagination
DROP FUNCTION IF EXISTS public.search_ingredients(text, int);

CREATE OR REPLACE FUNCTION public.search_ingredients(
  p_query  text DEFAULT '',
  p_limit  int  DEFAULT 20,
  p_offset int  DEFAULT 0
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  p_limit  := GREATEST(1, LEAST(COALESCE(p_limit, 20), 50));
  p_offset := GREATEST(0, COALESCE(p_offset, 0));

  RETURN COALESCE(
    (SELECT jsonb_agg(r)
     FROM (
       SELECT
         "ID"              AS id,
         "Ingredient Name" AS ingredient_name,
         "Also Known As"   AS also_known_as,
         "Category"        AS category,
         "Allergen"        AS allergen,
         "Vegan (Yes/No)"  AS vegan
       FROM ingredients
       WHERE p_query = '' OR btrim(p_query) = ''
          OR "Ingredient Name" ILIKE '%' || btrim(p_query) || '%'
          OR "Also Known As"   ILIKE '%' || btrim(p_query) || '%'
       ORDER BY "Ingredient Name" ASC
       LIMIT p_limit OFFSET p_offset
     ) r),
    '[]'::jsonb
  );
END;
$$;

REVOKE ALL ON FUNCTION public.search_ingredients(text, int, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.search_ingredients(text, int, int) TO anon, authenticated;

SELECT pg_notify('pgrst', 'reload schema');
SELECT 'fix-phase41-browse-pagination ready' AS status;
-- ########## END: fix-phase41-browse-pagination.sql ##########

-- ########## BEGIN: fix-phase42-scale-mitigation.sql ##########
-- fix-phase42-scale-mitigation.sql
-- Server-side stats, chef directory, baby browse, ingredient-linked recipes, admin search offset.
-- Safe to re-run.

-- ── 1. Homepage trust strip counts (no full-table REST fetch) ─────────
DROP FUNCTION IF EXISTS public.get_public_site_stats();
CREATE OR REPLACE FUNCTION public.get_public_site_stats()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT jsonb_build_object(
    'recipes', (SELECT count(*)::int FROM public.submitted_recipes WHERE status = 'approved'),
    'countries', (
      SELECT count(DISTINCT origin_country)::int FROM public.submitted_recipes
      WHERE status = 'approved' AND origin_country IS NOT NULL AND btrim(origin_country) <> ''
    ),
    'contributors', (
      SELECT count(DISTINCT user_id)::int FROM public.submitted_recipes
      WHERE status = 'approved' AND user_id IS NOT NULL
    ),
    'collections', (SELECT count(*)::int FROM public.collections WHERE is_public = true)
  );
$$;
GRANT EXECUTE ON FUNCTION public.get_public_site_stats() TO anon, authenticated;

-- ── 2. Chef directory (aggregated — no 100-recipe cap) ────────────────
DROP FUNCTION IF EXISTS public.get_chef_directory();
CREATE OR REPLACE FUNCTION public.get_chef_directory()
RETURNS TABLE (
  chef_name       text,
  credit_handle   text,
  username        text,
  recipe_count    bigint,
  countries       text[],
  categories      text[],
  is_cj_original  boolean
)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT
    btrim(sr.credit_name) AS chef_name,
    max(sr.credit_handle) AS credit_handle,
    max(p.username)       AS username,
    count(*)::bigint      AS recipe_count,
    array_remove(array_agg(DISTINCT sr.origin_country), NULL) AS countries,
    array_remove(array_agg(DISTINCT sr.category), NULL)       AS categories,
    bool_or(sr.source_type = 'Original') AS is_cj_original
  FROM public.submitted_recipes sr
  LEFT JOIN public.profiles p ON p.id = sr.user_id
  WHERE sr.status = 'approved'
    AND sr.visibility = 'Public'
    AND btrim(coalesce(sr.credit_name, '')) <> ''
  GROUP BY btrim(sr.credit_name)
  ORDER BY count(*) DESC, btrim(sr.credit_name) ASC;
$$;
GRANT EXECUTE ON FUNCTION public.get_chef_directory() TO anon, authenticated;

-- ── 3. Baby food browse (ingredients + tags for safety filters) ─────
DROP FUNCTION IF EXISTS public.get_baby_browse_recipes(int, int);
CREATE OR REPLACE FUNCTION public.get_baby_browse_recipes(
  p_limit  int DEFAULT 48,
  p_offset int DEFAULT 0
)
RETURNS TABLE (
  id              uuid,
  recipe_name     text,
  category        text,
  origin_country  text,
  image_url       text,
  dietary_tags    text[],
  occasion_tags   text[],
  health_tags     text[],
  ingredients     jsonb
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
BEGIN
  p_limit  := GREATEST(1, LEAST(COALESCE(p_limit, 48), 100));
  p_offset := GREATEST(0, COALESCE(p_offset, 0));

  RETURN QUERY
  SELECT sr.id, sr.recipe_name, sr.category, sr.origin_country, sr.image_url,
         sr.dietary_tags, sr.occasion_tags, sr.health_tags, sr.ingredients
    FROM public.submitted_recipes sr
   WHERE sr.status = 'approved'
     AND sr.visibility = 'Public'
     AND sr.category = 'Little Ones'
   ORDER BY sr.submitted_at DESC
   LIMIT p_limit OFFSET p_offset;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_baby_browse_recipes(int, int) TO anon, authenticated;

-- ── 4. Recipes using a governed ingredient (library profile links) ────
DROP FUNCTION IF EXISTS public.get_recipes_using_ingredient(int, int, int);
CREATE OR REPLACE FUNCTION public.get_recipes_using_ingredient(
  p_ingredient_id int,
  p_limit         int DEFAULT 12,
  p_offset        int DEFAULT 0
)
RETURNS TABLE (
  id          uuid,
  recipe_name text,
  image_url   text
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_names text[] := ARRAY[]::text[];
  v_aka   text;
  v_part  text;
BEGIN
  p_limit  := GREATEST(1, LEAST(COALESCE(p_limit, 12), 48));
  p_offset := GREATEST(0, COALESCE(p_offset, 0));

  IF p_ingredient_id IS NULL THEN RETURN; END IF;

  SELECT array_agg(DISTINCT lower(btrim(n)))
  INTO v_names
  FROM (
    SELECT i."Ingredient Name" AS n FROM ingredients i WHERE i."ID" = p_ingredient_id
    UNION ALL
    SELECT unnest(string_to_array(coalesce(i."Also Known As", ''), ',')) AS n
    FROM ingredients i WHERE i."ID" = p_ingredient_id
  ) raw
  WHERE n IS NOT NULL AND btrim(n) <> '';

  IF v_names IS NULL OR array_length(v_names, 1) IS NULL THEN RETURN; END IF;

  RETURN QUERY
  SELECT DISTINCT sr.id, sr.recipe_name, sr.image_url
    FROM public.submitted_recipes sr,
         jsonb_array_elements(COALESCE(sr.ingredients, '[]'::jsonb)) sec,
         jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
   WHERE sr.status = 'approved'
     AND sr.visibility = 'Public'
     AND lower(btrim(item->>'ingredient')) = ANY(v_names)
   ORDER BY sr.recipe_name
   LIMIT p_limit OFFSET p_offset;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_recipes_using_ingredient(int, int, int) TO anon, authenticated;

-- ── 5. Admin festival search — pagination ───────────────────────────
DROP FUNCTION IF EXISTS public.admin_search_recipes(text, int);
CREATE OR REPLACE FUNCTION public.admin_search_recipes(
  p_query  text DEFAULT '',
  p_limit  int  DEFAULT 24,
  p_offset int  DEFAULT 0
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  p_limit  := GREATEST(1, LEAST(COALESCE(p_limit, 24), 100));
  p_offset := GREATEST(0, COALESCE(p_offset, 0));

  RETURN COALESCE(
    (SELECT jsonb_agg(row_to_json(r) ORDER BY r.recipe_name)
     FROM (
       SELECT id, recipe_name, category, origin_country
       FROM public.submitted_recipes
       WHERE status = 'approved'
         AND (p_query IS NULL OR btrim(p_query) = '' OR recipe_name ILIKE '%' || btrim(p_query) || '%')
       ORDER BY recipe_name
       LIMIT p_limit OFFSET p_offset
     ) r),
    '[]'::jsonb
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_search_recipes(text, int, int) TO authenticated;

SELECT pg_notify('pgrst', 'reload schema');
SELECT 'fix-phase42-scale-mitigation ready' AS status;
-- ########## END: fix-phase42-scale-mitigation.sql ##########

-- ########## BEGIN: fix-library-governed-links.sql ##########
-- fix-library-governed-links.sql
-- Re-link starter library profiles to the best governed ingredient match per slug.
-- Uses fuzzy rules (like fix-phase25-library-links-patch), not hardcoded display names.
-- Run in Supabase SQL Editor, then: SQL-EDITOR-health-check.sql

-- Preview current links
SELECT lp.slug, lp.name AS profile_name, lp.governed_ingredient_id,
       gi."Ingredient Name" AS governed_name
FROM library_profiles lp
LEFT JOIN ingredients gi ON gi."ID" = lp.governed_ingredient_id
WHERE lp.profile_type = 'ingredient'
  AND lp.slug IN (
    'garlic','onion','butter','rice','tomato','chicken-breast','salt',
    'ginger','egg','flour','potato','coconut','milk','capsicum','olive-oil'
  )
ORDER BY lp.slug;

-- garlic
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower(btrim("Ingredient Name")) = 'garlic'
     OR lower("Ingredient Name") LIKE 'garlic,%'
  ORDER BY
    CASE WHEN lower(btrim("Ingredient Name")) = 'garlic' THEN 0 ELSE 1 END,
    "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'garlic';

-- butter
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%butter%'
    AND lower("Ingredient Name") NOT LIKE '%peanut%'
    AND lower("Ingredient Name") NOT LIKE '%cocoa%'
    AND lower("Ingredient Name") NOT LIKE '%almond%'
    AND lower("Ingredient Name") NOT LIKE '%buttermilk%'
  ORDER BY
    CASE WHEN lower(btrim("Ingredient Name")) = 'butter' THEN 0
         WHEN lower("Ingredient Name") LIKE 'butter%' THEN 1
         WHEN lower("Ingredient Name") LIKE '%unsalted butter%' THEN 2
         ELSE 3 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'butter';

-- rice
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%rice%'
    AND lower("Ingredient Name") NOT LIKE '%rice paper%'
    AND lower("Ingredient Name") NOT LIKE '%rice wine%'
    AND lower("Ingredient Name") NOT LIKE '%rice vinegar%'
    AND lower("Ingredient Name") NOT LIKE '%rice flour%'
    AND lower("Ingredient Name") NOT LIKE '%rice noodle%'
  ORDER BY
    CASE WHEN lower(btrim("Ingredient Name")) = 'rice' THEN 0
         WHEN lower("Ingredient Name") LIKE 'rice,%' THEN 1
         WHEN lower("Ingredient Name") LIKE '%basmati%' THEN 2
         ELSE 3 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'rice';

-- salt
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%salt%'
    AND lower("Ingredient Name") NOT LIKE '%celery%'
    AND lower("Ingredient Name") NOT LIKE '%garlic salt%'
    AND lower("Ingredient Name") NOT LIKE '%onion salt%'
    AND lower("Ingredient Name") NOT LIKE '%seasoning%'
  ORDER BY
    CASE WHEN lower(btrim("Ingredient Name")) = 'salt' THEN 0
         WHEN lower("Ingredient Name") LIKE '%sea salt%' THEN 1
         WHEN lower("Ingredient Name") LIKE '%table salt%' THEN 2
         ELSE 3 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'salt';

-- onion
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%onion%'
    AND lower("Ingredient Name") NOT LIKE '%onion powder%'
    AND lower("Ingredient Name") NOT LIKE '%onion salt%'
    AND lower("Ingredient Name") NOT LIKE '%spring onion%'
    AND lower("Ingredient Name") NOT LIKE '%green onion%'
  ORDER BY
    CASE WHEN lower(btrim("Ingredient Name")) IN ('onion','onions') THEN 0
         WHEN lower("Ingredient Name") LIKE '%brown onion%' THEN 1
         WHEN lower("Ingredient Name") LIKE '%yellow onion%' THEN 2
         ELSE 3 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'onion';

-- tomato
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%tomato%'
    AND lower("Ingredient Name") NOT LIKE '%paste%'
    AND lower("Ingredient Name") NOT LIKE '%sauce%'
    AND lower("Ingredient Name") NOT LIKE '%ketchup%'
    AND lower("Ingredient Name") NOT LIKE '%puree%'
    AND lower("Ingredient Name") NOT LIKE '%purée%'
  ORDER BY
    CASE WHEN lower(btrim("Ingredient Name")) IN ('tomato','tomatoes') THEN 0
         WHEN lower("Ingredient Name") LIKE '%roma%' THEN 1
         ELSE 2 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'tomato';

-- chicken-breast
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%chicken%'
    AND lower("Ingredient Name") LIKE '%breast%'
    AND lower("Ingredient Name") NOT LIKE '%ground%'
    AND lower("Ingredient Name") NOT LIKE '%mince%'
  ORDER BY
    CASE WHEN lower(btrim("Ingredient Name")) LIKE '%chicken breast%' THEN 0 ELSE 1 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'chicken-breast';

-- ginger
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%ginger%'
    AND lower("Ingredient Name") NOT LIKE '%powder%'
    AND lower("Ingredient Name") NOT LIKE '%ground%'
  ORDER BY
    CASE WHEN lower(btrim("Ingredient Name")) = 'ginger' THEN 0
         WHEN lower("Ingredient Name") LIKE '%fresh ginger%' THEN 1
         ELSE 2 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'ginger';

-- egg
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%egg%'
    AND lower("Ingredient Name") NOT LIKE '%eggplant%'
    AND lower("Ingredient Name") NOT LIKE '%egg white%'
    AND lower("Ingredient Name") NOT LIKE '%egg yolk%'
  ORDER BY
    CASE WHEN lower(btrim("Ingredient Name")) IN ('egg','eggs') THEN 0 ELSE 1 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'egg';

-- flour
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%flour%'
    AND lower("Ingredient Name") NOT LIKE '%rice flour%'
    AND lower("Ingredient Name") NOT LIKE '%almond flour%'
    AND lower("Ingredient Name") NOT LIKE '%coconut flour%'
  ORDER BY
    CASE WHEN lower("Ingredient Name") LIKE '%plain flour%' THEN 0
         WHEN lower(btrim("Ingredient Name")) = 'flour' THEN 1
         WHEN lower("Ingredient Name") LIKE '%all purpose%' THEN 2
         ELSE 3 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'flour';

-- potato
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%potato%'
    AND lower("Ingredient Name") NOT LIKE '%sweet potato%'
    AND lower("Ingredient Name") NOT LIKE '%potato starch%'
  ORDER BY
    CASE WHEN lower(btrim("Ingredient Name")) = 'potato' THEN 0
         WHEN lower("Ingredient Name") LIKE '%sebago%' THEN 1
         ELSE 2 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'potato';

-- coconut
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%coconut%'
    AND lower("Ingredient Name") NOT LIKE '%coconut oil%'
    AND lower("Ingredient Name") NOT LIKE '%coconut milk%'
    AND lower("Ingredient Name") NOT LIKE '%coconut cream%'
  ORDER BY
    CASE WHEN lower("Ingredient Name") LIKE '%desiccated%' THEN 0
         WHEN lower(btrim("Ingredient Name")) = 'coconut' THEN 1
         ELSE 2 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'coconut';

-- milk
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%milk%'
    AND lower("Ingredient Name") NOT LIKE '%coconut milk%'
    AND lower("Ingredient Name") NOT LIKE '%almond milk%'
    AND lower("Ingredient Name") NOT LIKE '%oat milk%'
    AND lower("Ingredient Name") NOT LIKE '%condensed%'
    AND lower("Ingredient Name") NOT LIKE '%evaporated%'
    AND lower("Ingredient Name") NOT LIKE '%buttermilk%'
  ORDER BY
    CASE WHEN lower(btrim("Ingredient Name")) = 'milk' THEN 0
         WHEN lower("Ingredient Name") LIKE '%full cream%' THEN 1
         ELSE 2 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'milk';

-- capsicum
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%capsicum%'
     OR lower("Ingredient Name") LIKE '%bell pepper%'
     OR lower("Ingredient Name") LIKE '%red pepper%'
  ORDER BY
    CASE WHEN lower("Ingredient Name") LIKE '%red capsicum%' THEN 0
         WHEN lower("Ingredient Name") LIKE '%capsicum%' THEN 1
         ELSE 2 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'capsicum';

-- olive-oil
UPDATE library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%olive oil%'
  ORDER BY
    CASE WHEN lower("Ingredient Name") LIKE '%extra virgin%' THEN 0
         WHEN lower(btrim("Ingredient Name")) = 'olive oil' THEN 1
         ELSE 2 END,
    length("Ingredient Name"), "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'olive-oil';

-- Verify: NULL governed_id or still pointing at buttermilk etc. is a problem
SELECT lp.slug, lp.name AS profile_name, lp.governed_ingredient_id,
       gi."Ingredient Name" AS governed_name,
       CASE
         WHEN lp.governed_ingredient_id IS NULL THEN 'MISSING LINK'
         WHEN lower(gi."Ingredient Name") LIKE '%buttermilk%' AND lp.slug = 'butter' THEN 'WRONG LINK'
         WHEN lower(gi."Ingredient Name") LIKE '%peanut butter%' AND lp.slug = 'butter' THEN 'WRONG LINK'
         ELSE 'ok'
       END AS link_status
FROM library_profiles lp
LEFT JOIN ingredients gi ON gi."ID" = lp.governed_ingredient_id
WHERE lp.profile_type = 'ingredient'
  AND lp.slug IN (
    'garlic','onion','butter','rice','tomato','chicken-breast','salt',
    'ginger','egg','flour','potato','coconut','milk','capsicum','olive-oil'
  )
ORDER BY lp.slug;

-- Single summary (Supabase often shows only the last result)
SELECT jsonb_build_object(
  'status', 'fix-library-governed-links ready',
  'profiles_checked', count(*),
  'all_ok', count(*) FILTER (WHERE link_status = 'ok'),
  'problems', COALESCE(jsonb_agg(jsonb_build_object(
    'slug', slug, 'governed_name', governed_name, 'link_status', link_status
  )) FILTER (WHERE link_status <> 'ok'), '[]'::jsonb)
) AS library_link_summary
FROM (
  SELECT lp.slug,
         gi."Ingredient Name" AS governed_name,
         CASE
           WHEN lp.governed_ingredient_id IS NULL THEN 'MISSING LINK'
           WHEN lower(gi."Ingredient Name") LIKE '%buttermilk%' AND lp.slug = 'butter' THEN 'WRONG LINK'
           WHEN lower(gi."Ingredient Name") LIKE '%peanut butter%' AND lp.slug = 'butter' THEN 'WRONG LINK'
           ELSE 'ok'
         END AS link_status
  FROM library_profiles lp
  LEFT JOIN ingredients gi ON gi."ID" = lp.governed_ingredient_id
  WHERE lp.profile_type = 'ingredient'
    AND lp.slug IN (
      'garlic','onion','butter','rice','tomato','chicken-breast','salt',
      'ginger','egg','flour','potato','coconut','milk','capsicum','olive-oil'
    )
) v;
-- ########## END: fix-library-governed-links.sql ##########

-- ########## BEGIN: fix-phase43-starter-library-health.sql ##########
-- fix-phase43-starter-library-health.sql
-- Align dashboard + SQL editor health checks with starter wrong-link detection.
-- Safe to re-run.

CREATE OR REPLACE FUNCTION public.admin_data_integrity_report()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_invalid_governed int;
  v_name_mismatch int;
  v_wrong_starter int;
  v_dupes int;
  v_orphan_recipe_names int;
  v_total_recipes int;
  v_approved_recipes int;
  v_total_ingredients int;
BEGIN
  IF auth.uid() IS NULL OR NOT is_admin() THEN RAISE EXCEPTION 'Permission denied'; END IF;

  SELECT count(*)::int INTO v_total_recipes FROM submitted_recipes;
  SELECT count(*)::int INTO v_approved_recipes FROM submitted_recipes WHERE status = 'approved';
  SELECT count(*)::int INTO v_total_ingredients FROM ingredients;

  SELECT count(*)::int INTO v_invalid_governed
  FROM library_profiles lp
  WHERE lp.profile_type = 'ingredient'
    AND lp.governed_ingredient_id IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM ingredients i WHERE i."ID" = lp.governed_ingredient_id);

  SELECT count(*)::int INTO v_name_mismatch
  FROM library_profiles lp
  JOIN ingredients i ON i."ID" = lp.governed_ingredient_id
  WHERE lp.profile_type = 'ingredient'
    AND lower(btrim(lp.name)) <> lower(btrim(i."Ingredient Name"));

  SELECT count(*)::int INTO v_wrong_starter
  FROM library_profiles lp
  JOIN ingredients gi ON gi."ID" = lp.governed_ingredient_id
  WHERE lp.profile_type = 'ingredient'
    AND (
      (lp.slug = 'butter' AND (
        lower(gi."Ingredient Name") LIKE '%buttermilk%'
        OR lower(gi."Ingredient Name") LIKE '%peanut butter%'
      ))
      OR (lp.slug = 'rice' AND lower(gi."Ingredient Name") LIKE '%rice paper%')
      OR (lp.slug = 'milk' AND lower(gi."Ingredient Name") LIKE '%buttermilk%')
    );

  SELECT count(*)::int INTO v_dupes
  FROM (
    SELECT lower(btrim("Ingredient Name")) AS n
    FROM ingredients
    WHERE "Ingredient Name" IS NOT NULL AND btrim("Ingredient Name") <> ''
    GROUP BY 1 HAVING count(*) > 1
  ) d;

  SELECT count(DISTINCT x.ing_name)::int INTO v_orphan_recipe_names
  FROM (
    SELECT lower(btrim(item->>'ingredient')) AS ing_name
    FROM submitted_recipes sr,
         jsonb_array_elements(COALESCE(sr.ingredients, '[]'::jsonb)) sec,
         jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
    WHERE sr.status = 'approved'
      AND btrim(COALESCE(item->>'ingredient', '')) <> ''
  ) x
  WHERE NOT EXISTS (
    SELECT 1 FROM ingredients i
    WHERE lower(btrim(i."Ingredient Name")) = x.ing_name
       OR lower(btrim(COALESCE(i."Also Known As", ''))) = x.ing_name
  );

  RETURN jsonb_build_object(
    'totals', jsonb_build_object(
      'recipes', v_total_recipes,
      'approved_recipes', v_approved_recipes,
      'ingredients', v_total_ingredients
    ),
    'issues', jsonb_build_object(
      'invalid_governed_links', v_invalid_governed,
      'library_name_mismatches', v_name_mismatch,
      'starter_library_wrong_links', v_wrong_starter,
      'duplicate_ingredient_names', v_dupes,
      'orphan_recipe_ingredient_names', v_orphan_recipe_names
    ),
    'healthy', (
      v_invalid_governed = 0
      AND v_name_mismatch = 0
      AND v_wrong_starter = 0
      AND v_dupes = 0
      AND v_orphan_recipe_names = 0
    )
  );
END; $$;

REVOKE ALL ON FUNCTION public.admin_data_integrity_report() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_data_integrity_report() TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_data_integrity_report_sql()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_invalid_governed int;
  v_name_mismatch int;
  v_wrong_starter int;
  v_dupes int;
  v_orphan_recipe_names int;
  v_total_recipes int;
  v_approved_recipes int;
  v_total_ingredients int;
BEGIN
  IF current_user NOT IN ('postgres', 'supabase_admin', 'service_role')
     AND (auth.uid() IS NULL OR NOT is_admin()) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  SELECT count(*)::int INTO v_total_recipes FROM submitted_recipes;
  SELECT count(*)::int INTO v_approved_recipes FROM submitted_recipes WHERE status = 'approved';
  SELECT count(*)::int INTO v_total_ingredients FROM ingredients;

  SELECT count(*)::int INTO v_invalid_governed
  FROM library_profiles lp
  WHERE lp.profile_type = 'ingredient'
    AND lp.governed_ingredient_id IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM ingredients i WHERE i."ID" = lp.governed_ingredient_id);

  SELECT count(*)::int INTO v_name_mismatch
  FROM library_profiles lp
  JOIN ingredients i ON i."ID" = lp.governed_ingredient_id
  WHERE lp.profile_type = 'ingredient'
    AND lower(btrim(lp.name)) <> lower(btrim(i."Ingredient Name"));

  SELECT count(*)::int INTO v_wrong_starter
  FROM library_profiles lp
  JOIN ingredients gi ON gi."ID" = lp.governed_ingredient_id
  WHERE lp.profile_type = 'ingredient'
    AND (
      (lp.slug = 'butter' AND (
        lower(gi."Ingredient Name") LIKE '%buttermilk%'
        OR lower(gi."Ingredient Name") LIKE '%peanut butter%'
      ))
      OR (lp.slug = 'rice' AND lower(gi."Ingredient Name") LIKE '%rice paper%')
      OR (lp.slug = 'milk' AND lower(gi."Ingredient Name") LIKE '%buttermilk%')
    );

  SELECT count(*)::int INTO v_dupes
  FROM (
    SELECT lower(btrim("Ingredient Name")) AS n
    FROM ingredients
    WHERE "Ingredient Name" IS NOT NULL AND btrim("Ingredient Name") <> ''
    GROUP BY 1 HAVING count(*) > 1
  ) d;

  SELECT count(DISTINCT x.ing_name)::int INTO v_orphan_recipe_names
  FROM (
    SELECT lower(btrim(item->>'ingredient')) AS ing_name
    FROM submitted_recipes sr,
         jsonb_array_elements(COALESCE(sr.ingredients, '[]'::jsonb)) sec,
         jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
    WHERE sr.status = 'approved'
      AND btrim(COALESCE(item->>'ingredient', '')) <> ''
  ) x
  WHERE NOT EXISTS (
    SELECT 1 FROM ingredients i
    WHERE lower(btrim(i."Ingredient Name")) = x.ing_name
       OR lower(btrim(COALESCE(i."Also Known As", ''))) = x.ing_name
  );

  RETURN jsonb_build_object(
    'totals', jsonb_build_object(
      'recipes', v_total_recipes,
      'approved_recipes', v_approved_recipes,
      'ingredients', v_total_ingredients
    ),
    'issues', jsonb_build_object(
      'invalid_governed_links', v_invalid_governed,
      'library_name_mismatches', v_name_mismatch,
      'starter_library_wrong_links', v_wrong_starter,
      'duplicate_ingredient_names', v_dupes,
      'orphan_recipe_ingredient_names', v_orphan_recipe_names
    ),
    'healthy', (
      v_invalid_governed = 0
      AND v_name_mismatch = 0
      AND v_wrong_starter = 0
      AND v_dupes = 0
      AND v_orphan_recipe_names = 0
    )
  );
END; $$;

REVOKE ALL ON FUNCTION public.admin_data_integrity_report_sql() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_data_integrity_report_sql() TO postgres, service_role;

SELECT 'fix-phase43-starter-library-health ready' AS status;
-- ########## END: fix-phase43-starter-library-health.sql ##########

SELECT pg_notify('pgrst', 'reload schema');
SELECT 'ALL PRODUCTION PATCHES COMPLETE' AS status;
