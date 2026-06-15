-- garden-v4-10-batch-import-queue.sql — load parsed Variety Assessment payloads
-- Safe to re-run. Updates variety_count + payload for matching source_path.

-- Zucchini (27 cultivars)
INSERT INTO public.garden_import_queue (source_path, species_name, species_slug, climate_slug, status, variety_count, payload)
SELECT 'brainstorm-inbox/import-payloads/zucchini.json', 'Zucchini', 'zucchini', 'multi', 'parsed', 27, NULL::jsonb
WHERE NOT EXISTS (SELECT 1 FROM public.garden_import_queue WHERE source_path = 'brainstorm-inbox/import-payloads/zucchini.json');

UPDATE public.garden_import_queue SET species_name = 'Zucchini', species_slug = 'zucchini',
  variety_count = 27, status = 'parsed'
WHERE source_path = 'brainstorm-inbox/import-payloads/zucchini.json' AND (payload IS NULL OR status IN ('pending','parsed'));

SELECT 'garden-v4-10-batch-import-queue ready — 208 species payloads' AS status;