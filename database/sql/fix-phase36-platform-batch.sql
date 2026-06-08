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
