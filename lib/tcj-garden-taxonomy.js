/**
 * Garden & Earth — ingredient-led sub-categories (A1–A13, 2026 v2).
 * `ingredients` = focus hints (not divisions). DB column: recipe_subcategories.ingredient_hints.
 * Curated technique dishes (Thoran, Poriyal, etc.) stay in the dishes table.
 */
var TCJ_GARDEN_TAXONOMY = [
  {
    code: 'A1',
    name: 'Roots & Tubers',
    emoji: '🥔',
    ingredients: ['Potatoes', 'Cassava', 'Carrots', 'Taro', 'Daikon', 'Parsnips', 'Turnips', 'Rutabaga', 'Beets', 'Sweet Potatoes', 'Radishes', 'Celeriac', 'Sunchokes', 'Jicama', 'Yams'],
    tagline: 'Starchy treasures, nourishing blocks, and earthy heritage growing beneath the soil.',
    description: 'From comforting potatoes and sweet yams to dense cassava, crisp daikon, and grounding carrots. These energy-rich foundations form the backbone of hearty, traditional meals across every continent.'
  },
  {
    code: 'A2',
    name: 'Stems, Shoots & Sprouts',
    shortName: 'Stems & Sprouts',
    emoji: '🎋',
    ingredients: ['Celery', 'Asparagus', 'Kohlrabi', 'Bamboo Shoots', 'Bean Sprouts', 'Fiddlehead Ferns', 'Rhubarb', 'Fennel Bulb', 'Samphire', 'Broccoli Rabe', 'Heart of Palm', 'Pea Shoots'],
    tagline: 'Crisp stalks, tender spears, and the vibrant early extensions of plant life.',
    description: 'Celebrating the crunch and fresh textures of asparagus, celery, kohlrabi, and bamboo shoots, alongside delicate microgreens and nutrient-packed bean sprouts that bring life to the plate.'
  },
  {
    code: 'A3',
    name: 'Brassicas',
    emoji: '🥦',
    ingredients: ['Cabbages', 'Broccoli', 'Cauliflower', 'Bok Choy', 'Brussels Sprouts', 'Kale', 'Savoy Cabbage', 'Napa Cabbage', 'Red Cabbage'],
    tagline: 'Cruciferous heads, robust florets, and deeply comforting sulfurous greens.',
    description: 'The diverse family of cabbages, broccoli, cauliflower, bok choy, and Brussels sprouts. Valued globally for their incredible ability to carry spices, char beautifully on open fire, or soften into sweet braises.'
  },
  {
    code: 'A4',
    name: 'Alliums',
    emoji: '🧅',
    ingredients: ['Onions', 'Garlic', 'Leeks', 'Shallots', 'Scallions', 'Chives', 'Elephant Garlic', 'Wild Garlic', 'Ramps', 'Garlic Scapes'],
    tagline: 'Pungent bulbs, sweet caramelized bases, and the aromatic starting point of global flavour.',
    description: 'The undisputed foundational layer of savory cooking. Bringing together white and red onions, pungent garlic, delicate shallots, sweet leeks, and vibrant green scallions that breathe aroma into every pot.'
  },
  {
    code: 'A5',
    name: 'Rhizomes & Fresh Aromatics',
    shortName: 'Rhizomes',
    emoji: '🫚',
    ingredients: ['Ginger', 'Turmeric', 'Galangal', 'Horseradish', 'Wasabi', 'Lesser Galangal', 'Fingerroot'],
    tagline: 'Underground horizontal stems, fiery roots, and intense flavor-layering elements.',
    description: 'The intense, medicinal, and warming heat of fresh ginger, vibrant yellow turmeric, citrusy galangal, and sharp horseradish. These elements define the deep spice pastes and aromatic bases of regional cuisines.'
  },
  {
    code: 'A6',
    name: 'Leafy Greens',
    emoji: '🥬',
    ingredients: ['Spinach', 'Water Spinach', 'Kale', 'Chard', 'Lettuces', 'Arugula', 'Watercress', 'Endive', 'Chicory', 'Radicchio', 'Collard Greens', 'Mustard Greens', 'Sorrel', 'Dandelion Greens', 'Amaranth', 'Tatsoi', 'Mizuna', 'Komatsuna'],
    tagline: 'Vibrant foliage, tender leaves, and mineral-rich canopies that cook down into pure comfort.',
    description: 'Celebrating fields of soft greens from delicate spinach and wild amaranth to robust Swiss chard, crisp lettuces, and water spinach. Eaten raw and crisp or wilted down into nourishing, garlicky sides.'
  },
  {
    code: 'A7',
    name: 'Culinary Herbs & Edible Flowers',
    shortName: 'Herbs & Flowers',
    emoji: '🌿',
    ingredients: ['Basil', 'Cilantro', 'Lemongrass', 'Mint', 'Squash Blossoms', 'Parsley', 'Dill', 'Chervil', 'Tarragon', 'Oregano', 'Thyme', 'Rosemary', 'Sage', 'Bay Leaves', 'Marjoram', 'Curry Leaves', 'Nasturtiums', 'Calendula', 'Borage', 'Lavender', 'Rose Petals', 'Hibiscus', 'Chive Blossoms', 'Banana Hearts'],
    tagline: 'Aromatic leaves, fragrant stems, and delicate blossoms that lift a dish with pure essence.',
    description: 'The poetry of the garden. Features fresh basil, cilantro, mint, lemongrass, and curry leaves, alongside stunning edible flora like squash blossoms and banana hearts used for wrapping, seasoning, and garnishing.'
  },
  {
    code: 'A8',
    name: 'Nightshades & Hanging Pods',
    shortName: 'Nightshades',
    emoji: '🍅',
    ingredients: ['Tomatoes', 'Eggplants', 'Bell Peppers', 'Chilies', 'Okra', 'Tomatillos', 'Goji Berries', 'Ground Cherries'],
    tagline: 'Sun-ripened vine fruits, glossy skins, and the juicy, savory staples of the summer harvest.',
    description: 'The ultimate cross-cultural building blocks. Showcasing rich tomatoes, silky eggplants, sweet bell peppers, fiery chili varieties, and viscous okra pods that anchor stews, salsas, and curries worldwide.'
  },
  {
    code: 'A9',
    name: 'Gourds & Squashes',
    shortName: 'Gourds',
    emoji: '🎃',
    ingredients: ['Pumpkin', 'Butternut Squash', 'Zucchini', 'Bitter Gourd', 'Acorn Squash', 'Delicata Squash', 'Kabocha Squash', 'Spaghetti Squash', 'Patty Pan Squash', 'Yellow Squash', 'Calabash', 'Bottle Gourd', 'Winter Melons', 'Luffa Gourd'],
    tagline: 'Thick-skinned vines, hollow centers, and sweet, flesh-heavy autumn and tropical harvests.',
    description: 'From the sweet, velvety depths of butternut pumpkins and pumpkins to the cooling, light crunch of zucchini, winter melons, and deeply bitter regional gourds.'
  },
  {
    code: 'A10',
    name: 'Savoury Fruits & Flora',
    shortName: 'Savoury Fruits',
    emoji: '🍌',
    ingredients: ['Plantains', 'Breadfruit', 'Green Bananas', 'Jackfruit', 'Cactus Pads', 'Green Mangoes', 'Green Papayas', 'Drumstick Pods', 'Moringa', 'Seaweed', 'Sea Vegetables'],
    tagline: 'Tropical tree bounties, desert flora, and starchy fruits treated strictly like meat or potatoes.',
    description: 'A culturally rich home for green plantains, breadfruit, savory bananas, and shredded young jackfruit, alongside rugged cactus pads (nopales) and desert succulents that substitute beautifully for starches and proteins.'
  },
  {
    code: 'A11',
    name: 'Corn & Fresh Maize',
    shortName: 'Corn',
    emoji: '🌽',
    ingredients: ['Sweetcorn', 'White Maize', 'Baby Corn', 'Corn on the Cob', 'Blue Corn', 'Red Corn', 'Polenta Corn'],
    tagline: 'Juicy golden kernels, sweet milk-filled cobs, and the ancient grain eaten fresh from the stalk.',
    description: 'Honoring fresh sweetcorn, ancestral white maize, tender baby corn, and whole cobs. Grilled over open street fires, simmered into sweet chowders, or tossed into vibrant stir-fries.'
  },
  {
    code: 'A12',
    name: 'Legumes & Pulses',
    shortName: 'Legumes',
    emoji: '🫘',
    ingredients: ['Lentils', 'Dals', 'Chickpeas', 'Black Beans', 'Edamame', 'Snap Peas', 'Kidney Beans', 'Pinto Beans', 'Cannellini Beans', 'Fava Beans', 'Lima Beans', 'Mung Beans', 'Azuki Beans', 'Pigeon Peas', 'Snow Peas', 'Sugar Snap Peas', 'Chickpea Shoots'],
    tagline: 'Nutrient-dense seeds, protein-packed pods, and the ancient sustaining life of the earth.',
    description: 'The bedrock of plant-based sustenance across history. Includes smooth lentils (dals), hearty chickpeas, black and kidney beans, and sweet fresh green peas, serving as comfort food in its purest form.'
  },
  {
    code: 'A13',
    name: 'Mushrooms & Fungi',
    shortName: 'Mushrooms',
    emoji: '🍄',
    ingredients: ['Shiitake', 'Button', 'Oyster', 'Enoki', 'Wood Ear', 'Porcini', 'Cremini', 'Portobello', 'King Trumpet', 'Chanterelle', 'Morel', "Lion's Mane", 'Maitake', 'Nameko', 'Shimeji', 'Straw Mushrooms', 'Hedgehog', 'Truffles'],
    tagline: 'The umbrella kingdom of deep forest umami, rich textures, and non-plant complexity.',
    description: 'A dedicated space for spore-bearing culinary treasures. From daily white button mushrooms and rich portobellos to aromatic shiitake, wood ears, wild porcini, and prized truffles that mimic the richness of meat.'
  }
];

var TCJ_GARDEN_SUB_NAMES = TCJ_GARDEN_TAXONOMY.map(function (c) { return c.name; });

function getGardenSubMeta(subName) {
  if (!subName || !TCJ_GARDEN_TAXONOMY) return null;
  for (var i = 0; i < TCJ_GARDEN_TAXONOMY.length; i++) {
    if (TCJ_GARDEN_TAXONOMY[i].name === subName) return TCJ_GARDEN_TAXONOMY[i];
  }
  return null;
}

function browseSubPillLabel(subName) {
  var sub = getGardenSubMeta(subName);
  if (sub && sub.shortName) return sub.shortName;
  return subName || '';
}

function gardenIngredientDisplay(subOrName) {
  var sub = typeof subOrName === 'string' ? getGardenSubMeta(subOrName) : subOrName;
  if (!sub) return '';
  if (sub.ingredients && sub.ingredients.length) return sub.ingredients.join(', ');
  return sub.examples || '';
}

function parseIngredientHintText(text) {
  return String(text || '').split(/[,;\n]+/).map(function (s) { return s.trim(); }).filter(Boolean);
}

function formatIngredientHints(hints) {
  if (!hints || !hints.length) return '';
  return hints.join(', ');
}

var GARDEN_INFER_ALIASES = [
  [/\b(brinjal|aubergine)\b/i, 'Nightshades & Hanging Pods'],
  [/\b(coriander leaf|cilantro)\b/i, 'Culinary Herbs & Edible Flowers'],
  [/\b(kangkung|morning glory)\b/i, 'Leafy Greens'],
  [/\b(nopales|cactus pad)\b/i, 'Savoury Fruits & Flora'],
  [/\b(beetroot)\b/i, 'Roots & Tubers'],
  [/\b(courgette)\b/i, 'Gourds & Squashes'],
  [/\b(chilli|chile)\b/i, 'Nightshades & Hanging Pods'],
  [/\b(dal\b|dhal\b)/i, 'Legumes & Pulses'],
  [/\b(thoran|poriyal|mezhukkupuratti|upperi|palya|vepudu)\b/i, 'Leafy Greens']
];

function buildGardenInferRules() {
  var rules = [];
  TCJ_GARDEN_TAXONOMY.forEach(function (sub) {
    (sub.ingredients || []).forEach(function (ing) {
      var term = String(ing).trim();
      if (!term) return;
      var parts = term.split(/\s+/).map(function (w) {
        return w.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      });
      var re = new RegExp('\\b' + parts.join('\\s+') + 's?\\b', 'i');
      rules.push({ re: re, sub: sub.name, len: term.length });
    });
  });
  rules.sort(function (a, b) { return b.len - a.len; });
  var out = rules.map(function (r) { return [r.re, r.sub]; });
  GARDEN_INFER_ALIASES.forEach(function (pair) { out.push(pair); });
  return out;
}

var GARDEN_INFER_RULES = buildGardenInferRules();

function inferGardenSubFromBlob(blob) {
  var text = String(blob || '').toLowerCase();
  var out = { sub: '', div: '' };
  if (!text) return out;
  for (var i = 0; i < GARDEN_INFER_RULES.length; i++) {
    if (GARDEN_INFER_RULES[i][0].test(text)) {
      out.sub = GARDEN_INFER_RULES[i][1];
      return out;
    }
  }
  if (/\b(vegetable|sabzi|salad|greens)\b/i.test(text)) out.sub = 'Leafy Greens';
  return out;
}

if (typeof window !== 'undefined') {
  window.TCJ_GARDEN_TAXONOMY = TCJ_GARDEN_TAXONOMY;
  window.getGardenSubMeta = getGardenSubMeta;
  window.browseSubPillLabel = browseSubPillLabel;
  window.gardenIngredientDisplay = gardenIngredientDisplay;
  window.parseIngredientHintText = parseIngredientHintText;
  window.formatIngredientHints = formatIngredientHints;
  window.inferGardenSubFromBlob = inferGardenSubFromBlob;
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    TCJ_GARDEN_TAXONOMY, TCJ_GARDEN_SUB_NAMES, getGardenSubMeta,
    gardenIngredientDisplay, parseIngredientHintText, formatIngredientHints,
    inferGardenSubFromBlob
  };
}
