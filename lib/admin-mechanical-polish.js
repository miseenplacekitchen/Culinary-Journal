/**
 * Mechanical admin recipe polish — no LLM. Same intent as tcj_normalize + governed names.
 */

const TCJ_CATEGORIES = [
  'Garden & Earth', 'Feather & Flock', 'Pasture & Hoof', 'Ocean & River',
  'The Grain Field', 'Wrapped & Stuffed', 'Curds, Creams & Eggs', 'Breads & Bakery',
  'Sweet Serenades', 'Sips & Stories', 'Preserved & Pantry',
];
const SPICE_LEVELS = ['Not Applicable', 'Mild', 'Medium', 'Hot', 'Very Hot', 'Extremely Hot'];
const SWEET_LEVELS = ['Not Applicable', 'Subtly Sweet', 'Lightly Sweet', 'Sweet', 'Very Sweet', 'Extremely Sweet'];

const LIGATURES = { ﬁ: 'fi', ﬂ: 'fl', ﬀ: 'ff', ﬃ: 'ffi', ﬄ: 'ffl' };
const BOILERPLATE_INTRO = 'Imported from Personal book collection.';
const SMALL_WORDS = new Set(['a', 'an', 'the', 'and', 'or', 'with', 'in', 'on', 'of', 'for', 'to']);

const CATEGORY_RULES = [
  [/\b(biriyani|biryani|pilaf|pulao|fried rice)\b/i, 'The Grain Field'],
  [/\b(puttu|idiyappam|idli|dosa|appam|waffle|pancake|omelette|porridge|breakfast)\b/i, 'Curds, Creams & Eggs'],
  [/\b(roti|chapati|paratha|naan|flatbread|bread|loaf|roll|pita|kulcha)\b/i, 'Breads & Bakery'],
  [/\b(cake|cookie|brownie|muffin|halwa|ladoo|kheer|pudding|dessert|sweet)\b/i, 'Sweet Serenades'],
  [/\b(soup|rasam|broth|stew)\b/i, 'Pasture & Hoof'],
  [/\b(pickle|chutney|jam|preserve)\b/i, 'Preserved & Pantry'],
  [/\b(mocktail|cocktail|martini|margarita|mojito|daiquiri|sangria|spritz|negroni|liqueur|spirit|vodka|gin|rum|whiskey|whisky|bourbon|tequila|brandy|wine|beer|cider|prosecco|champagne|mezcal|aperol|campari|bitters|shandy|rtd|hard seltzer)\b/i, 'Sips & Stories'],
  [/\b(water|sparkling water|mineral water|coffee|espresso|latte|cappuccino|matcha|tea|herbal tea|tisane|juice|nectar|smoothie|milkshake|shake|protein shake|protein drink|energy drink|kombucha|kefir|lassi|chaas|kvass|chicha|yerba mate|horchata|sharbat|jallab|bubble tea|boba|tonic|soda|cordial|squash|shrub|agua fresca|lemonade|refresher|hot chocolate|cocoa|drink|beverage|electrolyte|sports drink|ginger beer|ginger ale|seedlip|zero.?proof)\b/i, 'Sips & Stories'],
  [/\b(salad|raita|vegetable|sabzi|thoran|aubergine|eggplant|potato)\b/i, 'Garden & Earth'],
  [/\b(fish|prawn|shrimp|crab|seafood|meen)\b/i, 'Ocean & River'],
  [/\b(chicken|duck|turkey|poultry)\b/i, 'Feather & Flock'],
  [/\b(mutton|lamb|beef|pork|meat|steak|bacon|sausage)\b/i, 'Pasture & Hoof'],
  [/\b(rice|nasi|dal|lentil|grain)\b/i, 'The Grain Field'],
];

function fixLigatures(text) {
  let t = String(text || '');
  for (const [k, v] of Object.entries(LIGATURES)) t = t.split(k).join(v);
  return t.replace(/\s+/g, ' ').trim();
}

function titleCase(text) {
  return text.split(' ').map((w, i) => {
    const lw = w.toLowerCase();
    if (i > 0 && SMALL_WORDS.has(lw)) return lw;
    return lw ? lw[0].toUpperCase() + lw.slice(1) : w;
  }).join(' ');
}

function cleanRecipeTitle(raw) {
  let title = fixLigatures(raw);
  title = title.replace(/^(?:poul\s*try|meat|seafood|vegetarian|desserts)\s*\d+\s*/i, '').trim();
  if (title.length > 90) title = title.slice(0, 87).replace(/\s+\S*$/, '');
  if (!title) return 'Untitled Recipe';
  if (title.includes('(')) {
    const i = title.indexOf('(');
    return `${titleCase(title.slice(0, i).trim())} (${titleCase(title.slice(i + 1).replace(/\)$/, '').trim())})`;
  }
  return titleCase(title);
}

function parseJsonField(val, fallback) {
  if (val == null) return fallback;
  if (typeof val === 'object') return val;
  try { return JSON.parse(val); } catch (_) { return fallback; }
}

function inferCategory(name, ingredientNames) {
  if (typeof TcjCategoryInfer !== 'undefined' && TcjCategoryInfer.inferRecipeCategoryFromBlob) {
    return TcjCategoryInfer.inferRecipeCategoryFromBlob(name, ingredientNames);
  }
  const blob = `${name} ${ingredientNames.join(' ')}`.toLowerCase();
  for (const [re, cat] of CATEGORY_RULES) {
    if (re.test(blob)) return cat;
  }
  return 'The Grain Field';
}

function normalizeIngredients(raw) {
  const sections = parseJsonField(raw, []);
  if (!Array.isArray(sections)) return [];
  const out = [];
  for (const block of sections) {
    const secName = (block.section || block.section_name || 'Ingredients').trim() || 'Ingredients';
    const items = Array.isArray(block) ? block : (block.items || []);
    const normItems = [];
    for (const item of items) {
      if (typeof item === 'string') {
        normItems.push({ qty: '', unit: '', ingredient: item.trim(), note: '', category: '' });
        continue;
      }
      const ing = String(item.ingredient || item.name || '').trim();
      if (!ing) continue;
      normItems.push({
        qty: String(item.qty || item.quantity || '').trim(),
        unit: String(item.unit || '').trim(),
        ingredient: ing,
        note: String(item.note || '').trim(),
        category: String(item.category || '').trim(),
      });
    }
    if (normItems.length) out.push({ section: secName, items: normItems });
  }
  return out;
}

function normalizeMethod(raw) {
  const blocks = parseJsonField(raw, []);
  if (!Array.isArray(blocks)) return [];
  const out = [];
  for (const block of blocks) {
    const secName = (block.section || block.section_name || 'DIRECTIONS').trim() || 'DIRECTIONS';
    const steps = Array.isArray(block) ? block : (block.steps || []);
    const normSteps = [];
    for (const step of steps) {
      if (typeof step === 'string' && step.trim()) {
        normSteps.push({ title: '', text: step.trim() });
      } else if (step && step.text) {
        normSteps.push({ title: String(step.title || '').trim(), text: String(step.text).trim() });
      }
    }
    if (normSteps.length) out.push({ section: secName, steps: normSteps });
  }
  return out;
}

function applyGovernedNames(ingredients, canonicalMap) {
  for (const block of ingredients) {
    for (const item of block.items || []) {
      const key = (item.ingredient || '').toLowerCase();
      if (key && canonicalMap[key]) item.ingredient = canonicalMap[key];
    }
  }
  return ingredients;
}

function collectUnknown(ingredients, knownLower) {
  const unknown = [];
  const seen = new Set();
  for (const block of ingredients) {
    for (const item of block.items || []) {
      const name = (item.ingredient || '').trim();
      if (!name || name.length < 2) continue;
      const key = name.toLowerCase();
      if (seen.has(key) || knownLower.has(key)) continue;
      seen.add(key);
      unknown.push(name);
    }
  }
  return unknown;
}

function simpleIntro(name, category, creditName) {
  const dish = name || 'This dish';
  const src = creditName ? ` from ${creditName}` : '';
  return `${dish} — a ${category.toLowerCase()} recipe${src}, prepared in the TCJ style.`;
}

function pickChoice(value, allowed, fallback) {
  if (!value) return fallback;
  const t = String(value).trim();
  if (allowed.includes(t)) return t;
  const lower = t.toLowerCase();
  for (const a of allowed) {
    if (a.toLowerCase() === lower) return a;
  }
  return fallback;
}

/**
 * Rule-based polish — no LLM. Returns same shape as legacy agent output.
 */
function polishMechanically(row, canonicalMap, knownLower) {
  canonicalMap = canonicalMap || {};
  knownLower = knownLower || new Set(Object.keys(canonicalMap));

  const name = cleanRecipeTitle(row.recipe_name || '');
  let ingredients = normalizeIngredients(row.ingredients);
  let method = normalizeMethod(row.method);
  ingredients = applyGovernedNames(ingredients, canonicalMap);

  const ingNames = ingredients.flatMap((s) => (s.items || []).map((i) => i.ingredient));
  const category = pickChoice(row.category, TCJ_CATEGORIES, inferCategory(name, ingNames));

  let intro = String(row.introduction || '').trim();
  if (!intro || intro === BOILERPLATE_INTRO || /^Imported from .+\.$/i.test(intro)) {
    intro = simpleIntro(name, category, row.credit_name);
  }

  const ingCount = ingredients.reduce((n, s) => n + (s.items || []).length, 0);
  const stepCount = method.reduce((n, b) => n + (b.steps || []).length, 0);

  let reject_recommended = false;
  let reject_reason = '';
  if (ingCount < 2 && stepCount < 2) {
    reject_recommended = true;
    reject_reason = 'Not enough ingredients and steps — likely not a recipe';
  }

  const unknown = collectUnknown(ingredients, knownLower);
  const fixes = [];
  if (cleanRecipeTitle(row.recipe_name || '') !== row.recipe_name) fixes.push('title cleaned');
  if (ingredients.length) fixes.push(`${ingCount} ingredients normalized`);
  if (method.length) fixes.push(`${stepCount} steps kept`);
  if (unknown.length) fixes.push(`${unknown.length} unknown ingredient(s) flagged`);

  return {
    recipe_name: name,
    native_title: row.native_title || '',
    category,
    introduction: intro,
    prep_time_minutes: row.prep_time_minutes || 0,
    cook_time_minutes: row.cook_time_minutes || 0,
    servings: Math.max(1, parseInt(row.servings, 10) || 1),
    spice_level: pickChoice(row.spice_level, SPICE_LEVELS, 'Not Applicable'),
    sweet_level: pickChoice(row.sweet_level, SWEET_LEVELS, 'Not Applicable'),
    origin_continent: row.origin_continent || '',
    origin_country: row.origin_country || '',
    origin_state: row.origin_state || '',
    origin_locality: row.origin_locality || '',
    source_type: row.source_type || 'From a Book',
    credit_name: row.credit_name || '',
    credit_handle: row.credit_handle || '',
    credit_url: row.credit_url || row.import_source_url || '',
    ingredients,
    method,
    cooking_notes: row.cooking_notes || '',
    reject_recommended,
    reject_reason,
    agent_notes: fixes.length ? `Mechanical polish: ${fixes.join('; ')}.` : 'Mechanical polish applied.',
    unknown_ingredients: unknown,
  };
}

async function loadIngredientIndex(sbFetch, serviceKey) {
  const canonicalMap = {};
  const knownLower = new Set();
  let offset = 0;
  const pageSize = 1000;
  while (true) {
    const res = await sbFetch(
      `/rest/v1/ingredients?select=${encodeURIComponent('"Ingredient Name","Also Known As"')}&offset=${offset}&limit=${pageSize}`,
      { method: 'GET' },
      serviceKey,
    );
    if (!res.ok) break;
    const rows = await res.json();
    if (!rows || !rows.length) break;
    for (const row of rows) {
      const name = String(row['Ingredient Name'] || '').trim();
      if (!name) continue;
      canonicalMap[name.toLowerCase()] = name;
      knownLower.add(name.toLowerCase());
      const aka = String(row['Also Known As'] || '');
      for (const part of aka.split(/[,;/]/)) {
        const p = part.trim().toLowerCase();
        if (p) canonicalMap[p] = name;
      }
    }
    if (rows.length < pageSize) break;
    offset += pageSize;
  }
  return { canonicalMap, knownLower };
}

module.exports = {
  polishMechanically,
  loadIngredientIndex,
  cleanRecipeTitle,
};
