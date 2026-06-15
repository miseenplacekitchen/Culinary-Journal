-- fix-phase52-recipe-orphan-repair.sql
-- Run after fix-phase52-lane2-recipes.sql when health shows orphan_recipe_ingredient_names > 0.
-- Safe to re-run.

-- ── 1. Lane 2 staples missing from governed table ───────────────────
INSERT INTO public.ingredients ("Ingredient Name", "Category", "Notes")
SELECT x.name, x.cat, 'Phase 52 Lane 2 staple'
FROM (VALUES
  ('Water', 'Pantry'),
  ('Rice', 'Grains, Pasta & Noodles'),
  ('Lime', 'Produce'),
  ('Chickpea', 'Legumes & Pulses'),
  ('Cumin', 'Spices'),
  ('Turmeric', 'Spices'),
  ('Avocado', 'Produce'),
  ('Bread', 'Breads & Flatbreads'),
  ('Black pepper', 'Spices')
) AS x(name, cat)
WHERE NOT EXISTS (
  SELECT 1 FROM public.ingredients i
  WHERE lower(btrim(i."Ingredient Name")) = lower(btrim(x.name))
);

-- ── 2. Also-known-as aliases for common recipe shorthand ────────────
UPDATE public.ingredients i SET "Also Known As" = x.aka
FROM (VALUES
  ('Coconut Milk (canned, full fat)', 'coconut milk, coconut milk canned'),
  ('Tomato', 'tomatoes, canned tomato, chopped tomato'),
  ('Coriander', 'fresh coriander, coriander leaves, cilantro'),
  ('Cumin Seeds', 'cumin, ground cumin'),
  ('Garlic', 'garlic clove, garlic cloves'),
  ('Onion', 'onions, brown onion'),
  ('Butter', 'unsalted butter, salted butter'),
  ('Salt', 'sea salt, table salt')
) AS x(ing_name, aka)
WHERE lower(btrim(i."Ingredient Name")) = lower(btrim(x.ing_name))
  AND (i."Also Known As" IS NULL OR i."Also Known As" NOT ILIKE '%' || split_part(x.aka, ',', 1) || '%');

-- Fallback: append aka when ingredient exists under a close name
DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      ('coconut milk', '%coconut milk%'),
      ('cumin', '%cumin%'),
      ('turmeric', '%turmeric%'),
      ('tomato', '%tomato%'),
      ('coriander', '%coriander%'),
      ('chickpea', '%chickpea%'),
      ('black pepper', '%pepper%')
    ) AS m(needle, like_pat)
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM public.ingredients i
      WHERE lower(btrim(i."Ingredient Name")) = r.needle
         OR EXISTS (
           SELECT 1 FROM unnest(string_to_array(lower(COALESCE(i."Also Known As", '')), ',')) p(part)
           WHERE btrim(p.part) = r.needle
         )
    ) THEN
      UPDATE public.ingredients i SET "Also Known As" = CASE
        WHEN i."Also Known As" IS NULL OR btrim(i."Also Known As") = '' THEN r.needle
        WHEN lower(i."Also Known As") NOT LIKE '%' || r.needle || '%' THEN i."Also Known As" || ', ' || r.needle
        ELSE i."Also Known As"
      END
      WHERE i."ID" = (
        SELECT "ID" FROM public.ingredients
        WHERE lower("Ingredient Name") LIKE r.like_pat
        ORDER BY length("Ingredient Name")
        LIMIT 1
      );
    END IF;
  END LOOP;
END $$;

-- ── 3. Normalize approved recipe JSON (phase48 repair) ───────────────
SELECT public.repair_orphan_recipe_ingredients() AS phase52_repair_summary;

-- ── 4. Remaining orphans (expect zero rows) ───────────────────────────
SELECT DISTINCT x.ing_name AS orphan_still_remaining
FROM (
  SELECT lower(btrim(COALESCE(item->>'ingredient', item->>'name', ''))) AS ing_name
  FROM public.submitted_recipes sr,
       jsonb_array_elements(COALESCE(sr.ingredients, '[]'::jsonb)) sec,
       jsonb_array_elements(COALESCE(sec->'items', '[]'::jsonb)) item
  WHERE sr.status = 'approved'
    AND btrim(COALESCE(item->>'ingredient', item->>'name', '')) <> ''
) x
WHERE NOT EXISTS (
  SELECT 1 FROM public.ingredients i
  WHERE lower(btrim(i."Ingredient Name")) = x.ing_name
     OR EXISTS (
       SELECT 1
       FROM unnest(string_to_array(lower(COALESCE(i."Also Known As", '')), ',')) aka(part)
       WHERE btrim(aka.part) = x.ing_name
     )
)
ORDER BY 1;
