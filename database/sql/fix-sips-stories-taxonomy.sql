-- fix-sips-stories-taxonomy.sql — Sips & Stories J1–J9 (2026).
-- Run once after fix-grain-field-taxonomy.sql. Safe to re-run.
-- RPCs: fix-admin-taxonomy-editor.sql (run that first).
-- Supersedes fix-sips-drinks-taxonomy.sql (legacy 21-sub / division tree).
-- Base-ingredient focus hints on recipe_subcategories.ingredient_hints (not divisions).

ALTER TABLE public.recipe_subcategories
  ADD COLUMN IF NOT EXISTS ingredient_hints text[] DEFAULT '{}';

UPDATE public.recipe_divisions SET is_active = false WHERE category = 'Sips & Stories';
UPDATE public.recipe_subcategories SET is_active = false WHERE category = 'Sips & Stories';

INSERT INTO public.recipe_subcategories (category, name, sort_order, is_active) VALUES
  ('Sips & Stories', 'True Teas & Botanical Infusions', 10, true),
  ('Sips & Stories', 'Coffee Beans & Specialty Brews', 20, true),
  ('Sips & Stories', 'Crafted Milks, Boba & Cultured Dairy', 30, true),
  ('Sips & Stories', 'Pressed Fruits, Juices & Blended Smoothies', 40, true),
  ('Sips & Stories', 'Cordials, Syrups & Regional Coolers', 50, true),
  ('Sips & Stories', 'Sodas, Tonics & Effervescent Fizzes', 60, true),
  ('Sips & Stories', 'Living Cultures & Functional Tonics (Non-Alcoholic)', 70, true),
  ('Sips & Stories', 'Mocktails & Zero-Proof Mixology', 80, true),
  ('Sips & Stories', 'Wines, Beers & Crafted Spirits (Alcoholic)', 90, true)
ON CONFLICT (category, name) DO UPDATE SET sort_order = EXCLUDED.sort_order, is_active = EXCLUDED.is_active;

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Black Tea Leaves','Green Tea Leaves','White Tea Leaves','Oolong Leaves','Matcha Powder',
  'Dried Chamomile','Peppermint','Hibiscus','Rooibos'
] WHERE category = 'Sips & Stories' AND name = 'True Teas & Botanical Infusions';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Whole Coffee Beans','Green Coffee Seeds','Espresso Grounds','Roasted Chicory','Barley Seeds'
] WHERE category = 'Sips & Stories' AND name = 'Coffee Beans & Specialty Brews';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Whole Dairy Milk','Oat Milk','Almond Milk','Coconut Milk','Tapioca Boba Pearls','Yogurt','Kefir'
] WHERE category = 'Sips & Stories' AND name = 'Crafted Milks, Boba & Cultured Dairy';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Fresh Sugarcane','Citrus','Apples','Berries','Carrots','Beets','Leafy Greens'
] WHERE category = 'Sips & Stories' AND name = 'Pressed Fruits, Juices & Blended Smoothies';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Fresh Citrus Juices','Simple Syrup','Rose Water','Khus Extract','Fruit Vinegar','Shrub'
] WHERE category = 'Sips & Stories' AND name = 'Cordials, Syrups & Regional Coolers';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Carbonated Water','Sparkling Water','Craft Soda Syrup','Ginger Extract','Tonic Bark'
] WHERE category = 'Sips & Stories' AND name = 'Sodas, Tonics & Effervescent Fizzes';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Kombucha Scoby','Water Kefir Grains','Ginger Root','Turmeric Root','Apple Cider Vinegar','Coconut Water'
] WHERE category = 'Sips & Stories' AND name = 'Living Cultures & Functional Tonics (Non-Alcoholic)';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Alcohol-Free Spirit','Non-Alcoholic Bitters','Botanical Elixir'
] WHERE category = 'Sips & Stories' AND name = 'Mocktails & Zero-Proof Mixology';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Wine Grapes','Malted Barley','Hops','Vodka','Gin','Rum','Liqueur','Amaro'
] WHERE category = 'Sips & Stories' AND name = 'Wines, Beers & Crafted Spirits (Alcoholic)';

SELECT category, name, sort_order, array_length(ingredient_hints, 1) AS hint_count, is_active
FROM public.recipe_subcategories
WHERE category = 'Sips & Stories' AND is_active = true
ORDER BY sort_order;
