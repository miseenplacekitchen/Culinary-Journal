-- ══════════════════════════════════════════════════════════════════════
-- fix-phases-11-20-batch.sql — Admin ops polish (achievable non-gated slice)
-- Safe to re-run. Run after fix-phase10-batch.sql.
--
-- AFTER RUNNING — one-time (use same CRON_SECRET as edge functions + cron jobs):
--   SELECT admin_set_edge_config('cron_secret', 'YOUR_CRON_SECRET');
-- ══════════════════════════════════════════════════════════════════════

-- PHASE 11 — Source link re-check controls
DROP FUNCTION IF EXISTS public.admin_reset_source_link_check(uuid);
DROP FUNCTION IF EXISTS public.admin_queue_all_link_rechecks();

CREATE OR REPLACE FUNCTION public.admin_reset_source_link_check(p_recipe_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.submitted_recipes
     SET source_link_checked_at = NULL
   WHERE id = p_recipe_id
     AND status = 'approved'
     AND credit_url IS NOT NULL AND btrim(credit_url) <> '';
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_reset_source_link_check(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_queue_all_link_rechecks()
RETURNS int
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count int;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.submitted_recipes
     SET source_link_checked_at = NULL
   WHERE status = 'approved'
     AND credit_url IS NOT NULL AND btrim(credit_url) <> ''
     AND credit_url ILIKE 'http%';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_queue_all_link_rechecks() TO authenticated;

-- PHASE 12 — Admin "run now" for edge workers (email + dead links)
CREATE TABLE IF NOT EXISTS public.admin_edge_config (
  key        text PRIMARY KEY,
  value      text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.admin_edge_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "admin manages edge config" ON public.admin_edge_config;
CREATE POLICY "admin manages edge config" ON public.admin_edge_config
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());

DROP FUNCTION IF EXISTS public.admin_set_edge_config(text, text);
CREATE OR REPLACE FUNCTION public.admin_set_edge_config(p_key text, p_value text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_key IS NULL OR btrim(p_key) = '' THEN RAISE EXCEPTION 'Key required'; END IF;
  INSERT INTO public.admin_edge_config (key, value, updated_at)
  VALUES (p_key, COALESCE(p_value, ''), now())
  ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now();
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_set_edge_config(text, text) TO authenticated;

DROP FUNCTION IF EXISTS public.admin_invoke_edge_function(text);
CREATE OR REPLACE FUNCTION public.admin_invoke_edge_function(p_function text)
RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_secret text;
  v_url    text;
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  IF p_function NOT IN ('send-queued-emails', 'check-dead-links') THEN
    RAISE EXCEPTION 'Invalid function: %', p_function;
  END IF;
  SELECT value INTO v_secret FROM public.admin_edge_config WHERE key = 'cron_secret';
  IF v_secret IS NULL OR btrim(v_secret) = '' THEN
    RAISE EXCEPTION 'cron_secret not set — run: SELECT admin_set_edge_config(''cron_secret'', ''YOUR_SECRET'');';
  END IF;
  v_url := 'https://kzywmodvfbyexqgipcjt.supabase.co/functions/v1/' || p_function;
  RETURN net.http_post(
    url     := v_url,
    headers := jsonb_build_object(
      'Content-Type',  'application/json',
      'Authorization', 'Bearer ' || v_secret
    ),
    body    := '{}'::jsonb
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_invoke_edge_function(text) TO authenticated;

-- PHASE 13 — Admin edit origin locality (Issue 4.3 admin slice)
DO $$ DECLARE r record;
BEGIN
  FOR r IN SELECT p.oid::regprocedure AS sig FROM pg_proc p
           JOIN pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = 'public' AND p.proname = 'admin_edit_recipe'
  LOOP EXECUTE 'DROP FUNCTION IF EXISTS ' || r.sig; END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.admin_edit_recipe(
  p_id uuid, p_recipe_name text DEFAULT NULL, p_category text DEFAULT NULL,
  p_spice_level text DEFAULT NULL, p_native_title text DEFAULT NULL,
  p_introduction text DEFAULT NULL, p_cooking_notes text DEFAULT NULL,
  p_servings int DEFAULT NULL,
  p_origin_locality text DEFAULT NULL, p_origin_state text DEFAULT NULL,
  p_origin_country text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF NOT is_admin() THEN RAISE EXCEPTION 'Not authorized'; END IF;
  UPDATE public.submitted_recipes SET
    recipe_name      = COALESCE(NULLIF(btrim(p_recipe_name), ''), recipe_name),
    category         = COALESCE(NULLIF(btrim(p_category), ''), category),
    spice_level      = COALESCE(NULLIF(btrim(p_spice_level), ''), spice_level),
    native_title     = COALESCE(NULLIF(btrim(p_native_title), ''), native_title),
    introduction     = COALESCE(p_introduction, introduction),
    cooking_notes    = COALESCE(p_cooking_notes, cooking_notes),
    servings         = COALESCE(p_servings, servings),
    origin_locality  = COALESCE(NULLIF(btrim(p_origin_locality), ''), origin_locality),
    origin_state     = COALESCE(NULLIF(btrim(p_origin_state), ''), origin_state),
    origin_country   = COALESCE(NULLIF(btrim(p_origin_country), ''), origin_country)
  WHERE id = p_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_edit_recipe(
  uuid,text,text,text,text,text,text,int,text,text,text
) TO authenticated;

SELECT 'fix-phases-11-20-batch.sql complete — run admin_set_edge_config for cron_secret' AS status;
