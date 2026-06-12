-- fix-phase51-soft-launch-pages.sql
-- Register core member pages for soft launch (public or registered as appropriate).
-- Safe to re-run. Betty can still override in Site Management → Pages.

INSERT INTO public.site_pages (name, path, visibility, sort_order, min_tier) VALUES
  ('Recipes', 'recipes.html', 'public', 10, 'free'),
  ('Recipe Page', 'recipe-page.html', 'public', 11, 'free'),
  ('Submit Recipe', 'submit-recipe.html', 'registered', 12, 'free'),
  ('My Dashboard', 'my-dashboard.html', 'registered', 13, 'free'),
  ('Grocery List', 'grocery.html', 'registered', 14, 'free'),
  ('Pantry', 'pantry.html', 'registered', 15, 'free'),
  ('Meal Planner', 'meal-planner.html', 'registered', 16, 'free'),
  ('Household', 'household.html', 'registered', 17, 'free'),
  ('Library Directory', 'library-directory.html', 'public', 18, 'free'),
  ('Library Submit', 'library-submit.html', 'registered', 19, 'free'),
  ('Print Studio', 'print-studio.html', 'registered', 20, 'free'),
  ('Table Planner', 'table-planner.html', 'registered', 21, 'free'),
  ('Diary', 'diary.html', 'registered', 22, 'free'),
  ('Culinary Life', 'culinary-life.html', 'registered', 23, 'free'),
  ('Family Profiles', 'family-profiles.html', 'registered', 24, 'free'),
  ('Lane 2 Spot-Check', 'lane2-spot-check.html', 'registered', 250, 'free'),
  ('Theme Sweep', 'theme-sweep.html', 'registered', 251, 'free'),
  ('Admin Dashboard', 'dashboard.html', 'registered', 252, 'free')
ON CONFLICT (path) DO UPDATE SET
  name = EXCLUDED.name,
  visibility = EXCLUDED.visibility,
  sort_order = EXCLUDED.sort_order,
  min_tier = EXCLUDED.min_tier,
  updated_at = now();

-- Ensure browse + map pages stay public for soft launch
UPDATE public.site_pages SET visibility = 'public', min_tier = 'free', updated_at = now()
WHERE path IN (
  'recipes.html', 'recipe-page.html', 'library-directory.html',
  'food-map.html', 'festival-calendar.html', 'user.html', 'index.html'
);

SELECT path, name, visibility, min_tier
FROM public.site_pages
WHERE path IN ('recipes.html', 'grocery.html', 'meal-planner.html', 'dashboard.html', 'lane2-spot-check.html')
ORDER BY sort_order;
