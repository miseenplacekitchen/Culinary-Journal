-- fix-grain-field-taxonomy.sql — The Grain Field E1–E8 (2026).
-- Run once in Supabase SQL Editor after fix-ocean-river-taxonomy.sql. Safe to re-run.
-- Grain/starch focus hints on recipe_subcategories.ingredient_hints (not divisions).

ALTER TABLE public.recipe_subcategories
  ADD COLUMN IF NOT EXISTS ingredient_hints text[] DEFAULT '{}';

UPDATE public.recipe_divisions SET is_active = false WHERE category = 'The Grain Field';
UPDATE public.recipe_subcategories SET is_active = false WHERE category = 'The Grain Field';

INSERT INTO public.recipe_subcategories (category, name, sort_order, is_active) VALUES
  ('The Grain Field', 'Rice & Paddy Grains (Oryza)', 10, true),
  ('The Grain Field', 'Wheat & Triticum Derivatives', 20, true),
  ('The Grain Field', 'Maize & Corn Starch Kernels (Zea mays)', 30, true),
  ('The Grain Field', 'Oats, Barley & Rye (Northern Cereals)', 40, true),
  ('The Grain Field', 'Millets, Sorghum & Teff (Ancient Dryland Grains)', 50, true),
  ('The Grain Field', 'Pseudocereals (Quinoa, Amaranth & Buckwheat)', 60, true),
  ('The Grain Field', 'Grain Brans, Germs & Isolated Starches', 70, true),
  ('The Grain Field', 'Milled Strands & Extruded Shapes', 80, true)
ON CONFLICT (category, name) DO UPDATE SET sort_order = EXCLUDED.sort_order, is_active = EXCLUDED.is_active;

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Basmati','Jasmine','Sushi Short-Grain','Long-Grain White','Brown Rice',
  'Black Rice','Forbidden Rice','Wild Rice','Sticky Rice','Glutinous Rice','Red Cargo Rice'
] WHERE category = 'The Grain Field' AND name = 'Rice & Paddy Grains (Oryza)';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Bulgur','Couscous Pearls','Farro','Freekeh','Wheat Berries','Kamut','Spelt','Einkorn','Seitan'
] WHERE category = 'The Grain Field' AND name = 'Wheat & Triticum Derivatives';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Coarse Cornmeal','Hominy Grains','Polenta Grits','Masa Harina','Dried Corn Kernels','Cornstarch'
] WHERE category = 'The Grain Field' AND name = 'Maize & Corn Starch Kernels (Zea mays)';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Rolled Oats','Steel-Cut Oats','Pearl Barley','Pot Barley','Hulled Rye Grains','Flaked Rye','Triticale'
] WHERE category = 'The Grain Field' AND name = 'Oats, Barley & Rye (Northern Cereals)';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Pearl Millet','Bajra','Finger Millet','Ragi','Foxtail Millet','Kodo Millet',
  'Sorghum','Jowar','Teff','Fonio'
] WHERE category = 'The Grain Field' AND name = 'Millets, Sorghum & Teff (Ancient Dryland Grains)';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'White Quinoa','Red Quinoa','Black Quinoa','Whole Amaranth Seeds',
  'Buckwheat Groats','Kasha','Chia Seeds','Wild Grass Seeds'
] WHERE category = 'The Grain Field' AND name = 'Pseudocereals (Quinoa, Amaranth & Buckwheat)';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Wheat Bran','Oat Bran','Rice Bran','Wheat Germ','Sago Pearls','Tapioca Pearls','Potato Starch','Tapioca Starch'
] WHERE category = 'The Grain Field' AND name = 'Grain Brans, Germs & Isolated Starches';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Dried Spaghetti','Ramen Strands','Rice Vermicelli','Glass Noodles','Soba','Rice Sticks','Shaped Pasta'
] WHERE category = 'The Grain Field' AND name = 'Milled Strands & Extruded Shapes';

SELECT category, name, sort_order, array_length(ingredient_hints, 1) AS hint_count, is_active
FROM public.recipe_subcategories
WHERE category = 'The Grain Field' AND is_active = true
ORDER BY sort_order;
