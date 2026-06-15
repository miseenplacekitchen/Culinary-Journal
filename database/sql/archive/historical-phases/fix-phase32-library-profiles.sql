-- ══════════════════════════════════════════════════════════════════════
-- fix-phase32-library-profiles.sql — Desiree + Kipfler potato profiles
-- Safe to re-run. Links to governed ingredients 249, 250.
-- ══════════════════════════════════════════════════════════════════════

INSERT INTO public.ingredient_profiles (
  slug, name, also_known_as, category, flavour_profile, how_to_buy, how_to_store,
  how_to_prep, chefs_notes, did_you_know, status, visibility, governed_ingredient_id
) VALUES
('desiree-potato', 'Desiree Potato', 'Desiree, red-skinned all-rounder', 'Produce',
 'Creamy, slightly sweet flesh — roasts and mashes well.',
 'Firm, even red skin; no green patches or sprouts.',
 'Cool, dark, dry pantry — not the fridge.',
 'Scrub skin on for roasts; peel for smooth mash.',
 'All-rounder between waxy and floury — reliable for gratins and mash.',
 'Desiree is a popular European variety prized for rosy skin and yellow flesh.',
 'published', 'public', 249),
('kipfler-potato', 'Kipfler Potato', 'Kipfler, fingerling', 'Produce',
 'Nutty, waxy, firm — holds shape in salads and roasts.',
 'Slender, firm, no wrinkles; smaller is fine.',
 'Cool, dark, dry — use within two weeks for best texture.',
 'Halve lengthways for roasting; leave skin on.',
 'Do not mash — texture is the point; perfect for warm potato salads.',
 'Kipfler potatoes originated in Germany and became an Australian favourite.',
 'published', 'public', 250)
ON CONFLICT (slug) DO UPDATE SET
  name = EXCLUDED.name, governed_ingredient_id = EXCLUDED.governed_ingredient_id,
  flavour_profile = EXCLUDED.flavour_profile, how_to_buy = EXCLUDED.how_to_buy,
  how_to_store = EXCLUDED.how_to_store, how_to_prep = EXCLUDED.how_to_prep,
  chefs_notes = EXCLUDED.chefs_notes, did_you_know = EXCLUDED.did_you_know,
  status = EXCLUDED.status, updated_at = now();

SELECT slug, name, governed_ingredient_id FROM public.ingredient_profiles
WHERE slug IN ('desiree-potato', 'kipfler-potato') ORDER BY slug;
