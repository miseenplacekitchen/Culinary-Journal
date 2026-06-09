import { createRequire } from 'module';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const require = createRequire(import.meta.url);
const __dirname = dirname(fileURLToPath(import.meta.url));
const Core = require('../lib/recipe-import-core.js');
const Extract = require('../lib/recipe-import-extract.js');

const fixtures = JSON.parse(readFileSync(join(__dirname, 'wave1-import-fixtures.json'), 'utf8'));

const KOTHI_BLOB = `Gothambu Puttu Recipe
Preparation Time : 10 mins Cooking time : 6-8 mins Serves : 4
Ingredients :
Wheat Flour /Atta : 2 cups Grated Coconut : 1 cup Water : 3/4 cup or enough to moisten the flour Salt to taste : How to make Gothumbu Puttu :
1. Dry roast wheat flour. 2. Add salt to water. 3. Wet the flour. 4. Pulse in mixer. 5. Optional coconut. 6. Fill cooker. 7. Layer tube. 8. Steam 6-8 minutes. 9. Serve hot with curry.
Related Posts`;

const WPRM_HTML = `<div class="wprm-recipe-container">
<ul class="wprm-recipe-ingredients"><li>2 cups flour</li><li>1 tsp salt</li><li>1 cup water</li></ul>
<ol class="wprm-recipe-instructions"><li>Mix flour and salt.</li><li>Add water slowly.</li><li>Steam 10 minutes.</li></ol>
</div>`;

const PARTIAL_SCHEMA = {
  name: 'Rumali Roti',
  recipeIngredient: [],
  recipeInstructions: [
    { '@type': 'HowToStep', text: 'Knead the dough until smooth.' },
    { '@type': 'HowToStep', text: 'Roll very thin circles.' },
    { '@type': 'HowToStep', text: 'Cook on a hot tawa.' }
  ],
  prepTime: 'PT20M',
  cookTime: 'PT10M',
  recipeYield: '6'
};

const ARTICLE_RUMALI = `INGREDIENTS
Wheat flour : 2 cups
Salt : 1 tsp
Oil : 2 tbsp
METHOD
1. Knead dough with water.
2. Rest thirty minutes.
3. Roll thin and cook on tawa.`;

let passed = 0;
let failed = 0;

function assert(name, cond) {
  if (cond) { passed++; console.log('  OK', name); }
  else { failed++; console.error(' FAIL', name); }
}

console.log('Import pipeline tests (Wave 1 + Wave 2)\n');

// Wave 1 — Kothiyavunu colon blob
const seg = Core.segmentRecipeImportText(KOTHI_BLOB);
const conf = Core.computeImportConfidence(seg.ingCount, seg.method);
assert('kothiyavunu: 4 ingredients', seg.ingCount >= 4);
assert('kothiyavunu: 8+ steps', seg.methCount >= 8);
assert('kothiyavunu: wheat qty clean', /Wheat Flour.*2 cups/i.test(seg.ingredients[0] || '') && !/Grated Coconut/.test(seg.ingredients[0] || ''));
assert('kothiyavunu: confidence allows enrich', conf.allowEnrich === true);

// Wave 2 — hostname registry
const strat = Extract.resolveHostStrategy('www.kothiyavunu.com');
assert('host: kothiyavunu is wp-raw', strat.strategy === 'wp-raw');
assert('host: vegrecipes is wprm', Extract.resolveHostStrategy('vegrecipesofindia.com').strategy === 'wprm');
assert('host: allrecipes jsonld-first', Extract.resolveHostStrategy('allrecipes.com').strategy === 'jsonld-first');

// Wave 2 — fetch errors
assert('fetch error 403 message', /blocked|paste/i.test(Extract.getFetchErrorMessage(403, 'allrecipes.com')));
assert('non-recipe URL detection', Extract.isLikelyNonRecipeUrl('https://blog.com/category/dinner/') === true);

// Wave 2 — WPRM extract
const wprmText = Extract.wprmHtmlToStructuredText(WPRM_HTML);
assert('wprm: ingredients section', /INGREDIENTS[\s\S]*2 cups flour/i.test(wprmText));
assert('wprm: method section', /METHOD[\s\S]*Mix flour/i.test(wprmText));

// Wave 2 — JSON-LD merge (Rumali-style: instructions only in schema)
const analysis = Extract.analyzeJsonLdRecipe(PARTIAL_SCHEMA);
assert('rumali partial: no schema ingredients', analysis.hasIngredients === false);
assert('rumali partial: has schema steps', analysis.hasInstructions === true);
const merged = Extract.mergeJsonLdWithArticle(PARTIAL_SCHEMA, ARTICLE_RUMALI);
assert('rumali merge: uses blog ingredients', merged.ingCount >= 3);
assert('rumali merge: uses schema or blog steps', merged.methCount >= 3);
assert('rumali merge: mergeMode on', merged.mergeMode === true);
assert('rumali merge: prep from ISO', merged.meta.prep === '20');

// Wave 2 — ISO duration
assert('ISO PT15M', Extract.parseIsoDurationMinutes('PT15M') === '15');
assert('ISO PT1H30M', Extract.parseIsoDurationMinutes('PT1H30M') === '90');

// Wave 2 — buildImportPayload
const payload = Extract.buildImportPayload({
  html: '<html><body><div class="entry-content">' + WPRM_HTML + '</div></body></html>',
  host: 'vegrecipesofindia.com',
  url: 'https://vegrecipesofindia.com/test/',
  recipe: null,
  pageTitle: 'Test Recipe',
  fetchStatus: 'ok'
});
assert('payload: has article text', payload.articleText.length > 40);
assert('payload: parser version', payload.parserVersion === '2.0.0-wave2');

console.log('\n' + passed + ' passed, ' + failed + ' failed');
process.exit(failed > 0 ? 1 : 0);
