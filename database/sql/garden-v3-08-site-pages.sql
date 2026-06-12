-- garden-v3-08-site-pages.sql
-- Register Garden pages as hidden/staging. Betty toggles visibility in Site Management.

INSERT INTO public.site_pages (name, path, visibility, sort_order, min_tier) VALUES
  ('Garden Directory', 'garden-directory.html', 'hidden', 130, 'free'),
  ('Plant Profile', 'garden-plant.html', 'hidden', 131, 'free'),
  ('My Garden', 'my-garden.html', 'hidden', 132, 'free')
ON CONFLICT (path) DO UPDATE SET
  name = EXCLUDED.name,
  sort_order = EXCLUDED.sort_order,
  min_tier = EXCLUDED.min_tier;

SELECT path, name, visibility FROM public.site_pages
WHERE path IN ('garden-directory.html','garden-plant.html','my-garden.html')
ORDER BY sort_order;
