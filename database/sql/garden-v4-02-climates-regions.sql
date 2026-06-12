-- garden-v4-02-climates-regions.sql — climate-first seed (Brisbane → humid-subtropical, Kerala → tropical-monsoon)

INSERT INTO public.climate_zones (slug, name) VALUES
  ('humid-subtropical', 'Humid subtropical'),
  ('tropical-monsoon', 'Tropical monsoon')
ON CONFLICT (slug) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO public.regions (slug, name, climate_zone_id, is_active) VALUES
  ('in-kerala', 'Kerala / Thiruvalla',
   (SELECT id FROM public.climate_zones WHERE slug = 'tropical-monsoon' LIMIT 1), true),
  ('au-brisbane', 'Brisbane',
   (SELECT id FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1), true)
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name,
  climate_zone_id = EXCLUDED.climate_zone_id,
  is_active = EXCLUDED.is_active;

-- Map existing au-southeast to humid-subtropical if present
UPDATE public.regions SET climate_zone_id = (SELECT id FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1)
WHERE slug = 'au-southeast'
  AND climate_zone_id IS DISTINCT FROM (SELECT id FROM public.climate_zones WHERE slug = 'humid-subtropical' LIMIT 1);

SELECT 'garden-v4-02-climates-regions ready' AS status;
