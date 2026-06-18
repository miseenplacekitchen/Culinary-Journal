-- fix-garden-taxonomy-v2.sql — Garden & Earth A1–A13 (ingredient-led subs, 2026 v2).
-- Run once in Supabase SQL Editor after fix-categories-v2.sql. Safe to re-run.
-- Ingredient lists live on recipe_subcategories.ingredient_hints (NOT divisions).
-- Divisions (techniques/styles) for Garden come later. Curated dishes table unchanged.

-- ── Column for ingredient focus hints ────────────────────────────────────────
ALTER TABLE public.recipe_subcategories
  ADD COLUMN IF NOT EXISTS ingredient_hints text[] DEFAULT '{}';

-- ── Retire legacy Garden browse tree ───────────────────────────────────────
UPDATE public.recipe_divisions SET is_active = false
WHERE category = 'Garden & Earth';

UPDATE public.recipe_subcategories SET is_active = false
WHERE category = 'Garden & Earth';

-- ── A1–A13 sub-categories ────────────────────────────────────────────────────
INSERT INTO public.recipe_subcategories (category, name, sort_order, is_active) VALUES
  ('Garden & Earth', 'Roots & Tubers', 10, true),
  ('Garden & Earth', 'Stems, Shoots & Sprouts', 20, true),
  ('Garden & Earth', 'Brassicas', 30, true),
  ('Garden & Earth', 'Alliums', 40, true),
  ('Garden & Earth', 'Rhizomes & Fresh Aromatics', 50, true),
  ('Garden & Earth', 'Leafy Greens', 60, true),
  ('Garden & Earth', 'Culinary Herbs & Edible Flowers', 70, true),
  ('Garden & Earth', 'Nightshades & Hanging Pods', 80, true),
  ('Garden & Earth', 'Gourds & Squashes', 90, true),
  ('Garden & Earth', 'Savoury Fruits & Flora', 100, true),
  ('Garden & Earth', 'Corn & Fresh Maize', 110, true),
  ('Garden & Earth', 'Legumes & Pulses', 120, true),
  ('Garden & Earth', 'Mushrooms & Fungi', 130, true)
ON CONFLICT (category, name) DO UPDATE SET
  sort_order = EXCLUDED.sort_order,
  is_active = EXCLUDED.is_active;

-- ── Ingredient focus hints (main-ingredient → sub-category) ──────────────────
UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Potatoes','Cassava','Carrots','Taro','Daikon','Parsnips','Turnips','Rutabaga','Beets',
  'Sweet Potatoes','Radishes','Celeriac','Sunchokes','Jicama','Yams'
] WHERE category = 'Garden & Earth' AND name = 'Roots & Tubers';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Celery','Asparagus','Kohlrabi','Bamboo Shoots','Bean Sprouts','Fiddlehead Ferns','Rhubarb',
  'Fennel Bulb','Samphire','Broccoli Rabe','Heart of Palm','Pea Shoots'
] WHERE category = 'Garden & Earth' AND name = 'Stems, Shoots & Sprouts';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Cabbages','Broccoli','Cauliflower','Bok Choy','Brussels Sprouts','Kale','Savoy Cabbage',
  'Napa Cabbage','Red Cabbage'
] WHERE category = 'Garden & Earth' AND name = 'Brassicas';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Onions','Garlic','Leeks','Shallots','Scallions','Chives','Elephant Garlic','Wild Garlic',
  'Ramps','Garlic Scapes'
] WHERE category = 'Garden & Earth' AND name = 'Alliums';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Ginger','Turmeric','Galangal','Horseradish','Wasabi','Lesser Galangal','Fingerroot'
] WHERE category = 'Garden & Earth' AND name = 'Rhizomes & Fresh Aromatics';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Spinach','Water Spinach','Kale','Chard','Lettuces','Arugula','Watercress','Endive','Chicory',
  'Radicchio','Collard Greens','Mustard Greens','Sorrel','Dandelion Greens','Amaranth','Tatsoi',
  'Mizuna','Komatsuna'
] WHERE category = 'Garden & Earth' AND name = 'Leafy Greens';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Basil','Cilantro','Lemongrass','Mint','Squash Blossoms','Parsley','Dill','Chervil','Tarragon',
  'Oregano','Thyme','Rosemary','Sage','Bay Leaves','Marjoram','Curry Leaves','Nasturtiums',
  'Calendula','Borage','Lavender','Rose Petals','Hibiscus','Chive Blossoms','Banana Hearts'
] WHERE category = 'Garden & Earth' AND name = 'Culinary Herbs & Edible Flowers';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Tomatoes','Eggplants','Bell Peppers','Chilies','Okra','Tomatillos','Goji Berries','Ground Cherries'
] WHERE category = 'Garden & Earth' AND name = 'Nightshades & Hanging Pods';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Pumpkin','Butternut Squash','Zucchini','Bitter Gourd','Acorn Squash','Delicata Squash',
  'Kabocha Squash','Spaghetti Squash','Patty Pan Squash','Yellow Squash','Calabash','Bottle Gourd',
  'Winter Melons','Luffa Gourd'
] WHERE category = 'Garden & Earth' AND name = 'Gourds & Squashes';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Plantains','Breadfruit','Green Bananas','Jackfruit','Cactus Pads','Green Mangoes','Green Papayas',
  'Drumstick Pods','Moringa','Seaweed','Sea Vegetables'
] WHERE category = 'Garden & Earth' AND name = 'Savoury Fruits & Flora';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Sweetcorn','White Maize','Baby Corn','Corn on the Cob','Blue Corn','Red Corn','Polenta Corn'
] WHERE category = 'Garden & Earth' AND name = 'Corn & Fresh Maize';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Lentils','Dals','Chickpeas','Black Beans','Edamame','Snap Peas','Kidney Beans','Pinto Beans',
  'Cannellini Beans','Fava Beans','Lima Beans','Mung Beans','Azuki Beans','Pigeon Peas','Snow Peas',
  'Sugar Snap Peas','Chickpea Shoots'
] WHERE category = 'Garden & Earth' AND name = 'Legumes & Pulses';

UPDATE public.recipe_subcategories SET ingredient_hints = ARRAY[
  'Shiitake','Button','Oyster','Enoki','Wood Ear','Porcini','Cremini','Portobello','King Trumpet',
  'Chanterelle','Morel','Lion''s Mane','Maitake','Nameko','Shimeji','Straw Mushrooms','Hedgehog','Truffles'
] WHERE category = 'Garden & Earth' AND name = 'Mushrooms & Fungi';

-- RPCs (get_recipe_taxonomy, admin upsert, reorder): run fix-admin-taxonomy-editor.sql once.

SELECT name, sort_order, array_length(ingredient_hints, 1) AS hint_count, is_active
FROM public.recipe_subcategories
WHERE category = 'Garden & Earth' AND is_active = true
ORDER BY sort_order;
