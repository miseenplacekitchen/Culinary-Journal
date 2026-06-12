/* Submit recipe paste text normalization — extracted from submit-recipe.html */

// ── PASTE PARSER ─────────────────────────────────────────────────────────────
function splitInlineIngredientBlob(line) {
  line = String(line || '').replace(/\s+/g, ' ').trim();
  if (!line || line.length < 35) return [line];
  var core = (typeof RecipeImportCore !== 'undefined' ? RecipeImportCore : null);
  if (core && core.normalizeRecipeImportText) {
    var norm = core.normalizeRecipeImportText(line);
    var parts = norm.split('\n').map(function (l) { return l.trim(); }).filter(Boolean);
    if (parts.length >= 2) return parts;
  }
  return [line];
}

function splitInlineNumberedSteps(line) {
  line = String(line || '').trim();
  if (!line || !/\d+\.\s+[A-Za-z]/.test(line)) return [line];
  var marks = line.match(/\d+\.\s+/g) || [];
  if (marks.length < 2) return [line];
  return line.split(/(?=\d+\.\s+)/).map(function(s) { return s.trim(); }).filter(Boolean);
}

function normalizeBundledBlogRecipeText(text) {
  if (!text) return '';
  var core = (typeof RecipeImportCore !== 'undefined' ? RecipeImportCore : null);
  if (core && core.normalizeRecipeImportText) return core.normalizeRecipeImportText(text);
  var t = String(text).replace(/\r\n/g, '\n');
  t = t
    .replace(/Food\s+Advertisements\s+by\s*(\d+\.)/gi, '\n$1')
    .replace(/(preparation\s+time\s*:\s*[\d\s\-]+(?:mins?|minutes?))/gi, '\n$1\n')
    .replace(/(cooking\s+time\s*:\s*[\d\s\-]+(?:mins?|minutes?))/gi, '\n$1\n')
    .replace(/(serves?\s*:\s*\d+)/gi, '\n$1\n')
    .replace(/(ingredients?\s*:)/gi, '\nINGREDIENTS\n')
    .replace(/\s*:\s*(how\s+to\s+make\b)/gi, '\nMETHOD\n$1')
    .replace(/(how\s+to\s+make\b[^:\n]{0,90})\s*:\s*/gi, '\nMETHOD\n$1\n');
  var out = [];
  t.split('\n').forEach(function(raw) {
    var line = raw.replace(/\s+/g, ' ').trim();
    if (!line) return;
    if (/^ingredients?$/i.test(line)) { out.push('INGREDIENTS'); return; }
    if (/^method$/i.test(line)) { out.push('METHOD'); return; }
    if (/^how\s+to\s+make\b/i.test(line)) { out.push('METHOD'); out.push(line.replace(/\s*:?\s*$/, '')); return; }
    splitInlineIngredientBlob(line).forEach(function(part) {
      splitInlineNumberedSteps(part).forEach(function(s) { out.push(s); });
    });
  });
  return out.join('\n');
}

function preprocessRecipeText(text) {
  return normalizeBundledBlogRecipeText(text)
    .replace(/Food\s+Advertisements\s+by[^\n]*/gi, '')
    .replace(/#[\w\u00C0-\u024F]+/g, '')
    .replace(/(?:^|\n)\s*(?:\uD83C[\uDF00-\uDFFF]|\uD83D[\uDC00-\uDE4F])?\s*(?:INGREDIENTS?|WHAT YOU(?:'LL| WILL) NEED|YOU WILL NEED)\s*:?\s*/gi, '\nINGREDIENTS\n')
    .replace(/(?:^|\n)\s*how\s+to\s+make\s+[^:\n]{3,90}\s*:?\s*/gi, '\nMETHOD\n')
    .replace(/(?:^|\n)\s*(?:METHOD|INSTRUCTIONS?|DIRECTIONS?|STEPS?|HOW TO (?:MAKE|COOK|PREPARE))\s*:?\s*/gi, '\nMETHOD\n')
    .replace(/(?:^|\n)\s*(?:COOKING\s+)?NOTES?\s*(?:&\s*TIPS?)?\s*:?\s*/gi, '\nNOTES\n')
    .replace(/(?:^|\n)\s*(?:TIPS?|HINTS?|TRICKS?|VARIATIONS?)\s*:?\s*/gi, '\nTIPS\n')
    .replace(/(?:^|\n)\s*(?:SERVES?|SERVINGS?|YIELD)\s*:?\s*/gi, '\nSERVES\n')
    .replace(/\n{3,}/g, '\n\n');
}
