-- fix-phase49-library-profiles.sql
-- Sugar, bread, mushroom, cheddar, oregano.
-- Safe to re-run. Included when RUN-ALL-REMAINING bundle is regenerated.

INSERT INTO public.library_profiles (
  profile_type, slug, name, also_known_as, status, visibility, details
) VALUES
('ingredient', 'sugar', 'Sugar', 'White sugar, caster sugar', 'published', 'public', jsonb_build_object(
  'category', 'Pantry',
  'flavour_profile', 'Sweet — balances acid and carries caramel notes when heated.',
  'how_to_buy', 'Fine caster for baking; raw or demerara for crunch toppings.',
  'how_to_store', 'Airtight container in a dry pantry.',
  'how_to_prep', 'Sift if lumpy; measure level cups for baking accuracy.',
  'chefs_notes', 'Salt enhances sweetness — a pinch lifts desserts.',
  'did_you_know', 'Sugar was once sold in cone form and grated at home.'
)),
('ingredient', 'bread', 'Bread', 'Loaf, sliced bread', 'published', 'public', jsonb_build_object(
  'category', 'Bakery',
  'flavour_profile', 'Neutral base — toast, crumbs, and sandwiches.',
  'how_to_buy', 'Check date; artisan loaves same-day for best texture.',
  'how_to_store', 'Room temp 2–3 days; freeze slices for longer storage.',
  'how_to_prep', 'Stale bread makes excellent crumbs and French toast.',
  'chefs_notes', 'Oil or butter on cut faces slows staling.',
  'did_you_know', 'Sourdough relies on wild yeast and lactobacilli.'
)),
('ingredient', 'mushroom', 'Mushroom', 'Mushrooms, button mushrooms', 'published', 'public', jsonb_build_object(
  'category', 'Produce',
  'flavour_profile', 'Earthy, umami — sauté, roast, or soup.',
  'how_to_buy', 'Firm, dry caps; avoid slimy or darkened gills.',
  'how_to_store', 'Paper bag in fridge; use within a few days.',
  'how_to_prep', 'Wipe clean — do not soak; trim woody stems.',
  'chefs_notes', 'High heat and space — crowding steams instead of browns.',
  'did_you_know', 'Mushrooms are fungi, not vegetables botanically.'
)),
('ingredient', 'cheddar', 'Cheddar', 'Cheddar cheese', 'published', 'public', jsonb_build_object(
  'category', 'Dairy',
  'flavour_profile', 'Sharp to mild — melts, sauces, and gratins.',
  'how_to_buy', 'Block for grating; check age for sharper flavour.',
  'how_to_store', 'Fridge wrapped; bring to room temp for cheese boards.',
  'how_to_prep', 'Grate cold for clean shreds; low heat for smooth melts.',
  'chefs_notes', 'Add cheese off heat to prevent greasy splits.',
  'did_you_know', 'Cheddar originated in the English village of Cheddar.'
)),
('spice', 'oregano', 'Oregano', 'Dried oregano, fresh oregano', 'published', 'public', jsonb_build_object(
  'heat_level', 0,
  'flavour_wheel', 'Pungent, slightly bitter — Mediterranean tomato dishes.',
  'how_to_toast', 'Optional light toast for dried; crush between palms.',
  'when_to_add', 'Early in sauces; fresh leaves at end.',
  'chefs_notes', 'Dried oregano is stronger than fresh — use less volume.',
  'did_you_know', 'Oregano means "joy of the mountain" in Greek.'
))
ON CONFLICT (profile_type, slug) DO UPDATE SET
  name = EXCLUDED.name, also_known_as = EXCLUDED.also_known_as,
  status = EXCLUDED.status, visibility = EXCLUDED.visibility,
  details = EXCLUDED.details, updated_at = now();

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) IN ('sugar', 'white sugar', 'caster sugar')
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) = 'sugar' THEN 0 ELSE 1 END, "ID" LIMIT 1
) sub WHERE lp.profile_type = 'ingredient' AND lp.slug = 'sugar' AND sub.ing_id IS NOT NULL;

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) LIKE '%bread%'
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) = 'bread' THEN 0 ELSE 1 END, "ID" LIMIT 1
) sub WHERE lp.profile_type = 'ingredient' AND lp.slug = 'bread' AND sub.ing_id IS NOT NULL;

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) LIKE '%mushroom%'
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) = 'mushroom' THEN 0 ELSE 1 END, "ID" LIMIT 1
) sub WHERE lp.profile_type = 'ingredient' AND lp.slug = 'mushroom' AND sub.ing_id IS NOT NULL;

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) LIKE '%cheddar%'
  ORDER BY CASE WHEN lower("Ingredient Name") LIKE 'cheddar%' THEN 0 ELSE 1 END, "ID" LIMIT 1
) sub WHERE lp.profile_type = 'ingredient' AND lp.slug = 'cheddar' AND sub.ing_id IS NOT NULL;

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, updated_at = now()
FROM (
  SELECT "ID" AS ing_id FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) = 'oregano'
     OR lower("Ingredient Name") LIKE 'oregano,%'
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) = 'oregano' THEN 0 ELSE 1 END, "ID" LIMIT 1
) sub WHERE lp.profile_type = 'spice' AND lp.slug = 'oregano' AND sub.ing_id IS NOT NULL;

SELECT profile_type, slug, name, status, governed_ingredient_id
FROM public.library_profiles
WHERE slug IN ('sugar', 'bread', 'mushroom', 'cheddar', 'oregano')
ORDER BY slug;
