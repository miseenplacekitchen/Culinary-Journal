-- fix-garden-journal-page.sql — register Garden Journal page (hidden until Betty enables)

INSERT INTO public.site_pages (name, path, visibility, sort_order, min_tier) VALUES
  ('Garden Journal', 'garden-journal.html', 'hidden', 133, 'free')
ON CONFLICT (path) DO UPDATE SET
  name = EXCLUDED.name,
  sort_order = EXCLUDED.sort_order,
  min_tier = EXCLUDED.min_tier;

SELECT path, name, visibility FROM public.site_pages WHERE path = 'garden-journal.html';
