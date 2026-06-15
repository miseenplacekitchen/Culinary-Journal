-- garden-v3-07-seed-slice1.sql
-- One plant end-to-end: Tomato — lookups, profile, hinge, calendar, lesson. Safe to re-run.
-- REQUIRES garden-v3-01 … garden-v3-06 first. Do NOT run this file alone — use RUN-GARDEN-V3.sql from the top.

DO $$
BEGIN
  IF to_regclass('public.cat_high_level') IS NULL THEN
    RAISE EXCEPTION 'Garden foundation tables missing. Paste and run the entire RUN-GARDEN-V3.sql from line 1 (not seed-only).';
  END IF;
END $$;

-- Lookups
INSERT INTO public.cat_high_level (slug, name, definition) VALUES
  ('vegetable', 'Vegetable', 'Edible plants grown for leaves, roots, stems, or fruits.')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.cat_main (slug, name, definition) VALUES
  ('fruiting-veg', 'Fruiting vegetables', 'Plants grown for their fruiting bodies.')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.growth_habits (slug, name, description) VALUES
  ('climbing', 'Climbing / vining', 'Needs support — trellis, cage, or stake.')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.garden_layers (slug, name, description) VALUES
  ('herbaceous', 'Herbaceous layer', 'Non-woody annuals and perennials.')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.lifecycles (slug, name, traits) VALUES
  ('annual', 'Annual', 'Completes life cycle in one growing season.')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.ease_ratings (score, name, definition) VALUES
  (3, 'Moderate', 'Some care needed — staking, feeding, or pest watch.')
ON CONFLICT (score) DO NOTHING;

INSERT INTO public.seed_saving_groups (grp, name, notes) VALUES
  (5, 'Group 5 — self-pollinated', 'Tomato, bean, pea — minimal crossing risk.')
ON CONFLICT (grp) DO NOTHING;

INSERT INTO public.climate_zones (slug, name) VALUES
  ('warm-temperate', 'Warm temperate')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.regions (slug, name, climate_zone_id, is_active) VALUES
  ('au-southeast', 'Southeast Australia',
   (SELECT id FROM public.climate_zones WHERE slug = 'warm-temperate' LIMIT 1), true)
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.zone_definitions (zone, name, description) VALUES
  (0, 'Zone 0', 'Home / intensive kitchen garden'),
  (1, 'Zone 1', 'Most visited — herbs, salad, daily harvest'),
  (2, 'Zone 2', 'Perennials and small orchards'),
  (3, 'Zone 3', 'Main crops and larger plantings'),
  (4, 'Zone 4', 'Semi-wild forage and timber'),
  (5, 'Zone 5', 'Wild / observation only')
ON CONFLICT (zone) DO NOTHING;

INSERT INTO public.tags (slug, name) VALUES
  ('summer-crop', 'Summer crop'),
  ('kitchen-garden', 'Kitchen garden staple')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO public.topics (slug, name, summary) VALUES
  ('growing-basics', 'Growing basics', 'Soil, sun, water, and seasonal timing.')
ON CONFLICT (slug) DO NOTHING;

-- Tomato plant
INSERT INTO public.plants (
  slug, common_name, botanical_name, plant_family, plant_type, variety_cultivar, origin,
  size_height, size_spread, care_summary, is_published,
  high_level_category_id, main_category_id, growth_habit_id, garden_layer_id,
  lifecycle_id, ease_rating_id, seed_saving_group_id,
  pollination_type, flowering_season, propagation_methods, germination_time,
  time_to_harvest, harvest_season, harvesting_method, yield_per_plant,
  edible_parts, culinary_applications, toxic_parts, wildlife_attraction,
  growth_rate, planting_windows
) VALUES (
  'tomato',
  'Tomato',
  'Solanum lycopersicum',
  'Solanaceae',
  'Fruiting vegetable',
  'Cherry / salad / sauce cultivars',
  'Andean South America',
  '1–2 m with support',
  '45–60 cm',
  'Full sun, consistent water, stake or cage, feed when fruit sets. Pinch laterals on indeterminate types.',
  true,
  (SELECT id FROM public.cat_high_level WHERE slug = 'vegetable' LIMIT 1),
  (SELECT id FROM public.cat_main WHERE slug = 'fruiting-veg' LIMIT 1),
  (SELECT id FROM public.growth_habits WHERE slug = 'climbing' LIMIT 1),
  (SELECT id FROM public.garden_layers WHERE slug = 'herbaceous' LIMIT 1),
  (SELECT id FROM public.lifecycles WHERE slug = 'annual' LIMIT 1),
  (SELECT id FROM public.ease_ratings WHERE score = 3 LIMIT 1),
  (SELECT id FROM public.seed_saving_groups WHERE grp = 5 LIMIT 1),
  'Self-pollinating (flowers)',
  'Spring–summer',
  'Seed, transplant',
  '5–10 days at 21–27°C',
  '12–16 weeks from transplant',
  'Late spring through autumn',
  'Twist ripe fruit; cut trusses for sauce types',
  '3–15 kg per plant (cultivar dependent)',
  'Fruit (ripe), sometimes green fruit for pickles',
  'Fresh salads, sauces, passata, drying, roasting',
  'Leaves and green parts contain solanine — not for eating',
  'Bees visit flowers; ripe fruit attracts birds if unnetted',
  'Fast once established',
  'Transplant after last frost; successive sowing indoors 6–8 weeks ahead'
)
ON CONFLICT (slug) DO UPDATE SET
  common_name = EXCLUDED.common_name,
  botanical_name = EXCLUDED.botanical_name,
  care_summary = EXCLUDED.care_summary,
  is_published = EXCLUDED.is_published,
  updated_at = now();

-- Parts
INSERT INTO public.plant_parts (plant_id, part, role, notes)
SELECT p.id, v.part, v.role, v.notes
FROM public.plants p
CROSS JOIN (VALUES
  ('fruit', 'edible', 'Eat when fully coloured and slightly soft'),
  ('leaf', 'toxic', 'Solanine — decorative only'),
  ('flower', 'functional', 'Self-fertile; light shake helps in greenhouses')
) AS v(part, role, notes)
WHERE p.slug = 'tomato'
  AND NOT EXISTS (
    SELECT 1 FROM public.plant_parts pp
    WHERE pp.plant_id = p.id AND pp.part = v.part AND pp.role = v.role
  );

-- Climate care (warm temperate)
INSERT INTO public.plant_climate_care (plant_id, climate_zone_id, field_key, core, risk, fix)
SELECT p.id, cz.id, v.field_key, v.core, v.risk, v.fix
FROM public.plants p
JOIN public.climate_zones cz ON cz.slug = 'warm-temperate'
CROSS JOIN (VALUES
  ('sunlight', '6–8 hours direct sun', 'Less than 6h — leggy plants, poor fruit', 'Choose sunniest bed or pot'),
  ('water', 'Deep, even moisture; avoid wet leaves', 'Blossom end rot, splitting', 'Mulch; water at soil level mornings'),
  ('frost', 'Frost tender below ~2°C', 'Blackened foliage after cold nights', 'Cover or delay transplant until stable'),
  ('soil', 'Rich, well-drained, pH 6.0–6.8', 'Heavy clay — root rot', 'Compost + raised mound or large pot'),
  ('pest_mgmt', 'Inspect undersides weekly', 'Aphids, whitefly, caterpillars', 'Hose blast; remove hornworms by hand')
) AS v(field_key, core, risk, fix)
WHERE p.slug = 'tomato'
ON CONFLICT (plant_id, climate_zone_id, field_key) DO UPDATE SET
  core = EXCLUDED.core, risk = EXCLUDED.risk, fix = EXCLUDED.fix;

-- Calendar (Southern hemisphere warm-temperate months)
INSERT INTO public.plant_calendar (plant_id, climate_zone_id, activity, month_start, month_end, notes)
SELECT p.id, cz.id, v.activity, v.m_start, v.m_end, v.notes
FROM public.plants p
JOIN public.climate_zones cz ON cz.slug = 'warm-temperate'
CROSS JOIN (VALUES
  ('sow', 8::smallint, 9::smallint, 'Indoors or heat mat; pot up before planting out'),
  ('transplant', 10::smallint, 11::smallint, 'After frost risk; bury stem deep for extra roots'),
  ('harvest', 12::smallint, 4::smallint, 'Pick at breaker stage for storage; fully ripe for eating'),
  ('prune', 11::smallint, 2::smallint, 'Remove lower leaves touching soil; pinch laterals on cordon types')
) AS v(activity, m_start, m_end, notes)
WHERE p.slug = 'tomato'
  AND NOT EXISTS (
    SELECT 1 FROM public.plant_calendar pc
    WHERE pc.plant_id = p.id AND pc.activity = v.activity
      AND pc.month_start = v.m_start AND pc.month_end = v.m_end
  );

-- Hinge → governed Tomato ingredient (library profile first, then ingredients fallback)
INSERT INTO public.plant_ingredients (plant_id, ingredient_id, part, is_primary)
SELECT p.id, sub.ing_id, 'fruit', true
FROM public.plants p
CROSS JOIN LATERAL (
  SELECT ing_id FROM (
    SELECT lp.governed_ingredient_id AS ing_id, 0 AS pri
    FROM public.library_profiles lp
    WHERE lp.profile_type = 'ingredient' AND lp.slug = 'tomato' AND lp.governed_ingredient_id IS NOT NULL
    UNION ALL
    SELECT i."ID" AS ing_id, 1 AS pri FROM public.ingredients i
    WHERE lower(btrim(i."Ingredient Name")) IN ('tomato', 'tomatoes')
       OR lower(i."Ingredient Name") LIKE '%tomato%'
  ) picks ORDER BY pri LIMIT 1
) sub
WHERE p.slug = 'tomato' AND sub.ing_id IS NOT NULL
ON CONFLICT (plant_id, ingredient_id, part) DO NOTHING;

-- Pest organism
INSERT INTO public.organisms (slug, name, scientific_name, kind, description, is_published) VALUES
  ('tomato-hornworm', 'Tomato hornworm', 'Manduca quinquemaculata', 'pest',
   'Large green caterpillar that strips foliage fast.', true)
ON CONFLICT (slug) DO UPDATE SET is_published = EXCLUDED.is_published;

INSERT INTO public.plant_organisms (plant_id, organism_id, relationship, notes)
SELECT p.id, o.id, 'pest_of', 'Hand-pick at dusk; check for parasitic wasp cocoons before removing.'
FROM public.plants p, public.organisms o
WHERE p.slug = 'tomato' AND o.slug = 'tomato-hornworm'
ON CONFLICT (plant_id, organism_id, relationship) DO NOTHING;

-- Lesson
INSERT INTO public.lessons (slug, title, body, topic_id, difficulty, is_published) VALUES
  ('first-tomato-harvest',
   'Your first tomato harvest',
   'Tomatoes signal ripeness with colour, gentle give, and aroma at the stem. Harvest in the cool of morning, store stem-side up, and never refrigerate fully ripe fruit if you want best flavour.',
   (SELECT id FROM public.topics WHERE slug = 'growing-basics' LIMIT 1),
   'start',
   true)
ON CONFLICT (slug) DO UPDATE SET is_published = EXCLUDED.is_published;

INSERT INTO public.lesson_links (lesson_id, entity_type, entity_id)
SELECT l.id, 'plant', p.id
FROM public.lessons l, public.plants p
WHERE l.slug = 'first-tomato-harvest' AND p.slug = 'tomato'
  AND NOT EXISTS (
    SELECT 1 FROM public.lesson_links ll
    WHERE ll.lesson_id = l.id AND ll.entity_type = 'plant' AND ll.entity_id = p.id
  );

-- Tags + review + safety
INSERT INTO public.entity_tags (tag_id, entity_type, entity_id)
SELECT t.id, 'plant', p.id
FROM public.tags t, public.plants p
WHERE t.slug IN ('summer-crop', 'kitchen-garden') AND p.slug = 'tomato'
ON CONFLICT (tag_id, entity_type, entity_id) DO NOTHING;

INSERT INTO public.content_review (entity_type, entity_id, status, note)
SELECT 'plant', p.id, 'verified', 'Slice 1 seed — tomato E2E'
FROM public.plants p WHERE p.slug = 'tomato'
ON CONFLICT (entity_type, entity_id) DO UPDATE SET status = EXCLUDED.status;

INSERT INTO public.safety_flags (entity_type, entity_id, flag, message)
SELECT 'plant', p.id, 'toxic-foliage', 'Tomato leaves are not edible — solanine content.'
FROM public.plants p
WHERE p.slug = 'tomato'
  AND NOT EXISTS (
    SELECT 1 FROM public.safety_flags sf
    WHERE sf.entity_type = 'plant' AND sf.entity_id = p.id AND sf.flag = 'toxic-foliage'
  );

SELECT slug, common_name, is_published,
  (SELECT count(*) FROM public.plant_ingredients pi WHERE pi.plant_id = plants.id) AS ingredient_links
FROM public.plants WHERE slug = 'tomato';
