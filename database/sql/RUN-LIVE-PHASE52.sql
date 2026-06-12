-- =============================================================================
-- THE CULINARY JOURNAL — PHASE 52 LIVE (library + Lane 2 sample recipes)
-- Paste entire file in Supabase SQL Editor after code deploy.
-- Safe to re-run.
-- =============================================================================


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
