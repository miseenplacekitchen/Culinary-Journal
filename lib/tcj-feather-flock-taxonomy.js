/**
 * Feather & Flock — protein-led sub-categories (B1–B8, 2026).
 * `ingredients` = cut/focus hints (not divisions).
 */
var TCJ_FEATHER_TAXONOMY = [
  {
    code: 'B1',
    name: 'Chicken',
    emoji: '🐓',
    ingredients: ['Whole Chicken', 'Bone-In Drumsticks', 'Chicken Wings', 'Thigh Fillets', 'Breasts', 'Minced Chicken'],
    tagline: 'The global cornerstone of the coop, celebrated for its versatility and cross-cultural heritage.',
    description: 'From free-range village flocks to heritage breeds, chicken forms the foundational protein canvas for humanity, effortlessly carrying the heavy spices, rich braises, and crisp fires of every continent.'
  },
  {
    code: 'B2',
    name: 'Duck & Waterfowl',
    shortName: 'Duck',
    emoji: '🦆',
    ingredients: ['Whole Duck', 'Duck Breasts (Magret)', 'Duck Legs', 'Rendered Duck Fat', 'Whole Christmas Goose'],
    tagline: 'Rich, decadent swimming birds prized for their deep flavour, golden fat, and tender meat.',
    description: 'Honoring the rich culinary heritages of duck and goose. Known for their incredible ability to crisp to perfection under intense heat or soften into luxurious, slow-rendered traditional preserves.'
  },
  {
    code: 'B3',
    name: 'Turkey & Large Fowl',
    shortName: 'Turkey',
    emoji: '🦃',
    ingredients: ['Whole Turkey', 'Turkey Breasts', 'Large Turkey Wings', 'Drumsticks', 'Ground Turkey'],
    tagline: 'Generous, lean-breasted birds steeped in ancestral traditions and grand communal feasts.',
    description: 'Originating in the Americas and embraced globally, turkey represents celebration and abundance, transforming beautifully through deep slow-smoking, rich aromatic moles, and grand whole roasts.'
  },
  {
    code: 'B4',
    name: 'Quail & Small Bush Fowl',
    shortName: 'Quail',
    emoji: '🪶',
    ingredients: ['Whole Quail', 'Spatchcocked Quail', 'Small Fowl Breasts', 'Petite Drumsticks'],
    tagline: 'Delicate, petite birds valued across history for their tender meat and elegant presentation.',
    description: 'A celebration of small-scale poultry traditions. These prized birds are often stuffed whole, threaded onto skewers over hot charcoal, or pan-fried with intense spice rubs.'
  },
  {
    code: 'B5',
    name: 'Pigeon & Squab',
    shortName: 'Pigeon',
    emoji: '🪵',
    ingredients: ['Whole Squab', 'Young Pigeon Breasts', 'Small Game Bird Crowns'],
    tagline: 'One of humanity’s oldest avian traditions, offering deeply rich, dark, and storied game meat.',
    description: 'From the slow-baked pastry pies of North Africa to the clay-pot roasts of East Asia, squab is a timeless delicacy reserved for comforting heritage recipes and complex spice pairings.'
  },
  {
    code: 'B6',
    name: 'Wild Game Birds',
    shortName: 'Game Birds',
    emoji: '🌾',
    ingredients: ['Whole Pheasant', 'Wild Partridge Breasts', 'Woodcock', 'Grouse Crowns'],
    tagline: 'Forest-foraged and wild-hunted birds that carry the raw, rustic flavours of the untamed landscape.',
    description: 'Bringing together pheasant, partridge, and grouse. These birds are deeply rooted in seasonal hunting heritages, prepared through slow-simmered comfort pots, rich gravies, and rustic open-fire roasts.'
  },
  {
    code: 'B7',
    name: 'Giant Flightless Birds',
    shortName: 'Flightless',
    emoji: '🦩',
    ingredients: ['Ostrich Fan Steaks', 'Emu Fillets', 'Ostrich Kebabs', 'Lean Strips'],
    tagline: 'The unexpected frontier of the avian world, yielding exceptionally lean, rich red meats.',
    description: 'Showcasing ostrich and emu traditions. These unique giant birds step outside typical poultry profiles, offering dense, steak-like cuts that are quickly seared or cured across regional modern cultures.'
  },
  {
    code: 'B8',
    name: 'Poultry Offal & Internal Treasures',
    shortName: 'Poultry Offal',
    emoji: '🫁',
    ingredients: ['Chicken Livers', 'Duck Gizzards', 'Turkey Hearts', 'Poultry Necks', 'Cockscombs', 'Chicken Feet', 'Giblets', 'Foie Gras'],
    tagline: 'Honoring the whole bird through zero-waste heritages, rich organ meats, and deeply flavorful internal delicacies.',
    description: 'Utilizing the whole animal from head to tail is a massive, celebrated tradition across Asia, Europe, and Africa. This sub-category provides an undisputed, premium home for French chicken liver mousses, delicate duck foie gras, East Asian dim sum chicken feet, and skewered gizzards over charcoal.'
  }
];

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { TCJ_FEATHER_TAXONOMY };
}
