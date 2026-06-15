-- Biryanis / rice mains taxonomy + Mutton sub-category (run in Supabase SQL editor)

INSERT INTO public.recipe_subcategories (category, name, sort_order) VALUES
  ('Grains & Comfort', 'Biryanis & Pilafs', 1),
  ('Grains & Comfort', 'Fried & Stir-Fry Rice', 2),
  ('Grains & Comfort', 'Plain & Steamed Rice', 3),
  ('Grains & Comfort', 'Porridge & Congee', 4),
  ('Meat & Fire', 'Mutton', 4),
  ('Meat & Fire', 'Pork', 5),
  ('Meat & Fire', 'Goat', 6)
ON CONFLICT (category, name) DO NOTHING;

INSERT INTO public.recipe_divisions (category, subcategory, name, emoji, subtitle, description, sort_order) VALUES
  ('Grains & Comfort', 'Biryanis & Pilafs', 'Chicken Biryani', '🍗', 'Poultry layered rice', 'Chicken biryanis and dum biryanis.', 1),
  ('Grains & Comfort', 'Biryanis & Pilafs', 'Mutton Biryani', '🥩', 'Goat / mutton', 'Mutton and goat biryanis.', 2),
  ('Grains & Comfort', 'Biryanis & Pilafs', 'Lamb Biryani', '🍖', 'Sheep / lamb', 'Lamb biryanis.', 3),
  ('Grains & Comfort', 'Biryanis & Pilafs', 'Vegetable Biryani', '🥬', 'Plant-based', 'Vegetable and paneer biryanis.', 4),
  ('Grains & Comfort', 'Biryanis & Pilafs', 'Seafood Biryani', '🐟', 'Fish & shellfish', 'Prawn, fish and mixed seafood biryanis.', 5),
  ('Grains & Comfort', 'Biryanis & Pilafs', 'Mixed / Layered Biryani', '🍚', 'Combination', 'Multi-protein or festive layered biryanis.', 6),
  ('Grains & Comfort', 'Fried & Stir-Fry Rice', 'Fried Rice', '🍳', 'Wok-style', 'Fried rice and nasi goreng styles.', 1),
  ('Meat & Fire', 'Mutton', 'Curries & Stews', '🍲', 'Slow-cooked', 'Mutton curries, stews and braises.', 1),
  ('Meat & Fire', 'Mutton', 'Roasts & Grills', '🔥', 'High heat', 'Grilled, roasted and tandoor mutton.', 2)
ON CONFLICT (category, subcategory, name) DO NOTHING;
