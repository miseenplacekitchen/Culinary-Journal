/**
 * Canonical TCJ recipe categories (A–L) — titles and browse copy.
 * Live browse cards load from Supabase `categories`; run fix-category-copy.sql to sync DB.
 */
var TCJ_CATEGORY_COPY = [
  { id: 'rise-shine', name: 'Rise & Shine', emoji: '🌅', description: 'Breakfasts, morning rituals, and early-day nourishment' },
  { id: 'evening-table', name: 'The Evening Table', emoji: '☕', description: 'Snacks, small plates, street bites, tea-time, and social evening foods' },
  { id: 'garden-earth', name: 'Garden & Earth', emoji: '🥬', description: 'Vegetables, plant-based dishes, legumes, roots, greens, and foraged foods' },
  { id: 'meat-fire', name: 'Meat & Fire', emoji: '🍖', description: 'Meat dishes across methods: grilling, roasting, braising, frying, smoking' },
  { id: 'ocean-river', name: 'Ocean & River', emoji: '🌊', description: 'Fish, shellfish, crustaceans, freshwater species, coastal traditions' },
  { id: 'slow-soulful', name: 'Slow & Soulful', emoji: '🥘', description: 'Stews, braises, slow cooking, comfort pots, heritage dishes, winter warmers' },
  { id: 'grains-comfort', name: 'Grains & Comfort', emoji: '🍚', description: 'Rice, noodles, pasta, porridges, pilafs, dumplings, grain-based comfort foods' },
  { id: 'breads-bakes', name: 'Breads & Bakes', emoji: '🫓', description: 'Flatbreads, leavened breads, pastries, savoury bakes, global bakery traditions' },
  { id: 'sweet-serenades', name: 'Sweet Serenades', emoji: '🍮', description: 'Desserts, sweets, puddings, confections, global sweet traditions' },
  { id: 'sips-stories', name: 'Sips & Stories', emoji: '🥂', description: 'Teas, coffees, broths, juices, cocktails, cultural beverages' },
  { id: 'preserved-cherished', name: 'Preserved & Cherished', emoji: '🫙', description: 'Pickles, ferments, chutneys, jams, curing, drying, pantry staples' },
  { id: 'little-ones', name: 'Little Ones', emoji: '👶', description: 'Children\u2019s meals, toddler foods, school snacks, gentle flavours' }
];

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { TCJ_CATEGORY_COPY };
}
