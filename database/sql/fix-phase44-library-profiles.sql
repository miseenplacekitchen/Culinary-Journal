-- fix-phase44-library-profiles.sql
-- Carrot, celery, honey, spinach, coriander (unified library_profiles).
-- Safe to re-run. Run in Supabase SQL Editor after RUN-LIVE-CLEANUP.sql.

INSERT INTO public.library_profiles (
  profile_type, slug, name, also_known_as, status, visibility, details
) VALUES
('ingredient', 'carrot', 'Carrot', 'Gajar', 'published', 'public', jsonb_build_object(
  'category', 'Produce',
  'flavour_profile', 'Sweet, earthy, crisp when raw; mellow and sweet when roasted.',
  'how_to_buy', 'Firm, bright colour; tops fresh if attached; avoid rubbery or cracked.',
  'how_to_store', 'Fridge crisper 2–3 weeks; remove tops to stop moisture loss.',
  'how_to_prep', 'Scrub or peel; cut even sizes for even cooking.',
  'chefs_notes', 'Roast at high heat to concentrate sugars; raw adds crunch and colour.',
  'did_you_know', 'Carrots were originally purple and yellow before orange varieties dominated.'
)),
('ingredient', 'celery', 'Celery', 'Celery stalks', 'published', 'public', jsonb_build_object(
  'category', 'Produce',
  'flavour_profile', 'Clean, grassy, mildly bitter — backbone of mirepoix and stocks.',
  'how_to_buy', 'Crisp stalks that snap; pale green to green; leaves perky.',
  'how_to_store', 'Fridge upright in water or wrapped; use leaves in stock.',
  'how_to_prep', 'Stringy outer stalks fine for stock; tender inner for salads.',
  'chefs_notes', 'Salt draws moisture — balance in dressings; never overcook to grey mush.',
  'did_you_know', 'Celery was a luxury in Victorian times and used as a table centrepiece.'
)),
('ingredient', 'honey', 'Honey', 'Pure honey', 'published', 'public', jsonb_build_object(
  'category', 'Pantry',
  'flavour_profile', 'Floral sweetness — flavour varies by flower source.',
  'how_to_buy', 'Clear labelling of origin; avoid crystallised unless you want it.',
  'how_to_store', 'Cool pantry; crystallisation is natural — warm gently to reliquefy.',
  'how_to_prep', 'Measure with oiled spoon; add off heat to preserve aroma.',
  'chefs_notes', 'Never feed honey to infants under twelve months.',
  'did_you_know', 'Honey is one of the few foods that does not spoil when sealed properly.'
)),
('ingredient', 'spinach', 'Spinach', 'Palak, baby spinach', 'published', 'public', jsonb_build_object(
  'category', 'Produce',
  'flavour_profile', 'Mild, mineral, tender — wilts to almost nothing.',
  'how_to_buy', 'Dry leaves, no slime; baby spinach for salads; bunches for cooking.',
  'how_to_store', 'Fridge in bag with paper towel; use within a few days.',
  'how_to_prep', 'Wash grit away; stem thick bunches; add huge volume — it collapses.',
  'chefs_notes', 'Blanch and shock for bright green; squeeze dry for fillings.',
  'did_you_know', 'Spinach iron content was overstated in early nutrition tables due to a decimal error.'
)),
('spice', 'coriander', 'Coriander', 'Cilantro seed, dhania', 'published', 'public', jsonb_build_object(
  'heat_level', 0,
  'flavour_wheel', 'Citrus, floral, warm — seed and leaf are different ingredients.',
  'how_to_toast', 'Toast seeds in dry pan until fragrant; grind fresh for curries.',
  'when_to_add', 'Ground early in wet masalas; whole seeds in pickles and tempering.',
  'chefs_notes', 'Leaves (cilantro) bolt in heat — grow in partial shade if gardening.',
  'did_you_know', 'Coriander is one of the oldest spices in recorded cuisine.'
))
ON CONFLICT (profile_type, slug) DO UPDATE SET
  name = EXCLUDED.name,
  also_known_as = EXCLUDED.also_known_as,
  status = EXCLUDED.status,
  visibility = EXCLUDED.visibility,
  details = EXCLUDED.details,
  updated_at = now();

-- Fuzzy governed-ingredient links
UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) IN ('carrot', 'carrots')
     OR lower("Ingredient Name") LIKE 'carrot,%'
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) = 'carrot' THEN 0 ELSE 1 END, "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'carrot' AND sub.ing_id IS NOT NULL;

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) IN ('celery', 'celery stalks')
     OR lower("Ingredient Name") LIKE 'celery%'
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) = 'celery' THEN 0 ELSE 1 END, "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'celery' AND sub.ing_id IS NOT NULL;

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) = 'honey'
     OR lower("Ingredient Name") LIKE 'honey,%'
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) = 'honey' THEN 0 ELSE 1 END, "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'honey' AND sub.ing_id IS NOT NULL;

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) IN ('spinach', 'baby spinach')
     OR lower("Ingredient Name") LIKE 'spinach%'
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) = 'spinach' THEN 0 ELSE 1 END, "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'ingredient' AND lp.slug = 'spinach' AND sub.ing_id IS NOT NULL;

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, updated_at = now()
FROM (
  SELECT "ID" AS ing_id FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) IN ('coriander', 'coriander seeds', 'coriander seed')
     OR lower("Ingredient Name") LIKE 'coriander%'
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) LIKE 'coriander seed%' THEN 0 ELSE 1 END, "ID"
  LIMIT 1
) sub
WHERE lp.profile_type = 'spice' AND lp.slug = 'coriander' AND sub.ing_id IS NOT NULL;

SELECT profile_type, slug, name, status, governed_ingredient_id
FROM public.library_profiles
WHERE slug IN ('carrot', 'celery', 'honey', 'spinach', 'coriander')
ORDER BY profile_type, slug;
