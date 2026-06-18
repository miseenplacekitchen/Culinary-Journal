-- fix-category-copy.sql — Update browse category taglines (A–L).
-- Run once in Supabase SQL Editor. Safe to re-run.

UPDATE public.categories SET description = 'Breakfasts, morning rituals, and early-day nourishment'
WHERE name = 'Rise & Shine';

UPDATE public.categories SET description = 'Snacks, small plates, street bites, tea-time, and social evening foods'
WHERE name = 'The Evening Table';

UPDATE public.categories SET description = 'Vegetables, plant-based dishes, legumes, roots, greens, and foraged foods'
WHERE name = 'Garden & Earth';

UPDATE public.categories SET description = 'Meat dishes across methods: grilling, roasting, braising, frying, smoking'
WHERE name = 'Meat & Fire';

UPDATE public.categories SET description = 'Fish, shellfish, crustaceans, freshwater species, coastal traditions'
WHERE name = 'Ocean & River';

UPDATE public.categories SET description = 'Stews, braises, slow cooking, comfort pots, heritage dishes, winter warmers'
WHERE name = 'Slow & Soulful';

UPDATE public.categories SET description = 'Rice, noodles, pasta, porridges, pilafs, dumplings, grain-based comfort foods'
WHERE name = 'Grains & Comfort';

UPDATE public.categories SET description = 'Flatbreads, leavened breads, pastries, savoury bakes, global bakery traditions'
WHERE name = 'Breads & Bakes';

UPDATE public.categories SET description = 'Desserts, sweets, puddings, confections, global sweet traditions'
WHERE name = 'Sweet Serenades';

UPDATE public.categories SET description = 'Teas, coffees, broths, juices, cocktails, cultural beverages'
WHERE name = 'Sips & Stories';

UPDATE public.categories SET description = 'Pickles, ferments, chutneys, jams, curing, drying, pantry staples'
WHERE name = 'Preserved & Cherished';

UPDATE public.categories SET description = 'Children''s meals, toddler foods, school snacks, gentle flavours'
WHERE name = 'Little Ones';

-- Retired from the 12-category book taxonomy — hide from browse if column exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'categories' AND column_name = 'is_active'
  ) THEN
    UPDATE public.categories SET is_active = false
    WHERE name IN ('Feast Days', 'Nourish & Heal');
  END IF;
END $$;

SELECT name, description FROM public.categories
WHERE name IN (
  'Rise & Shine', 'The Evening Table', 'Garden & Earth', 'Meat & Fire',
  'Ocean & River', 'Slow & Soulful', 'Grains & Comfort', 'Breads & Bakes',
  'Sweet Serenades', 'Sips & Stories', 'Preserved & Cherished', 'Little Ones'
)
ORDER BY sort_order;
