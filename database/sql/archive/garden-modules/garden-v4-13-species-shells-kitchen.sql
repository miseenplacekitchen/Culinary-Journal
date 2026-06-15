-- garden-v4-13-species-shells-kitchen.sql — draft plant rows for GM Apply pipeline
-- Safe to re-run. Does not publish — set is_published in GM when ready.

-- Bell Pepper (32 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('bell-pepper', 'Bell Pepper',
  'Draft species shell — 32 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Basil (29 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('basil', 'Basil',
  'Draft species shell — 29 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Cucumber (53 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('cucumber', 'Cucumber',
  'Draft species shell — 53 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Spinach (33 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('spinach', 'Spinach',
  'Draft species shell — 33 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Carrot (0 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('carrot', 'Carrot',
  'Draft species shell — 0 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Potato (38 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('potato', 'Potato',
  'Draft species shell — 38 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Pumpkin (51 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('pumpkin', 'Pumpkin',
  'Draft species shell — 51 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Zucchini (27 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('zucchini', 'Zucchini',
  'Draft species shell — 27 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Onion (60 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('onion', 'Onion',
  'Draft species shell — 60 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Garlic (56 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('garlic', 'Garlic',
  'Draft species shell — 56 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Coriander (17 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('coriander', 'Coriander',
  'Draft species shell — 17 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Peas (0 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('peas', 'Peas',
  'Draft species shell — 0 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Chili Pepper (23 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('chili-pepper', 'Chili Pepper',
  'Draft species shell — 23 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Strawberry (28 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('strawberry', 'Strawberry',
  'Draft species shell — 28 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Broccoli (25 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('broccoli', 'Broccoli',
  'Draft species shell — 25 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Cabbage (44 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('cabbage', 'Cabbage',
  'Draft species shell — 44 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Mint (70 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('mint', 'Mint',
  'Draft species shell — 70 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Parsley (49 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('parsley', 'Parsley',
  'Draft species shell — 49 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Thyme (28 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('thyme', 'Thyme',
  'Draft species shell — 28 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Rosemary (31 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('rosemary', 'Rosemary',
  'Draft species shell — 31 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Watermelon (36 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('watermelon', 'Watermelon',
  'Draft species shell — 36 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Melon (80 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('melon', 'Melon',
  'Draft species shell — 80 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Sweet Potato (91 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('sweet-potato', 'Sweet Potato',
  'Draft species shell — 91 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Bean (36 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('bean', 'Bean',
  'Draft species shell — 36 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Celery (31 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('celery', 'Celery',
  'Draft species shell — 31 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Turnip (20 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('turnip', 'Turnip',
  'Draft species shell — 20 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Radish (0 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('radish', 'Radish',
  'Draft species shell — 0 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Beetroot (24 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('beetroot', 'Beetroot',
  'Draft species shell — 24 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

SELECT 'garden-v4-13-species-shells-kitchen ready — 28 draft species' AS status;