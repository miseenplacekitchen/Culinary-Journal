-- seed-dish-index-test-data.sql — Sample Dish Index rows for Betty admin testing.
-- Safe to re-run. Removes prior seed rows tagged [TCJ_TEST_SEED] then re-inserts.
-- Does NOT touch DI000001 (Appam) or other production rows.
-- Run in Supabase SQL Editor, then run verify-dish-index-test-data.sql

DELETE FROM public.recipe_name_library
 WHERE notes LIKE '%[TCJ_TEST_SEED]%';

INSERT INTO public.recipe_name_library (
  dish_code, recipe_name, native_name, alternate_names,
  category, sub_category, division,
  origin_country, origin_state,
  primary_ingredients, dietary_tags, meal_type_tags,
  introduction, difficulty, spice_level, cooking_style,
  prep_time_minutes, servings,
  research_status, content_status, is_active, notes
) VALUES
  -- Duplicate cluster (normalized name "dosa")
  ('DI900001', 'Dosa', 'தோசை', '{}',
   'Indian', 'South Indian Breakfast', '',
   'India', 'Tamil Nadu',
   ARRAY['rice','urad dal'], ARRAY['Vegetarian'], ARRAY['Breakfast'],
   'Crisp fermented crepe.', 'Easy', 'Mild', 'Pan-fried',
   480, 4, 'verified', 'not_started', true, '[TCJ_TEST_SEED] duplicate A'),
  ('DI900002', 'Dosa', 'Dosai', '{}',
   '', '', '',
   'India', '',
   ARRAY['rice'], '{}', '{}',
   '', 'Easy', 'Mild', '',
   NULL, NULL, 'idea_only', 'not_started', true, '[TCJ_TEST_SEED] duplicate B — missing category'),

  -- Second duplicate cluster ("idli")
  ('DI900003', 'Idli', 'இட்லி', '{}',
   'Indian', 'South Indian Breakfast', '',
   'India', 'Karnataka',
   ARRAY['rice','urad dal'], ARRAY['Vegetarian'], ARRAY['Breakfast'],
   'Steamed rice cakes.', 'Easy', 'Not Applicable', 'Steamed',
   600, 6, 'ready_to_draft', 'not_started', true, '[TCJ_TEST_SEED] ready unlinked'),
  ('DI900004', 'Idli', '', '{}',
   'Indian', '', '',
   '', 'Kerala',
   '{}', '{}', '{}',
   '', 'Easy', '', '',
   NULL, NULL, 'needs_research', 'not_started', true, '[TCJ_TEST_SEED] duplicate idli — missing country on one'),

  -- Coverage gap samples
  ('DI900005', 'Puttu', 'പുട്ട്', '{}',
   '', '', '',
   'India', 'Kerala',
   ARRAY['rice flour','coconut'], ARRAY['Vegetarian'], ARRAY['Breakfast'],
   'Steamed rice cylinders.', 'Easy', 'Mild', 'Steamed',
   20, 4, 'needs_research', 'not_started', true, '[TCJ_TEST_SEED] missing category'),
  ('DI900006', 'Pav Bhaji', '', '{}',
   'Indian', 'Street Food', '',
   '', 'Maharashtra',
   ARRAY['potato','butter'], '{}', ARRAY['Dinner'],
   'Mumbai street classic.', 'Intermediate', 'Medium', '',
   30, 4, 'verified', 'not_started', true, '[TCJ_TEST_SEED] missing country'),
  ('DI900007', 'Biryani', 'बिरयानी', '{}',
   'Indian', '', '',
   'India', '',
   ARRAY['basmati rice'], '{}', ARRAY['Dinner'],
   'Layered rice dish.', 'Advanced', 'Hot', 'Slow-cooked',
   45, 6, 'verified', 'draft_created', true, '[TCJ_TEST_SEED] missing sub-category'),

  -- Archived row
  ('DI900008', 'Retired Test Dish', '', '{}',
   'Indian', 'Curries', '',
   'India', '',
   '{}', '{}', '{}',
   '', 'Easy', '', '',
   NULL, NULL, 'idea_only', 'retired', false, '[TCJ_TEST_SEED] archived'),

  -- Wide metadata row (scroll + completeness chip)
  ('DI900009', 'Chicken Tikka Masala', '', ARRAY['CTM'],
   'Indian', 'Curries', 'Tomato-based',
   'United Kingdom', 'England',
   ARRAY['chicken','yogurt','tomato'], ARRAY['Gluten-free'], ARRAY['Dinner'],
   'British-Indian restaurant classic.', 'Intermediate', 'Medium', 'Grilled',
   40, 4, 'verified', 'linked', true, '[TCJ_TEST_SEED] full metadata'),
  ('DI900010', 'Appam', 'അപ്പം', '{}',
   'Indian', 'South Indian Breakfast', '',
   'India', 'Kerala',
   ARRAY['rice','coconut'], ARRAY['Vegetarian'], ARRAY['Breakfast'],
   'Fermented rice pancake — duplicate name vs live Appam for cluster test.', 'Easy', 'Mild', 'Pan-fried',
   30, 4, 'idea_only', 'not_started', true, '[TCJ_TEST_SEED] duplicate name cluster with live Appam');

SELECT 'seed-dish-index-test-data complete — ' || count(*)::text || ' test rows'
  FROM public.recipe_name_library
 WHERE notes LIKE '%[TCJ_TEST_SEED]%';
