-- ═══════════════════════════════════════════════════════════════
-- THE CULINARY JOURNAL — 06-culinary-life.sql
-- Culinary Life system: cooking events, recipe mentions, 
-- milestones, and the discovery engine.
-- Run after 05-diary.sql
-- ═══════════════════════════════════════════════════════════════

-- ── COOKING EVENTS ──────────────────────────────────────────────
-- Passive capture: every time a user marks a recipe as cooked.
-- This is the foundation of the "system discovers" model.
CREATE TABLE IF NOT EXISTS public.cooking_events (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid        REFERENCES auth.users(id) ON DELETE CASCADE,
  recipe_id    uuid        REFERENCES public.submitted_recipes(id) ON DELETE SET NULL,
  recipe_name  text        NOT NULL,  -- denormalised for resilience
  cooked_at    date        NOT NULL DEFAULT CURRENT_DATE,
  notes        text        DEFAULT '',
  servings     int         DEFAULT 1,
  occasion     text        DEFAULT '', -- e.g. 'weeknight', 'birthday', 'christmas'
  rating       int         CHECK (rating BETWEEN 1 AND 5),
  created_at   timestamptz DEFAULT now()
);
ALTER TABLE public.cooking_events ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.cooking_events TO authenticated;
DROP POLICY IF EXISTS "Users manage own cooking events" ON public.cooking_events;
CREATE POLICY "Users manage own cooking events"
  ON public.cooking_events FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE INDEX IF NOT EXISTS cooking_events_user_date ON public.cooking_events(user_id, cooked_at DESC);
CREATE INDEX IF NOT EXISTS cooking_events_recipe    ON public.cooking_events(recipe_id);

-- ── DIARY ↔ RECIPE LINKS ────────────────────────────────────────
-- When a diary entry mentions a recipe, record the link.
CREATE TABLE IF NOT EXISTS public.diary_recipe_mentions (
  diary_entry_id uuid REFERENCES public.diary_entries(id) ON DELETE CASCADE,
  recipe_id      uuid REFERENCES public.submitted_recipes(id) ON DELETE CASCADE,
  user_id        uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  PRIMARY KEY (diary_entry_id, recipe_id)
);
ALTER TABLE public.diary_recipe_mentions ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, DELETE ON public.diary_recipe_mentions TO authenticated;
DROP POLICY IF EXISTS "Users manage own mentions" ON public.diary_recipe_mentions;
CREATE POLICY "Users manage own mentions"
  ON public.diary_recipe_mentions FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- ── USER MILESTONES ──────────────────────────────────────────────
-- Auto-generated milestones. System writes these when thresholds hit.
CREATE TABLE IF NOT EXISTS public.user_milestones (
  id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid        REFERENCES auth.users(id) ON DELETE CASCADE,
  milestone    text        NOT NULL,  -- e.g. 'first_recipe', '50_cooks', 'first_print'
  label        text        NOT NULL,  -- human-readable
  achieved_at  timestamptz DEFAULT now(),
  data         jsonb       DEFAULT '{}'
);
ALTER TABLE public.user_milestones ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT ON public.user_milestones TO authenticated;
DROP POLICY IF EXISTS "Users read own milestones" ON public.user_milestones;
CREATE POLICY "Users read own milestones"
  ON public.user_milestones FOR SELECT TO authenticated
  USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "System inserts milestones" ON public.user_milestones;
CREATE POLICY "System inserts milestones"
  ON public.user_milestones FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);
CREATE UNIQUE INDEX IF NOT EXISTS milestones_unique ON public.user_milestones(user_id, milestone);

-- ═══════════════════════════════════════════════════════════════
-- RPC FUNCTIONS
-- ═══════════════════════════════════════════════════════════════

-- ── LOG A COOKING EVENT ─────────────────────────────────────────
DROP FUNCTION IF EXISTS public.log_cooking_event(uuid, text, date, text, int, text, int);
CREATE FUNCTION public.log_cooking_event(
  p_recipe_id   uuid    DEFAULT NULL,
  p_recipe_name text    DEFAULT '',
  p_cooked_at   date    DEFAULT CURRENT_DATE,
  p_notes       text    DEFAULT '',
  p_servings    int     DEFAULT 1,
  p_occasion    text    DEFAULT '',
  p_rating      int     DEFAULT NULL
) RETURNS public.cooking_events
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE result public.cooking_events;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  INSERT INTO public.cooking_events
    (user_id, recipe_id, recipe_name, cooked_at, notes, servings, occasion, rating)
  VALUES
    (auth.uid(), p_recipe_id, p_recipe_name, p_cooked_at,
     p_notes, p_servings, p_occasion, p_rating)
  RETURNING * INTO result;
  -- Check and award milestones
  PERFORM check_cooking_milestones();
  RETURN result;
END;
$$;
GRANT EXECUTE ON FUNCTION public.log_cooking_event(uuid,text,date,text,int,text,int) TO authenticated;

-- ── CULINARY LIFE OVERVIEW ──────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_culinary_life();
CREATE FUNCTION public.get_culinary_life()
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  uid               uuid := auth.uid();
  total_cooks       bigint;
  this_year_cooks   bigint;
  this_month_cooks  bigint;
  unique_recipes    bigint;
  diary_count       bigint;
  collection_count  bigint;
  recipe_count      bigint;
  this_year         int := EXTRACT(YEAR FROM CURRENT_DATE);
BEGIN
  IF uid IS NULL THEN RETURN '{}'; END IF;

  SELECT COUNT(*)                INTO total_cooks      FROM cooking_events WHERE user_id = uid;
  SELECT COUNT(*)                INTO this_year_cooks  FROM cooking_events WHERE user_id = uid AND EXTRACT(YEAR  FROM cooked_at) = this_year;
  SELECT COUNT(*)                INTO this_month_cooks FROM cooking_events WHERE user_id = uid AND EXTRACT(YEAR  FROM cooked_at) = this_year AND EXTRACT(MONTH FROM cooked_at) = EXTRACT(MONTH FROM CURRENT_DATE);
  SELECT COUNT(DISTINCT recipe_name) INTO unique_recipes FROM cooking_events WHERE user_id = uid;
  SELECT COUNT(*)                INTO diary_count      FROM diary_entries  WHERE user_id = uid;
  SELECT COUNT(*)                INTO collection_count FROM collections    WHERE user_id = uid;
  SELECT COUNT(*)                INTO recipe_count     FROM submitted_recipes WHERE user_id = uid AND status = 'approved';

  RETURN json_build_object(
    'total_cooks',       total_cooks,
    'this_year_cooks',   this_year_cooks,
    'this_month_cooks',  this_month_cooks,
    'unique_recipes',    unique_recipes,
    'diary_entries',     diary_count,
    'collections',       collection_count,
    'published_recipes', recipe_count
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_culinary_life() TO authenticated;

-- ── FAMILY FAVOURITES (system-discovered) ───────────────────────
DROP FUNCTION IF EXISTS public.get_family_favourites(int);
CREATE FUNCTION public.get_family_favourites(p_limit int DEFAULT 10)
RETURNS TABLE (
  recipe_id    uuid,
  recipe_name  text,
  cook_count   bigint,
  last_cooked  date,
  avg_rating   numeric,
  diary_mentions bigint
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  RETURN QUERY
    SELECT
      ce.recipe_id,
      ce.recipe_name,
      COUNT(*) AS cook_count,
      MAX(ce.cooked_at) AS last_cooked,
      ROUND(AVG(ce.rating), 1) AS avg_rating,
      COUNT(DISTINCT drm.diary_entry_id) AS diary_mentions
    FROM cooking_events ce
    LEFT JOIN diary_recipe_mentions drm ON drm.recipe_id = ce.recipe_id AND drm.user_id = ce.user_id
    WHERE ce.user_id = auth.uid()
      AND ce.recipe_id IS NOT NULL
    GROUP BY ce.recipe_id, ce.recipe_name
    ORDER BY cook_count DESC, diary_mentions DESC
    LIMIT p_limit;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_family_favourites(int) TO authenticated;

-- ── CULINARY TIMELINE ───────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_culinary_timeline(int);
CREATE FUNCTION public.get_culinary_timeline(p_limit int DEFAULT 20)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  uid uuid := auth.uid();
  timeline json;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  SELECT json_agg(events ORDER BY event_date DESC)
  INTO timeline
  FROM (
    -- Cooking events
    SELECT
      'cook'         AS event_type,
      id::text       AS source_id,
      cooked_at      AS event_date,
      recipe_name    AS label,
      notes          AS detail,
      rating::text   AS meta,
      occasion       AS context
    FROM cooking_events
    WHERE user_id = uid
    UNION ALL
    -- Diary entries
    SELECT
      'diary'        AS event_type,
      id::text       AS source_id,
      entry_date     AS event_date,
      COALESCE(NULLIF(title,''), 'Journal Entry') AS label,
      LEFT(content, 100) AS detail,
      entry_type     AS meta,
      mood           AS context
    FROM diary_entries
    WHERE user_id = uid
    UNION ALL
    -- Recipe submissions
    SELECT
      'recipe'       AS event_type,
      id::text       AS source_id,
      submitted_at::date AS event_date,
      recipe_name    AS label,
      status         AS detail,
      category       AS meta,
      ''             AS context
    FROM submitted_recipes
    WHERE user_id = uid
    UNION ALL
    -- Milestones
    SELECT
      'milestone'    AS event_type,
      NULL::text     AS source_id,
      achieved_at::date AS event_date,
      label          AS label,
      milestone      AS detail,
      ''             AS meta,
      ''             AS context
    FROM user_milestones
    WHERE user_id = uid
    LIMIT p_limit
  ) events;
  RETURN COALESCE(timeline, '[]'::json);
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_culinary_timeline(int) TO authenticated;

-- ── YEAR IN REVIEW ──────────────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_year_in_review(int);
CREATE FUNCTION public.get_year_in_review(p_year int DEFAULT NULL)
RETURNS json
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  uid    uuid := auth.uid();
  yr     int  := COALESCE(p_year, EXTRACT(YEAR FROM CURRENT_DATE)::int);
  result json;
BEGIN
  IF uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  SELECT json_build_object(
    'year', yr,
    'total_cooks',
      (SELECT COUNT(*) FROM cooking_events WHERE user_id=uid AND EXTRACT(YEAR FROM cooked_at)=yr),
    'unique_recipes',
      (SELECT COUNT(DISTINCT recipe_name) FROM cooking_events WHERE user_id=uid AND EXTRACT(YEAR FROM cooked_at)=yr),
    'diary_entries',
      (SELECT COUNT(*) FROM diary_entries WHERE user_id=uid AND EXTRACT(YEAR FROM entry_date)=yr),
    'top_recipe',
      (SELECT recipe_name FROM cooking_events WHERE user_id=uid AND EXTRACT(YEAR FROM cooked_at)=yr
       GROUP BY recipe_name ORDER BY COUNT(*) DESC LIMIT 1),
    'top_occasion',
      (SELECT occasion FROM cooking_events WHERE user_id=uid AND EXTRACT(YEAR FROM cooked_at)=yr
       AND occasion != '' GROUP BY occasion ORDER BY COUNT(*) DESC LIMIT 1),
    'months',
      (SELECT json_agg(json_build_object('month', m, 'cooks', c) ORDER BY m)
       FROM (SELECT EXTRACT(MONTH FROM cooked_at)::int AS m, COUNT(*) AS c
             FROM cooking_events WHERE user_id=uid AND EXTRACT(YEAR FROM cooked_at)=yr
             GROUP BY m) monthly)
  ) INTO result;
  RETURN result;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_year_in_review(int) TO authenticated;

-- ── RECENT COOKING ACTIVITY ─────────────────────────────────────
DROP FUNCTION IF EXISTS public.get_recent_cooks(int);
CREATE FUNCTION public.get_recent_cooks(p_limit int DEFAULT 12)
RETURNS SETOF public.cooking_events
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  RETURN QUERY
    SELECT * FROM cooking_events
    WHERE user_id = auth.uid()
    ORDER BY cooked_at DESC, created_at DESC
    LIMIT p_limit;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_recent_cooks(int) TO authenticated;

-- ── MILESTONE CHECKER (called internally) ───────────────────────
DROP FUNCTION IF EXISTS public.check_cooking_milestones();
CREATE FUNCTION public.check_cooking_milestones()
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  uid        uuid := auth.uid();
  cook_count bigint;
BEGIN
  SELECT COUNT(*) INTO cook_count FROM cooking_events WHERE user_id = uid;
  -- First cook
  IF cook_count = 1 THEN
    INSERT INTO user_milestones(user_id, milestone, label)
    VALUES (uid, 'first_cook', 'First recipe cooked!') ON CONFLICT DO NOTHING;
  END IF;
  -- 10 cooks
  IF cook_count = 10 THEN
    INSERT INTO user_milestones(user_id, milestone, label, data)
    VALUES (uid, '10_cooks', '10 recipes cooked', '{"count":10}') ON CONFLICT DO NOTHING;
  END IF;
  -- 50 cooks
  IF cook_count = 50 THEN
    INSERT INTO user_milestones(user_id, milestone, label, data)
    VALUES (uid, '50_cooks', '50 meals cooked — you''re on a roll', '{"count":50}') ON CONFLICT DO NOTHING;
  END IF;
  -- 100 cooks
  IF cook_count = 100 THEN
    INSERT INTO user_milestones(user_id, milestone, label, data)
    VALUES (uid, '100_cooks', '100 meals cooked', '{"count":100}') ON CONFLICT DO NOTHING;
  END IF;
END;
$$;
GRANT EXECUTE ON FUNCTION public.check_cooking_milestones() TO authenticated;

-- ── DELETE A COOKING EVENT ──────────────────────────────────────
DROP FUNCTION IF EXISTS public.delete_cooking_event(uuid);
CREATE FUNCTION public.delete_cooking_event(p_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  DELETE FROM cooking_events WHERE id = p_id AND user_id = auth.uid();
END;
$$;
GRANT EXECUTE ON FUNCTION public.delete_cooking_event(uuid) TO authenticated;

-- ── UPDATE COOKING EVENT (AP-03) ─────────────────────────────────
DROP FUNCTION IF EXISTS public.update_cooking_event(uuid, text, date, int, text);
CREATE FUNCTION public.update_cooking_event(
  p_id uuid, p_recipe_name text DEFAULT NULL, p_cooked_at date DEFAULT NULL,
  p_rating int DEFAULT NULL, p_notes text DEFAULT NULL
)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  UPDATE cooking_events SET
    recipe_name = COALESCE(NULLIF(p_recipe_name,''), recipe_name),
    cooked_at   = COALESCE(p_cooked_at, cooked_at),
    rating      = COALESCE(p_rating, rating),
    notes       = COALESCE(p_notes, notes)
  WHERE id = p_id AND user_id = auth.uid();
  IF NOT FOUND THEN RAISE EXCEPTION 'not_found_or_not_yours'; END IF;
END; $$;
REVOKE ALL ON FUNCTION public.update_cooking_event(uuid, text, date, int, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.update_cooking_event(uuid, text, date, int, text) TO authenticated;
