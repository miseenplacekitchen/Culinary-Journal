import { createRequire } from 'module';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const require = createRequire(import.meta.url);
const __dirname = dirname(fileURLToPath(import.meta.url));
const Extract = require('../lib/recipe-import-extract.js');
const Core = require('../lib/recipe-import-core.js');

const html = readFileSync(join(__dirname, 'fixtures/kothiyavunu-puttu-live.html'), 'utf8');
const host = 'kothiyavunu.com';

const raw = Extract.extractRawArticleText(html, host);
const article = Extract.extractArticleTextFromHtml(html, host);
const payload = Extract.buildImportPayload({
  html,
  host,
  url: 'https://www.kothiyavunu.com/2013/08/gothambu-puttu-recipe-wheat-puttu-recipe/',
  recipe: Extract.extractJsonLdRecipe(html),
  pageTitle: 'Gothambu Puttu',
  fetchStatus: 'ok'
});

console.log('=== RAW (first 1200) ===');
console.log(raw.slice(0, 1200));
console.log('\n=== ARTICLE TEXT ===');
console.log(article);
console.log('\n=== PAYLOAD ===');
console.log(JSON.stringify({
  ingCount: payload.ingCount,
  methCount: payload.methCount,
  extractor: payload.extractor,
  warnings: payload.warnings
}, null, 2));
console.log('\n=== SEGMENT ===');
const seg = Core.segmentRecipeImportText(article);
console.log('ing', seg.ingCount, 'meth', seg.methCount);
console.log(seg.normalizedText);
