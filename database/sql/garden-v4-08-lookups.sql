-- garden-v4-08-lookups.sql — additional lookup vocab from Garden Database manual (slice 2)

INSERT INTO public.soil_types (slug, name, ph_low, ph_high) VALUES
  ('loam', 'Loam', 6.0, 7.0),
  ('sandy-loam', 'Sandy loam', 5.5, 7.0),
  ('clay-loam', 'Clay loam', 6.0, 7.5),
  ('potting-mix', 'Premium potting mix', 5.5, 6.5),
  ('compost-rich', 'Compost-rich bed', 6.0, 7.0)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.sunlight_levels (slug, name, hours) VALUES
  ('full-sun', 'Full sun', '6+ hours direct'),
  ('part-sun', 'Part sun', '4–6 hours'),
  ('part-shade', 'Part shade', '2–4 hours'),
  ('bright-indirect', 'Bright indirect', 'Bright, no direct midday')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.growth_habits (slug, name, description) VALUES
  ('bush', 'Bush / determinate', 'Compact, stops at set height.'),
  ('spreading', 'Spreading / ground cover', 'Low horizontal spread.'),
  ('upright', 'Upright / columnar', 'Vertical habit, minimal spread.')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.cat_main (slug, name, definition) VALUES
  ('leafy-greens', 'Leafy greens', 'Grown primarily for leaves.'),
  ('herbs-aromatic', 'Herbs & aromatics', 'Culinary herbs and scented plants.'),
  ('root-tuber', 'Roots & tubers', 'Edible underground storage organs.')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.tags (slug, name) VALUES
  ('monsoon-crop', 'Monsoon-season crop'),
  ('heat-tolerant', 'Heat tolerant'),
  ('humidity-adapted', 'Humidity adapted'),
  ('container-suitable', 'Container suitable'),
  ('fruit-fly-risk', 'Fruit fly — net fruit')
ON CONFLICT (slug) DO NOTHING;

SELECT 'garden-v4-08-lookups ready' AS status;
