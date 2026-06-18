-- fix-categories-v2.sql — Eleven main categories (A–K, 2026 book taxonomy v2).
-- Run once in Supabase SQL Editor. Safe to re-run.
-- Sub-categories: redo separately — this only updates top-level categories + recipe remaps.

-- ── Rename / repurpose browse rows (keeps stable category_id for dishes FK) ──
UPDATE public.categories SET
  name = 'Garden & Earth', emoji = '🥬', sort_order = 10,
  description = 'Fresh vegetables, nourishing legumes, earthy roots, and wild greens that connect you to the land and seasons.'
WHERE name IN ('Garden & Earth');

UPDATE public.categories SET
  name = 'Feather & Flock', emoji = '🐓', sort_order = 20,
  description = 'Poultry in every form. Chicken, duck, turkey prepared with skill across cultures.'
WHERE name IN ('Meat & Fire', 'Feather & Flock');

UPDATE public.categories SET
  name = 'Pasture & Hoof', emoji = '🍖', sort_order = 30,
  description = 'Rich meats grilled, roasted, braised, or slow-cooked to bring depth and satisfaction. Each cut tells its own story.'
WHERE name IN ('Slow & Soulful', 'Pasture & Hoof');

UPDATE public.categories SET
  name = 'Ocean & River', emoji = '🌊', sort_order = 40,
  description = 'The sea''s generous gifts. Fresh finfish, shellfish, and crustaceans that carry the salt and soul of coastal traditions.'
WHERE name IN ('Ocean & River');

UPDATE public.categories SET
  name = 'The Grain Field', emoji = '🌾', sort_order = 50,
  description = 'The foundation of home cooking. Rice, noodles, pasta, pilafs, and grain bowls that anchor meals and nourish the body.'
WHERE name IN ('Grains & Comfort', 'The Grain Field');

UPDATE public.categories SET
  name = 'Wrapped & Stuffed', emoji = '🥟', sort_order = 60,
  description = 'Crafted with intention and care. Dumplings, empanadas, samosas, and hand-folded doughs filled with tradition.'
WHERE name IN ('The Evening Table', 'Wrapped & Stuffed');

UPDATE public.categories SET
  name = 'Curds, Creams & Eggs', emoji = '🥛', sort_order = 70,
  description = 'Eggs that bind and nourish. Cheese that flavours. Dairy that enriches everything it touches.'
WHERE name IN ('Rise & Shine', 'Curds, Creams & Eggs');

UPDATE public.categories SET
  name = 'Breads & Bakery', emoji = '🫓', sort_order = 80,
  description = 'The smell of home baking. Flatbreads, yeasted loaves, and savoury pastries that warm the kitchen and the heart.'
WHERE name IN ('Breads & Bakes', 'Breads & Bakery');

UPDATE public.categories SET
  name = 'Sweet Serenades', emoji = '🍮', sort_order = 90,
  description = 'Moments of joy and celebration. Desserts, cakes, puddings, and confections that sweeten life.'
WHERE name IN ('Sweet Serenades');

UPDATE public.categories SET
  name = 'Sips & Stories', emoji = '🥂', sort_order = 100,
  description = 'Where rituals are born and people gather. Teas, coffees, broths, juices, and cocktails that connect us.'
WHERE name IN ('Sips & Stories');

UPDATE public.categories SET
  name = 'Preserved & Pantry', emoji = '🏺', sort_order = 110,
  description = 'Time honoured flavours held close. Pickles, chutneys, spice blends, and sauces that carry seasons in a jar.'
WHERE name IN ('Preserved & Cherished', 'Preserved & Pantry');

-- Retire categories not in A–K
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'categories' AND column_name = 'is_active'
  ) THEN
    UPDATE public.categories SET is_active = false
    WHERE name IN ('Little Ones', 'Feast Days', 'Nourish & Heal');
  END IF;
END $$;

-- ── Remap submitted_recipes.category (coarse — review poultry split in admin) ──
UPDATE public.submitted_recipes SET category = 'Garden & Earth' WHERE category = 'Garden & Earth';
UPDATE public.submitted_recipes SET category = 'Ocean & River' WHERE category = 'Ocean & River';
UPDATE public.submitted_recipes SET category = 'Sweet Serenades' WHERE category = 'Sweet Serenades';
UPDATE public.submitted_recipes SET category = 'Sips & Stories' WHERE category = 'Sips & Stories';
UPDATE public.submitted_recipes SET category = 'The Grain Field' WHERE category = 'Grains & Comfort';
UPDATE public.submitted_recipes SET category = 'Curds, Creams & Eggs' WHERE category = 'Rise & Shine';
UPDATE public.submitted_recipes SET category = 'Breads & Bakery' WHERE category = 'Breads & Bakes';
UPDATE public.submitted_recipes SET category = 'Preserved & Pantry' WHERE category = 'Preserved & Cherished';
UPDATE public.submitted_recipes SET category = 'Wrapped & Stuffed' WHERE category = 'The Evening Table';
UPDATE public.submitted_recipes SET category = 'Pasture & Hoof' WHERE category IN ('Slow & Soulful', 'Meat & Fire', 'Little Ones');
UPDATE public.submitted_recipes SET category = 'Curds, Creams & Eggs'
WHERE category = 'Curds, Creams & Eggs'
   OR (category = 'The Grain Field' AND (
        recipe_name ILIKE '%egg%' OR recipe_name ILIKE '%omelette%'
        OR recipe_name ILIKE '%curd%' OR recipe_name ILIKE '%yogurt%'
        OR recipe_name ILIKE '%cheese%' OR recipe_name ILIKE '%paneer%'
      ));

UPDATE public.submitted_recipes SET category = 'Feather & Flock'
WHERE category = 'Pasture & Hoof'
  AND (recipe_name ILIKE '%chicken%' OR recipe_name ILIKE '%duck%'
    OR recipe_name ILIKE '%turkey%' OR recipe_name ILIKE '%poultry%');

-- ── Remap taxonomy tables (sub-categories redo next — keeps old tree browsable) ──
UPDATE public.recipe_subcategories SET category = 'The Grain Field' WHERE category = 'Grains & Comfort';
UPDATE public.recipe_subcategories SET category = 'Breads & Bakery' WHERE category = 'Breads & Bakes';
UPDATE public.recipe_subcategories SET category = 'Preserved & Pantry' WHERE category = 'Preserved & Cherished';
UPDATE public.recipe_subcategories SET category = 'Wrapped & Stuffed' WHERE category = 'The Evening Table';
UPDATE public.recipe_subcategories SET category = 'Feather & Flock' WHERE category = 'Meat & Fire';
UPDATE public.recipe_subcategories SET category = 'Pasture & Hoof' WHERE category IN ('Slow & Soulful', 'Little Ones');
UPDATE public.recipe_subcategories SET category = 'Curds, Creams & Eggs' WHERE category = 'Rise & Shine';

UPDATE public.recipe_divisions SET category = 'The Grain Field' WHERE category = 'Grains & Comfort';
UPDATE public.recipe_divisions SET category = 'Breads & Bakery' WHERE category = 'Breads & Bakes';
UPDATE public.recipe_divisions SET category = 'Preserved & Pantry' WHERE category = 'Preserved & Cherished';
UPDATE public.recipe_divisions SET category = 'Wrapped & Stuffed' WHERE category = 'The Evening Table';
UPDATE public.recipe_divisions SET category = 'Feather & Flock' WHERE category = 'Meat & Fire';
UPDATE public.recipe_divisions SET category = 'Pasture & Hoof' WHERE category IN ('Slow & Soulful', 'Little Ones');
UPDATE public.recipe_divisions SET category = 'Curds, Creams & Eggs' WHERE category = 'Rise & Shine';

SELECT name, emoji, description, sort_order
FROM public.categories
WHERE name IN (
  'Garden & Earth', 'Feather & Flock', 'Pasture & Hoof', 'Ocean & River',
  'The Grain Field', 'Wrapped & Stuffed', 'Curds, Creams & Eggs', 'Breads & Bakery',
  'Sweet Serenades', 'Sips & Stories', 'Preserved & Pantry'
)
ORDER BY sort_order;
