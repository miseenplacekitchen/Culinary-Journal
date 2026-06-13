-- =============================================================================
-- THE CULINARY JOURNAL — GARDEN GO-LIVE (step 2j)
-- Requires RUN-GARDEN-V3.sql, RUN-GARDEN-V3-POLISH.sql, RUN-GARDEN-V4.sql,
-- and garden-v4-10 import queue already applied on Supabase.
--
-- This bundle:
--   1. Flips garden pages hidden → registered (signed-in members)
--   2. Inserts draft species shells for all 208 import-queue species
--   3. Applies all queued cultivar payloads (species with shells only)
--
-- Paste THE ENTIRE FILE in Supabase SQL Editor. Safe to re-run.
-- Expect: garden pages visibility = registered; import queue mostly approved.
-- Public directory still shows only is_published species (Tomato until you publish more).
-- =============================================================================


-- ########## BEGIN: fix-garden-v3-visible.sql ##########
-- fix-garden-v3-visible.sql
-- Flip Garden pages from hidden → registered (signed-in members). Safe to re-run.

UPDATE public.site_pages SET visibility = 'registered'
WHERE path IN ('garden-directory.html', 'garden-plant.html', 'my-garden.html', 'garden-journal.html');

SELECT path, name, visibility FROM public.site_pages
WHERE path LIKE 'garden%' OR path = 'my-garden.html'
ORDER BY sort_order;
-- ########## END: fix-garden-v3-visible.sql ##########

-- ########## BEGIN: garden-v4-14-all-species-shells.sql ##########
-- garden-v4-14-all-species-shells.sql — draft plant rows for GM Apply pipeline
-- Safe to re-run. Does not publish — set is_published in GM when ready.

-- Agave (49 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('agave', 'Agave',
  'Draft species shell — 49 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Almond (25 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('almond', 'Almond',
  'Draft species shell — 25 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Aloe Vera (17 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('aloe-vera', 'Aloe Vera',
  'Draft species shell — 17 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Amaranth (0 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('amaranth', 'Amaranth',
  'Draft species shell — 0 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Angels Trumpet (84 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('angels-trumpet', 'Angels Trumpet',
  'Draft species shell — 84 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Apple (31 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('apple', 'Apple',
  'Draft species shell — 31 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Apricot (20 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('apricot', 'Apricot',
  'Draft species shell — 20 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Argan (24 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('argan', 'Argan',
  'Draft species shell — 24 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Arrowroot (25 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('arrowroot', 'Arrowroot',
  'Draft species shell — 25 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Artichoke (73 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('artichoke', 'Artichoke',
  'Draft species shell — 73 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Ashwagandha (23 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('ashwagandha', 'Ashwagandha',
  'Draft species shell — 23 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Asparagus (25 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('asparagus', 'Asparagus',
  'Draft species shell — 25 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Avocado (36 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('avocado', 'Avocado',
  'Draft species shell — 36 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Baby's Breath (16 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('baby-s-breath', 'Baby''s Breath',
  'Draft species shell — 16 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Bamboo (37 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('bamboo', 'Bamboo',
  'Draft species shell — 37 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Banana (51 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('banana', 'Banana',
  'Draft species shell — 51 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Banksia (25 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('banksia', 'Banksia',
  'Draft species shell — 25 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Barley (41 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('barley', 'Barley',
  'Draft species shell — 41 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Basil (29 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('basil', 'Basil',
  'Draft species shell — 29 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Bean (36 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('bean', 'Bean',
  'Draft species shell — 36 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Beetroot (24 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('beetroot', 'Beetroot',
  'Draft species shell — 24 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Bell Pepper (32 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('bell-pepper', 'Bell Pepper',
  'Draft species shell — 32 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Betel Leaf (0 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('betel-leaf', 'Betel Leaf',
  'Draft species shell — 0 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Bilimbi (0 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('bilimbi', 'Bilimbi',
  'Draft species shell — 0 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Blackberry (27 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('blackberry', 'Blackberry',
  'Draft species shell — 27 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Bloodroot (3 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('bloodroot', 'Bloodroot',
  'Draft species shell — 3 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Bluebell (2 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('bluebell', 'Bluebell',
  'Draft species shell — 2 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Blueberry (23 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('blueberry', 'Blueberry',
  'Draft species shell — 23 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Bottle Gourd (66 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('bottle-gourd', 'Bottle Gourd',
  'Draft species shell — 66 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Bottle Gourd (White Gourd) (66 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('bottle-gourd-white-gourd', 'Bottle Gourd (White Gourd)',
  'Draft species shell — 66 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Breadfruit (30 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('breadfruit', 'Breadfruit',
  'Draft species shell — 30 cultivars in import queue. Curate in GM Interface.', false)
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

-- Cantaloupe (50 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('cantaloupe', 'Cantaloupe',
  'Draft species shell — 50 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Cardamom (51 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('cardamom', 'Cardamom',
  'Draft species shell — 51 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Carolina Silverbell (8 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('carolina-silverbell', 'Carolina Silverbell',
  'Draft species shell — 8 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Carrot (0 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('carrot', 'Carrot',
  'Draft species shell — 0 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Cashew (36 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('cashew', 'Cashew',
  'Draft species shell — 36 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Cassava (42 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('cassava', 'Cassava',
  'Draft species shell — 42 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Cauliflower (26 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('cauliflower', 'Cauliflower',
  'Draft species shell — 26 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Celery (31 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('celery', 'Celery',
  'Draft species shell — 31 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Chamomile (12 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('chamomile', 'Chamomile',
  'Draft species shell — 12 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Cherry (11 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('cherry', 'Cherry',
  'Draft species shell — 11 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Chestnut (18 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('chestnut', 'Chestnut',
  'Draft species shell — 18 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Chicory (20 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('chicory', 'Chicory',
  'Draft species shell — 20 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Chikoo (44 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('chikoo', 'Chikoo',
  'Draft species shell — 44 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Chili Pepper (23 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('chili-pepper', 'Chili Pepper',
  'Draft species shell — 23 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Cinnamon (30 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('cinnamon', 'Cinnamon',
  'Draft species shell — 30 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Clove (19 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('clove', 'Clove',
  'Draft species shell — 19 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Coconut (42 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('coconut', 'Coconut',
  'Draft species shell — 42 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Coffee (37 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('coffee', 'Coffee',
  'Draft species shell — 37 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Coriander (17 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('coriander', 'Coriander',
  'Draft species shell — 17 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Cotton (53 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('cotton', 'Cotton',
  'Draft species shell — 53 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Crabapple Tree (1 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('crabapple-tree', 'Crabapple Tree',
  'Draft species shell — 1 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Cranberry (17 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('cranberry', 'Cranberry',
  'Draft species shell — 17 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Crepe Myrtle (33 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('crepe-myrtle', 'Crepe Myrtle',
  'Draft species shell — 33 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Cucumber (53 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('cucumber', 'Cucumber',
  'Draft species shell — 53 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Curry Leaf (16 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('curry-leaf', 'Curry Leaf',
  'Draft species shell — 16 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Custard Apple (28 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('custard-apple', 'Custard Apple',
  'Draft species shell — 28 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Daikon (26 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('daikon', 'Daikon',
  'Draft species shell — 26 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Date Palm (25 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('date-palm', 'Date Palm',
  'Draft species shell — 25 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Dill (24 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('dill', 'Dill',
  'Draft species shell — 24 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Dragon Fruit (54 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('dragon-fruit', 'Dragon Fruit',
  'Draft species shell — 54 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Drumstick Tree (27 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('drumstick-tree', 'Drumstick Tree',
  'Draft species shell — 27 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Durian (24 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('durian', 'Durian',
  'Draft species shell — 24 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Edamame (25 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('edamame', 'Edamame',
  'Draft species shell — 25 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Elder Tree (17 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('elder-tree', 'Elder Tree',
  'Draft species shell — 17 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Eucalyptus (48 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('eucalyptus', 'Eucalyptus',
  'Draft species shell — 48 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Fennel (30 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('fennel', 'Fennel',
  'Draft species shell — 30 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Fenugreek (31 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('fenugreek', 'Fenugreek',
  'Draft species shell — 31 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Fig (54 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('fig', 'Fig',
  'Draft species shell — 54 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Finger Lime (38 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('finger-lime', 'Finger Lime',
  'Draft species shell — 38 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Flax (53 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('flax', 'Flax',
  'Draft species shell — 53 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Fringe Tree (19 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('fringe-tree', 'Fringe Tree',
  'Draft species shell — 19 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Gardenia (40 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('gardenia', 'Gardenia',
  'Draft species shell — 40 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Garlic (56 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('garlic', 'Garlic',
  'Draft species shell — 56 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Ginger (51 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('ginger', 'Ginger',
  'Draft species shell — 51 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Ginseng (0 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('ginseng', 'Ginseng',
  'Draft species shell — 0 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Goji Berry (38 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('goji-berry', 'Goji Berry',
  'Draft species shell — 38 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Golden Shower Tree (7 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('golden-shower-tree', 'Golden Shower Tree',
  'Draft species shell — 7 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Goldenrod (0 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('goldenrod', 'Goldenrod',
  'Draft species shell — 0 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Gooseberry (22 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('gooseberry', 'Gooseberry',
  'Draft species shell — 22 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Grapefruit (30 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('grapefruit', 'Grapefruit',
  'Draft species shell — 30 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Grapes (68 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('grapes', 'Grapes',
  'Draft species shell — 68 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Guava (48 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('guava', 'Guava',
  'Draft species shell — 48 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Gum Tree (27 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('gum-tree', 'Gum Tree',
  'Draft species shell — 27 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Hazelnut (32 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('hazelnut', 'Hazelnut',
  'Draft species shell — 32 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Henna (19 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('henna', 'Henna',
  'Draft species shell — 19 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Hibiscus (26 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('hibiscus', 'Hibiscus',
  'Draft species shell — 26 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Honeydew Melon (24 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('honeydew-melon', 'Honeydew Melon',
  'Draft species shell — 24 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Horseradish (30 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('horseradish', 'Horseradish',
  'Draft species shell — 30 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Hyssop (20 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('hyssop', 'Hyssop',
  'Draft species shell — 20 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Ice Cream Bean (21 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('ice-cream-bean', 'Ice Cream Bean',
  'Draft species shell — 21 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Illawara Plum (5 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('illawara-plum', 'Illawara Plum',
  'Draft species shell — 5 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Jaboticaba (45 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('jaboticaba', 'Jaboticaba',
  'Draft species shell — 45 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Jacaranda Tree (16 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('jacaranda-tree', 'Jacaranda Tree',
  'Draft species shell — 16 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Jackfruit (63 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('jackfruit', 'Jackfruit',
  'Draft species shell — 63 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Jute (33 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('jute', 'Jute',
  'Draft species shell — 33 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Kiwi (24 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('kiwi', 'Kiwi',
  'Draft species shell — 24 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Kohlrabi (50 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('kohlrabi', 'Kohlrabi',
  'Draft species shell — 50 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Leek (5 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('leek', 'Leek',
  'Draft species shell — 5 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Lemon (37 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('lemon', 'Lemon',
  'Draft species shell — 37 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Lemon Balm (19 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('lemon-balm', 'Lemon Balm',
  'Draft species shell — 19 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Lemongrass (31 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('lemongrass', 'Lemongrass',
  'Draft species shell — 31 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Lime (48 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('lime', 'Lime',
  'Draft species shell — 48 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Longan (34 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('longan', 'Longan',
  'Draft species shell — 34 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Loofah (41 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('loofah', 'Loofah',
  'Draft species shell — 41 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Lychee (26 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('lychee', 'Lychee',
  'Draft species shell — 26 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Macadamia (38 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('macadamia', 'Macadamia',
  'Draft species shell — 38 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Magnolia (80 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('magnolia', 'Magnolia',
  'Draft species shell — 80 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Mahogany (19 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('mahogany', 'Mahogany',
  'Draft species shell — 19 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Mango (0 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('mango', 'Mango',
  'Draft species shell — 0 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Mangosteen (0 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('mangosteen', 'Mangosteen',
  'Draft species shell — 0 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Maple (7 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('maple', 'Maple',
  'Draft species shell — 7 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Melon (80 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('melon', 'Melon',
  'Draft species shell — 80 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Milk Thistle (24 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('milk-thistle', 'Milk Thistle',
  'Draft species shell — 24 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Mint (70 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('mint', 'Mint',
  'Draft species shell — 70 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Miracle Fruit (6 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('miracle-fruit', 'Miracle Fruit',
  'Draft species shell — 6 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Mulberry (89 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('mulberry', 'Mulberry',
  'Draft species shell — 89 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Mustard (52 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('mustard', 'Mustard',
  'Draft species shell — 52 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Myrrh (11 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('myrrh', 'Myrrh',
  'Draft species shell — 11 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Nectarine (17 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('nectarine', 'Nectarine',
  'Draft species shell — 17 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Neem (21 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('neem', 'Neem',
  'Draft species shell — 21 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Nutmeg (4 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('nutmeg', 'Nutmeg',
  'Draft species shell — 4 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Okra (31 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('okra', 'Okra',
  'Draft species shell — 31 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Olive (37 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('olive', 'Olive',
  'Draft species shell — 37 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Onion (60 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('onion', 'Onion',
  'Draft species shell — 60 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Orange (31 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('orange', 'Orange',
  'Draft species shell — 31 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Oregano (23 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('oregano', 'Oregano',
  'Draft species shell — 23 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Papaya (46 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('papaya', 'Papaya',
  'Draft species shell — 46 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Parsley (49 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('parsley', 'Parsley',
  'Draft species shell — 49 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Parsnip (18 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('parsnip', 'Parsnip',
  'Draft species shell — 18 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Passionfruit (30 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('passionfruit', 'Passionfruit',
  'Draft species shell — 30 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Peach (49 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('peach', 'Peach',
  'Draft species shell — 49 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Peanut (40 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('peanut', 'Peanut',
  'Draft species shell — 40 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Pear (25 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('pear', 'Pear',
  'Draft species shell — 25 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Peas (0 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('peas', 'Peas',
  'Draft species shell — 0 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Pecan (20 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('pecan', 'Pecan',
  'Draft species shell — 20 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Persimmon (40 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('persimmon', 'Persimmon',
  'Draft species shell — 40 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Pili Nut (30 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('pili-nut', 'Pili Nut',
  'Draft species shell — 30 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Pine (16 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('pine', 'Pine',
  'Draft species shell — 16 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Pineapple (40 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('pineapple', 'Pineapple',
  'Draft species shell — 40 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Pistachio (17 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('pistachio', 'Pistachio',
  'Draft species shell — 17 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Plum (39 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('plum', 'Plum',
  'Draft species shell — 39 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Pomegranate (37 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('pomegranate', 'Pomegranate',
  'Draft species shell — 37 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Pomelo (0 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('pomelo', 'Pomelo',
  'Draft species shell — 0 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Potato (38 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('potato', 'Potato',
  'Draft species shell — 38 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Prickly Pear Cactus (15 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('prickly-pear-cactus', 'Prickly Pear Cactus',
  'Draft species shell — 15 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Pumpkin (51 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('pumpkin', 'Pumpkin',
  'Draft species shell — 51 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Quinoa (21 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('quinoa', 'Quinoa',
  'Draft species shell — 21 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Radish (0 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('radish', 'Radish',
  'Draft species shell — 0 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Rambutan (34 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('rambutan', 'Rambutan',
  'Draft species shell — 34 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Raspberry (11 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('raspberry', 'Raspberry',
  'Draft species shell — 11 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Rhubarb (22 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('rhubarb', 'Rhubarb',
  'Draft species shell — 22 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Rice (46 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('rice', 'Rice',
  'Draft species shell — 46 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Rose (12 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('rose', 'Rose',
  'Draft species shell — 12 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Rose Apple (19 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('rose-apple', 'Rose Apple',
  'Draft species shell — 19 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Rosemary (31 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('rosemary', 'Rosemary',
  'Draft species shell — 31 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Rubber Tree (41 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('rubber-tree', 'Rubber Tree',
  'Draft species shell — 41 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Rye (0 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('rye', 'Rye',
  'Draft species shell — 0 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Saffron (17 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('saffron', 'Saffron',
  'Draft species shell — 17 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Sage (22 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('sage', 'Sage',
  'Draft species shell — 22 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Sapodilla (72 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('sapodilla', 'Sapodilla',
  'Draft species shell — 72 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Sapote (26 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('sapote', 'Sapote',
  'Draft species shell — 26 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Sesame (11 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('sesame', 'Sesame',
  'Draft species shell — 11 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Shallots (30 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('shallots', 'Shallots',
  'Draft species shell — 30 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Sorghum (84 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('sorghum', 'Sorghum',
  'Draft species shell — 84 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Sorrel (46 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('sorrel', 'Sorrel',
  'Draft species shell — 46 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Soursop (27 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('soursop', 'Soursop',
  'Draft species shell — 27 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Spinach (33 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('spinach', 'Spinach',
  'Draft species shell — 33 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Squash (22 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('squash', 'Squash',
  'Draft species shell — 22 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Starfruit (59 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('starfruit', 'Starfruit',
  'Draft species shell — 59 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Strawberry (28 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('strawberry', 'Strawberry',
  'Draft species shell — 28 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Sunflower (48 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('sunflower', 'Sunflower',
  'Draft species shell — 48 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Sweet Bay Magnolia (16 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('sweet-bay-magnolia', 'Sweet Bay Magnolia',
  'Draft species shell — 16 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Sweet Flag (17 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('sweet-flag', 'Sweet Flag',
  'Draft species shell — 17 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Sweet Pea (19 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('sweet-pea', 'Sweet Pea',
  'Draft species shell — 19 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Sweet Potato (91 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('sweet-potato', 'Sweet Potato',
  'Draft species shell — 91 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Swiss Chard (29 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('swiss-chard', 'Swiss Chard',
  'Draft species shell — 29 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Tamarind (33 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('tamarind', 'Tamarind',
  'Draft species shell — 33 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Taro (16 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('taro', 'Taro',
  'Draft species shell — 16 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Tarragon (8 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('tarragon', 'Tarragon',
  'Draft species shell — 8 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Tea Tree (33 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('tea-tree', 'Tea Tree',
  'Draft species shell — 33 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Teak (47 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('teak', 'Teak',
  'Draft species shell — 47 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Thyme (28 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('thyme', 'Thyme',
  'Draft species shell — 28 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Tomatillo (25 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('tomatillo', 'Tomatillo',
  'Draft species shell — 25 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Tomato (91 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('tomato', 'Tomato',
  'Draft species shell — 91 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Tulip (61 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('tulip', 'Tulip',
  'Draft species shell — 61 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Turmeric (69 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('turmeric', 'Turmeric',
  'Draft species shell — 69 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Turnip (20 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('turnip', 'Turnip',
  'Draft species shell — 20 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Valerian (15 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('valerian', 'Valerian',
  'Draft species shell — 15 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Vanilla (19 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('vanilla', 'Vanilla',
  'Draft species shell — 19 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Viola (8 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('viola', 'Viola',
  'Draft species shell — 8 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Walnut (44 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('walnut', 'Walnut',
  'Draft species shell — 44 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Wasabi (6 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('wasabi', 'Wasabi',
  'Draft species shell — 6 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Watermelon (36 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('watermelon', 'Watermelon',
  'Draft species shell — 36 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Weeping Cherry (23 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('weeping-cherry', 'Weeping Cherry',
  'Draft species shell — 23 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Weeping Willow (5 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('weeping-willow', 'Weeping Willow',
  'Draft species shell — 5 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Wheat (36 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('wheat', 'Wheat',
  'Draft species shell — 36 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Wingnut (Pterocarya) (8 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('wingnut-pterocarya', 'Wingnut (Pterocarya)',
  'Draft species shell — 8 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Winter Aconite (18 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('winter-aconite', 'Winter Aconite',
  'Draft species shell — 18 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Winter Melon (16 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('winter-melon', 'Winter Melon',
  'Draft species shell — 16 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Winter Savory (16 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('winter-savory', 'Winter Savory',
  'Draft species shell — 16 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Wisteria (5 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('wisteria', 'Wisteria',
  'Draft species shell — 5 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Witch Hazel (5 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('witch-hazel', 'Witch Hazel',
  'Draft species shell — 5 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Yam (36 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('yam', 'Yam',
  'Draft species shell — 36 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Yucca (52 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('yucca', 'Yucca',
  'Draft species shell — 52 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

-- Zucchini (27 cultivars in queue)
INSERT INTO public.plants (slug, common_name, care_summary, is_published)
VALUES ('zucchini', 'Zucchini',
  'Draft species shell — 27 cultivars in import queue. Curate in GM Interface.', false)
ON CONFLICT (slug) DO NOTHING;

SELECT 'garden-v4-14-all-species-shells ready — 208 draft species' AS status;
-- ########## END: garden-v4-14-all-species-shells.sql ##########

-- ########## BEGIN: garden-v4-15-batch-apply-imports.sql ##########
-- garden-v4-15-batch-apply-imports.sql
-- Apply all import-queue payloads that have a matching species shell.
-- Requires: garden-v4-14 species shells + garden-v4-09 import RPCs.
-- Safe to re-run — skips rows already approved.

-- Allow SQL Editor (postgres) as well as authenticated admin sessions
CREATE OR REPLACE FUNCTION public.admin_apply_garden_import(p_queue_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row garden_import_queue%ROWTYPE;
  v_plant uuid;
  v_climate uuid;
  v_var uuid;
  v_ing integer;
  v_item jsonb;
  v_slug text;
  v_inserted int := 0;
  v_updated int := 0;
BEGIN
  IF NOT is_admin() AND current_user NOT IN ('postgres', 'supabase_admin') THEN
    RAISE EXCEPTION 'admin only';
  END IF;

  SELECT * INTO v_row FROM garden_import_queue WHERE id = p_queue_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'import queue row not found';
  END IF;
  IF v_row.payload IS NULL OR v_row.payload->'varieties' IS NULL THEN
    RAISE EXCEPTION 'payload missing varieties array';
  END IF;

  SELECT id INTO v_plant FROM plants WHERE slug = COALESCE(v_row.species_slug, v_row.payload->>'species_slug') LIMIT 1;
  IF v_plant IS NULL THEN
    RAISE EXCEPTION 'species plant row missing for slug % — seed species before applying cultivars',
      COALESCE(v_row.species_slug, v_row.payload->>'species_slug');
  END IF;

  SELECT "ID" INTO v_ing FROM ingredients
  WHERE lower("Ingredient Name") LIKE '%' || lower(COALESCE(v_row.species_slug, '')) || '%'
  ORDER BY "ID" LIMIT 1;

  FOR v_item IN SELECT * FROM jsonb_array_elements(v_row.payload->'varieties')
  LOOP
    v_slug := v_item->>'slug';
    IF v_slug IS NULL OR v_slug = '' THEN
      CONTINUE;
    END IF;

    INSERT INTO plant_varieties (
      plant_id, slug, name, lineage_type, origin, traits, flesh_fruit,
      yield_notes, growing_notes, availability, sort_order, is_published
    ) VALUES (
      v_plant,
      v_slug,
      COALESCE(v_item->>'name', v_slug),
      COALESCE(v_item->>'lineage_type', 'open_pollinated'),
      v_item->>'origin',
      v_item->>'traits',
      COALESCE(v_item->>'flesh_fruit', v_item->>'flesh'),
      COALESCE(v_item->>'yield_notes', v_item->>'yield'),
      COALESCE(v_item->>'growing_notes', v_item->>'notes'),
      v_item->>'availability',
      COALESCE((v_item->>'sort_order')::int, 0),
      true
    )
    ON CONFLICT (plant_id, slug) DO UPDATE SET
      name = EXCLUDED.name,
      lineage_type = EXCLUDED.lineage_type,
      origin = EXCLUDED.origin,
      traits = EXCLUDED.traits,
      flesh_fruit = EXCLUDED.flesh_fruit,
      yield_notes = EXCLUDED.yield_notes,
      growing_notes = EXCLUDED.growing_notes,
      availability = EXCLUDED.availability,
      sort_order = EXCLUDED.sort_order,
      is_published = true,
      updated_at = now()
    RETURNING id INTO v_var;

    v_inserted := v_inserted + 1;

    SELECT id INTO v_climate FROM climate_zones WHERE slug = v_item->>'climate_slug' LIMIT 1;
    IF v_var IS NOT NULL AND v_climate IS NOT NULL THEN
      INSERT INTO variety_climate_suitability (variety_id, climate_zone_id, suitability, climate_notes)
      VALUES (
        v_var, v_climate, 'recommended',
        left(COALESCE(v_item->>'growing_notes', v_item->>'notes', ''), 500)
      )
      ON CONFLICT (variety_id, climate_zone_id) DO UPDATE SET climate_notes = EXCLUDED.climate_notes;
      v_updated := v_updated + 1;

      IF v_ing IS NOT NULL THEN
        INSERT INTO variety_ingredients (variety_id, ingredient_id, part, is_primary, notes)
        VALUES (v_var, v_ing, 'fruit', true, 'Variety: ' || COALESCE(v_item->>'name', v_slug))
        ON CONFLICT (variety_id, ingredient_id, part) DO UPDATE SET notes = EXCLUDED.notes;
      END IF;
    END IF;
  END LOOP;

  UPDATE garden_import_queue
  SET status = 'approved', processed_at = now(), variety_count = v_inserted
  WHERE id = p_queue_id;

  RETURN jsonb_build_object(
    'queue_id', p_queue_id,
    'species_slug', v_row.species_slug,
    'varieties_upserted', v_inserted,
    'climate_links', v_updated
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_apply_all_garden_imports()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r record;
  v_result jsonb;
  v_ok int := 0;
  v_fail int := 0;
  v_errors jsonb := '[]'::jsonb;
BEGIN
  IF NOT is_admin() AND current_user NOT IN ('postgres', 'supabase_admin') THEN
    RAISE EXCEPTION 'admin only';
  END IF;

  FOR r IN
    SELECT q.id, q.species_slug, q.species_name
    FROM public.garden_import_queue q
    WHERE q.payload IS NOT NULL
      AND q.payload->'varieties' IS NOT NULL
      AND jsonb_array_length(q.payload->'varieties') > 0
      AND q.status IN ('pending', 'parsed', 'staging')
      AND EXISTS (
        SELECT 1 FROM public.plants p
        WHERE p.slug = COALESCE(q.species_slug, q.payload->>'species_slug')
      )
    ORDER BY q.species_name
  LOOP
    BEGIN
      v_result := public.admin_apply_garden_import(r.id);
      v_ok := v_ok + 1;
    EXCEPTION WHEN OTHERS THEN
      v_fail := v_fail + 1;
      v_errors := v_errors || jsonb_build_array(jsonb_build_object(
        'species_slug', r.species_slug,
        'species_name', r.species_name,
        'error', SQLERRM
      ));
    END;
  END LOOP;

  RETURN jsonb_build_object(
    'applied', v_ok,
    'failed', v_fail,
    'errors', v_errors
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_apply_garden_import(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_apply_all_garden_imports() TO authenticated;

SELECT public.admin_apply_all_garden_imports() AS batch_result;

SELECT status, count(*) AS rows
FROM public.garden_import_queue
GROUP BY status
ORDER BY status;

SELECT count(*) AS published_cultivars
FROM public.plant_varieties
WHERE is_published = true;

SELECT 'garden-v4-15-batch-apply-imports ready' AS status;
-- ########## END: garden-v4-15-batch-apply-imports.sql ##########
