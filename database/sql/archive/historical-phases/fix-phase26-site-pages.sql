-- ══════════════════════════════════════════════════════════════════════
-- fix-phase26-site-pages.sql — Register cultural, event, legal, contributor pages
-- Safe to re-run. Betty controls visibility in Site Management → Pages.
-- ══════════════════════════════════════════════════════════════════════

INSERT INTO public.site_pages (name, path, visibility, sort_order, min_tier) VALUES
  ('Food by Map', 'food-map.html', 'public', 120, 'free'),
  ('Festival Calendar', 'festival-calendar.html', 'public', 121, 'free'),
  ('Onam Sadya Planner', 'onam-sadya.html', 'registered', 122, 'free'),
  ('Eid Feast Planner', 'eid-feast.html', 'registered', 123, 'free'),
  ('Christmas Roast Planner', 'christmas-roast.html', 'registered', 124, 'free'),
  ('Contributor Profile', 'user.html', 'public', 125, 'free'),
  ('Cookie Policy', 'cookies.html', 'public', 200, 'free'),
  ('Copyright Policy', 'copyright.html', 'public', 201, 'free'),
  ('DMCA Policy', 'dmca.html', 'public', 202, 'free'),
  ('Attribution Policy', 'attribution-policy.html', 'public', 203, 'free'),
  ('Photo Upload Policy', 'photo-upload-policy.html', 'public', 204, 'free'),
  ('UGC Agreement', 'ugc-agreement.html', 'public', 205, 'free'),
  ('Community Guidelines', 'community-guidelines.html', 'public', 206, 'free'),
  ('Accessibility', 'accessibility.html', 'public', 207, 'free'),
  ('Data Breach Policy', 'data-breach.html', 'public', 208, 'free'),
  ('Event Seating Policy', 'event-seating-policy.html', 'public', 209, 'free'),
  ('Credit & Preservation', 'credit-preservation.html', 'public', 210, 'free'),
  ('Food Safety', 'food-safety.html', 'public', 211, 'free')
ON CONFLICT (path) DO UPDATE SET
  name = EXCLUDED.name,
  visibility = COALESCE(public.site_pages.visibility, EXCLUDED.visibility),
  sort_order = EXCLUDED.sort_order,
  min_tier = EXCLUDED.min_tier;

SELECT path, name, visibility FROM public.site_pages
WHERE path IN ('food-map.html','festival-calendar.html','user.html','cookies.html','accessibility.html')
ORDER BY sort_order;
