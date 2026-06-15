-- fix-phase50-ingredient-categories.sql
-- Assign categories to phase48 auto-added Uncategorised ingredients.
-- Safe to re-run.

UPDATE public.ingredients SET
  "Category" = CASE
    WHEN lower("Ingredient Name") ~ '(chicken|beef|pork|lamb|mutton|fish|prawn|shrimp|crab|squid|egg|tofu)' THEN 'Protein'
    WHEN lower("Ingredient Name") ~ '(milk|cream|butter|cheese|yogurt|yoghurt|ghee|paneer)' THEN 'Dairy'
    WHEN lower("Ingredient Name") ~ '(oil|vinegar|sauce|paste|stock|broth|flour|rice|pasta|noodle|semolina|sugar|salt|spice|powder|cumin|turmeric|paprika)' THEN 'Pantry'
    WHEN lower("Ingredient Name") ~ '(onion|garlic|tomato|pepper|carrot|celery|herb|leaf|spinach|potato|apple|banana|mushroom|lemon|ginger)' THEN 'Produce'
    ELSE 'Pantry'
  END,
  "Sub Category" = COALESCE(NULLIF(btrim("Sub Category"), ''), 'General'),
  "Notes" = CASE
    WHEN "Notes" LIKE '%fix-phase48%' THEN regexp_replace("Notes", 'Auto-added by fix-phase48[^.]*\.?', 'Category assigned by fix-phase50', 'g')
    ELSE COALESCE("Notes", 'Category assigned by fix-phase50')
  END
WHERE "Category" IS NULL
   OR btrim("Category") IN ('', 'Uncategorised', 'Uncategorized')
   OR "Notes" LIKE '%fix-phase48%';

SELECT "ID", "Ingredient Name", "Category", "Sub Category"
FROM public.ingredients
WHERE "Notes" LIKE '%fix-phase50%' OR "Notes" LIKE '%fix-phase48%'
ORDER BY "ID" DESC
LIMIT 20;
