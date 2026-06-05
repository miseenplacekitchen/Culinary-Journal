-- ══════════════════════════════════════════════════════════════════════
-- Pantry — The Culinary Journal
-- Stores each user's pantry items as a jsonb array.
-- One row per user — upsert on save.
-- ══════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS public.pantry (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  items      jsonb       NOT NULL DEFAULT '[]',
  updated_at timestamptz NOT NULL DEFAULT NOW()
);

ALTER TABLE public.pantry ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "users manage own pantry" ON public.pantry;
CREATE POLICY "users manage own pantry" ON public.pantry
  FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- Save pantry items (full replace)
DROP FUNCTION IF EXISTS public.save_my_pantry(jsonb);
CREATE FUNCTION public.save_my_pantry(p_items jsonb)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  INSERT INTO pantry (user_id, items, updated_at)
  VALUES (auth.uid(), p_items, NOW())
  ON CONFLICT (user_id)
  DO UPDATE SET items = EXCLUDED.items, updated_at = NOW();
END; $$;
REVOKE ALL ON FUNCTION public.save_my_pantry(jsonb) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.save_my_pantry(jsonb) TO authenticated;

-- Get pantry items
DROP FUNCTION IF EXISTS public.get_my_pantry();
CREATE FUNCTION public.get_my_pantry()
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Not authenticated'; END IF;
  RETURN COALESCE(
    (SELECT items FROM pantry WHERE user_id = auth.uid()),
    '[]'::jsonb
  );
END; $$;
REVOKE ALL ON FUNCTION public.get_my_pantry() FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.get_my_pantry() TO authenticated;

SELECT 'Pantry ready' AS status;

SELECT pg_notify('pgrst', 'reload schema');
