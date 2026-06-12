-- =============================================================================
-- THE CULINARY JOURNAL — RUN ALL REMAINING LIVE STEPS
-- Paste entire file in Supabase SQL Editor after site code deploy.
-- Order: library 44–49 → site fill 45 → orphan 48 → categories 50 → pages 51 → health.
-- =============================================================================


-- ########## BEGIN: fix-phase44-library-profiles.sql ##########
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
-- ########## END: fix-phase44-library-profiles.sql ##########

-- ########## BEGIN: fix-phase45-site-fill.sql ##########
-- fix-phase45-site-fill.sql
-- Festival dish slots, approve pending recipes, free-tier limit settings (off by default).
-- Safe to re-run. Run after fix-phase44-library-profiles.sql on live Supabase.

-- ── Festival dish slots (beyond Onam sadya) ───────────────────────────
INSERT INTO public.festival_dishes (festival_id, dish_name, section_label, sort_order)
SELECT f.id, d.name, d.section, d.ord
FROM public.festivals f
CROSS JOIN (VALUES
  ('eid', 'Dates & water', 'Iftar', 1),
  ('eid', 'Soup / shorba', 'Iftar', 2),
  ('eid', 'Samosas / pakoras', 'Iftar', 3),
  ('eid', 'Biryani or pilaf', 'Main', 4),
  ('eid', 'Grilled meat / kebabs', 'Main', 5),
  ('eid', 'Salad & raita', 'Sides', 6),
  ('eid', 'Dessert / sheer khurma', 'Sweet', 7),
  ('christmas', 'Roast main', 'Main', 1),
  ('christmas', 'Roast potatoes', 'Sides', 2),
  ('christmas', 'Steamed vegetables', 'Sides', 3),
  ('christmas', 'Gravy / jus', 'Sides', 4),
  ('christmas', 'Christmas pudding', 'Dessert', 5),
  ('christmas', 'Mince pies', 'Dessert', 6),
  ('diwali', 'Mithai / sweets platter', 'Sweets', 1),
  ('diwali', 'Savouries / namkeen', 'Snacks', 2),
  ('diwali', 'Main feast curry', 'Main', 3),
  ('diwali', 'Rice or bread', 'Main', 4),
  ('diwali', 'Chutney & pickle', 'Sides', 5),
  ('wedding', 'Welcome drinks', 'Reception', 1),
  ('wedding', 'Appetisers', 'Reception', 2),
  ('wedding', 'Main course — vegetarian', 'Feast', 3),
  ('wedding', 'Main course — non-vegetarian', 'Feast', 4),
  ('wedding', 'Rice / bread service', 'Feast', 5),
  ('wedding', 'Dessert table', 'Sweet', 6),
  ('thanksgiving', 'Roast turkey', 'Main', 1),
  ('thanksgiving', 'Stuffing', 'Sides', 2),
  ('thanksgiving', 'Cranberry sauce', 'Sides', 3),
  ('thanksgiving', 'Mashed potatoes', 'Sides', 4),
  ('thanksgiving', 'Pumpkin pie', 'Dessert', 5),
  ('easter', 'Roast lamb or ham', 'Main', 1),
  ('easter', 'Hot cross buns', 'Bakery', 2),
  ('easter', 'Spring vegetables', 'Sides', 3),
  ('easter', 'Simnel cake', 'Dessert', 4),
  ('lunar-new-year', 'Dumplings', 'Main', 1),
  ('lunar-new-year', 'Nian gao / rice cake', 'Sweet', 2),
  ('lunar-new-year', 'Fish dish', 'Main', 3),
  ('lunar-new-year', 'Longevity noodles', 'Main', 4),
  ('lunar-new-year', 'Tray of togetherness', 'Snacks', 5)
) AS d(slug, name, section, ord)
WHERE f.slug = d.slug
  AND NOT EXISTS (
    SELECT 1 FROM public.festival_dishes fd
    WHERE fd.festival_id = f.id AND fd.dish_name = d.name
  );

-- ── Approve all pending recipes (increases public browse content) ─────
UPDATE public.submitted_recipes
SET status = 'approved',
    reviewed_at = COALESCE(reviewed_at, now())
WHERE status = 'pending';

-- ── Free-tier limit settings (disabled until admin enables) ───────────
INSERT INTO public.site_settings (key, value) VALUES
  ('enforce_free_limits', 'false'),
  ('free_max_recipes', '10'),
  ('free_max_photo_imports_month', '5'),
  ('free_max_tables', '1')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

SELECT jsonb_build_object(
  'status', 'fix-phase45-site-fill ready',
  'approved_now', (SELECT count(*)::int FROM public.submitted_recipes WHERE status = 'approved'),
  'pending_remaining', (SELECT count(*)::int FROM public.submitted_recipes WHERE status = 'pending'),
  'festival_dish_counts', (
    SELECT jsonb_object_agg(f.slug, cnt)
    FROM (
      SELECT f2.slug, count(fd.id)::int AS cnt
      FROM public.festivals f2
      LEFT JOIN public.festival_dishes fd ON fd.festival_id = f2.id
      GROUP BY f2.slug
    ) f
  )
) AS phase45_summary;
-- ########## END: fix-phase45-site-fill.sql ##########

-- ########## BEGIN: fix-phase46-library-profiles.sql ##########
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
-- ########## END: fix-phase46-library-profiles.sql ##########

-- ########## BEGIN: fix-phase47-library-profiles.sql ##########
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
-- ########## END: fix-phase47-library-profiles.sql ##########

-- ########## BEGIN: fix-phase48-recipe-ingredient-orphans.sql ##########
-- fix-phase48-recipe-ingredient-orphans.sql
-- Repair approved-recipe ingredient lines that do not match governed ingredients.
-- Safe to re-run. Run when health_report shows orphan_recipe_ingredient_names > 0.

-- ── 1. Show orphans before repair ─────────────────────────────────────
SELECT DISTINCT
  x.ing_name AS orphan_name,
  x.recipe_count
FROM (
  SELECT
    lower(btrim(COALESCE(item->>'ingredient', item->>'name', ''))) AS ing_name,
    count(DISTINCT sr.id)::int AS recipe_count
  FROM public.submitted_recipes sr,
       jsonb_array_elements(COALESCE(sr.ingredients, '[]'::jsonb)) sec,
       jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
  WHERE sr.status = 'approved'
    AND btrim(COALESCE(item->>'ingredient', item->>'name', '')) <> ''
  GROUP BY 1
) x
WHERE NOT EXISTS (
  SELECT 1 FROM public.ingredients i
  WHERE lower(btrim(i."Ingredient Name")) = x.ing_name
     OR EXISTS (
       SELECT 1
       FROM unnest(string_to_array(lower(COALESCE(i."Also Known As", '')), ',')) aka(part)
       WHERE btrim(aka.part) = x.ing_name
     )
)
ORDER BY x.recipe_count DESC, x.ing_name;

-- ── 2. Resolve raw text → canonical governed name (or null) ───────────
CREATE OR REPLACE FUNCTION public.tcj_resolve_governed_ingredient_name(p_raw text)
RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_raw text;
  v_name text;
  v_cnt int;
BEGIN
  v_raw := lower(btrim(COALESCE(p_raw, '')));
  IF v_raw = '' OR length(v_raw) < 2 THEN RETURN NULL; END IF;

  SELECT i."Ingredient Name" INTO v_name
  FROM public.ingredients i
  WHERE lower(btrim(i."Ingredient Name")) = v_raw
  LIMIT 1;
  IF v_name IS NOT NULL THEN RETURN v_name; END IF;

  SELECT i."Ingredient Name" INTO v_name
  FROM public.ingredients i
  WHERE i."Also Known As" IS NOT NULL
    AND EXISTS (
      SELECT 1
      FROM unnest(string_to_array(lower(i."Also Known As"), ',')) aka(part)
      WHERE btrim(aka.part) = v_raw
    )
  LIMIT 1;
  IF v_name IS NOT NULL THEN RETURN v_name; END IF;

  SELECT count(*)::int INTO v_cnt
  FROM public.ingredients i
  WHERE length(v_raw) >= 4
    AND lower(btrim(i."Ingredient Name")) LIKE '%' || v_raw || '%';

  IF v_cnt = 1 THEN
    SELECT i."Ingredient Name" INTO v_name
    FROM public.ingredients i
    WHERE length(v_raw) >= 4
      AND lower(btrim(i."Ingredient Name")) LIKE '%' || v_raw || '%'
    LIMIT 1;
    RETURN v_name;
  END IF;

  SELECT count(*)::int INTO v_cnt
  FROM public.ingredients i
  WHERE length(v_raw) >= 4
    AND v_raw LIKE '%' || lower(btrim(i."Ingredient Name")) || '%'
    AND length(btrim(i."Ingredient Name")) >= 4;

  IF v_cnt = 1 THEN
    SELECT i."Ingredient Name" INTO v_name
    FROM public.ingredients i
    WHERE length(v_raw) >= 4
      AND v_raw LIKE '%' || lower(btrim(i."Ingredient Name")) || '%'
      AND length(btrim(i."Ingredient Name")) >= 4
    LIMIT 1;
    RETURN v_name;
  END IF;

  RETURN NULL;
END;
$$;

-- ── 3. Rewrite approved recipe JSON (ingredient + name keys) ──────────
CREATE OR REPLACE FUNCTION public.repair_orphan_recipe_ingredients()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_rec record;
  v_secs jsonb;
  v_sec jsonb;
  v_item jsonb;
  v_new_items jsonb;
  v_raw text;
  v_canonical text;
  v_changed boolean;
  v_recipes int := 0;
  v_lines int := 0;
  v_inserted int := 0;
  v_orphan text;
BEGIN
  FOR v_rec IN
    SELECT id, ingredients
    FROM public.submitted_recipes
    WHERE status = 'approved' AND ingredients IS NOT NULL
  LOOP
    v_secs := '[]'::jsonb;
    v_changed := false;

    FOR v_sec IN SELECT value FROM jsonb_array_elements(v_rec.ingredients) AS t(value)
    LOOP
      v_new_items := '[]'::jsonb;
      FOR v_item IN SELECT value FROM jsonb_array_elements(COALESCE(v_sec->'items', '[]'::jsonb)) AS t(value)
      LOOP
        v_raw := btrim(COALESCE(v_item->>'ingredient', v_item->>'name', ''));
        IF v_raw <> '' THEN
          v_canonical := public.tcj_resolve_governed_ingredient_name(v_raw);
          IF v_canonical IS NOT NULL
             AND (v_item->>'ingredient' IS DISTINCT FROM v_canonical
                  OR v_item->>'name' IS DISTINCT FROM v_canonical) THEN
            v_item := jsonb_set(v_item, '{ingredient}', to_jsonb(v_canonical), true);
            v_item := jsonb_set(v_item, '{name}', to_jsonb(v_canonical), true);
            v_changed := true;
            v_lines := v_lines + 1;
          ELSIF btrim(COALESCE(v_item->>'ingredient', '')) = '' AND btrim(COALESCE(v_item->>'name', '')) <> '' THEN
            v_item := jsonb_set(v_item, '{ingredient}', to_jsonb(btrim(v_item->>'name')), true);
            v_changed := true;
            v_lines := v_lines + 1;
          END IF;
        END IF;
        v_new_items := v_new_items || jsonb_build_array(v_item);
      END LOOP;
      v_sec := jsonb_set(v_sec, '{items}', v_new_items);
      v_secs := v_secs || jsonb_build_array(v_sec);
    END LOOP;

    IF v_changed THEN
      UPDATE public.submitted_recipes SET ingredients = v_secs WHERE id = v_rec.id;
      v_recipes := v_recipes + 1;
    END IF;
  END LOOP;

  FOR v_orphan IN
    SELECT DISTINCT lower(btrim(COALESCE(item->>'ingredient', item->>'name', ''))) AS ing_name
    FROM public.submitted_recipes sr,
         jsonb_array_elements(COALESCE(sr.ingredients, '[]'::jsonb)) sec,
         jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
    WHERE sr.status = 'approved'
      AND btrim(COALESCE(item->>'ingredient', item->>'name', '')) <> ''
      AND public.tcj_resolve_governed_ingredient_name(
        btrim(COALESCE(item->>'ingredient', item->>'name', ''))
      ) IS NULL
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM public.ingredients i
      WHERE lower(btrim(i."Ingredient Name")) = v_orphan
    ) THEN
      INSERT INTO public.ingredients ("Ingredient Name", "Category", "Notes")
      VALUES (
        initcap(v_orphan),
        'Uncategorised',
        'Auto-added by fix-phase48 — recipe orphan repair'
      );
      v_inserted := v_inserted + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'recipes_updated', v_recipes,
    'lines_normalized', v_lines,
    'ingredients_inserted', v_inserted
  );
END;
$$;

SELECT public.repair_orphan_recipe_ingredients() AS phase48_repair_summary;

-- ── 4. Orphans remaining (expect zero rows) ───────────────────────────
SELECT DISTINCT x.ing_name AS orphan_still_remaining
FROM (
  SELECT lower(btrim(COALESCE(item->>'ingredient', item->>'name', ''))) AS ing_name
  FROM public.submitted_recipes sr,
       jsonb_array_elements(COALESCE(sr.ingredients, '[]'::jsonb)) sec,
       jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
  WHERE sr.status = 'approved'
    AND btrim(COALESCE(item->>'ingredient', item->>'name', '')) <> ''
) x
WHERE NOT EXISTS (
  SELECT 1 FROM public.ingredients i
  WHERE lower(btrim(i."Ingredient Name")) = x.ing_name
     OR EXISTS (
       SELECT 1
       FROM unnest(string_to_array(lower(COALESCE(i."Also Known As", '')), ',')) aka(part)
       WHERE btrim(aka.part) = x.ing_name
     )
)
ORDER BY 1;
-- ########## END: fix-phase48-recipe-ingredient-orphans.sql ##########

-- ########## BEGIN: fix-phase49-library-profiles.sql ##########
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
-- ########## END: fix-phase49-library-profiles.sql ##########

-- ########## BEGIN: fix-phase50-ingredient-categories.sql ##########
-- fix-phase50-ingredient-categories.sql
-- Assign categories to phase48 auto-added Uncategorised ingredients.
-- Safe to re-run.

UPDATE public.ingredients SET
  "Category" = CASE
    WHEN lower("Ingredient Name") ~ '(chicken|beef|pork|lamb|mutton|fish|prawn|shrimp|crab|squid|egg|tofu)' THEN 'Protein'
    WHEN lower("Ingredient Name") ~ '(milk|cream|butter|cheese|yogurt|yoghurt|ghee|paneer)' THEN 'Dairy'
    WHEN lower("Ingredient Name") ~ '(oil|vinegar|sauce|paste|stock|broth|flour|rice|pasta|noodle|semolina|sugar|salt|spice|powder|cumin|turmeric|paprika)' THEN 'Pantry'
    WHEN lower("Ingredient Name") ~ '(onion|garlic|tomato|pepper|carrot|celery|herb|leaf|spinach|potato|apple|banana|mushroom|lemon|ginger)' THEN 'Produce'
    ELSE 'Pantry'
  END,
  "Sub Category" = COALESCE(NULLIF(btrim("Sub Category"), ''), 'General'),
  "Notes" = CASE
    WHEN "Notes" LIKE '%fix-phase48%' THEN regexp_replace("Notes", 'Auto-added by fix-phase48[^.]*\.?', 'Category assigned by fix-phase50', 'g')
    ELSE COALESCE("Notes", 'Category assigned by fix-phase50')
  END
WHERE "Category" IS NULL
   OR btrim("Category") IN ('', 'Uncategorised', 'Uncategorized')
   OR "Notes" LIKE '%fix-phase48%';

SELECT "ID", "Ingredient Name", "Category", "Sub Category"
FROM public.ingredients
WHERE "Notes" LIKE '%fix-phase50%' OR "Notes" LIKE '%fix-phase48%'
ORDER BY "ID" DESC
LIMIT 20;
-- ########## END: fix-phase50-ingredient-categories.sql ##########

-- ########## BEGIN: fix-phase51-soft-launch-pages.sql ##########
-- fix-phase51-soft-launch-pages.sql
-- Register core member pages for soft launch (public or registered as appropriate).
-- Safe to re-run. Betty can still override in Site Management → Pages.

INSERT INTO public.site_pages (name, path, visibility, sort_order, min_tier) VALUES
  ('Recipes', 'recipes.html', 'public', 10, 'free'),
  ('Recipe Page', 'recipe-page.html', 'public', 11, 'free'),
  ('Submit Recipe', 'submit-recipe.html', 'registered', 12, 'free'),
  ('My Dashboard', 'my-dashboard.html', 'registered', 13, 'free'),
  ('Grocery List', 'grocery.html', 'registered', 14, 'free'),
  ('Pantry', 'pantry.html', 'registered', 15, 'free'),
  ('Meal Planner', 'meal-planner.html', 'registered', 16, 'free'),
  ('Household', 'household.html', 'registered', 17, 'free'),
  ('Library Directory', 'library-directory.html', 'public', 18, 'free'),
  ('Library Submit', 'library-submit.html', 'registered', 19, 'free'),
  ('Print Studio', 'print-studio.html', 'registered', 20, 'free'),
  ('Table Planner', 'table-planner.html', 'registered', 21, 'free'),
  ('Diary', 'diary.html', 'registered', 22, 'free'),
  ('Culinary Life', 'culinary-life.html', 'registered', 23, 'free'),
  ('Family Profiles', 'family-profiles.html', 'registered', 24, 'free'),
  ('Lane 2 Spot-Check', 'lane2-spot-check.html', 'registered', 250, 'free'),
  ('Theme Sweep', 'theme-sweep.html', 'registered', 251, 'free'),
  ('Admin Dashboard', 'dashboard.html', 'registered', 252, 'free')
ON CONFLICT (path) DO UPDATE SET
  name = EXCLUDED.name,
  visibility = EXCLUDED.visibility,
  sort_order = EXCLUDED.sort_order,
  min_tier = EXCLUDED.min_tier,
  updated_at = now();

-- Ensure browse + map pages stay public for soft launch
UPDATE public.site_pages SET visibility = 'public', min_tier = 'free', updated_at = now()
WHERE path IN (
  'recipes.html', 'recipe-page.html', 'library-directory.html',
  'food-map.html', 'festival-calendar.html', 'user.html', 'index.html'
);

SELECT path, name, visibility, min_tier
FROM public.site_pages
WHERE path IN ('recipes.html', 'grocery.html', 'meal-planner.html', 'dashboard.html', 'lane2-spot-check.html')
ORDER BY sort_order;
-- ########## END: fix-phase51-soft-launch-pages.sql ##########


-- ########## BEGIN: fix-phase52-library-profiles.sql ##########
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
-- ########## END: fix-phase52-library-profiles.sql ##########

-- ########## BEGIN: fix-phase52-lane2-recipes.sql ##########
-- fix-phase52-lane2-recipes.sql
-- Seed three approved public recipes for Lane 2 / hero testing (verify account).
-- Safe to re-run — skips when recipe_name already exists.

DO $$
DECLARE
  v_uid uuid;
  v_n   int := 0;
BEGIN
  SELECT u.id INTO v_uid FROM auth.users u
  WHERE lower(u.email) = lower('tcj.verify@outlook.com')
  LIMIT 1;

  IF v_uid IS NULL THEN
    RAISE NOTICE 'tcj.verify@outlook.com not found — create account first (fix-tcj-verify-account.sql)';
    RETURN;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.submitted_recipes WHERE recipe_name = 'Lemon Herb Rice') THEN
    INSERT INTO public.submitted_recipes (
      user_id, recipe_name, category, spice_level, sweet_level,
      origin_continent, origin_country, introduction,
      prep_time_minutes, cook_time_minutes, servings,
      dietary_tags, meal_type_tags, style_tags,
      ingredients, method, cooking_notes,
      source_type, visibility, status, reviewed_at, difficulty
    ) VALUES (
      v_uid, 'Lemon Herb Rice', 'Rice & Grains', 'Mild', 'Not Applicable',
      'Asia', 'India',
      'A bright, everyday rice side with lemon and herbs — pairs with curries or grilled fish.',
      10, 20, 4,
      ARRAY['Vegetarian'], ARRAY['Side', 'Rice'], ARRAY['Everyday', 'Traditional'],
      jsonb_build_array(jsonb_build_object(
        'section', 'Ingredients',
        'items', jsonb_build_array(
          jsonb_build_object('qty', '1', 'unit', 'cup', 'ingredient', 'Rice', 'note', 'basmati or jasmine', 'category', ''),
          jsonb_build_object('qty', '2', 'unit', 'cup', 'ingredient', 'Water', 'note', '', 'category', ''),
          jsonb_build_object('qty', '1', 'unit', 'tbsp', 'ingredient', 'Butter', 'note', 'or oil', 'category', ''),
          jsonb_build_object('qty', '1', 'unit', '', 'ingredient', 'Lime', 'note', 'zest and juice', 'category', ''),
          jsonb_build_object('qty', '2', 'unit', 'tbsp', 'ingredient', 'Coriander', 'note', 'fresh, chopped', 'category', '')
        )
      )),
      jsonb_build_array(jsonb_build_object(
        'section', 'DIRECTIONS',
        'steps', jsonb_build_array(
          jsonb_build_object('title', '', 'text', 'Rinse rice until water runs mostly clear; drain well.'),
          jsonb_build_object('title', '', 'text', 'Bring water to a boil with a pinch of salt; add rice, cover, and simmer on low 15 minutes.'),
          jsonb_build_object('title', '', 'text', 'Rest covered 5 minutes; fluff with a fork.'),
          jsonb_build_object('title', '', 'text', 'Fold through butter, lime zest, lime juice, and coriander. Serve warm.')
        )
      )),
      'Resting the rice keeps grains separate.',
      'Original', 'Public', 'approved', now(), 'Easy'
    );
    v_n := v_n + 1;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.submitted_recipes WHERE recipe_name = 'Quick Chickpea Curry') THEN
    INSERT INTO public.submitted_recipes (
      user_id, recipe_name, category, spice_level, sweet_level,
      origin_continent, origin_country, introduction,
      prep_time_minutes, cook_time_minutes, servings,
      dietary_tags, meal_type_tags, style_tags,
      ingredients, method, cooking_notes,
      source_type, visibility, status, reviewed_at, difficulty
    ) VALUES (
      v_uid, 'Quick Chickpea Curry', 'Curries & Stews', 'Medium', 'Not Applicable',
      'Asia', 'India',
      'Pantry-friendly chickpea curry for weeknights — serve with rice or flatbread.',
      15, 25, 4,
      ARRAY['Vegetarian', 'Vegan'], ARRAY['Main', 'Dinner'], ARRAY['Everyday', 'Comfort Food'],
      jsonb_build_array(jsonb_build_object(
        'section', 'Ingredients',
        'items', jsonb_build_array(
          jsonb_build_object('qty', '2', 'unit', 'can', 'ingredient', 'Chickpea', 'note', 'drained and rinsed', 'category', ''),
          jsonb_build_object('qty', '1', 'unit', 'medium', 'ingredient', 'Onion', 'note', 'diced', 'category', ''),
          jsonb_build_object('qty', '3', 'unit', 'clove', 'ingredient', 'Garlic', 'note', 'minced', 'category', ''),
          jsonb_build_object('qty', '1', 'unit', 'tsp', 'ingredient', 'Cumin', 'note', '', 'category', ''),
          jsonb_build_object('qty', '0.5', 'unit', 'tsp', 'ingredient', 'Turmeric', 'note', '', 'category', ''),
          jsonb_build_object('qty', '400', 'unit', 'g', 'ingredient', 'Tomato', 'note', 'canned chopped', 'category', ''),
          jsonb_build_object('qty', '0.5', 'unit', 'cup', 'ingredient', 'Coconut milk', 'note', '', 'category', '')
        )
      )),
      jsonb_build_array(jsonb_build_object(
        'section', 'DIRECTIONS',
        'steps', jsonb_build_array(
          jsonb_build_object('title', '', 'text', 'Sauté onion in oil until golden; add garlic, cumin, and turmeric.'),
          jsonb_build_object('title', '', 'text', 'Add tomatoes; simmer until thickened.'),
          jsonb_build_object('title', '', 'text', 'Stir in chickpeas and coconut milk; simmer 15 minutes.'),
          jsonb_build_object('title', '', 'text', 'Season with salt; finish with lime juice if liked.')
        )
      )),
      'Mash a few chickpeas against the pan for a thicker sauce.',
      'Original', 'Public', 'approved', now(), 'Easy'
    );
    v_n := v_n + 1;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.submitted_recipes WHERE recipe_name = 'Avocado Lime Toast') THEN
    INSERT INTO public.submitted_recipes (
      user_id, recipe_name, category, spice_level, sweet_level,
      origin_continent, origin_country, introduction,
      prep_time_minutes, cook_time_minutes, servings,
      dietary_tags, meal_type_tags, style_tags,
      ingredients, method, cooking_notes,
      source_type, visibility, status, reviewed_at, difficulty
    ) VALUES (
      v_uid, 'Avocado Lime Toast', 'Breakfast & Brunch', 'Not Applicable', 'Not Applicable',
      'Oceania', 'Australia',
      'Simple café-style toast — good for Lane 2 hero and grocery add tests.',
      5, 5, 2,
      ARRAY['Vegetarian'], ARRAY['Breakfast', 'Brunch'], ARRAY['Everyday', 'Modern'],
      jsonb_build_array(jsonb_build_object(
        'section', 'Ingredients',
        'items', jsonb_build_array(
          jsonb_build_object('qty', '2', 'unit', 'slice', 'ingredient', 'Bread', 'note', 'sourdough or wholegrain', 'category', ''),
          jsonb_build_object('qty', '1', 'unit', 'large', 'ingredient', 'Avocado', 'note', 'ripe', 'category', ''),
          jsonb_build_object('qty', '0.5', 'unit', '', 'ingredient', 'Lime', 'note', 'juice', 'category', ''),
          jsonb_build_object('qty', '1', 'unit', 'pinch', 'ingredient', 'Salt', 'note', 'flaky if possible', 'category', ''),
          jsonb_build_object('qty', '1', 'unit', 'pinch', 'ingredient', 'Black pepper', 'note', '', 'category', '')
        )
      )),
      jsonb_build_array(jsonb_build_object(
        'section', 'DIRECTIONS',
        'steps', jsonb_build_array(
          jsonb_build_object('title', '', 'text', 'Toast bread until crisp.'),
          jsonb_build_object('title', '', 'text', 'Mash avocado with lime juice and salt.'),
          jsonb_build_object('title', '', 'text', 'Spread on toast; finish with pepper. Serve immediately.')
        )
      )),
      'Acid and salt keep avocado vivid green for a few minutes.',
      'Original', 'Public', 'approved', now(), 'Easy'
    );
    v_n := v_n + 1;
  END IF;

  RAISE NOTICE 'phase52 recipes inserted: %', v_n;
END $$;

SELECT recipe_name, status, visibility, servings, reviewed_at
FROM public.submitted_recipes
WHERE recipe_name IN ('Lemon Herb Rice', 'Quick Chickpea Curry', 'Avocado Lime Toast')
ORDER BY recipe_name;

SELECT jsonb_build_object(
  'approved_total', (SELECT count(*)::int FROM public.submitted_recipes WHERE status = 'approved'),
  'pending_total', (SELECT count(*)::int FROM public.submitted_recipes WHERE status = 'pending')
) AS recipe_counts;
-- ########## END: fix-phase52-lane2-recipes.sql ##########

-- ########## BEGIN: fix-phase52-library-profiles.sql ##########
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
-- ########## END: fix-phase52-library-profiles.sql ##########

-- ########## BEGIN: fix-phase52-lane2-recipes.sql ##########
-- fix-phase52-lane2-recipes.sql
-- Seed three approved public recipes for Lane 2 / hero testing (verify account).
-- Safe to re-run — skips when recipe_name already exists.

DO $$
DECLARE
  v_uid uuid;
  v_n   int := 0;
BEGIN
  SELECT u.id INTO v_uid FROM auth.users u
  WHERE lower(u.email) = lower('tcj.verify@outlook.com')
  LIMIT 1;

  IF v_uid IS NULL THEN
    RAISE NOTICE 'tcj.verify@outlook.com not found — create account first (fix-tcj-verify-account.sql)';
    RETURN;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.submitted_recipes WHERE recipe_name = 'Lemon Herb Rice') THEN
    INSERT INTO public.submitted_recipes (
      user_id, recipe_name, category, spice_level, sweet_level,
      origin_continent, origin_country, introduction,
      prep_time_minutes, cook_time_minutes, servings,
      dietary_tags, meal_type_tags, style_tags,
      ingredients, method, cooking_notes,
      source_type, visibility, status, reviewed_at, difficulty
    ) VALUES (
      v_uid, 'Lemon Herb Rice', 'Rice & Grains', 'Mild', 'Not Applicable',
      'Asia', 'India',
      'A bright, everyday rice side with lemon and herbs — pairs with curries or grilled fish.',
      10, 20, 4,
      ARRAY['Vegetarian'], ARRAY['Side', 'Rice'], ARRAY['Everyday', 'Traditional'],
      jsonb_build_array(jsonb_build_object(
        'section', 'Ingredients',
        'items', jsonb_build_array(
          jsonb_build_object('qty', '1', 'unit', 'cup', 'ingredient', 'Rice', 'note', 'basmati or jasmine', 'category', ''),
          jsonb_build_object('qty', '2', 'unit', 'cup', 'ingredient', 'Water', 'note', '', 'category', ''),
          jsonb_build_object('qty', '1', 'unit', 'tbsp', 'ingredient', 'Butter', 'note', 'or oil', 'category', ''),
          jsonb_build_object('qty', '1', 'unit', '', 'ingredient', 'Lime', 'note', 'zest and juice', 'category', ''),
          jsonb_build_object('qty', '2', 'unit', 'tbsp', 'ingredient', 'Coriander', 'note', 'fresh, chopped', 'category', '')
        )
      )),
      jsonb_build_array(jsonb_build_object(
        'section', 'DIRECTIONS',
        'steps', jsonb_build_array(
          jsonb_build_object('title', '', 'text', 'Rinse rice until water runs mostly clear; drain well.'),
          jsonb_build_object('title', '', 'text', 'Bring water to a boil with a pinch of salt; add rice, cover, and simmer on low 15 minutes.'),
          jsonb_build_object('title', '', 'text', 'Rest covered 5 minutes; fluff with a fork.'),
          jsonb_build_object('title', '', 'text', 'Fold through butter, lime zest, lime juice, and coriander. Serve warm.')
        )
      )),
      'Resting the rice keeps grains separate.',
      'Original', 'Public', 'approved', now(), 'Easy'
    );
    v_n := v_n + 1;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.submitted_recipes WHERE recipe_name = 'Quick Chickpea Curry') THEN
    INSERT INTO public.submitted_recipes (
      user_id, recipe_name, category, spice_level, sweet_level,
      origin_continent, origin_country, introduction,
      prep_time_minutes, cook_time_minutes, servings,
      dietary_tags, meal_type_tags, style_tags,
      ingredients, method, cooking_notes,
      source_type, visibility, status, reviewed_at, difficulty
    ) VALUES (
      v_uid, 'Quick Chickpea Curry', 'Curries & Stews', 'Medium', 'Not Applicable',
      'Asia', 'India',
      'Pantry-friendly chickpea curry for weeknights — serve with rice or flatbread.',
      15, 25, 4,
      ARRAY['Vegetarian', 'Vegan'], ARRAY['Main', 'Dinner'], ARRAY['Everyday', 'Comfort Food'],
      jsonb_build_array(jsonb_build_object(
        'section', 'Ingredients',
        'items', jsonb_build_array(
          jsonb_build_object('qty', '2', 'unit', 'can', 'ingredient', 'Chickpea', 'note', 'drained and rinsed', 'category', ''),
          jsonb_build_object('qty', '1', 'unit', 'medium', 'ingredient', 'Onion', 'note', 'diced', 'category', ''),
          jsonb_build_object('qty', '3', 'unit', 'clove', 'ingredient', 'Garlic', 'note', 'minced', 'category', ''),
          jsonb_build_object('qty', '1', 'unit', 'tsp', 'ingredient', 'Cumin', 'note', '', 'category', ''),
          jsonb_build_object('qty', '0.5', 'unit', 'tsp', 'ingredient', 'Turmeric', 'note', '', 'category', ''),
          jsonb_build_object('qty', '400', 'unit', 'g', 'ingredient', 'Tomato', 'note', 'canned chopped', 'category', ''),
          jsonb_build_object('qty', '0.5', 'unit', 'cup', 'ingredient', 'Coconut milk', 'note', '', 'category', '')
        )
      )),
      jsonb_build_array(jsonb_build_object(
        'section', 'DIRECTIONS',
        'steps', jsonb_build_array(
          jsonb_build_object('title', '', 'text', 'Sauté onion in oil until golden; add garlic, cumin, and turmeric.'),
          jsonb_build_object('title', '', 'text', 'Add tomatoes; simmer until thickened.'),
          jsonb_build_object('title', '', 'text', 'Stir in chickpeas and coconut milk; simmer 15 minutes.'),
          jsonb_build_object('title', '', 'text', 'Season with salt; finish with lime juice if liked.')
        )
      )),
      'Mash a few chickpeas against the pan for a thicker sauce.',
      'Original', 'Public', 'approved', now(), 'Easy'
    );
    v_n := v_n + 1;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.submitted_recipes WHERE recipe_name = 'Avocado Lime Toast') THEN
    INSERT INTO public.submitted_recipes (
      user_id, recipe_name, category, spice_level, sweet_level,
      origin_continent, origin_country, introduction,
      prep_time_minutes, cook_time_minutes, servings,
      dietary_tags, meal_type_tags, style_tags,
      ingredients, method, cooking_notes,
      source_type, visibility, status, reviewed_at, difficulty
    ) VALUES (
      v_uid, 'Avocado Lime Toast', 'Breakfast & Brunch', 'Not Applicable', 'Not Applicable',
      'Oceania', 'Australia',
      'Simple café-style toast — good for Lane 2 hero and grocery add tests.',
      5, 5, 2,
      ARRAY['Vegetarian'], ARRAY['Breakfast', 'Brunch'], ARRAY['Everyday', 'Modern'],
      jsonb_build_array(jsonb_build_object(
        'section', 'Ingredients',
        'items', jsonb_build_array(
          jsonb_build_object('qty', '2', 'unit', 'slice', 'ingredient', 'Bread', 'note', 'sourdough or wholegrain', 'category', ''),
          jsonb_build_object('qty', '1', 'unit', 'large', 'ingredient', 'Avocado', 'note', 'ripe', 'category', ''),
          jsonb_build_object('qty', '0.5', 'unit', '', 'ingredient', 'Lime', 'note', 'juice', 'category', ''),
          jsonb_build_object('qty', '1', 'unit', 'pinch', 'ingredient', 'Salt', 'note', 'flaky if possible', 'category', ''),
          jsonb_build_object('qty', '1', 'unit', 'pinch', 'ingredient', 'Black pepper', 'note', '', 'category', '')
        )
      )),
      jsonb_build_array(jsonb_build_object(
        'section', 'DIRECTIONS',
        'steps', jsonb_build_array(
          jsonb_build_object('title', '', 'text', 'Toast bread until crisp.'),
          jsonb_build_object('title', '', 'text', 'Mash avocado with lime juice and salt.'),
          jsonb_build_object('title', '', 'text', 'Spread on toast; finish with pepper. Serve immediately.')
        )
      )),
      'Acid and salt keep avocado vivid green for a few minutes.',
      'Original', 'Public', 'approved', now(), 'Easy'
    );
    v_n := v_n + 1;
  END IF;

  RAISE NOTICE 'phase52 recipes inserted: %', v_n;
END $$;

SELECT recipe_name, status, visibility, servings, reviewed_at
FROM public.submitted_recipes
WHERE recipe_name IN ('Lemon Herb Rice', 'Quick Chickpea Curry', 'Avocado Lime Toast')
ORDER BY recipe_name;

SELECT jsonb_build_object(
  'approved_total', (SELECT count(*)::int FROM public.submitted_recipes WHERE status = 'approved'),
  'pending_total', (SELECT count(*)::int FROM public.submitted_recipes WHERE status = 'pending')
) AS recipe_counts;
-- ########## END: fix-phase52-lane2-recipes.sql ##########

-- ########## BEGIN: fix-phase52-recipe-orphan-repair.sql ##########
-- fix-phase52-recipe-orphan-repair.sql
-- Run after fix-phase52-lane2-recipes.sql when health shows orphan_recipe_ingredient_names > 0.
-- Safe to re-run.

-- ── 1. Lane 2 staples missing from governed table ───────────────────
INSERT INTO public.ingredients ("Ingredient Name", "Category", "Notes")
SELECT x.name, x.cat, 'Phase 52 Lane 2 staple'
FROM (VALUES
  ('Water', 'Pantry'),
  ('Rice', 'Grains, Pasta & Noodles'),
  ('Lime', 'Produce'),
  ('Chickpea', 'Legumes & Pulses'),
  ('Cumin', 'Spices'),
  ('Turmeric', 'Spices'),
  ('Avocado', 'Produce'),
  ('Bread', 'Breads & Flatbreads'),
  ('Black pepper', 'Spices')
) AS x(name, cat)
WHERE NOT EXISTS (
  SELECT 1 FROM public.ingredients i
  WHERE lower(btrim(i."Ingredient Name")) = lower(btrim(x.name))
);

-- ── 2. Also-known-as aliases for common recipe shorthand ────────────
UPDATE public.ingredients i SET "Also Known As" = x.aka
FROM (VALUES
  ('Coconut Milk (canned, full fat)', 'coconut milk, coconut milk canned'),
  ('Tomato', 'tomatoes, canned tomato, chopped tomato'),
  ('Coriander', 'fresh coriander, coriander leaves, cilantro'),
  ('Cumin Seeds', 'cumin, ground cumin'),
  ('Garlic', 'garlic clove, garlic cloves'),
  ('Onion', 'onions, brown onion'),
  ('Butter', 'unsalted butter, salted butter'),
  ('Salt', 'sea salt, table salt')
) AS x(ing_name, aka)
WHERE lower(btrim(i."Ingredient Name")) = lower(btrim(x.ing_name))
  AND (i."Also Known As" IS NULL OR i."Also Known As" NOT ILIKE '%' || split_part(x.aka, ',', 1) || '%');

-- Fallback: append aka when ingredient exists under a close name
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('coconut milk', '%coconut milk%'),
      ('cumin', '%cumin%'),
      ('turmeric', '%turmeric%'),
      ('tomato', '%tomato%'),
      ('coriander', '%coriander%'),
      ('chickpea', '%chickpea%'),
      ('black pepper', '%pepper%')
    ) AS m(needle, like_pat)
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM public.ingredients i
      WHERE lower(btrim(i."Ingredient Name")) = r.needle
         OR EXISTS (
           SELECT 1 FROM unnest(string_to_array(lower(COALESCE(i."Also Known As", '')), ',')) p(part)
           WHERE btrim(p.part) = r.needle
         )
    ) THEN
      UPDATE public.ingredients i SET "Also Known As" = CASE
        WHEN i."Also Known As" IS NULL OR btrim(i."Also Known As") = '' THEN r.needle
        WHEN lower(i."Also Known As") NOT LIKE '%' || r.needle || '%' THEN i."Also Known As" || ', ' || r.needle
        ELSE i."Also Known As"
      END
      WHERE i."ID" = (
        SELECT "ID" FROM public.ingredients
        WHERE lower("Ingredient Name") LIKE r.like_pat
        ORDER BY length("Ingredient Name")
        LIMIT 1
      );
    END IF;
  END LOOP;
END $$;

-- ── 3. Normalize approved recipe JSON (phase48 repair) ───────────────
SELECT public.repair_orphan_recipe_ingredients() AS phase52_repair_summary;

-- ── 4. Remaining orphans (expect zero rows) ───────────────────────────
SELECT DISTINCT x.ing_name AS orphan_still_remaining
FROM (
  SELECT lower(btrim(COALESCE(item->>'ingredient', item->>'name', ''))) AS ing_name
  FROM public.submitted_recipes sr,
       jsonb_array_elements(COALESCE(sr.ingredients, '[]'::jsonb)) sec,
       jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
  WHERE sr.status = 'approved'
    AND btrim(COALESCE(item->>'ingredient', item->>'name', '')) <> ''
) x
WHERE NOT EXISTS (
  SELECT 1 FROM public.ingredients i
  WHERE lower(btrim(i."Ingredient Name")) = x.ing_name
     OR EXISTS (
       SELECT 1
       FROM unnest(string_to_array(lower(COALESCE(i."Also Known As", '')), ',')) aka(part)
       WHERE btrim(aka.part) = x.ing_name
     )
)
ORDER BY 1;
-- ########## END: fix-phase52-recipe-orphan-repair.sql ##########
-- ########## BEGIN: SQL-EDITOR-health-check.sql ##########
-- =============================================================================
-- RUN IN SUPABASE SQL EDITOR (no login required)
-- Copy all → paste → Run. Turn OFF "limit 100" if Supabase shows that option.
-- Or run RUN-LIVE-CLEANUP.sql for the full live sequence.
-- =============================================================================

SELECT jsonb_build_object(
  'totals', jsonb_build_object(
    'recipes', (SELECT count(*)::int FROM public.submitted_recipes),
    'approved_recipes', (SELECT count(*)::int FROM public.submitted_recipes WHERE status = 'approved'),
    'ingredients', (SELECT count(*)::int FROM public.ingredients)
  ),
  'issues', jsonb_build_object(
    'invalid_governed_links', (
      SELECT count(*)::int FROM public.library_profiles lp
      WHERE lp.profile_type = 'ingredient'
        AND lp.governed_ingredient_id IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM public.ingredients i WHERE i."ID" = lp.governed_ingredient_id
        )
    ),
    'library_name_mismatches', (
      SELECT count(*)::int FROM public.library_profiles lp
      JOIN public.ingredients i ON i."ID" = lp.governed_ingredient_id
      WHERE lp.profile_type = 'ingredient'
        AND lower(btrim(lp.name)) <> lower(btrim(i."Ingredient Name"))
    ),
    'duplicate_ingredient_names', (
      SELECT count(*)::int FROM (
        SELECT lower(btrim("Ingredient Name")) AS n
        FROM public.ingredients
        WHERE "Ingredient Name" IS NOT NULL AND btrim("Ingredient Name") <> ''
        GROUP BY 1 HAVING count(*) > 1
      ) d
    ),
    'starter_library_wrong_links', (
      SELECT count(*)::int
      FROM public.library_profiles lp
      JOIN public.ingredients gi ON gi."ID" = lp.governed_ingredient_id
      WHERE lp.profile_type = 'ingredient'
        AND (
          (lp.slug = 'butter' AND (
            lower(gi."Ingredient Name") LIKE '%buttermilk%'
            OR lower(gi."Ingredient Name") LIKE '%peanut butter%'
          ))
          OR (lp.slug = 'rice' AND lower(gi."Ingredient Name") LIKE '%rice paper%')
          OR (lp.slug = 'milk' AND lower(gi."Ingredient Name") LIKE '%buttermilk%')
        )
    ),
    'orphan_recipe_ingredient_names', (
      SELECT count(DISTINCT x.ing_name)::int
      FROM (
        SELECT lower(btrim(COALESCE(item->>'ingredient', item->>'name', ''))) AS ing_name
        FROM public.submitted_recipes sr,
             jsonb_array_elements(COALESCE(sr.ingredients, '[]'::jsonb)) sec,
             jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
        WHERE sr.status = 'approved'
          AND btrim(COALESCE(item->>'ingredient', item->>'name', '')) <> ''
      ) x
      WHERE NOT EXISTS (
        SELECT 1 FROM public.ingredients i
        WHERE lower(btrim(i."Ingredient Name")) = x.ing_name
           OR EXISTS (
             SELECT 1
             FROM unnest(string_to_array(lower(COALESCE(i."Also Known As", '')), ',')) aka(part)
             WHERE btrim(aka.part) = x.ing_name
           )
      )
    )
  ),
  'healthy', (
    (SELECT count(*)::int FROM public.library_profiles lp
      WHERE lp.profile_type = 'ingredient'
        AND lp.governed_ingredient_id IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM public.ingredients i WHERE i."ID" = lp.governed_ingredient_id)
    ) = 0
    AND (SELECT count(*)::int FROM public.library_profiles lp
      JOIN public.ingredients i ON i."ID" = lp.governed_ingredient_id
      WHERE lp.profile_type = 'ingredient'
        AND lower(btrim(lp.name)) <> lower(btrim(i."Ingredient Name"))
    ) = 0
    AND (SELECT count(*)::int FROM (
      SELECT lower(btrim("Ingredient Name")) AS n FROM public.ingredients
      WHERE "Ingredient Name" IS NOT NULL AND btrim("Ingredient Name") <> ''
      GROUP BY 1 HAVING count(*) > 1
    ) d) = 0
    AND (SELECT count(*)::int FROM public.library_profiles lp
      JOIN public.ingredients gi ON gi."ID" = lp.governed_ingredient_id
      WHERE lp.profile_type = 'ingredient'
        AND (
          (lp.slug = 'butter' AND (lower(gi."Ingredient Name") LIKE '%buttermilk%' OR lower(gi."Ingredient Name") LIKE '%peanut butter%'))
          OR (lp.slug = 'rice' AND lower(gi."Ingredient Name") LIKE '%rice paper%')
          OR (lp.slug = 'milk' AND lower(gi."Ingredient Name") LIKE '%buttermilk%')
        )
    ) = 0
    AND (SELECT count(DISTINCT x.ing_name)::int
      FROM (
        SELECT lower(btrim(COALESCE(item->>'ingredient', item->>'name', ''))) AS ing_name
        FROM public.submitted_recipes sr,
             jsonb_array_elements(COALESCE(sr.ingredients, '[]'::jsonb)) sec,
             jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
        WHERE sr.status = 'approved'
          AND btrim(COALESCE(item->>'ingredient', item->>'name', '')) <> ''
      ) x
      WHERE NOT EXISTS (
        SELECT 1 FROM public.ingredients i
        WHERE lower(btrim(i."Ingredient Name")) = x.ing_name
           OR EXISTS (
             SELECT 1
             FROM unnest(string_to_array(lower(COALESCE(i."Also Known As", '')), ',')) aka(part)
             WHERE btrim(aka.part) = x.ing_name
           )
      )
    ) = 0
  )
) AS health_report;
-- ########## END: SQL-EDITOR-health-check.sql ##########
