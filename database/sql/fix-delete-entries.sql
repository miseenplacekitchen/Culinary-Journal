-- Quick patch: diary + culinary life delete. Safe to re-run.
-- Or use the full fix-all-live.sql (includes this section).

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

SELECT pg_notify('pgrst', 'reload schema');
