-- fix-garden-v3-visible.sql
-- Flip Garden pages from hidden → registered (signed-in members). Safe to re-run.

UPDATE public.site_pages SET visibility = 'registered'
WHERE path IN ('garden-directory.html', 'garden-plant.html', 'my-garden.html', 'garden-journal.html');

SELECT path, name, visibility FROM public.site_pages
WHERE path LIKE 'garden%' OR path = 'my-garden.html'
ORDER BY sort_order;
