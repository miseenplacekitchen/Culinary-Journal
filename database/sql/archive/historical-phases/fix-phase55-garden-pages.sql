-- fix-phase55-garden-pages.sql — ensure all Garden member pages are registered
-- Safe to re-run. Run after RUN-GARDEN-GO-LIVE.sql if journal still hidden.

INSERT INTO public.site_pages (name, path, visibility, sort_order, min_tier) VALUES
  ('Garden Journal', 'garden-journal.html', 'registered', 133, 'free')
ON CONFLICT (path) DO UPDATE SET
  name = EXCLUDED.name,
  sort_order = EXCLUDED.sort_order,
  min_tier = EXCLUDED.min_tier;

UPDATE public.site_pages
SET visibility = 'registered', updated_at = now()
WHERE path IN (
  'garden-directory.html',
  'garden-plant.html',
  'my-garden.html',
  'garden-journal.html'
)
AND visibility IS DISTINCT FROM 'registered';

SELECT path, name, visibility
FROM public.site_pages
WHERE path IN (
  'garden-directory.html',
  'garden-plant.html',
  'my-garden.html',
  'garden-journal.html'
)
ORDER BY sort_order;

SELECT 'fix-phase55-garden-pages ready — garden pages registered' AS status;
