-- fix-phase47-library-profiles.sql
-- Apple, banana, pasta, red wine vinegar, thyme.
-- Safe to re-run. Included in RUN-ALL-REMAINING.sql when bundle is regenerated.

INSERT INTO public.library_profiles (
  profile_type, slug, name, also_known_as, status, visibility, details
) VALUES
('ingredient', 'apple', 'Apple', 'Apples', 'published', 'public', jsonb_build_object(
  'category', 'Produce',
  'flavour_profile', 'Sweet-tart crunch — baking, salads, and sauces.',
  'how_to_buy', 'Firm, unbruised; stem intact; variety affects bake vs eat-fresh.',
  'how_to_store', 'Fridge extends life; keep away from strong odours.',
  'how_to_prep', 'Acidulate slices to slow browning; core for even cooking.',
  'chefs_notes', 'Granny Smith holds shape in pies; softer varieties for puree.',
  'did_you_know', 'Thousands of apple varieties exist worldwide.'
)),
('ingredient', 'banana', 'Banana', 'Bananas', 'published', 'public', jsonb_build_object(
  'category', 'Produce',
  'flavour_profile', 'Sweet, creamy — ripe for eating, spotted for baking.',
  'how_to_buy', 'Green for later; yellow with brown specks for immediate use.',
  'how_to_store', 'Room temp to ripen; fridge slows ripening (skin darkens).',
  'how_to_prep', 'Mash ripe for breads; freeze peeled chunks for smoothies.',
  'chefs_notes', 'Never refrigerate unripe bananas — they may not sweeten properly.',
  'did_you_know', 'Bananas are botanically berries.'
)),
('ingredient', 'pasta', 'Pasta', 'Dried pasta, noodles', 'published', 'public', jsonb_build_object(
  'category', 'Pantry',
  'flavour_profile', 'Neutral carrier — shape pairs with sauce weight.',
  'how_to_buy', 'Bronze-die often grips sauce better; check best-before.',
  'how_to_store', 'Airtight dry pantry; use within a year for best texture.',
  'how_to_prep', 'Salt water generously; reserve pasta water for sauces.',
  'chefs_notes', 'Match shape to sauce — ridges for chunky, smooth for cream.',
  'did_you_know', 'Italy recognises hundreds of pasta shapes.'
)),
('ingredient', 'red-wine-vinegar', 'Red Wine Vinegar', 'Wine vinegar', 'published', 'public', jsonb_build_object(
  'category', 'Pantry',
  'flavour_profile', 'Sharp, fruity acidity — dressings and deglazing.',
  'how_to_buy', 'Clear bottle; no sediment clouding unless aged style.',
  'how_to_store', 'Cool pantry; cap tight — lasts years.',
  'how_to_prep', 'Balance with oil and pinch of salt in vinaigrettes.',
  'chefs_notes', 'A splash lifts lentil and bean dishes at the end.',
  'did_you_know', 'Vinegar was used as a preservative long before refrigeration.'
)),
('spice', 'thyme', 'Thyme', 'Fresh thyme, dried thyme', 'published', 'public', jsonb_build_object(
  'heat_level', 0,
  'flavour_wheel', 'Earthy, lemon-herbal — stocks, roasts, and stews.',
  'how_to_toast', 'Not needed — add early in slow cooks, late for fresh garnish.',
  'when_to_add', 'Whole sprigs in braises; strip leaves for fine dishes.',
  'chefs_notes', 'Dried thyme is potent — use about a third of fresh volume.',
  'did_you_know', 'Thyme was associated with courage in ancient symbolism.'
))
ON CONFLICT (profile_type, slug) DO UPDATE SET
  name = EXCLUDED.name, also_known_as = EXCLUDED.also_known_as,
  status = EXCLUDED.status, visibility = EXCLUDED.visibility,
  details = EXCLUDED.details, updated_at = now();

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) IN ('apple', 'apples')
     OR lower("Ingredient Name") LIKE 'apple%'
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) = 'apple' THEN 0 ELSE 1 END, "ID" LIMIT 1
) sub WHERE lp.profile_type = 'ingredient' AND lp.slug = 'apple' AND sub.ing_id IS NOT NULL;

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) IN ('banana', 'bananas')
     OR lower("Ingredient Name") LIKE 'banana%'
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) = 'banana' THEN 0 ELSE 1 END, "ID" LIMIT 1
) sub WHERE lp.profile_type = 'ingredient' AND lp.slug = 'banana' AND sub.ing_id IS NOT NULL;

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) LIKE '%pasta%'
     OR lower(btrim("Ingredient Name")) LIKE '%spaghetti%'
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) = 'pasta' THEN 0 ELSE 1 END, "ID" LIMIT 1
) sub WHERE lp.profile_type = 'ingredient' AND lp.slug = 'pasta' AND sub.ing_id IS NOT NULL;

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) LIKE '%red wine vinegar%'
     OR lower(btrim("Ingredient Name")) LIKE '%wine vinegar%'
  ORDER BY CASE WHEN lower("Ingredient Name") LIKE 'red wine vinegar%' THEN 0 ELSE 1 END, "ID" LIMIT 1
) sub WHERE lp.profile_type = 'ingredient' AND lp.slug = 'red-wine-vinegar' AND sub.ing_id IS NOT NULL;

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, updated_at = now()
FROM (
  SELECT "ID" AS ing_id FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) = 'thyme'
     OR lower("Ingredient Name") LIKE 'thyme,%'
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) = 'thyme' THEN 0 ELSE 1 END, "ID" LIMIT 1
) sub WHERE lp.profile_type = 'spice' AND lp.slug = 'thyme' AND sub.ing_id IS NOT NULL;

SELECT profile_type, slug, name, status, governed_ingredient_id
FROM public.library_profiles
WHERE slug IN ('apple', 'banana', 'pasta', 'red-wine-vinegar', 'thyme')
ORDER BY slug;
