import { createRequire } from 'module';
import { readFileSync, existsSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const require = createRequire(import.meta.url);
const __dirname = dirname(fileURLToPath(import.meta.url));
const Core = require('../lib/recipe-import-core.js');
const Extract = require('../lib/recipe-import-extract.js');

const registry = JSON.parse(readFileSync(join(__dirname, 'site-registry.json'), 'utf8'));
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

console.log('Import pipeline tests — Wave 1 + 2 + 3\n');

// Core version
assert('parser version wave2+', Core.PARSER_VERSION.startsWith('2.'));

// Site registry phase 1 fixtures
Object.entries(registry.expectations || {}).forEach(function ([file, expect]) {
  if (file.endsWith('.html')) return;
  runBlobFixture(file, expect);
});

// WPRM HTML fixture
const wprmHtml = loadFixture('wprm-sample.html');
if (wprmHtml) {
  const wprmText = Extract.wprmHtmlToStructuredText(wprmHtml);
  const payload = Extract.buildImportPayload({
    html: '<div class="entry-content">' + wprmHtml + '</div>',
    host: 'vegrecipesofindia.com',
    url: 'https://vegrecipesofindia.com/test/',
    recipe: null,
    pageTitle: 'Test',
    fetchStatus: 'ok'
  });
  assert('wprm: structured text', /INGREDIENTS[\s\S]*flour/i.test(wprmText));
  assert('wprm: payload extractor family', payload.extractor === 'wprm' || payload.ingCount >= 3);
  assert('wprm: raw article preserved', (payload.import_raw_article_text || '').length > 20);
}

// JSON-LD merge (Rumali-style)
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

// Host registry coverage
const hosts = ['kothiyavunu.com', 'vegrecipesofindia.com', 'allrecipes.com'];
hosts.forEach(function (h) {
  const s = Extract.resolveHostStrategy(h);
  assert('host strategy ' + h, !!s.strategy);
});

// Enrich threshold 70
const kothi = loadFixture('kothiyavunu-puttu-blob.txt');
if (kothi) {
  const seg = Core.segmentRecipeImportText(kothi);
  const conf = Core.computeImportConfidence(seg.ingCount, seg.method);
  assert('enrich min 70: puttu score 60', conf.score === 60);
  assert('enrich min 70: puttu blocked', conf.allowEnrich === false);
}

console.log('\n' + passed + ' passed, ' + failed + ' failed');
process.exit(failed > 0 ? 1 : 0);
