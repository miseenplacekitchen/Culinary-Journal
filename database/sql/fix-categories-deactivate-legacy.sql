-- fix-categories-deactivate-legacy.sql
-- Hides Feast Days, Little Ones, Nourish & Heal from browse + admin (is_active = false).
-- Run once in Supabase SQL Editor after fix-categories-v2.sql.
-- Safe to re-run.

ALTER TABLE public.categories
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;

UPDATE public.categories
SET is_active = false
WHERE name IN ('Feast Days', 'Little Ones', 'Nourish & Heal');

-- Optional: hide any other retired top-level names if rows still exist
UPDATE public.categories
SET is_active = false
WHERE name IN (
  'Rise & Shine', 'The Evening Table', 'Meat & Fire', 'Slow & Soulful',
  'Grains & Comfort', 'Breads & Bakes', 'Preserved & Cherished'
);

SELECT name, emoji, sort_order, is_active
FROM public.categories
ORDER BY sort_order;

SELECT COUNT(*) AS active_category_count
FROM public.categories
WHERE COALESCE(is_active, true) = true;
