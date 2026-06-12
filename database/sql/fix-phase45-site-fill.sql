-- fix-phase45-site-fill.sql
-- Festival dish slots, approve pending recipes, free-tier limit settings (off by default).
-- Safe to re-run. Run after fix-phase44-library-profiles.sql on live Supabase.

-- ── Festival dish slots (beyond Onam sadya) ───────────────────────────
INSERT INTO public.festival_dishes (festival_id, dish_name, section_label, sort_order)
SELECT f.id, d.name, d.section, d.ord
FROM public.festivals f
CROSS JOIN (VALUES
  ('eid', 'Dates & water', 'Iftar', 1),
  ('eid', 'Soup / shorba', 'Iftar', 2),
  ('eid', 'Samosas / pakoras', 'Iftar', 3),
  ('eid', 'Biryani or pilaf', 'Main', 4),
  ('eid', 'Grilled meat / kebabs', 'Main', 5),
  ('eid', 'Salad & raita', 'Sides', 6),
  ('eid', 'Dessert / sheer khurma', 'Sweet', 7),
  ('christmas', 'Roast main', 'Main', 1),
  ('christmas', 'Roast potatoes', 'Sides', 2),
  ('christmas', 'Steamed vegetables', 'Sides', 3),
  ('christmas', 'Gravy / jus', 'Sides', 4),
  ('christmas', 'Christmas pudding', 'Dessert', 5),
  ('christmas', 'Mince pies', 'Dessert', 6),
  ('diwali', 'Mithai / sweets platter', 'Sweets', 1),
  ('diwali', 'Savouries / namkeen', 'Snacks', 2),
  ('diwali', 'Main feast curry', 'Main', 3),
  ('diwali', 'Rice or bread', 'Main', 4),
  ('diwali', 'Chutney & pickle', 'Sides', 5),
  ('wedding', 'Welcome drinks', 'Reception', 1),
  ('wedding', 'Appetisers', 'Reception', 2),
  ('wedding', 'Main course — vegetarian', 'Feast', 3),
  ('wedding', 'Main course — non-vegetarian', 'Feast', 4),
  ('wedding', 'Rice / bread service', 'Feast', 5),
  ('wedding', 'Dessert table', 'Sweet', 6),
  ('thanksgiving', 'Roast turkey', 'Main', 1),
  ('thanksgiving', 'Stuffing', 'Sides', 2),
  ('thanksgiving', 'Cranberry sauce', 'Sides', 3),
  ('thanksgiving', 'Mashed potatoes', 'Sides', 4),
  ('thanksgiving', 'Pumpkin pie', 'Dessert', 5),
  ('easter', 'Roast lamb or ham', 'Main', 1),
  ('easter', 'Hot cross buns', 'Bakery', 2),
  ('easter', 'Spring vegetables', 'Sides', 3),
  ('easter', 'Simnel cake', 'Dessert', 4),
  ('lunar-new-year', 'Dumplings', 'Main', 1),
  ('lunar-new-year', 'Nian gao / rice cake', 'Sweet', 2),
  ('lunar-new-year', 'Fish dish', 'Main', 3),
  ('lunar-new-year', 'Longevity noodles', 'Main', 4),
  ('lunar-new-year', 'Tray of togetherness', 'Snacks', 5)
) AS d(slug, name, section, ord)
WHERE f.slug = d.slug
  AND NOT EXISTS (
    SELECT 1 FROM public.festival_dishes fd
    WHERE fd.festival_id = f.id AND fd.dish_name = d.name
  );

-- ── Approve all pending recipes (increases public browse content) ─────
UPDATE public.submitted_recipes
SET status = 'approved',
    reviewed_at = COALESCE(reviewed_at, now())
WHERE status = 'pending';

-- ── Free-tier limit settings (disabled until admin enables) ───────────
INSERT INTO public.site_settings (key, value) VALUES
  ('enforce_free_limits', 'false'),
  ('free_max_recipes', '10'),
  ('free_max_photo_imports_month', '5'),
  ('free_max_tables', '1')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;

SELECT jsonb_build_object(
  'status', 'fix-phase45-site-fill ready',
  'approved_now', (SELECT count(*)::int FROM public.submitted_recipes WHERE status = 'approved'),
  'pending_remaining', (SELECT count(*)::int FROM public.submitted_recipes WHERE status = 'pending'),
  'festival_dish_counts', (
    SELECT jsonb_object_agg(f.slug, cnt)
    FROM (
      SELECT f2.slug, count(fd.id)::int AS cnt
      FROM public.festivals f2
      LEFT JOIN public.festival_dishes fd ON fd.festival_id = f2.id
      GROUP BY f2.slug
    ) f
  )
) AS phase45_summary;
