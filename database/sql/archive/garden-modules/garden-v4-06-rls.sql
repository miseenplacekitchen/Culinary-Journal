-- garden-v4-06-rls.sql — RLS for variety layer + import queue

ALTER TABLE public.plant_varieties ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "garden varieties published read" ON public.plant_varieties;
CREATE POLICY "garden varieties published read" ON public.plant_varieties
  FOR SELECT TO anon, authenticated USING (is_published = true);
DROP POLICY IF EXISTS "garden varieties admin" ON public.plant_varieties;
CREATE POLICY "garden varieties admin" ON public.plant_varieties
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
GRANT SELECT ON public.plant_varieties TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.plant_varieties TO authenticated;

ALTER TABLE public.variety_climate_suitability ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "variety climate read" ON public.variety_climate_suitability;
CREATE POLICY "variety climate read" ON public.variety_climate_suitability
  FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "variety climate admin" ON public.variety_climate_suitability;
CREATE POLICY "variety climate admin" ON public.variety_climate_suitability
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
GRANT SELECT ON public.variety_climate_suitability TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.variety_climate_suitability TO authenticated;

ALTER TABLE public.variety_ingredients ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "variety ingredients read" ON public.variety_ingredients;
CREATE POLICY "variety ingredients read" ON public.variety_ingredients
  FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS "variety ingredients admin" ON public.variety_ingredients;
CREATE POLICY "variety ingredients admin" ON public.variety_ingredients
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
GRANT SELECT ON public.variety_ingredients TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.variety_ingredients TO authenticated;

ALTER TABLE public.garden_import_queue ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "garden import admin" ON public.garden_import_queue;
CREATE POLICY "garden import admin" ON public.garden_import_queue
  FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin());
GRANT SELECT, INSERT, UPDATE, DELETE ON public.garden_import_queue TO authenticated;

SELECT 'garden-v4-06-rls ready' AS status;
