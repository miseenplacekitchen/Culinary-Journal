/**
 * Ocean & River — species-led sub-categories (D1–D8, 2026).
 * `ingredients` = cut/species focus hints (not divisions).
 */
var TCJ_OCEAN_TAXONOMY = [
  {
    code: 'D1',
    name: 'White & Delicate Finfish',
    shortName: 'White Fish',
    emoji: '🐟',
    ingredients: ['Whole Whitefish', 'Skin-On Fillets', 'Fish Steaks', 'Cheeks', 'Delicate White Flakes', 'Cod', 'Sea Bass', 'Snapper', 'Halibut', 'Haddock'],
    tagline: 'Gentle, flaky saltwater finfish harvested from coastal reefs, deep oceans, and marine bays.',
    description: 'Spanning ocean cod, sea bass, snapper, halibut, and haddock. These delicate treasures are celebrated globally for their mild flavour profiles, transforming beautifully through gentle steaming, crispy high-heat pan-sears, or light, comforting coastal broths.'
  },
  {
    code: 'D2',
    name: 'Oily & Robust Finfish',
    shortName: 'Oily Fish',
    emoji: '🍣',
    ingredients: ['Whole Oily Fish', 'Rich Steaks', 'Belly Strips', 'Cured Loins', 'Smoked Sides', 'Salmon', 'Tuna', 'Mackerel', 'Sardines', 'Anchovies'],
    tagline: 'Nutrient-dense, rich-fatted saltwater fish carrying the intense, deep umami and brine of the open seas.',
    description: 'Bringing together wild salmon, ocean tuna, mackerel, sardines, and anchovies. Prized by coastal and island cultures for their bold, distinctive flavours, these fish hold up exceptionally well to open charcoal flames, deep smokehouses, or raw, pristine sashimi preparations.'
  },
  {
    code: 'D3',
    name: 'Freshwater & River Species',
    shortName: 'Freshwater',
    emoji: '🪵',
    ingredients: ['Whole River Fish', 'Skinless Basa Fillets', 'Mud-Dressed Catfish Steaks', 'Delicate Lake Fillets', 'Rohu', 'Catfish', 'Tilapia', 'Pangasius', 'Snakehead', 'Carp', 'Perch', 'Basa', 'Trout'],
    tagline: 'Delicate, smooth-skinned and fine-scaled fish harvested from freshwater rivers, inland lakes, and ancient river deltas.',
    description: 'Capturing Rohu, Catfish, Tilapia, Pangasius, Snakehead, Carp, Perch, Basa, and freshwater Trout. Deeply woven into the heartland and river-basin heritages of inland continents, these species are celebrated for their soft, absorbing flesh that drinks in heavy mustard pastes, hot clay-pot simmers, and rustic lakeside fries.'
  },
  {
    code: 'D4',
    name: 'Crustaceans & Crawlers',
    shortName: 'Crustaceans',
    emoji: '🦐',
    ingredients: ['Whole Head-On Prawns', 'Peeled Shrimp', 'Lobster Tails', 'Crab Claws', 'Soft-Shell Crabs'],
    tagline: 'Sweet, firm-fleshed armored species harvested from sandy sea beds, mangrove swamps, and riverbanks.',
    description: 'The universal luxury of prawns, crabs, lobsters, and crayfish. Revered across global street markets and high-end coastal tables alike for their natural sweetness, rendering beautifully into rich garlic-butter bakes, fiery wok stir-fries, or deeply aromatic coastal curries.'
  },
  {
    code: 'D5',
    name: 'Bivalves & Shelled Molluscs',
    shortName: 'Bivalves',
    emoji: '🦪',
    ingredients: ['In-Shell Mussels', 'Shucked Oysters', 'Whole Clams', 'Scallops on the Half-Shell', 'Cockles'],
    tagline: 'Delicate marine filters tucked inside protective shells, capturing the pure, salty essence of the tides.',
    description: 'Exploring mussels, clams, oysters, and scallops. These shelled wonders are deeply woven into maritime heritages, traditionally steamed open in fragrant wine or lemongrass broths, grilled over hot coals in their own shells, or eaten raw right at the shoreline.'
  },
  {
    code: 'D6',
    name: 'Cephalopods & Soft Tissues',
    shortName: 'Cephalopods',
    emoji: '🦑',
    ingredients: ['Squid Tubes', 'Octopus Tentacles', 'Whole Cuttlefish', 'Squid Ink Bags', 'Cleaned Rings'],
    tagline: 'Intelligent, tentacled sea creatures prized for their unique, meaty textures and deep ink bases.',
    description: 'Celebrating the unique culinary craft of preparing squid, octopus, and cuttlefish. From the sun-dried octopus tavernas of the Mediterranean to the high-heat wok-tossed squid of East Asia, these ingredients offer an unmatched, firm bite that absorbs complex marinades and slow-braised sauces perfectly.'
  },
  {
    code: 'D7',
    name: 'Cartilaginous & Heavy Marine Giants',
    shortName: 'Sharks & Rays',
    emoji: '🦈',
    ingredients: ['Shark Steaks', 'Ray Wings', 'Swordfish Loins', 'Dense Marine Cuts'],
    tagline: 'Fierce, bone-free apex predators yielding firm, dense, steak-like textures that cross the line between fish and meat.',
    description: 'Showcasing swordfish, skate and ray wings, and traditional shark heritages. These majestic ocean wanderers offer substantial, meaty cuts that do not flake apart, making them the ultimate canvas for robust skewered grills, heavy tandoor spices, and slow-simmered island stews.'
  },
  {
    code: 'D8',
    name: 'Sea Vegetables & Aquatic Flora',
    shortName: 'Sea Vegetables',
    emoji: '🌊',
    ingredients: ['Dried Nori Sheets', 'Fresh Wakame', 'Kelp Fronds', 'Kombu Strips', 'Sea Grapes'],
    tagline: 'Mineral-rich marine canopies and ocean greens harvested from shallow coastal waters and sea farms.',
    description: 'Bringing together nori, wakame, dulse, kelp, and sea grapes. Deeply revered in coastal East Asian traditions and modern oceanic culinary arts, these maritime greens infuse recipes with dense, salty minerals, crisp briny snaps, and the pure, deep umami essence of the tides.'
  }
];

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { TCJ_OCEAN_TAXONOMY };
}
