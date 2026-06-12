-- fix-phase46-library-profiles.sql
-- Zucchini, eggplant, yogurt, basil, green beans (unified library_profiles).
-- Safe to re-run. Run after fix-phase44/45 or via RUN-ALL-REMAINING.sql.

INSERT INTO public.library_profiles (
  profile_type, slug, name, also_known_as, status, visibility, details
) VALUES
('ingredient', 'zucchini', 'Zucchini', 'Courgette', 'published', 'public', jsonb_build_object(
  'category', 'Produce',
  'flavour_profile', 'Mild, slightly sweet — versatile for grill, bake, and quick sauté.',
  'how_to_buy', 'Firm, glossy skin; small to medium often sweeter than oversized.',
  'how_to_store', 'Fridge crisper up to a week; use soon if skin nicks.',
  'how_to_prep', 'Salting and draining reduces water in baked dishes.',
  'chefs_notes', 'Do not overcook — mushy zucchini is a texture crime.',
  'did_you_know', 'Zucchini flowers are edible and prized in Italian cooking.'
)),
('ingredient', 'eggplant', 'Eggplant', 'Aubergine, brinjal', 'published', 'public', jsonb_build_object(
  'category', 'Produce',
  'flavour_profile', 'Sponge-like flesh that absorbs flavours; creamy when roasted.',
  'how_to_buy', 'Heavy, smooth skin; stem green and fresh.',
  'how_to_store', 'Cool pantry or fridge; use within a few days.',
  'how_to_prep', 'Salt slices to reduce bitterness and oil absorption.',
  'chefs_notes', 'Char whole for baba ganoush; roast for silky dips.',
  'did_you_know', 'Eggplant is a berry botanically.'
)),
('ingredient', 'yogurt', 'Yogurt', 'Yoghurt, curd', 'published', 'public', jsonb_build_object(
  'category', 'Dairy',
  'flavour_profile', 'Tangy, creamy — marinades, sauces, and baking.',
  'how_to_buy', 'Check date; Greek styles are thicker for dips.',
  'how_to_store', 'Fridge; stir whey if separated.',
  'how_to_prep', 'Bring to room temp for baking batters if recipe specifies.',
  'chefs_notes', 'Full-fat yogurt holds up better in hot curries than skim.',
  'did_you_know', 'Yogurt has been made for at least four thousand years.'
)),
('ingredient', 'basil', 'Basil', 'Sweet basil', 'published', 'public', jsonb_build_object(
  'category', 'Produce',
  'flavour_profile', 'Sweet, anise-herbal — best fresh, never long-cooked.',
  'how_to_buy', 'Perky leaves, no black spots; smell should be bright.',
  'how_to_store', 'Stem in water like flowers; fridge loosely wrapped.',
  'how_to_prep', 'Tear rather than chop to limit bruising; add at end of cooking.',
  'chefs_notes', 'Thai basil is a different ingredient — label your stash.',
  'did_you_know', 'Basil is central to pesto Genovese.'
)),
('ingredient', 'green-beans', 'Green Beans', 'French beans, string beans', 'published', 'public', jsonb_build_object(
  'category', 'Produce',
  'flavour_profile', 'Crisp, grassy — quick cook keeps colour and snap.',
  'how_to_buy', 'Snap cleanly; no bulging seeds inside pod.',
  'how_to_store', 'Fridge in bag; use within a few days.',
  'how_to_prep', 'Trim stem end only; blanch for salads.',
  'chefs_notes', 'Overboiling turns them army-green — shock in ice water.',
  'did_you_know', 'Green beans are eaten pod and all unlike shelling beans.'
))
ON CONFLICT (profile_type, slug) DO UPDATE SET
  name = EXCLUDED.name, also_known_as = EXCLUDED.also_known_as,
  status = EXCLUDED.status, visibility = EXCLUDED.visibility,
  details = EXCLUDED.details, updated_at = now();

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) IN ('zucchini', 'courgette')
     OR lower("Ingredient Name") LIKE 'zucchini%'
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) = 'zucchini' THEN 0 ELSE 1 END, "ID" LIMIT 1
) sub WHERE lp.profile_type = 'ingredient' AND lp.slug = 'zucchini' AND sub.ing_id IS NOT NULL;

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) IN ('eggplant', 'aubergine')
     OR lower("Ingredient Name") LIKE 'eggplant%'
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) = 'eggplant' THEN 0 ELSE 1 END, "ID" LIMIT 1
) sub WHERE lp.profile_type = 'ingredient' AND lp.slug = 'eggplant' AND sub.ing_id IS NOT NULL;

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) LIKE '%yogurt%'
     OR lower(btrim("Ingredient Name")) LIKE '%yoghurt%'
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) = 'yogurt' THEN 0 ELSE 1 END, "ID" LIMIT 1
) sub WHERE lp.profile_type = 'ingredient' AND lp.slug = 'yogurt' AND sub.ing_id IS NOT NULL;

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) = 'basil'
     OR lower("Ingredient Name") LIKE 'basil,%'
  ORDER BY CASE WHEN lower(btrim("Ingredient Name")) = 'basil' THEN 0 ELSE 1 END, "ID" LIMIT 1
) sub WHERE lp.profile_type = 'ingredient' AND lp.slug = 'basil' AND sub.ing_id IS NOT NULL;

UPDATE public.library_profiles lp SET governed_ingredient_id = sub.ing_id, name = sub.ing_name, updated_at = now()
FROM (
  SELECT "ID" AS ing_id, "Ingredient Name" AS ing_name FROM public.ingredients
  WHERE lower(btrim("Ingredient Name")) LIKE '%green bean%'
     OR lower(btrim("Ingredient Name")) LIKE '%french bean%'
  ORDER BY CASE WHEN lower("Ingredient Name") LIKE 'green bean%' THEN 0 ELSE 1 END, "ID" LIMIT 1
) sub WHERE lp.profile_type = 'ingredient' AND lp.slug = 'green-beans' AND sub.ing_id IS NOT NULL;

SELECT profile_type, slug, name, status, governed_ingredient_id
FROM public.library_profiles
WHERE slug IN ('zucchini', 'eggplant', 'yogurt', 'basil', 'green-beans')
ORDER BY slug;
