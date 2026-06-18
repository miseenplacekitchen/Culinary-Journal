/**
 * Sips & Stories — ingredient-led sub-categories (J1–J9, 2026).
 * `ingredients` = base-ingredient / format focus hints (not divisions).
 */
var TCJ_SIPS_STORIES_TAXONOMY = [
  {
    code: 'J1',
    name: 'True Teas & Botanical Infusions',
    shortName: 'Teas & Tisanes',
    emoji: '🍃',
    ingredients: ['Black Tea Leaves', 'Green Tea Leaves', 'White Tea Leaves', 'Oolong Leaves', 'Matcha Powder', 'Dried Chamomile', 'Peppermint', 'Hibiscus', 'Rooibos'],
    tagline: 'Sun-dried leaves, vibrant blossoms, and wild botanicals steeped gently to release clarity and comfort.',
    description: 'English Breakfast, Earl Grey, Japanese Matcha, Herbal Tisanes, Moroccan Mint, and Classic Iced Teas.'
  },
  {
    code: 'J2',
    name: 'Coffee Beans & Specialty Brews',
    shortName: 'Coffee',
    emoji: '🫘',
    ingredients: ['Whole Coffee Beans', 'Green Coffee Seeds', 'Espresso Grounds', 'Roasted Chicory', 'Barley Seeds'],
    tagline: 'Fire-roasted beans and fragrant seeds ground fine and brewed to awaken the senses and spark stories.',
    description: 'Hot Espresso, Cappuccinos, Pour-Overs, Turkish Coffee, Cold Brew, Nitro, and modern Pumpkin Spiced Lattes.'
  },
  {
    code: 'J3',
    name: 'Crafted Milks, Boba & Cultured Dairy',
    shortName: 'Milks & Boba',
    emoji: '🥛',
    ingredients: ['Whole Dairy Milk', 'Oat Milk', 'Almond Milk', 'Coconut Milk', 'Tapioca Boba Pearls', 'Yogurt', 'Kefir'],
    tagline: 'Rich dairy, pressed nut milks, and cultured yogurts whisked into comforting, creamy creations.',
    description: 'Chocolate Milk, Oat Milk, Bubble and Boba Milk Teas, and global yogurt drinks like Lassis, Ayran, and Chaas.'
  },
  {
    code: 'J4',
    name: 'Pressed Fruits, Juices & Blended Smoothies',
    shortName: 'Juices & Smoothies',
    emoji: '🍎',
    ingredients: ['Fresh Sugarcane', 'Citrus', 'Apples', 'Berries', 'Carrots', 'Beets', 'Leafy Greens'],
    tagline: 'Sun-ripened orchard fruits and crisp garden vegetables crushed, pressed, or blended at peak freshness.',
    description: 'Fresh Orange Juice, Green Celery Juice, Fruit Smoothies, and thick, drinkable Acai Smoothie Bowls.'
  },
  {
    code: 'J5',
    name: 'Cordials, Syrups & Regional Coolers',
    shortName: 'Cordials & Coolers',
    emoji: '🍋',
    ingredients: ['Fresh Citrus Juices', 'Simple Syrup', 'Rose Water', 'Khus Extract', 'Fruit Vinegar', 'Shrub'],
    tagline: 'Tart citrus squeezes, sweet macerated syrups, and traditional herbal concentrates built to refresh.',
    description: 'Homemade Simple Syrups, Classic Lemonades, Limeades, Shrubs, Nimbu Pani, and regional concentrates like Jaljeera or Rose Sharbat.'
  },
  {
    code: 'J6',
    name: 'Sodas, Tonics & Effervescent Fizzes',
    shortName: 'Sodas & Fizz',
    emoji: '🫧',
    ingredients: ['Carbonated Water', 'Sparkling Water', 'Craft Soda Syrup', 'Ginger Extract', 'Tonic Bark'],
    tagline: 'Crisp carbonation, aromatic barks, and sweet bubbles crafted for celebration and sparkle.',
    description: 'Homemade Craft Colas, Root Beer, Ginger Ale, Classic Tonic Waters, and non-alcoholic Sparkling Hibiscus Fizzes.'
  },
  {
    code: 'J7',
    name: 'Living Cultures & Functional Tonics (Non-Alcoholic)',
    shortName: 'Ferments & Tonics',
    emoji: '🦠',
    ingredients: ['Kombucha Scoby', 'Water Kefir Grains', 'Ginger Root', 'Turmeric Root', 'Apple Cider Vinegar', 'Coconut Water'],
    tagline: 'Ancient effervescent ferments and potent wellness shots driven by living cultures and healing botanicals.',
    description: 'Plain and Flavoured Kombuchas, Water Kefirs, Apple Cider Vinegar Tonics, Ginger Shots, and pure Electrolyte and Coconut Water.'
  },
  {
    code: 'J8',
    name: 'Mocktails & Zero-Proof Mixology',
    shortName: 'Mocktails',
    emoji: '🍹',
    ingredients: ['Alcohol-Free Spirit', 'Non-Alcoholic Bitters', 'Botanical Elixir'],
    tagline: 'The sophisticated craft of layering flavours, herbs, and zero-proof spirits without a single drop of alcohol.',
    description: 'Virgin Mojitos, Virgin Piña Coladas, Shirley Temples, and modern craft Zero-Proof Gins and spirit alternatives.'
  },
  {
    code: 'J9',
    name: 'Wines, Beers & Crafted Spirits (Alcoholic)',
    shortName: 'Wine, Beer & Spirits',
    emoji: '🍷',
    ingredients: ['Wine Grapes', 'Malted Barley', 'Hops', 'Vodka', 'Gin', 'Rum', 'Liqueur', 'Amaro'],
    tagline: 'The deep historical craft of fermenting and distilling grains, fruits, and botanicals into social spirits.',
    description: 'All Beer styles, Red, White, and Sparkling Wines, Ciders, Sake, base spirits, and all Cocktail Families (Sours, Highballs, Tiki, Spirit-Forward).'
  }
];

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { TCJ_SIPS_STORIES_TAXONOMY };
}
