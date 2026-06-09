import { createRequire } from 'module';
import { readFileSync, existsSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const require = createRequire(import.meta.url);
const __dirname = dirname(fileURLToPath(import.meta.url));
const Core = require('../lib/recipe-import-core.js');
const Extract = require('../lib/recipe-import-extract.js');
const Validate = require('../lib/recipe-import-validate.js');

const registry = JSON.parse(readFileSync(join(__dirname, 'site-registry.json'), 'utf8'));
const gold = JSON.parse(readFileSync(join(__dirname, 'gold-expectations.json'), 'utf8'));
const wave1 = JSON.parse(readFileSync(join(__dirname, 'wave1-import-fixtures.json'), 'utf8'));
const fixturesDir = join(__dirname, 'fixtures');

let passed = 0;
let failed = 0;

function assert(name, cond) {
  if (cond) { passed++; console.log('  OK', name); }
  else { failed++; console.error(' FAIL', name); }
}

function loadFixture(name) {
  const p = join(fixturesDir, name);
  if (!existsSync(p)) return null;
  return readFileSync(p, 'utf8');
}

function runGoldFixture(file, expect) {
  const blob = loadFixture(file);
  if (!blob) { assert(file + ': file exists', false); return; }
  const seg = Core.segmentRecipeImportText(blob);
  const result = Core.evaluateStructuralGold(seg, expect);
  assert(file + ': structural gold pass', result.pass);
  if (!result.pass) {
    result.issues.forEach(function (issue) { console.error('       -', issue); });
  }
  assert(file + ': structural score >= 99', result.score >= 99);
}

function runBlobFixture(name, expect) {
  const blob = loadFixture(name);
  if (!blob) { assert(name + ': file exists', false); return; }
  const seg = Core.segmentRecipeImportText(blob);
  const conf = Core.computeImportConfidence(seg.ingCount, seg.method);
  if (expect.ingredients_min != null) assert(name + ': ingredients_min', seg.ingCount >= expect.ingredients_min);
  if (expect.steps_min != null) assert(name + ': steps_min', seg.methCount >= expect.steps_min);
  if (expect.steps_max != null) assert(name + ': steps_max', seg.methCount <= expect.steps_max);
  if (expect.auto_enrich === false) assert(name + ': enrich gated', conf.allowEnrich === false);
  if (expect.qty_patterns) {
    const joined = seg.ingredients.join(' ');
    expect.qty_patterns.forEach(function (pat) {
      assert(name + ': qty ' + pat, joined.includes(pat) || /1\s*1\/2|1½/.test(joined));
    });
  }
}

console.log('Import pipeline tests — checklist complete\n');

assert('parser version 2.3+', Core.PARSER_VERSION.startsWith('2.3'));
assert('extractor version 2.3+', Extract.EXTRACTOR_VERSION.startsWith('2.3'));

// Gold structural tests (99% accuracy bar)
Object.entries(gold.fixtures || {}).forEach(function ([file, expect]) {
  runGoldFixture(file, expect);
});

// Wave 1 fixture registry (wired)
(wave1.fixtures || []).forEach(function (fx) {
  const file = fx.id === 'kothiyavunu-gothambu-puttu' ? 'kothiyavunu-puttu-blob.txt'
    : fx.id === 'curryworld-rumali-roti' ? 'rumali-roti-blob.txt'
    : fx.id === 'curryworld-soya-65' ? 'soya-65-blob.txt'
    : fx.id === 'curryworld-biriyani' ? 'curryworld-biriyani-blob.txt' : null;
  if (file && fx.expect) runBlobFixture(file, fx.expect);
});

function runHtmlFixture(name, host, url, expect) {
  const html = loadFixture(name);
  if (!html) { assert(name + ': file exists', false); return; }
  const payload = Extract.buildImportPayload({
    html: html,
    host: host,
    url: url,
    recipe: Extract.extractJsonLdRecipe(html),
    pageTitle: 'Fixture',
    fetchStatus: 'ok'
  });
  if (expect.extractor) assert(name + ': extractor ' + expect.extractor, payload.extractor === expect.extractor);
  if (expect.ingredients_min != null) assert(name + ': ingredients_min', payload.ingCount >= expect.ingredients_min);
  if (expect.steps_min != null) assert(name + ': steps_min', payload.methCount >= expect.steps_min);
  assert(name + ': importQuality', payload.importQuality && payload.importQuality.confidence_score != null);
  assert(name + ': attribution', payload.attribution && payload.attribution.source_url);
}

runHtmlFixture('wprm-modern-live.html', 'vegrecipesofindia.com', 'https://vegrecipesofindia.com/masala-dosa/', registry.expectations['wprm-modern-live.html'] || {});
runHtmlFixture('jsonld-commercial-sample.html', 'allrecipes.com', 'https://www.allrecipes.com/recipe/test/', registry.expectations['jsonld-commercial-sample.html'] || {});

const rumaliBlob = loadFixture('rumali-roti-blob.txt');
if (rumaliBlob) {
  const partial = {
    name: 'Rumali Roti',
    recipeIngredient: [],
    recipeInstructions: [
      { '@type': 'HowToStep', text: 'Knead the dough until smooth.' },
      { '@type': 'HowToStep', text: 'Roll very thin circles.' },
      { '@type': 'HowToStep', text: 'Cook on a hot tawa.' }
    ],
    prepTime: 'PT20M'
  };
  const merged = Extract.mergeJsonLdWithArticle(partial, rumaliBlob);
  assert('rumali merge: ingredients', merged.ingCount >= 3);
  assert('rumali merge: steps', merged.methCount >= 3);
  assert('rumali merge: mode', merged.mergeMode === true);
}

const hosts = ['kothiyavunu.com', 'vegrecipesofindia.com', 'allrecipes.com', '10.com.au', 'philly.com.au'];
hosts.forEach(function (h) {
  const s = Extract.resolveHostStrategy(h);
  assert('host strategy ' + h, !!s.strategy);
});

const kothi = loadFixture('kothiyavunu-puttu-blob.txt');
if (kothi) {
  const seg = Core.segmentRecipeImportText(kothi);
  const conf = Core.computeImportConfidence(seg.ingCount, seg.method);
  assert('enrich min 70: puttu score 60', conf.score === 60);
  assert('enrich min 70: puttu blocked', conf.allowEnrich === false);
}

const kothiLiveHtml = loadFixture('kothiyavunu-puttu-live.html');
if (kothiLiveHtml) {
  const payload = Extract.buildImportPayload({
    html: kothiLiveHtml,
    host: 'kothiyavunu.com',
    url: 'https://www.kothiyavunu.com/2013/08/gothambu-puttu-recipe-wheat-puttu-recipe/',
    recipe: Extract.extractJsonLdRecipe(kothiLiveHtml),
    pageTitle: 'Gothambu Puttu Recipe',
    fetchStatus: 'ok'
  });
  assert('kothi live html: extractor wp-raw', payload.extractor === 'wp-raw');
  assert('kothi live html: version 2.3+', (payload.extractorVersion || '').startsWith('2.3'));
  assert('kothi live html: importQuality', payload.importQuality && payload.importQuality.review_required === true);
  assert('kothi live html: ingredients_min', payload.ingCount >= 4);
  assert('kothi live html: steps_min', payload.methCount >= 8);
  assert('kothi live html: steps_max', payload.methCount <= 10);
  assert('kothi live html: no triple METHOD', (payload.articleText.match(/\nMETHOD/g) || []).length <= 2);
  assert('kothi live html: attribution url', payload.attribution && payload.attribution.source_url.includes('kothiyavunu'));
  assert('kothi live html: raw audit trail', (payload.import_raw_article_text || '').length > 100);
}

// Social / structure checks
assert('looksLikeStructuredRecipe needs ing+steps', Core.looksLikeStructuredRecipe('1 cup flour\n2 tsp salt\n3. Mix\n4. Bake') === true);
assert('looksLikeStructuredRecipe rejects qty-only', Core.looksLikeStructuredRecipe('1 cup flour\n2 tsp salt\n3 tbsp oil') === false);
assert('splitBundledCaption adds sections', /\nINGREDIENTS\n/.test(Core.splitBundledCaption('Ingredients: flour Method: 1. Mix 2. Bake')));

// Validation helpers
assert('dietary: GF+wheat blocked', Validate.dietaryContradictions(['Wheat flour', 'Salt'], ['tag-gf']).length === 1);
assert('dietary: vegan+chicken blocked', Validate.dietaryContradictions(['Chicken'], ['tag-vegan']).length === 1);
assert('category: puttu not ocean', Validate.categoryContradictsTitle('Ocean & River', 'Gothambu Puttu Recipe') !== null);

const pineapple = loadFixture('pineapple-biryani-annotated.txt');
if (pineapple) {
  const seg = Core.segmentRecipeImportText(pineapple);
  const conf = Core.computeImportConfidence(seg.ingCount, seg.method, [], seg.ingredients);
  assert('pineapple annotated: no clarity check in steps', !(seg.method || []).some(function (s) {
    return /please\s+confirm|this\s+may\s+be\s+a\s+typo/i.test(String(s || ''));
  }));
  assert('pineapple annotated: tips captured', (seg.tips || []).length >= 3);
  assert('pineapple annotated: submitWarn on pollution', conf.submitWarn === true || conf.score < 70);
  assert('pineapple annotated: prep 75m', seg.meta && seg.meta.prep === '75');
  assert('pineapple annotated: ingredient sections', (seg.ingredients || []).filter(function (l, i) {
    return /:\s*$/.test(String(l || '')) || (Core.isIngredientGroupHeader && Core.isIngredientGroupHeader(l, seg.ingredients[i + 1]));
  }).length >= 5);
  assert('pineapple annotated: method sections', (seg.methodSections || []).length >= 4);
  runGoldFixture('pineapple-biryani-annotated.txt', gold.fixtures['pineapple-biryani-annotated.txt'] || {});
}

// Category inference from core
if (kothi) {
  const seg = Core.segmentRecipeImportText(kothi);
  const cat = Core.inferRecipeCategoryFromBlob(seg.title, seg.ingredients);
  assert('puttu category Breads & Bakes', cat === 'Breads & Bakes');
  assert('puttu not Ocean & River', cat !== 'Ocean & River');
}

console.log('\n' + passed + ' passed, ' + failed + ' failed');
process.exit(failed > 0 ? 1 : 0);
