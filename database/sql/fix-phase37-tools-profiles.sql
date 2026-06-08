-- fix-phase37-tools-profiles.sql — richer Tools & Appliances library fields
-- Safe to re-run.

ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS material text;
ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS capacity_notes text;
ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS heat_compatibility text;
ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS skill_level text;
ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS swap_if_missing text;
ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS care_schedule text;
ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS pairs_well_with text;
ALTER TABLE public.tool_profiles ADD COLUMN IF NOT EXISTS best_for text;

UPDATE public.tool_profiles SET
  material = COALESCE(material, 'Cast iron'),
  capacity_notes = COALESCE(capacity_notes, '10–12 inch (25–30 cm) — serves 2–4'),
  heat_compatibility = COALESCE(heat_compatibility, 'Gas · electric · oven-safe · induction (if enamel base)'),
  skill_level = COALESCE(skill_level, 'Beginner-friendly once seasoned'),
  swap_if_missing = COALESCE(swap_if_missing, 'Heavy stainless frying pan — won''t hold heat as evenly'),
  care_schedule = COALESCE(care_schedule, 'After each use: wash, dry, light oil wipe. Monthly: oven re-season if sticky.'),
  pairs_well_with = COALESCE(pairs_well_with, 'Silicone spatula · chain mail scrubber · lid for braising'),
  best_for = COALESCE(best_for, 'Searing · shallow frying · cornbread · stove-to-oven dishes')
WHERE slug = 'cast-iron-skillet' AND status = 'published';

UPDATE public.tool_profiles SET
  material = COALESCE(material, 'High-carbon or stainless steel'),
  capacity_notes = COALESCE(capacity_notes, '20–25 cm blade — all-purpose home size'),
  heat_compatibility = COALESCE(heat_compatibility, 'Hand-wash only · not dishwasher-safe (handles wood)'),
  skill_level = COALESCE(skill_level, 'Intermediate — pinch grip takes practice'),
  swap_if_missing = COALESCE(swap_if_missing, 'Santoku or utility knife for veg; cleaver only for heavy prep'),
  care_schedule = COALESCE(care_schedule, 'Every use: hone on steel. Quarterly: whetstone sharpen. Store on magnetic strip.'),
  pairs_well_with = COALESCE(pairs_well_with, 'Honing steel · cutting board · knife guard'),
  best_for = COALESCE(best_for, 'Mise en place · protein breakdown · fine dice')
WHERE slug = 'chefs-knife' AND status = 'published';

SELECT 'Phase 37 tools profiles ready' AS status;
