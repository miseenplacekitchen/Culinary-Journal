-- =============================================================================
-- THE CULINARY JOURNAL — LIVE FOLLOW-UP (after phases 44–48 already ran)
-- Paste in Supabase if RUN-ALL-REMAINING was partially applied earlier.
-- Order: library 49 → ingredient categories 50 → soft-launch pages 51 → health.
-- =============================================================================

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
