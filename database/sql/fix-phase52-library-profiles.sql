-- fix-phase52-library-profiles.sql
-- Cumin, turmeric, chickpea, lentil, lime, avocado.
-- Safe to re-run. Run after phases 44–51 on live Supabase.

INSERT INTO public.library_profiles (
  profile_type, slug, name, also_known_as, status, visibility, details
) VALUES
('spice', 'cumin', 'Cumin', 'Jeera, ground cumin', 'published', 'public', jsonb_build_object(
  'heat_level', 1,
  'flavour_wheel', 'Warm, earthy, nutty — curries, rice, and roasted vegetables.',
  'how_to_toast', 'Dry-toast whole seeds until fragrant; grind fresh for brightest flavour.',
  'when_to_add', 'Whole seeds in hot oil at start; ground cumin mid-cook or in marinades.',
  'chefs_notes', 'Burnt cumin tastes bitter — pull pan off heat as soon as it smells toasted.',
  'did_you_know', 'Cumin is one of the most-used spices worldwide.'
)),
('spice', 'turmeric', 'Turmeric', 'Haldi, ground turmeric', 'published', 'public', jsonb_build_object(
  'heat_level', 0,
  'flavour_wheel', 'Earthy, slightly bitter, golden colour — curries, rice, and pickles.',
  'how_to_toast', 'Usually used ground; bloom briefly in oil to release colour and aroma.',
  'when_to_add', 'Early in oil with aromatics; stains boards and cloth — handle carefully.',
  'chefs_notes', 'Pair with black pepper — piperine may improve curcumin absorption.',
  'did_you_know', 'Fresh turmeric root is milder and less dusty than dried powder.'
)),
('ingredient', 'chickpea', 'Chickpea', 'Garbanzo bean, chana', 'published', 'public', jsonb_build_object(
  'category', 'Legumes & Pulses',
  'flavour_profile', 'Nutty, creamy when cooked — hummus, curries, and salads.',
  'how_to_buy', 'Dried for best value; canned for speed — check sodium on labels.',
  'how_to_store', 'Dried in airtight jar; canned in pantry until opened.',
  'how_to_prep', 'Soak dried overnight; pressure-cook or simmer until tender.',
  'chefs_notes', 'Save aquafaba from cans for vegan foams and baking experiments.',
  'did_you_know', 'Chickpeas have been cultivated for roughly seven thousand years.'
)),
('ingredient', 'lentil', 'Lentil', 'Masoor dal, red lentil, green lentil', 'published', 'public', jsonb_build_object(
  'category', 'Legumes & Pulses',
  'flavour_profile', 'Mild, earthy — soups, dals, and hearty salads.',
  'how_to_buy', 'Red lentils cook fastest; green and brown hold shape better.',
  'how_to_store', 'Cool dry pantry in sealed container.',
  'how_to_prep', 'Rinse; red lentils need no soak; older green lentils benefit from soaking.',
  'chefs_notes', 'Skim foam early when boiling for cleaner dal.',
  'did_you_know', 'Lentils are among the oldest domesticated crops.'
)),
('ingredient', 'lime', 'Lime', 'Persian lime, key lime', 'published', 'public', jsonb_build_object(
  'category', 'Produce',
  'flavour_profile', 'Bright acid and floral zest — finish curries, drinks, and salads.',
  'how_to_buy', 'Heavy for size; smooth skin; avoid hard or shrivelled fruit.',
  'how_to_store', 'Fridge extends life; zest before juicing if using both.',
  'how_to_prep', 'Roll on bench to release juice; microplane for fine zest.',
  'chefs_notes', 'Add juice off heat so volatile aroma stays bright.',
  'did_you_know', 'Lime juice was used by British sailors against scurvy.'
)),
('ingredient', 'avocado', 'Avocado', 'Avo', 'published', 'public', jsonb_build_object(
  'category', 'Produce',
  'flavour_profile', 'Buttery, mild — toast, salads, and creamy sauces.',
  'how_to_buy', 'Firm if eating later; yield gently at stem when ripe today.',
  'how_to_store', 'Ripen at room temp; fridge slows over-ripening.',
  'how_to_prep', 'Lemon or lime juice slows browning on cut surfaces.',
  'chefs_notes', 'Salt and acid transform bland avocado into a proper dish.',
  'did_you_know', 'Avocados are botanically berries.'
))
ON CONFLICT (profile_type, slug) DO UPDATE SET
  name = EXCLUDED.name, also_known_as = EXCLUDED.also_known_as,
  status = EXCLUDED.status, visibility = EXCLUDED.visibility,
  details = EXCLUDED.details, updated_at = now();

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) IN ('cumin', 'cumin seeds', 'ground cumin')
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) = 'cumin' THEN 0 ELSE 1 END, "ID" LIMIT 1
) sub WHERE lp.profile_type = 'spice' AND lp.slug = 'cumin' AND sub.ing_id IS NOT NULL;

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) LIKE '%turmeric%'
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) = 'turmeric' THEN 0 ELSE 1 END, "ID" LIMIT 1
) sub WHERE lp.profile_type = 'spice' AND lp.slug = 'turmeric' AND sub.ing_id IS NOT NULL;

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) LIKE '%chickpea%'
     OR lower(btrim("Ingredient Name")) LIKE '%garbanzo%'
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) LIKE 'chickpea%' THEN 0 ELSE 1 END, "ID" LIMIT 1
) sub WHERE lp.profile_type = 'ingredient' AND lp.slug = 'chickpea' AND sub.ing_id IS NOT NULL;

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) LIKE '%lentil%'
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) = 'lentil' THEN 0 ELSE 1 END, "ID" LIMIT 1
) sub WHERE lp.profile_type = 'ingredient' AND lp.slug = 'lentil' AND sub.ing_id IS NOT NULL;

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) IN ('lime', 'limes')
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) = 'lime' THEN 0 ELSE 1 END, "ID" LIMIT 1
) sub WHERE lp.profile_type = 'ingredient' AND lp.slug = 'lime' AND sub.ing_id IS NOT NULL;

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) LIKE '%avocado%'
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) = 'avocado' THEN 0 ELSE 1 END, "ID" LIMIT 1
) sub WHERE lp.profile_type = 'ingredient' AND lp.slug = 'avocado' AND sub.ing_id IS NOT NULL;

SELECT profile_type, slug, name, status, governed_ingredient_id
FROM public.library_profiles
WHERE slug IN ('cumin', 'turmeric', 'chickpea', 'lentil', 'lime', 'avocado')
ORDER BY slug;
