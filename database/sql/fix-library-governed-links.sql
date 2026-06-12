-- fix-library-governed-links.sql
-- Re-link starter ingredient library profiles to the correct governed ingredient rows.
-- Run in Supabase SQL Editor, then: SQL-EDITOR-health-check.sql

CREATE TEMP TABLE _lib_slug_targets (slug text PRIMARY KEY, ingredient_name text NOT NULL);
INSERT INTO _lib_slug_targets (slug, ingredient_name) VALUES
  ('salt',      'Fine Sea Salt'),
  ('onion',     'Brown Onion'),
  ('butter',    'Unsalted Butter'),
  ('rice',      'Basmati Rice'),
  ('tomato',    'Roma Tomato'),
  ('ginger',    'Fresh Ginger'),
  ('egg',       'Eggs'),
  ('flour',     'Plain Flour'),
  ('potato',    'Sebago Potato'),
  ('coconut',   'Desiccated Coconut'),
  ('milk',      'Full Cream Milk'),
  ('capsicum',  'Red Capsicum'),
  ('olive-oil', 'Extra Virgin Olive Oil');

-- Preview mismatches before update
SELECT lp.slug, lp.name AS current_name, t.ingredient_name AS target_name,
       i."ID" AS target_id, gi."Ingredient Name" AS current_governed_name
FROM library_profiles lp
JOIN _lib_slug_targets t ON t.slug = lp.slug
LEFT JOIN ingredients i ON lower(btrim(i."Ingredient Name")) = lower(btrim(t.ingredient_name))
LEFT JOIN ingredients gi ON gi."ID" = lp.governed_ingredient_id
WHERE lp.profile_type = 'ingredient';

UPDATE library_profiles lp
SET
  governed_ingredient_id = i."ID",
  name = i."Ingredient Name",
  updated_at = now()
FROM _lib_slug_targets t
JOIN ingredients i ON lower(btrim(i."Ingredient Name")) = lower(btrim(t.ingredient_name))
WHERE lp.profile_type = 'ingredient'
  AND lp.slug = t.slug;

SELECT 'fix-library-governed-links ready' AS status;
