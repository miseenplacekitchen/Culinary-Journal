/**
 * The Grain Field — ingredient-led sub-categories (E1–E8, 2026).
 * `ingredients` = grain/starch focus hints (not divisions).
 */
var TCJ_GRAIN_FIELD_TAXONOMY = [
  {
    code: 'E1',
    name: 'Rice & Paddy Grains (Oryza)',
    shortName: 'Rice',
    emoji: '🍚',
    ingredients: ['Basmati', 'Jasmine', 'Sushi Short-Grain', 'Long-Grain White', 'Brown Rice', 'Black Rice', 'Forbidden Rice', 'Wild Rice', 'Sticky Rice', 'Glutinous Rice', 'Red Cargo Rice'],
    tagline: 'The global heartbeat of sustenance, encompassing raw, whole polished grains and fragrant wetland harvests.',
    description: 'From the pristine terraced paddies of Asia to the expansive delta plains of the Americas and Africa. Rice is the ultimate foundational starch, celebrated globally for its incredible ability to absorb slow-simmered broths, steam into fluffy separate clouds, or starch up into comforting, creamy risottos and regional rice bowls.'
  },
  {
    code: 'E2',
    name: 'Wheat & Triticum Derivatives',
    shortName: 'Wheat',
    emoji: '🌾',
    ingredients: ['Bulgur', 'Couscous Pearls', 'Farro', 'Freekeh', 'Wheat Berries', 'Kamut', 'Spelt', 'Einkorn', 'Seitan'],
    tagline: 'The ancient foundation of Western and West Asian food cultures, showcasing cracked, parboiled, and pearled grains.',
    description: 'Celebrating the immense culinary diversity of the wheat berry before it is ground into flour. This category houses the earthy, smoky depth of Levantine freekeh, the quick-hydrating convenience of North African couscous, and the dense, comforting chew of ancestral Italian farro grains.'
  },
  {
    code: 'E3',
    name: 'Maize & Corn Starch Kernels (Zea mays)',
    shortName: 'Maize',
    emoji: '🌽',
    ingredients: ['Coarse Cornmeal', 'Hominy Grains', 'Polenta Grits', 'Masa Harina', 'Dried Corn Kernels', 'Cornstarch'],
    tagline: 'The sacred, sun-ripened grain of the Americas, processed through ancient traditions to unlock deep nutrition.',
    description: 'Grounded in indigenous Mesoamerican and American traditions. While fresh sweetcorn on the cob belongs to vegetables, this sub-category houses corn in its architectural grain state serving as the course, slow-stirred foundation for Italian polenta, Southern grits, and the lime-treated hominy that anchors deep Mexican stews.'
  },
  {
    code: 'E4',
    name: 'Oats, Barley & Rye (Northern Cereals)',
    shortName: 'Oats & Barley',
    emoji: '🥣',
    ingredients: ['Rolled Oats', 'Steel-Cut Oats', 'Pearl Barley', 'Pot Barley', 'Hulled Rye Grains', 'Flaked Rye', 'Triticale'],
    tagline: 'Robust, cold-hardy grains native to northern climates, valued for their nutty textures and rustic comfort.',
    description: 'Grounded in the culinary heritages of Northern and Eastern Europe, the British Isles, and Central Asia. These grains are celebrated for their incredible binding power and thick, velvety textures, transforming beautifully into rich slow-stirred breakfast bowls, hearty winter broth fillers, or dense grain bakes.'
  },
  {
    code: 'E5',
    name: 'Millets, Sorghum & Teff (Ancient Dryland Grains)',
    shortName: 'Millets',
    emoji: '🫓',
    ingredients: ['Pearl Millet', 'Bajra', 'Finger Millet', 'Ragi', 'Foxtail Millet', 'Kodo Millet', 'Sorghum', 'Jowar', 'Teff', 'Fonio'],
    tagline: 'Resilient, drought-resistant ancient grains that have sustained sub-Saharan Africa and South Asia for millennia.',
    description: 'The rising stars of global climate-resilient agriculture. Encompassing African fonio, Ethiopian teff, and the massive millet family of India. These tiny, nutrient-dense grain powerhouses offer an earthy, intensely nutty flavour profile, serving as the gluten-free foundational starch for traditional flatbread batters, fermented morning porridge pots, and fluffy steamed grain dishes.'
  },
  {
    code: 'E6',
    name: 'Pseudocereals (Quinoa, Amaranth & Buckwheat)',
    shortName: 'Pseudocereals',
    emoji: '📐',
    ingredients: ['White Quinoa', 'Red Quinoa', 'Black Quinoa', 'Whole Amaranth Seeds', 'Buckwheat Groats', 'Kasha', 'Chia Seeds', 'Wild Grass Seeds'],
    tagline: 'Broadleaf plant seeds that behave exactly like culinary grains, carrying exceptionally high protein profiles.',
    description: 'Deeply rooted in the ancestral agricultural systems of the Andean highlands (Quinoa), Mesoamerica (Amaranth), and the rugged peaks of Eastern Europe and the Himalayas (Buckwheat). These naturally gluten-free seeds offer a distinct, popping texture and an unadorned, grassy, or nutty profile.'
  },
  {
    code: 'E7',
    name: 'Grain Brans, Germs & Isolated Starches',
    shortName: 'Brans & Starches',
    emoji: '🥖',
    ingredients: ['Wheat Bran', 'Oat Bran', 'Rice Bran', 'Wheat Germ', 'Sago Pearls', 'Tapioca Pearls', 'Potato Starch', 'Tapioca Starch'],
    tagline: 'The functional elements of the grain field, separating pure texture, fibre jackets, and binding starches.',
    description: 'This solves the missing link for auxiliary grain cooking. It houses the fibrous outer jackets (Brans) used for texture and health, alongside palm-pith sago and root-tapioca pearls which behave exactly like cooking grains in Southeast Asian and South Asian savory and morning dishes.'
  },
  {
    code: 'E8',
    name: 'Milled Strands & Extruded Shapes',
    shortName: 'Noodles & Pasta',
    emoji: '🍜',
    ingredients: ['Dried Spaghetti', 'Ramen Strands', 'Rice Vermicelli', 'Glass Noodles', 'Soba', 'Rice Sticks', 'Shaped Pasta'],
    tagline: 'The ultimate cross-cultural evolution of grains, transformed into dried, rolled, and extruded strands.',
    description: 'All processed pasta and noodles grouped here — geographic filters already separate Italy (Pasta) from Japan (Ramen) and Vietnam (Pho). This single sub-category cleanly handles every noodle and pasta strand in the world without clashing with the raw grains above.'
  }
];

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { TCJ_GRAIN_FIELD_TAXONOMY };
}
