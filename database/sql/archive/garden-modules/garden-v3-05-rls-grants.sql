-- garden-v3-05-rls-grants.sql
-- RLS + grants — public reads published content; admins manage; users own personal rows.

-- Lookup tables: world-readable, admin writes
DO $$ DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'cat_high_level','cat_main','garden_layers','growth_habits','lifecycles',
    'soil_types','sunlight_levels','seed_saving_groups','ease_ratings',
    'climate_zones','regions','zone_definitions','tags'
  ]
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS "garden lookup read" ON public.%I', t);
    EXECUTE format('CREATE POLICY "garden lookup read" ON public.%I FOR SELECT TO anon, authenticated USING (true)', t);
    EXECUTE format('DROP POLICY IF EXISTS "garden lookup admin" ON public.%I', t);
    EXECUTE format('CREATE POLICY "garden lookup admin" ON public.%I FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin())', t);
    EXECUTE format('GRANT SELECT ON public.%I TO anon, authenticated', t);
    EXECUTE format('GRANT INSERT, UPDATE, DELETE ON public.%I TO authenticated', t);
  END LOOP;
END $$;

-- Published content tables
DO $$ DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['plants','guilds','organisms','drinks','lessons','learning_paths','preservation_methods']
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS "garden published read" ON public.%I', t);
    EXECUTE format('CREATE POLICY "garden published read" ON public.%I FOR SELECT TO anon, authenticated USING (is_published = true)', t);
    EXECUTE format('DROP POLICY IF EXISTS "garden published admin" ON public.%I', t);
    EXECUTE format('CREATE POLICY "garden published admin" ON public.%I FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin())', t);
    EXECUTE format('GRANT SELECT ON public.%I TO anon, authenticated', t);
    EXECUTE format('GRANT INSERT, UPDATE, DELETE ON public.%I TO authenticated', t);
  END LOOP;
END $$;

-- Child / link tables: readable when parent published (simplified — authenticated read + admin write)
DO $$ DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'plant_parts','plant_climate_care','plant_culture','plant_companions','plant_calendar',
    'plant_organisms','plant_ingredients','guild_members',
    'ingredient_preservation','drink_ingredients','pairings',
    'topics','path_steps','lesson_links','entity_tags','media','sources','safety_flags','content_review'
  ]
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('DROP POLICY IF EXISTS "garden child read" ON public.%I', t);
    EXECUTE format('CREATE POLICY "garden child read" ON public.%I FOR SELECT TO anon, authenticated USING (true)', t);
    EXECUTE format('DROP POLICY IF EXISTS "garden child admin" ON public.%I', t);
    EXECUTE format('CREATE POLICY "garden child admin" ON public.%I FOR ALL TO authenticated USING (is_admin()) WITH CHECK (is_admin())', t);
    EXECUTE format('GRANT SELECT ON public.%I TO anon, authenticated', t);
    EXECUTE format('GRANT INSERT, UPDATE, DELETE ON public.%I TO authenticated', t);
  END LOOP;
END $$;

-- User-owned rows
ALTER TABLE public.user_plants ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "user_plants own" ON public.user_plants;
CREATE POLICY "user_plants own" ON public.user_plants FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_plants TO authenticated;

ALTER TABLE public.user_regions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "user_regions own" ON public.user_regions;
CREATE POLICY "user_regions own" ON public.user_regions FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_regions TO authenticated;

ALTER TABLE public.garden_journal ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "garden_journal own" ON public.garden_journal;
CREATE POLICY "garden_journal own" ON public.garden_journal FOR ALL TO authenticated
  USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.garden_journal TO authenticated;

-- Storage bucket garden-media
INSERT INTO storage.buckets (id, name, public)
VALUES ('garden-media', 'garden-media', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Admin uploads garden media" ON storage.objects;
CREATE POLICY "Admin uploads garden media"
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'garden-media' AND is_admin());

DROP POLICY IF EXISTS "Admin updates garden media" ON storage.objects;
CREATE POLICY "Admin updates garden media"
  ON storage.objects FOR UPDATE TO authenticated
  USING (bucket_id = 'garden-media' AND is_admin());

DROP POLICY IF EXISTS "Anyone reads garden media" ON storage.objects;
CREATE POLICY "Anyone reads garden media"
  ON storage.objects FOR SELECT TO anon, authenticated
  USING (bucket_id = 'garden-media');

SELECT 'garden-v3-05-rls-grants ready' AS status;
