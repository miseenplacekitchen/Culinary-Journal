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
