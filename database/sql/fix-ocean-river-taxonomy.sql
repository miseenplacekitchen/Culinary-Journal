-- fix-ocean-river-taxonomy.sql — Ocean & River D1–D8 (2026).
-- Run once in Supabase SQL Editor after fix-feather-pasture-taxonomy.sql. Safe to re-run.
-- Cut/species focus hints on recipe_subcategories.ingredient_hints (not divisions).

ALTER TABLE public.recipe_subcategories
  ADD COLUMN IF NOT EXISTS ingredient_hints text[] DEFAULT '{}';

UPDATE public.recipe_divisions SET is_active = false WHERE category = 'Ocean & River';
UPDATE public.recipe_subcategories SET is_active = false WHERE category = 'Ocean & River';

INSERT INTO public.recipe_subcategories (category, name, sort_order, is_active) VALUES
  ('Ocean & River', 'White & Delicate Finfish', 10, true),
  ('Ocean & River', 'Oily & Robust Finfish', 20, true),
  ('Ocean & River', 'Freshwater & River Species', 30, true),
  ('Ocean & River', 'Crustaceans & Crawlers', 40, true),
  ('Ocean & River', 'Bivalves & Shelled Molluscs', 50, true),
  ('Ocean & River', 'Cephalopods & Soft Tissues', 60, true),
  ('Ocean & River', 'Cartilaginous & Heavy Marine Giants', 70, true),
  ('Ocean & River', 'Sea Vegetables & Aquatic Flora', 80, true)
ON CONFLICT (category, name) DO UPDATE SET sort_order = EXCLUDED.sort_order, is_active = EXCLUDED.is_active;

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Whole Whitefish','Skin-On Fillets','Fish Steaks','Cheeks','Delicate White Flakes',
  'Cod','Sea Bass','Snapper','Halibut','Haddock'
] WHERE category = 'Ocean & River' AND name = 'White & Delicate Finfish';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Whole Oily Fish','Rich Steaks','Belly Strips','Cured Loins','Smoked Sides',
  'Salmon','Tuna','Mackerel','Sardines','Anchovies'
] WHERE category = 'Ocean & River' AND name = 'Oily & Robust Finfish';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Whole River Fish','Skinless Basa Fillets','Mud-Dressed Catfish Steaks','Delicate Lake Fillets',
  'Rohu','Catfish','Tilapia','Pangasius','Snakehead','Carp','Perch','Basa','Trout'
] WHERE category = 'Ocean & River' AND name = 'Freshwater & River Species';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Whole Head-On Prawns','Peeled Shrimp','Lobster Tails','Crab Claws','Soft-Shell Crabs'
] WHERE category = 'Ocean & River' AND name = 'Crustaceans & Crawlers';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'In-Shell Mussels','Shucked Oysters','Whole Clams','Scallops on the Half-Shell','Cockles'
] WHERE category = 'Ocean & River' AND name = 'Bivalves & Shelled Molluscs';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Squid Tubes','Octopus Tentacles','Whole Cuttlefish','Squid Ink Bags','Cleaned Rings'
] WHERE category = 'Ocean & River' AND name = 'Cephalopods & Soft Tissues';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Shark Steaks','Ray Wings','Swordfish Loins','Dense Marine Cuts'
] WHERE category = 'Ocean & River' AND name = 'Cartilaginous & Heavy Marine Giants';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Dried Nori Sheets','Fresh Wakame','Kelp Fronds','Kombu Strips','Sea Grapes'
] WHERE category = 'Ocean & River' AND name = 'Sea Vegetables & Aquatic Flora';

SELECT category, name, sort_order, array_length(ingredient_hints, 1) AS hint_count, is_active
FROM public.recipe_subcategories
WHERE category = 'Ocean & River' AND is_active = true
ORDER BY sort_order;
