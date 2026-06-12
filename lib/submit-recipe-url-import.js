/* Submit recipe URL import + JSON-LD populate — extracted from submit-recipe.html */
var NL = String.fromCharCode(10);

// ── RECIPE AUTO-IMPORT FROM URL ──────────────────────────────────

function isSocialMediaUrl(url) {
  return /instagram\.com|tiktok\.com|facebook\.com\/(reel|watch|share)|youtube\.com\/(shorts|watch)|pinterest\.com\/pin/i.test(url || '');
}

function looksLikeStructuredRecipe(text) {
  if (typeof RecipeImportCore !== 'undefined' && RecipeImportCore.looksLikeStructuredRecipe) {
    return RecipeImportCore.looksLikeStructuredRecipe(text);
  }
  return false;
}

function splitBundledCaption(text) {
  if (typeof RecipeImportCore !== 'undefined' && RecipeImportCore.splitBundledCaption) {
    return RecipeImportCore.splitBundledCaption(text);
  }
  return text;
}

function extractTitleFromCaption(caption) {
  if (!caption) return '';
  var first = caption.split('\n').map(function(l) { return l.trim(); }).filter(Boolean)[0] || '';
  first = first.replace(/#[\w\u00C0-\u024F]+/g, '').trim();
  if (first.length > 80) first = first.slice(0, 80);
  return first;
}

function generateRecipeFromName(name) {
  var n = (name || '').trim();
  if (!n) return null;
  var lower = n.toLowerCase();
  var ings = [], steps = [];
  if (/pickle|achar|upperi|thoran/i.test(lower)) {
    ings = ['2 cups main vegetable or fruit, diced', '2 tbsp salt', '1 tsp turmeric', '1–2 tsp chilli powder', '1 tsp mustard seeds', '3 tbsp oil'];
    steps = ['Wash and dry produce; cut into even pieces.', 'Mix salt and spices; coat evenly and rest 15 minutes.', 'Heat oil, splutter mustard seeds, pour over mixture.', 'Bottle when cool; rest at least 24 hours before serving.'];
  } else if (/chutney|thuvaiyal|pachadi/i.test(lower)) {
    ings = ['1 cup grated coconut (or main base)', '2 tbsp oil', '1 tsp mustard seeds', '2–4 dried red chillies', 'salt to taste', 'water as needed'];
    steps = ['Dry-roast or sauté aromatics until fragrant.', 'Grind base with minimal water to desired consistency.', 'Temper mustard seeds and chillies in oil; pour over chutney.', 'Adjust salt and serve chilled or at room temperature.'];
  } else if (/curry|korma|masala|stew/i.test(lower)) {
    ings = ['500 g main protein or vegetables', '2 medium onions, sliced', '3 cloves garlic, minced', '1 inch ginger, grated', '2 tbsp oil', '1 tsp ground spices', 'salt to taste', 'water or stock as needed'];
    steps = ['Sauté onions in oil until golden; add garlic and ginger.', 'Add spices and cook until fragrant.', 'Add main ingredient; cover and cook until tender.', 'Season, simmer to desired consistency, and serve hot.'];
  } else if (/cake|cookie|brownie|muffin|bread|bake/i.test(lower)) {
    ings = ['250 g flour', '150 g sugar', '100 g butter or oil', '2 eggs', '1 tsp baking powder', 'pinch of salt', 'milk or water as needed'];
    steps = ['Preheat oven and prepare tin.', 'Cream butter and sugar; add eggs.', 'Fold in dry ingredients until just combined.', 'Bake until set and golden; cool before serving.'];
  } else if (/salad|raita/i.test(lower)) {
    ings = ['3 cups vegetables or greens', '2 tbsp oil or yoghurt base', '1 tbsp lemon juice', 'salt and pepper to taste', 'fresh herbs for garnish'];
    steps = ['Prep and chop all components.', 'Whisk dressing; toss with main ingredients.', 'Rest 10 minutes for flavours to meld.', 'Garnish and serve chilled.'];
  } else {
    ings = ['500 g main ingredient', '1 medium onion, diced', '2 cloves garlic, minced', '2 tbsp oil', 'salt and pepper to taste', 'water or stock as needed'];
    steps = ['Prep all ingredients.', 'Sauté aromatics in oil until softened.', 'Add main ingredient and cook through.', 'Season, finish, and serve.'];
  }
  return 'INGREDIENTS\n' + ings.join('\n') + '\n\nMETHOD\n' + steps.map(function(s, i) { return (i + 1) + '. ' + s; }).join('\n');
}

function generateStarterFromName() {
  var nameEl = document.getElementById('recipe-name');
  var pasteEl = document.getElementById('paste-input');
  var name = (nameEl && nameEl.value.trim()) || '';
  if (!name && pasteEl) {
    var paste = pasteEl.value.trim();
    if (paste && paste.split('\n').length <= 2) name = extractTitleFromCaption(paste);
  }
  if (!name) {
    showMsg('Enter a recipe name first (or paste a short caption with the dish name), then click Generate starter.', 'error');
    if (nameEl) nameEl.focus();
    return;
  }
  if (nameEl && !nameEl.value.trim()) nameEl.value = name;
  var stub = generateRecipeFromName(name);
  if (pasteEl && stub) pasteEl.value = stub;
  showMsg('Starter template generated for “' + name + '”. Review, edit, then Parse Recipe.', 'success');
  document.getElementById('parse-tips').style.display = 'block';
  setTimeout(parseRecipe, 200);
}

function decodeImportEntities(s) {
  return String(s || '')
    .replace(/&nbsp;/gi, ' ').replace(/&#8211;|&ndash;/gi, '–').replace(/&#8212;|&mdash;/gi, '—')
    .replace(/&#8220;|&ldquo;/gi, '"').replace(/&#8221;|&rdquo;/gi, '"')
    .replace(/&#8216;|&lsquo;/gi, "'").replace(/&#8217;|&rsquo;/gi, "'")
    .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>');
}

function htmlFragmentToText(fragment) {
  if (!fragment) return '';
  return decodeImportEntities(fragment
    .replace(/<script[\s\S]*?<\/script>/gi, ' ')
    .replace(/<style[\s\S]*?<\/style>/gi, ' ')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/(p|div|h[1-6]|li|tr|section|article)>/gi, '\n')
    .replace(/<[^>]+>/g, ' ')
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .replace(/[ \t]{2,}/g, ' ')
    .trim());
}

var BLOG_STOP_LINES = [
  /^share this:/i, /^print\s*\(/i, /^email a link/i, /^like this:/i, /^loading\.?\.?\.?$/i,
  /^one response to/i, /^leave a reply/i, /^cancel reply/i, /^recent posts/i, /^categories$/i,
  /^trending$/i, /^subscribe to our newsletters/i, /^discover more from/i,
  /^loading comments/i, /^write a comment/i, /^type your email/i, /^continue reading/i,
  /^author$/i, /^written by$/i, /^facebook$/i, /^instagram$/i, /^youtube$/i, /^search$/i,
  /^skip to content/i, /^about me$/i, /^recipe request$/i, /^copyright$/i, /^subscribe$/i,
  /^happy cooking/i, /^with love$/i,
  /food advertisements by/i, /^\(?\s*\d+\s*reviews?\s*\)?\.?$/i,
  /^check here for more/i, /^sharing is caring/i, /^bon appetit/i,
  /^related posts?/i, /^\d+\s+comments?$/i,
  /^note\s*:/i, /^love$/i, /^veena$/i, /^vinu$/i, /^loading$/i
];

var BLOG_NAV_LINES = /^(beef|chicken|mutton|egg|rice|bread|breakfast|cakes|snacks|soups|drinks|sea food|pickles|sweets|useful tips|my cooking|post delivery|healthy salads|indian vegetable|kerala sadya|spice mixes|chutneys|curryworld menu|biriyani|chinese dishes)/i;

function isBlogIngredientsHeader(line) {
  return /^ingredients?\s*:?\s*$/i.test(String(line || '').replace(/[\u00A0\u200B]/g, ' ').trim());
}

function trimBlogRecipeText(text) {
  if (!text) return '';
  var lines = text.split('\n').map(function(l) { return l.trim(); }).filter(Boolean);
  var start = 0;
  var ingIdx = -1;
  for (var i = 0; i < lines.length; i++) {
    if (isBlogIngredientsHeader(lines[i])) { ingIdx = i; break; }
  }
  if (ingIdx >= 0) start = ingIdx;
  else {
    for (var f = 0; f < lines.length; f++) {
      if (lines[f].length > 10 && lines[f].length < 90 && !BLOG_NAV_LINES.test(lines[f]) && !BLOG_STOP_LINES.some(function(re) { return re.test(lines[f]); })) {
        start = f; break;
      }
    }
  }
  var end = lines.length;
  for (var k = start; k < lines.length; k++) {
    var hit = false;
    for (var s = 0; s < BLOG_STOP_LINES.length; s++) {
      if (BLOG_STOP_LINES[s].test(lines[k])) { end = k; hit = true; break; }
    }
    if (hit || /^share on /i.test(lines[k])) break;
  }
  return lines.slice(start, end).join('\n');
}

function extractArticleHtmlFromPage(html) {
  if (!html) return '';
  var patterns = [
    /<div[^>]*class="[^"]*\bentry-content\b[^"]*"[^>]*>([\s\S]*)/i,
    /<div[^>]*class="[^"]*\bwp-block-post-content\b[^"]*"[^>]*>([\s\S]*)/i,
    /<div[^>]*class="[^"]*\bpost-content\b[^"]*"[^>]*>([\s\S]*)/i,
    /<article[^>]*>([\s\S]*?)<\/article>/i,
    /<div[^>]*itemprop=["']articleBody["'][^>]*>([\s\S]*)/i,
    /<main[^>]*>([\s\S]*?)<\/main>/i
  ];
  for (var p = 0; p < patterns.length; p++) {
    var m = html.match(patterns[p]);
    if (!m || !m[1] || m[1].length < 200) continue;
    var chunk = m[1];
    var stops = [/<footer\b/i, /class="[^"]*\bcomments-area\b/i, /id=["']comments["']/i, /Share this:/i, /Leave a Reply/i, /Recent Posts/i];
    var cut = chunk.length;
    for (var si = 0; si < stops.length; si++) {
      var idx = chunk.search(stops[si]);
      if (idx > 150 && idx < cut) cut = idx;
    }
    chunk = chunk.slice(0, cut);
    if (chunk.length > 200) return chunk;
  }
  return '';
}

function extractArticleTextFromHtml(html) {
  var ext = (typeof RecipeImportExtract !== 'undefined' ? RecipeImportExtract : null);
  if (ext && ext.extractArticleTextFromHtml) {
    var host = '';
    try { host = new URL(document.getElementById('source-url-input').value.trim()).hostname; } catch(e) { console.warn('url-import', e); }
    return ext.extractArticleTextFromHtml(html, host);
  }
  var fragment = extractArticleHtmlFromPage(html);
  var text = fragment ? htmlFragmentToText(fragment) : '';
  var trimmed = text.length > 150 ? trimBlogRecipeText(text) : trimBlogRecipeText(htmlFragmentToText(html.slice(0, 120000)));
  var core = (typeof RecipeImportCore !== 'undefined' ? RecipeImportCore : null);
  if (core && core.segmentRecipeImportText) {
    return core.segmentRecipeImportText(trimmed).normalizedText || core.normalizeRecipeImportText(trimmed);
  }
  return normalizeBundledBlogRecipeText(trimmed);
}

function extractPageTitleFromHtml(html) {
  var og = html.match(/property=["']og:title["'][^>]*content=["']([^"']+)["']/i)
    || html.match(/content=["']([^"']+)["'][^>]*property=["']og:title["']/i);
  if (og && og[1]) return decodeImportEntities(og[1]).replace(/\s*[-|–—]\s*[^-|–—]+$/, '').trim();
  var h1 = html.match(/<h1[^>]*class="[^"]*entry-title[^"]*"[^>]*>([\s\S]*?)<\/h1>/i);
  if (h1 && h1[1]) return htmlFragmentToText(h1[1]).trim();
  return '';
}

async function applyUrlImportToPaste(articleText, pageTitle, statusSuffix) {
  try { clearDraftStorage(); } catch(e) { console.warn('url-import', e); }
  var draftPrompt = document.getElementById('draft-restore-prompt');
  if (draftPrompt) draftPrompt.style.display = 'none';
  var pasteEl = document.getElementById('paste-input');
  var parseRes = document.getElementById('parse-result');
  if (parseRes) parseRes.style.display = 'none';
  // Structure from raw article text first — OCR cleanup RPC can drop short lines like "Chicken -1 1/2kg".
  var extracted = extractRecipeCore(articleText);
  var cleaned = articleText;
  if (!extracted.hasContent) {
    cleaned = await cleanupOcrText(articleText);
    extracted = extractRecipeCore(cleaned);
  }
  var finalText = extracted.hasContent ? extracted.pasteText : cleaned;
  if (pasteEl) pasteEl.value = finalText;
  var nameEl = document.getElementById('recipe-name');
  expandPasteSection();
  applyBlogMetaToForm(parseBlogMetaFromLines(articleText.split('\n')));
  if (nameEl && pageTitle && !nameEl.value.trim()) {
    nameEl.value = normalizeImportPageTitle(pageTitle);
    try { clearDraftStorage(); } catch(e) { console.warn('url-import', e); }
    var draftPrompt = document.getElementById('draft-restore-prompt');
    if (draftPrompt) draftPrompt.style.display = 'none';
  } else if (nameEl) {
    var fallbackTitle = (extracted.title || '').trim();
    if (fallbackTitle && isLikelyRecipeTitleLine(fallbackTitle) && !nameEl.value.trim()) {
      nameEl.value = fallbackTitle;
    }
  }
  document.getElementById('parse-tips').style.display = 'block';
  populateAuxiliaryFromSections({
    notes: extracted.notes || [],
    tips: extracted.tips || [],
    serves: extracted.serves || []
  });
  if (extracted.hasContent) {
    var warnSuffix = (extracted.warnings && extracted.warnings.length)
      ? ' (' + extracted.warnings.join('; ') + ')' : '';
    showImportStatus(
      'Extracted ' + extracted.ingCount + ' ingredient' + (extracted.ingCount === 1 ? '' : 's') +
      ' and ' + extracted.methCount + ' step' + (extracted.methCount === 1 ? '' : 's') +
      (statusSuffix || '') + warnSuffix + ' — parsing now. Review and correct anything that looks wrong.',
      true
    );
    setTimeout(function() { if (typeof parseRecipe === 'function') parseRecipe(); }, 300);
  } else {
    showImportStatus('Recipe text imported' + (statusSuffix || '') + ' — review in the paste box, then click Parse Recipe.', null);
  }
}

async function importFromUrl() {
  var url = document.getElementById('source-url-input').value.trim();
  if (!url || !url.startsWith('http')) { showImportStatus('Please enter a valid recipe URL first.', false); return; }
  var importBtn = document.querySelector('button[onclick="importFromUrl()"]');
  if (importBtn) { importBtn.disabled = true; importBtn.textContent = 'Importing…'; }
  var creditUrl = document.getElementById('credit-url');
  if (creditUrl && !creditUrl.value) creditUrl.value = url;
  var srcSomewhere = document.querySelector('input[name="source-type"][value="From Somewhere Else"]');
  if (srcSomewhere) srcSomewhere.checked = true;

  showImportStatus('Fetching recipe...', null);
  var html = '';
  var recipe = null;
  var pageTitle = '';
  var articleText = '';
  try {
  try {
    var apiRes = await fetch('/api/fetch-recipe-url?url=' + encodeURIComponent(url), { signal: AbortSignal.timeout(14000) });
    var payload = null;
    try { payload = await apiRes.json(); } catch(e) { console.warn('url-import', e); }
    if (!apiRes.ok || (payload && payload.ok === false)) {
      var errMsg = (payload && payload.error) ? payload.error : ('Import failed (HTTP ' + apiRes.status + ')');
      var pasteHint = (payload && payload.pasteHint) ? (' ' + payload.pasteHint) : '';
      if (payload && payload.fetchStatus === 'non-recipe-url') {
        showImportStatus(errMsg + pasteHint, false);
        return;
      }
      if (payload && payload.fallbackSuggested === false) {
        showImportStatus(errMsg + pasteHint, false);
        return;
      }
      if (payload && payload.fetchStatus === 'bot-blocked') {
        showImportStatus(errMsg + ' Trying browser fallback reader…', null);
      } else if (!isSocialMediaUrl(url)) {
        showImportStatus(errMsg + (pasteHint || ' — trying fallback reader…'), null);
      }
    }
    if (apiRes.ok && payload && payload.ok !== false) {
      pageTitle = payload.pageTitle || '';
      articleText = payload.articleText || '';
      if (articleText.length <= 80 && payload.html) {
        articleText = extractArticleTextFromHtml(payload.html);
        payload.articleText = articleText;
      }
      if (payload.social) {
        await applySocialCaptionImport({
          url: url,
          caption: (payload.caption || '').trim(),
          platform: payload.platform || 'Social',
          hasRecipeStructure: payload.hasRecipeStructure
        });
        return;
      }
      await applyServerImportPayload(payload, url);
      return;
    } else if (isSocialMediaUrl(url)) {
      maybeShowVideoRecipeHelp(url, 'video-only');
      showImportStatus('Could not reach that social post. Use the Google AI Mode prompt below, or paste caption / recipe text manually.', false);
      return;
    }
  } catch(e) { console.warn('url-import', e); }
  if (!html) {
    try {
      showImportStatus('Primary fetch failed — trying fallback reader (may be incomplete)…', null);
      var proxyUrl = 'https://api.allorigins.win/get?url=' + encodeURIComponent(url);
      var res = await fetch(proxyUrl, {signal: AbortSignal.timeout(12000)});
      if (!res.ok) throw new Error('Could not fetch the page.');
      var data = await res.json();
      html = data.contents || '';
    } catch(e) {
      showImportStatus((e.message || 'Import failed') + ' — paste the recipe text manually instead.', false);
      return;
    }
  }
  if (!html && !articleText) { showImportStatus('Empty response — paste the recipe text manually.', false); return; }
  if (!articleText && html) {
    articleText = extractArticleTextFromHtml(html);
    if (!pageTitle) pageTitle = extractPageTitleFromHtml(html);
  }
  recipe = html ? extractJsonLdRecipe(html) : null;
  var ext = (typeof RecipeImportExtract !== 'undefined' ? RecipeImportExtract : null);
  if (ext && ext.buildImportPayload && html) {
    var host = '';
    try { host = new URL(url).hostname; } catch(e) { console.warn('url-import', e); }
    var localPayload = ext.buildImportPayload({ html: html, host: host, url: url, recipe: recipe, pageTitle: pageTitle, fetchStatus: 'fallback' });
    localPayload.warnings = (localPayload.warnings || []).concat(['Imported via browser fallback reader']);
    await applyServerImportPayload(localPayload, url);
    return;
  }
  if (recipe && recipeJsonLdIsTrustworthy(recipe)) {
    populateFromJsonLd(recipe, url);
    showImportStatus('Recipe imported! Review all fields below before submitting.', true);
    return;
  }
  if (articleText.length > 80) {
    await applyUrlImportToPaste(articleText, pageTitle, ' from blog (fallback)');
    applyJsonLdMetaToForm(recipe);
    return;
  }
  if (recipe) {
    populateFromJsonLd(recipe, url);
    showImportStatus('Recipe imported via schema (ingredients may be incomplete). Review and correct before submitting.', null);
    return;
  }
  showImportStatus('No recipe content found on that page. Try pasting the text manually.', false);
  } finally {
    if (importBtn) { importBtn.disabled = false; importBtn.textContent = '\u2B07 Import'; }
  }
}

function showScanStatus(msg, ok) {
  var el = document.getElementById('scan-status');
  if (!el) return;
  el.textContent = (ok===true?'✅ ':ok===false?'⚠ ':'⏳ ') + msg;
  el.style.display = 'block';
  el.style.color = ok===true?'var(--success)':ok===false?'var(--danger)':'var(--text-muted)';
}

async function cleanupOcrText(raw) {
  try {
    var sess = null;
    try { sess = JSON.parse(localStorage.getItem('tcj_session')||'null'); } catch(e) { console.warn('url-import', e); }
    var auth = (sess&&sess.access_token) ? 'Bearer '+sess.access_token : 'Bearer '+SUPA_KEY;
    var res = await fetch(SUPA_URL+'/rest/v1/rpc/cleanup_recipe_ocr', {
      method:'POST',
      headers:{'apikey':SUPA_KEY,'Authorization':auth,'Content-Type':'application/json'},
      body: JSON.stringify({ p_text: raw })
    });
    if (res.ok) {
      var data = await res.json();
      if (data && data.cleaned) return data.cleaned;
    }
  } catch(e) { console.warn('url-import', e); }
  return raw.replace(/[ \t]{2,}/g,' ').replace(/\n{3,}/g,'\n\n').trim();
}

function stripScanLine(s) {
  return s.replace(/^[\u2022\u00b7\u2023\u2043*\-\u2013\u2014\u25AA\u25CF\u25CB\u2713\u2714]\s+/, '').trim();
}

function isScanNoiseLine(line) {
  if (!line || line.length < 2) return true;
  if (/^\d{1,3}$/.test(line)) return true;
  if (/^\d+\s*\/\s*\d+$/.test(line)) return true;
  if (/^page\s+\d+/i.test(line)) return true;
  if (/^©|copyright|all rights reserved/i.test(line)) return true;
  if (/^www\.|^https?:\/\//i.test(line)) return true;
  if (/^(recipe\s+by|photograph|photo\s+by|source:)/i.test(line)) return true;
  if (/woolworths\.com|feedback|fresh ideas/i.test(line)) return true;
  if (/^\d{1,2}\/\d{1,2}\/\d{2,4}/.test(line)) return true;
  if (line.length > 200 && !/\d/.test(line)) return true;
  return false;
}

function isNutritionOrMetaLine(line) {
  if (!line) return true;
  if (/nutrition/i.test(line)) return true;
  if (/\d+\s*kJ|\bkJ\s*\/|\/\s*\d+\s*Cal|\bdaily energy intake/i.test(line)) return true;
  if (/^protein$|^fat$|^carbs$|^sugars$/i.test(line)) return true;
  if (/^\d+(\.\d+)?g$/i.test(line)) return true;
  if (/quantities above are a guide|average adult diet/i.test(line)) return true;
  if (/^description$/i.test(line)) return true;
  if (/est\.?\s*cost|difficulty$/i.test(line)) return true;
  if (/^prep$|^cook$/i.test(line)) return true;
  if (/^%|^\d+%\s+of\s+daily/i.test(line)) return true;
  return false;
}

function isStepHeaderLine(line) {
  return /^(?:step|method)\s+\d+\s+of\s+\d+/i.test(line);
}

function titleCaseWord(word) {
  if (!word) return word;
  var w = word.toLowerCase();
  if (w === 'mr' || w === 'mrs' || w === 'ms' || w === 'dr') return w.charAt(0).toUpperCase() + w.slice(1);
  return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
}

function titleCaseIngredientName(name) {
  if (!name || !name.trim()) return name || '';
  return name.trim().split(/\s+/).map(function(token) {
    if (token.indexOf('-') >= 0) {
      return token.split('-').map(function(part) { return titleCaseWord(part); }).join('-');
    }
    var apo = token.match(/^([^']+)'(.*)$/);
    if (apo) return titleCaseWord(apo[1]) + "'" + apo[2].toLowerCase();
    return titleCaseWord(token);
  }).join(' ');
}

var PARSE_UNIT_WORDS = '(?:teaspoons?|tsp|tablespoons?|tbsp|tbs|cups?|grams?|g|gm|kilograms?|kg|millilitres?|milliliters?|ml|litres?|liters?|l|ounces?|oz|pounds?|lbs?|lb|pinch(?:es)?|bunch(?:es)?|cloves?|leaves?|sprigs?|handfuls?|handful|pods?|nos?|drops?|pieces?|slice|slices|to\\s+taste)';
// Matches 1/2, 1 1/2, ½, 0.25 — slash fractions must be in-token (not only after a space).
var PARSE_QTY_PAT = '[\\d\u00BC-\u00BE\u2150-\u215E\\/\\.]+(?:\\s+[\\d\u00BC-\u00BE\u2150-\u215E\\/\\.]+)?';
var PARSE_PREP_NOTE_WORDS = 'chopped|sliced(?:\\s+lengthwise)?|finely\\s+chopped|medium|black|reqd|as\\s+needed|as\\s+reqd|to\\s+taste|for\\s+frying';

function normalizeParsedQty(qty) {
  if (!qty) return '';
  qty = String(qty).trim().replace(/\s+/g, ' ');
  var doubled = qty.match(/^1(\d\/\d)$/);
  if (doubled) return '1 ' + doubled[1];
  return qty;
}

function normalizeParsedUnit(unit) {
  if (!unit) return '';
  var u = String(unit).trim();
  if (window.normalizeUnit) u = window.normalizeUnit(u);
  if (u === 'no' || u === 'nos') return 'piece';
  return u;
}

function normalizeRecipeTitleKey(text) {
  return String(text || '').toLowerCase().replace(/[^\w\s]/g, '').replace(/\s+/g, ' ')
    .replace(/\brotti\b/g, 'roti').trim();
}

function isRecipeTitleEchoLine(line, title) {
  var a = normalizeRecipeTitleKey(line);
  if (!a || a.length < 4) return false;
  var candidates = [title];
  var nameEl = document.getElementById('recipe-name');
  if (nameEl && nameEl.value.trim()) candidates.push(nameEl.value.trim());
  for (var i = 0; i < candidates.length; i++) {
    var b = normalizeRecipeTitleKey(candidates[i]);
    if (b && a === b) return true;
  }
  return false;
}

function isMethodAttributionLine(line) {
  var t = String(line || '').trim();
  if (!t) return false;
  return /^(?:i\s+got\s+this\s+recipe|i\s+am\s+sharing|i'?m\s+sharing|thanks\s+for|source:|recipe\s+(?:from|credit)|adapted\s+from)/i.test(t)
    || /\b(?:van\s+re\s+vah|vah\s*re\s*vah|vahrehva|youtube|video\s+of\s+making|sharing\s+the\s+video|more\s+easier\s+for\s+u)\b/i.test(t)
    || /\b(?:subscribe|follow\s+my\s+(?:page|blog)|like\s+my\s+page)\b/i.test(t);
}

function appendCookingNote(text) {
  var el = document.getElementById('cooking-notes');
  if (!el || !(text || '').trim()) return;
  var note = String(text).trim();
  var existing = el.value.trim();
  el.value = existing ? existing + '\n' + note : note;
}

function createAuxCollector() {
  return { notes: [], tips: [], serves: [] };
}

function isRecipeTipOrNoteLine(line) {
  var t = String(line || '').trim();
  if (!t) return false;
  return /^(?:tips?|hints?|tricks?|variations?|notes?|cooking\s+notes?|chef'?s?\s+note|watch\s+out|caution|important)\s*:?\s*\S/i.test(t);
}

function pushAuxLine(aux, line) {
  if (!aux || !(line || '').trim()) return;
  var t = String(line).trim();
  if (/^(?:tips?|hints?|tricks?|variations?|chef'?s?\s+note)\s*:?\s*/i.test(t)) {
    aux.tips.push(t.replace(/^(?:tips?|hints?|tricks?|variations?|chef'?s?\s+note)\s*:?\s*/i, '').trim() || t);
  } else {
    aux.notes.push(t);
  }
}

function mergeAuxSections(a, b) {
  a = a || createAuxCollector();
  b = b || createAuxCollector();
  return {
    notes: (a.notes || []).concat(b.notes || []),
    tips: (a.tips || []).concat(b.tips || []),
    serves: (a.serves || []).concat(b.serves || [])
  };
}

function populateAuxiliaryFromSections(aux) {
  if (!aux) return;
  var blocks = [];
  if (aux.notes && aux.notes.length) blocks.push(aux.notes.join('\n'));
  if (aux.tips && aux.tips.length) {
    blocks.push(aux.tips.map(function(t) { return /^tip/i.test(t) ? t : 'Tip: ' + t; }).join('\n'));
  }
  if (blocks.length) {
    var block = blocks.join('\n\n');
    var notesEl = document.getElementById('cooking-notes');
    if (notesEl && notesEl.value.indexOf(block) < 0) appendCookingNote(block);
  }
  if (aux.serves && aux.serves.length) {
    var n = parseServesNumber(aux.serves);
    if (n) {
      var servEl = document.getElementById('servings');
      if (servEl && !servEl.value.trim()) servEl.value = n;
    }
  }
}

function importAuxSectionsFromRawLines(rawLines) {
  var aux = createAuxCollector();
  var current = null;
  for (var i = 0; i < rawLines.length; i++) {
    var ln = rawLines[i];
    if (/^(?:notes?|cooking\s+notes?|notes?\s*&\s*tips?)\s*:?$/i.test(ln)) { current = 'notes'; continue; }
    if (/^(?:tips?|hints?|tricks?|variations?|tips?\s*&\s*notes?)\s*:?$/i.test(ln)) { current = 'tips'; continue; }
    if (/^(?:serves?|servings?|yield)\s*:?$/i.test(ln)) { current = 'serves'; continue; }
    if (/^(?:ingredients?|method|directions?|instructions?|steps?)\s*:?$/i.test(ln)) { current = null; continue; }
    if (!current) {
      if (isRecipeTipOrNoteLine(ln)) pushAuxLine(aux, ln);
      continue;
    }
    if (ln) aux[current].push(ln);
  }
  populateAuxiliaryFromSections(aux);
}

function isMethodSectionHeader(line, nextLine) {
  var core = (typeof RecipeImportCore !== 'undefined' ? RecipeImportCore : null);
  if (core && core.isMethodStageHeader && core.isMethodStageHeader(line, nextLine || '')) return true;
  var t = String(line || '').trim().replace(/\s*:?\s*$/, '');
  if (!t || t.length > 65) return false;
  if (/^\d+\.\s/.test(t)) return false;
  if (nextLine && /^\d+\.\s+\S/.test(String(nextLine).trim())) return true;
  return /^(?:for\s+(?:the\s+)?|now\s+(?:the\s+)?)[a-z][\w\s]{2,40}$/i.test(t);
}

function isIngredientSubHeader(line) {
  if (!line || line.length > 55) return false;
  if (isMethodSectionHeader(line)) return false;
  if (/\d/.test(line)) return false;
  var core = (typeof RecipeImportCore !== 'undefined' ? RecipeImportCore : null);
  if (core && core.isIngredientGroupHeader && core.isIngredientGroupHeader(line, '')) return true;
  var t = String(line).trim().replace(/\s*:?\s*$/, '');
  if (/^for\s+(?:the\s+)?[a-z][\w\s]{2,40}\s*$/i.test(t)) return true;
  return /^(sauce|filling|topping|garnish|marinade|marinate|marination|batter|crust|glaze|frosting|icing|dressing|stuffing|coating|base|pastry|dough|syrup|broth|stock|spice\s*mix|spice\s*blend|masala|rice|tadka|tempering|paste|chutney|raita|salsa|pickle|gravy|curry\s*base|to\s+serve|serving|assembly|chicken\s+marinade|fried\s+garnish|layering\s+and\s+finishing|optional\s+for\s+serving)\s*:?$/i.test(t);
}

function isMethodStepLine(line) {
  if (!line || isScanNoiseLine(line) || isNutritionOrMetaLine(line)) return false;
  var t = String(line).trim();
  if (!t || /^(ingredients?|method|description|nutrition|feedback)$/i.test(t)) return false;
  if (/^(?:step\s*)?\d+[\.\):\-]\s+\S/i.test(t)) return true;
  if (isMethodSectionHeader(t)) return true;
  if (t.length < 8) return false;
  if (/^(?:so\s+)?ur\s+\w+\s+is\s+ready/i.test(t)) return false;
  if (/^(then|next|finally|meanwhile|check|do\s+the\s+same|both\s+of\s+them|when\s+it\s+starts|in\s+a\s+bowl)\b/i.test(t)) return true;
  if (isMethodAttributionLine(t)) return false;
  if (/\b(soak|wash|boil|fry|roast|heat|add|cook|stir|mix|make|knead|spread|cover|allow|rest|press|roll|dust|turn|fold|separate|mean|crush|drain|remove|strain|saut[eé]|serve|check|sprinkle|place|close|prick|decorate|layer|bring|simmer|bake|transfer|whisk|blend|grind|chop|slice|peel|beat|reduce|season|garnish|dum|parboil|blanch|marinate|grease|toast|brown|puff|split|share|keep\s+aside|set\s+aside|keep\s+that|par-cook|little\s+by\s+little|equal\s+size|puffing)\b/i.test(t)) return true;
  return false;
}

function isLikelyRecipeTitleLine(line) {
  if (!line || line.length > 90 || line.length < 4) return false;
  if (/^ingredients?$/i.test(line) || /^method$/i.test(line)) return false;
  if (isIngredientLikeLine(line) || isIngredientSubHeader(line)) return false;
  var s = splitIngredientLine(line);
  if (s && (s.header || s.qty || s.unit)) return false;
  return true;
}

function isOrphanAltQtyLine(line) {
  return /^\(?\s*or\s+[\d\u00BC-\u00BE\/]/i.test(String(line || '').trim());
}

function isQtyUnitFragment(text) {
  var t = String(text || '').trim();
  if (!t) return false;
  return new RegExp(
    '^' + PARSE_QTY_PAT + '(?:\\s*(?:' + PARSE_UNIT_WORDS + '))?\\s*$', 'i'
  ).test(t);
}

function extractQtyUnitFragment(text) {
  var t = String(text || '').trim();
  var m = t.match(new RegExp(
    '^(' + PARSE_QTY_PAT + ')\\s*\\b(' + PARSE_UNIT_WORDS + ')\\b\\s*(.*)$', 'i'
  ));
  if (!m) return null;
  return {
    qty: normalizeParsedQty(m[1].trim()),
    unit: normalizeParsedUnit(m[2]),
    rest: (m[3] || '').trim()
  };
}

function normalizeIngredientAlias(name) {
  var lc = String(name || '').toLowerCase().trim();
  var map = {
    'soya': 'Soya Chunks', 'soya chunks': 'Soya Chunks',
    'kashmiri chilli powder': 'Kashmiri Chilli Powder', 'kashmiri chilli powde': 'Kashmiri Chilli Powder',
    'chilli powder': 'Chilli Powder', 'turmeric powder': 'Turmeric Powder',
    'lemon juice': 'Lemon Juice', 'ginger garlic paste': 'Ginger Garlic Paste',
    'cornflour': 'Cornflour', 'rice flour': 'Rice Flour',
    'garam masala': 'Garam Masala', 'cumin powder': 'Cumin Powder',
    'green chilli': 'Green Chilli', 'green chillies': 'Green Chilli',
    'curry leaves': 'Curry Leaves', 'coriander leaves': 'Coriander Leaves',
    'chilli sauce': 'Chilli Sauce', 'ketchup': 'Ketchup', 'salt': 'Salt', 'water': 'Water', 'curd': 'Curd',
    'kismis': 'Raisins', 'basmati': 'Basmati Rice', 'all purpose flour': 'All Purpose Flour',
    'wheat flour': 'Wheat Flour', 'rice flour': 'Rice Flour',
    'corn flour': 'Cornflour', 'meal maker': 'Soya Chunks', 'soya nuggets': 'Soya Chunks',
    'lem': 'Lemon Juice', 'ging': 'Ginger Garlic Paste', 'cori': 'Coriander Leaves',
    'gree': 'Green Chilli', 'wate': 'Water',
    'red chilly powder': 'Red Chilli Powder', 'red chilli powder': 'Red Chilli Powder',
    'mint leaves': 'Mint Leaves', 'mint leaves (pudhina)': 'Mint Leaves',
    'small onion': 'Small Onion', 'small onions': 'Small Onion',
    'pepper powder': 'Pepper Powder', 'pepper powder (black)': 'Pepper Powder',
    'basmati rice': 'Basmati Rice', 'pine apple essence': 'Pineapple Essence',
    'pineapple essence': 'Pineapple Essence', 'cashew nuts': 'Cashew Nuts',
    'yellow colour': 'Yellow Food Colour'
  };
  return map[lc] || name;
}

function stripRedundantUnitFromName(name, unit) {
  if (!name || !unit) return (name || '').trim();
  var n = String(name).trim();
  var u = String(unit).trim().toLowerCase();
  var strip = {
    handful: /^handful\s+/i,
    pinch: /^pinch(?:es)?\s+/i,
    tbsp: /^tbsps?\s+/i,
    tsp: /^tsps?\s+/i,
    cup: /^cups?\s+/i,
    drop: /^drops?\s+/i,
    pod: /^pods?\s+/i
  };
  if (strip[u]) return n.replace(strip[u], '').trim();
  return n;
}

function inferIngredientUnit(name, qty) {
  var n = String(name || '').toLowerCase();
  if (/\b(ghee|oil|dalda)\b/.test(n) && !qty) return '';
  if (/\bleaves?\b/.test(n)) return 'leaf';
  if (/\bcloves?\b/.test(n) && !/\bcardamom\b/.test(n) && qty) return 'clove';
  if (/\b(cinnamon|cardamom|egg|onion|chilli|chillies|raisin|cashew|garlic|pineapple)\b/.test(n) && qty && /^\d+$/.test(String(qty).trim())) return 'piece';
  if (/\b(pepper)\b/.test(n) && qty && /^\d+$/.test(String(qty).trim()) && !/powder/.test(n)) return 'piece';
  if (/\bsalt\b/.test(n) && !qty) return 'pinch';
  if (/\bhandful\b/.test(n)) return 'handful';
  return '';
}

function isValidIngredientQtyFragment(s) {
  var t = String(s || '').trim();
  if (!t || /\bless\s+than\b/i.test(t)) return false;
  if (!/^[\d\u00BC-\u00BE\u2150-\u215E\/\.\s]+$/.test(t)) return false;
  return /[\d\u00BC-\u00BE\/]/.test(t);
}

function parseTrailingQtyInName(name, existingNote) {
  var n = normalizeBlogIngredientLine(String(name || '').trim());
  if (!n || /\bless\s+than\b/i.test(n)) return null;
  var dashNote = n.match(new RegExp('^(.+?)\\s+(' + PARSE_QTY_PAT + ')\\s*\\b(' + PARSE_UNIT_WORDS +
    ')\\b\\s*[-–—]\\s*(.+)$', 'i'));
  if (dashNote) {
    return {
      qty: normalizeParsedQty(dashNote[2].trim()),
      unit: normalizeParsedUnit(dashNote[3]),
      name: titleCaseIngredientName(dashNote[1].trim()),
      note: existingNote ? existingNote + '; ' + dashNote[4].trim() : dashNote[4].trim()
    };
  }
  var m = n.match(new RegExp('^(.+?)\\s+(' + PARSE_QTY_PAT + ')\\s*\\b(' + PARSE_UNIT_WORDS + ')\\b\\s*(.*)$', 'i'));
  if (!m || !m[1] || !m[1].trim()) return null;
  var tail = (m[4] || '').trim();
  var note = existingNote || '';
  if (tail) note = note ? note + '; ' + tail : tail;
  return {
    qty: normalizeParsedQty(m[2].trim()),
    unit: normalizeParsedUnit(m[3]),
    name: titleCaseIngredientName(m[1].trim()),
    note: note
  };
}

function reparseEmbeddedIngredientName(item) {
  if (!item || !(item.name || '').trim()) return item || {};
  var trail = parseTrailingQtyInName(item.name, item.note);
  if (trail) return trail;
  var embedded = splitIngredientLine(item.name);
  if (embedded && !embedded.header && (embedded.name || '').trim() && (embedded.qty || embedded.unit)) {
    return {
      qty: embedded.qty || item.qty || '',
      unit: embedded.unit || item.unit || '',
      name: embedded.name,
      note: [item.note, embedded.note].filter(Boolean).join('; ').replace(/^;\s*/, '')
    };
  }
  return item;
}

function isEmbeddedPrefixIngredientName(name) {
  if (parseTrailingQtyInName(name)) return true;
  var s = splitIngredientLine(name);
  return !!(s && !s.header && (s.name || '').trim() && (s.qty || s.unit));
}

function isValidParsedIngredient(item) {
  if (!item || !item.name) return false;
  var n = item.name.trim();
  if (!n || n.length < 2 || ING_JUNK_NAMES.test(n) || isIngredientSubHeader(n)) return false;
  if (isRecipeTitleEchoLine(n)) return false;
  if (isEmbeddedPrefixIngredientName(n)) return false;
  if (isFragmentIngredientName(n)) return false;
  if (isOrphanAltQtyLine(n)) return false;
  if (isQtyUnitFragment(n)) return false;
  if (/^[\d\s\.\/\u00BC-\u00BE\u2150-\u215E\-]+$/.test(n)) return false;
  if (/^[\d\s\.\/\u00BC-\u00BE\u2150-\u215E]+\s*(tsp|tbsp|tbs|cup|cups|g|gm|kg|ml|oz|lb)\s*$/i.test(n)) return false;
  return true;
}

function consolidateParsedItems(items) {
  var list = (items || []).slice();
  var i = 0;
  while (i < list.length) {
    var item = list[i] || {};
    var name = (item.name || '').trim();
    var note = (item.note || '').trim();

    if (!name && /^or\s+/i.test(note)) {
      if (i + 1 < list.length) {
        list[i + 1].note = list[i + 1].note ? list[i + 1].note + '; ' + note : note;
        if (item.qty && !list[i + 1].qty) list[i + 1].qty = item.qty;
        if (item.unit && !list[i + 1].unit) list[i + 1].unit = item.unit;
      } else if (list.length) {
        var prev = list[i - 1];
        if (prev) prev.note = prev.note ? prev.note + '; ' + note : note;
      }
      list.splice(i, 1);
      continue;
    }

    if (name && isQtyUnitFragment(name)) {
      var frag = extractQtyUnitFragment(name);
      if (frag && i + 1 < list.length) {
        var next = list[i + 1];
        if (next.name && !isQtyUnitFragment(next.name) && !next.qty && !next.unit) {
          next.qty = next.qty || frag.qty;
          next.unit = next.unit || frag.unit;
          if (frag.rest) next.note = next.note ? next.note + '; ' + frag.rest : frag.rest;
          else if (item.note) next.note = next.note ? next.note + '; ' + item.note : item.note;
          list.splice(i, 1);
          continue;
        }
      }
      list.splice(i, 1);
      continue;
    }

    if (!name && !item.qty && item.unit && !note) {
      list.splice(i, 1);
      continue;
    }
    if (!name && item.qty && i + 1 < list.length) {
      var nxt = list[i + 1];
      if ((nxt.name || '').trim() && !nxt.qty && !nxt.unit) {
        nxt.qty = nxt.qty || item.qty;
        nxt.unit = nxt.unit || item.unit;
        nxt.note = nxt.note || item.note || note;
        list.splice(i, 1);
        continue;
      }
    }

    if (name && isFragmentIngredientName(name) && i + 1 < list.length) {
      var fragNext = list[i + 1];
      var frag = extractQtyUnitFragment(name);
      if (frag && fragNext && (fragNext.unit || fragNext.qty) && !(fragNext.name || '').trim()) {
        fragNext.qty = fragNext.qty || frag.qty;
        fragNext.unit = fragNext.unit || frag.unit;
        list.splice(i, 1);
        continue;
      }
    }

    i++;
  }

  var out = [];
  list.forEach(function(item) {
    item = reparseEmbeddedIngredientName(item || {});
    var n = (item.name || '').trim();
    if (!n || !isValidParsedIngredient(item)) return;
    if (isOrphanAltQtyLine(n)) {
      if (out.length) {
        out[out.length - 1].note = out[out.length - 1].note
          ? out[out.length - 1].note + '; ' + n.replace(/^\(|\)$/g, '').trim()
          : n.replace(/^\(|\)$/g, '').trim();
      }
      return;
    }
    item.name = normalizeIngredientAlias(titleCaseIngredientName(n))
      .replace(/\s+as\s+reqd$/i, '').replace(/\s+as\s+needed$/i, '')
      .replace(/\s+to\s+taste$/i, '').trim();
    if (!item.unit) item.unit = inferIngredientUnit(item.name, item.qty);
    item.name = stripRedundantUnitFromName(item.name, item.unit);
    out.push(item);
  });
  return out;
}

function mergeOrphanAltOntoItems(items) {
  return consolidateParsedItems(items);
}

function fixMethodContractions(text) {
  return String(text || '')
    .replace(/\bdon\s+t\b/gi, "don't")
    .replace(/\bcan\s+t\b/gi, "can't")
    .replace(/\bwon\s+t\b/gi, "won't")
    .replace(/\bisn\s+t\b/gi, "isn't")
    .replace(/\bI\s+m\b/gi, "I'm")
    .replace(/\byou\s+re\b/gi, "you're")
    .replace(/\bit\s+s\b/gi, "it's");
}

function expandMethodStepText(stepText) {
  var t = fixMethodContractions(String(stepText || '').replace(/^(?:step\s*)?\d+[\.\):\-]\s*/i, '').trim());
  if (!t) return [];
  if (t.length <= 220) return [t];
  if (/\(\s*note\s*:/i.test(t)) return [t];
  var parts = t.split(/(?<=[.!?])\s+(?=[A-Z"'(])/);
  parts = parts.map(function(p) { return p.trim(); }).filter(function(p) { return p.length > 12; });
  return parts.length > 1 ? parts : [t];
}

function expandLongMethodSteps(steps) {
  var out = [];
  (steps || []).forEach(function(step) {
    expandMethodStepText(step).forEach(function(s) { out.push(s); });
  });
  return out;
}

function normalizeStuckBlogQty(line) {
  return String(line || '').replace(/-\s*1(\d\/\d)/g, '- 1 $1');
}

function normalizeBlogIngredientLine(line) {
  line = String(line || '').trim();
  line = line.replace(/[–—]/g, '-');
  line = normalizeStuckBlogQty(line);
  line = line.replace(/(\d)(tbsp|tbs|tsp|kg|gm|g|ml|l|cups?|pods|nos|drops)\b/gi, '$1 $2');
  line = line.replace(/([\d\u00BC-\u00BE\u2150-\u215E\/\.]+(?:\s+[\d\u00BC-\u00BE\u2150-\u215E\/\.]+)?)(kg|gm|g|ml|l|tbsp|tbs|tsp|cups?|pods|nos|drops)\b/gi, '$1 $2');
  line = line.replace(/(frying|chopped|sliced|medium|black|reqd)(\()/gi, '$1 $2');
  line = line.replace(/piece\(/gi, 'piece (');
  line = line.replace(/(kg|g|tsp|tbsp|tbs|cups?|nos|pods?)\(([^)]+)\)/gi, '$1 ($2)');
  line = line.replace(/\bone\s+pinch\b/gi, '1 pinch');
  line = line.replace(/\bas\s+reqd\b/gi, 'as needed');
  line = line.replace(/([a-z])(big|small)\s+piece/gi, '$1 - $2 piece');
  line = line.replace(/([a-z])-(big|small)\s+piece/gi, '$1 - $2 piece');
  line = line.replace(/(colour|color)-one\s+pinch/gi, '$1 - one pinch');
  return line.replace(/\s+/g, ' ').trim();
}

function splitIngredientLine(line) {
  if (!line) return null;
  line = String(line).trim();
  if (!line) return null;
  line = line.replace(/^[-•*]\s+/, '').replace(/\s*[–—]\s*/g, ' - ');
  line = line.replace(/[\s\-–—]+$/,'').trim();
  if (!line) return null;
  line = normalizeBlogIngredientLine(line);
  if (isIngredientSubHeader(line)) return { header: true, name: line.replace(/\s*:?\s*$/, '') };

  var note = '';
  if (/\s+plus\s*$/i.test(line)) {
    note = 'extra as needed';
    line = line.replace(/\s+plus\s*$/i, '').trim();
  }

  var akaQty = line.match(/^(.+?)\(([^)]+)\)\s*-\s*(\d+)\s*$/);
  if (akaQty) {
    return {
      qty: akaQty[3],
      unit: '',
      name: titleCaseIngredientName(akaQty[1].trim()),
      note: note ? note + '; ' + akaQty[2].trim() : akaQty[2].trim()
    };
  }

  var orParen = line.match(/^(.+?)\s*\(\s*or\s+([^)]+)\)\s*$/i);
  if (orParen) {
    line = orParen[1].trim();
    note = 'or ' + orParen[2].trim();
  } else {
    var prepParen = line.match(new RegExp('^(.+?)\\s*\\((' + PARSE_PREP_NOTE_WORDS + ')\\)\\s*$', 'i'));
    if (prepParen) {
      line = prepParen[1].trim();
      note = note ? note + '; ' + prepParen[2].trim() : prepParen[2].trim();
    } else {
      var parenNote = line.match(/^(.+?)\s*\(([^)]+)\)\s*$/);
      if (parenNote && parenNote[2].length < 80 && !/\bfor\s+/i.test(parenNote[2])) {
        line = parenNote[1].trim();
        note = note ? note + '; ' + parenNote[2].trim() : parenNote[2].trim();
      }
    }
  }
  var altQty = line.match(/\s+or\s+(\d[\d\s\/\.\u00BC-\u00BE]*\s*(?:g|gm|kg|ml|cup|cups|oz|lb)\b.*)$/i);
  if (altQty) {
    note = note ? note + '; or ' + altQty[1].trim() : 'or ' + altQty[1].trim();
    line = line.replace(altQty[0], '').trim();
  }
  var commaNote = line.match(/^(.+?),\s*(.{3,})$/);
  if (commaNote && commaNote[2].length < 100 && !/^(and|or)\s/i.test(commaNote[1])) {
    line = commaNote[1].trim();
    var cNote = commaNote[2].trim();
    if (/^plus$/i.test(cNote)) note = note || 'extra as needed';
    else note = note ? note + '; ' + cNote : cNote;
  }

  // Blog suffix: "Name - 1/2 tsp" or "Name -11/2tsp" (normalizeStuckBlogQty fixes -11/2 → - 1 1/2)
  var doubled = line.match(new RegExp('^(.+?)\\s*-\\s*1(\\d\\/\\d)(' + PARSE_UNIT_WORDS + ')\\b\\s*(.*)$', 'i'));
  if (doubled) {
    var extra2 = (doubled[4] || '').trim();
    if (extra2) note = note ? note + '; ' + extra2 : extra2;
    return {
      qty: '1 ' + doubled[2],
      unit: normalizeParsedUnit(doubled[3]),
      name: titleCaseIngredientName(doubled[1].trim()),
      note: note
    };
  }

  var lessThanQty = line.match(new RegExp('^(.+?)\\s*-\\s*less\\s+than\\s+(' + PARSE_QTY_PAT + ')\\s*(' + PARSE_UNIT_WORDS + ')?\\b\\s*(.*)$', 'i'));
  if (lessThanQty) {
    var ltExtra = (lessThanQty[4] || '').trim();
    var ltNote = 'less than ' + lessThanQty[2].trim() + (lessThanQty[3] ? ' ' + normalizeParsedUnit(lessThanQty[3]) : '');
    if (ltExtra) ltNote += '; ' + ltExtra;
    note = note ? note + '; ' + ltNote : ltNote;
    return {
      qty: '', unit: '',
      name: titleCaseIngredientName(lessThanQty[1].trim()),
      note: note
    };
  }

  var forUse = line.match(/^(.+?)\s*-\s*for\s+([a-z][\w\s]{2,40})\s*$/i);
  if (forUse) {
    note = note ? note + '; for ' + forUse[2].trim() : 'for ' + forUse[2].trim();
    return {
      qty: '', unit: '',
      name: titleCaseIngredientName(forUse[1].trim()),
      note: note
    };
  }

  var colonLine = line.match(new RegExp('^(.+?)\\s*:\\s*([\\d\\u00BC-\\u00BE\\u2150-\\u215E\\/\\.\\s]+)\\s*(' + PARSE_UNIT_WORDS + ')?\\b\\s*(.*)$', 'i'));
  if (colonLine && isValidIngredientQtyFragment(colonLine[2])) {
    var colExtra = (colonLine[4] || '').trim();
    if (colExtra) note = note ? note + '; ' + colExtra : colExtra;
    return {
      qty: normalizeParsedQty(colonLine[2].trim()),
      unit: normalizeParsedUnit(colonLine[3] || ''),
      name: titleCaseIngredientName(colonLine[1].trim()),
      note: note
    };
  }

  var stuck = line.match(new RegExp('^(.+?)\\s*-\\s*([\\d\\u00BC-\\u00BE\\u2150-\\u215E\\/\\.\\s]+)(' + PARSE_UNIT_WORDS + ')\\b\\s*(.*)$', 'i'));
  if (stuck && isValidIngredientQtyFragment(stuck[2])) {
    var extra = (stuck[4] || '').trim();
    if (extra) note = note ? note + '; ' + extra : extra;
    return {
      qty: normalizeParsedQty(stuck[2].trim()),
      unit: normalizeParsedUnit(stuck[3]),
      name: titleCaseIngredientName(stuck[1].trim()),
      note: note
    };
  }

  var blog = line.match(new RegExp('^(.+?)\\s*-\\s*([\\d\\u00BC-\\u00BE\\u2150-\\u215E\\/\\.\\s]+)\\s*(' + PARSE_UNIT_WORDS + ')?\\b\\s*(.*)$', 'i'));
  if (blog && isValidIngredientQtyFragment(blog[2])) {
    var extra3 = (blog[4] || '').trim();
    if (extra3) note = note ? note + '; ' + extra3 : extra3;
    return {
      qty: normalizeParsedQty(blog[2].trim()),
      unit: normalizeParsedUnit(blog[3] || ''),
      name: titleCaseIngredientName(blog[1].trim()),
      note: note
    };
  }

  var tasteOnly = line.match(/^(.+?)\s*-\s*(as\s+needed|as\s+reqd|to\s+taste)\s*$/i);
  if (tasteOnly) {
    return {
      qty: '', unit: 'pinch',
      name: titleCaseIngredientName(tasteOnly[1].trim()),
      note: note || 'to taste'
    };
  }

  var wordPinch = line.match(/^(.+?)\s*-\s*one\s+pinch\s*$/i);
  if (wordPinch) {
    return { qty: '1', unit: 'pinch', name: titleCaseIngredientName(wordPinch[1].trim()), note: note };
  }

  var handfulLine = line.match(/^(.+?)\s*-\s*handful\s*$/i);
  if (handfulLine) {
    return { qty: '', unit: 'handful', name: titleCaseIngredientName(handfulLine[1].trim()), note: note };
  }

  var sizePiece = line.match(/^(.+?)\s*-\s*(big|small)\s+piece(?:\s*\(([^)]+)\))?\s*$/i);
  if (sizePiece) {
    var spNote = sizePiece[2].toLowerCase() + ' piece';
    if (sizePiece[3]) spNote += '; ' + sizePiece[3].trim();
    note = note ? note + '; ' + spNote : spNote;
    return { qty: '1', unit: 'piece', name: titleCaseIngredientName(sizePiece[1].trim()), note: note };
  }

  var nosQty = line.match(/^(.+?)\s*-\s*(\d+)\s+nos(?:\s+for\s+frying)?\s*(.*)$/i);
  if (nosQty) {
    var nosExtra = (nosQty[3] || '').replace(/^\(|\)$/g, '').trim();
    if (nosExtra) note = note ? note + '; ' + nosExtra : nosExtra;
    if (/for\s+frying/i.test(line)) note = note ? note + '; for frying' : 'for frying';
    return {
      qty: nosQty[2],
      unit: 'piece',
      name: titleCaseIngredientName(nosQty[1].trim()),
      note: note
    };
  }

  var trailInLine = parseTrailingQtyInName(line, note);
  if (trailInLine) return trailInLine;

  // Standard prefix: "1/2 tsp salt" or qty+unit only "1 1/2 cup"
  var prefixRe = new RegExp('^(' + PARSE_QTY_PAT + ')\\s*\\b(' + PARSE_UNIT_WORDS + ')\\b(?:\\s+(.+))?$', 'i');
  var prefix = prefixRe.exec(line);
  if (prefix) {
    var restName = (prefix[3] || '').trim();
    return {
      qty: normalizeParsedQty(prefix[1].trim()),
      unit: normalizeParsedUnit(prefix[2]),
      name: restName ? titleCaseIngredientName(restName) : '',
      note: note
    };
  }

  var countName = line.match(/^(\d+)\s+([A-Za-z][\w\s'()-]+)$/);
  if (countName && countName[2] && !/^(tsp|tbsp|tbs|cup|cups|g|gm|kg|ml|oz|lb)\b/i.test(countName[2])) {
    return {
      qty: countName[1],
      unit: '',
      name: titleCaseIngredientName(countName[2].trim()),
      note: note
    };
  }

  var countOnly = line.match(/^(.+?)\s*-\s*(\d+)\s*$/);
  if (countOnly) {
    return {
      qty: countOnly[2],
      unit: '',
      name: titleCaseIngredientName(countOnly[1].trim()),
      note: note
    };
  }

  var qtyOnly = line.match(/^(.+?)\s*-\s*([\d\u00BC-\u00BE\u2150-\u215E\/\.]+)\s*$/);
  if (qtyOnly) {
    return {
      qty: normalizeParsedQty(qtyOnly[2].trim()),
      unit: '',
      name: titleCaseIngredientName(qtyOnly[1].trim()),
      note: note
    };
  }

  var nameColonOnly = line.match(/^(.+?)\s*:\s*$/);
  if (nameColonOnly && nameColonOnly[1].length > 1 && nameColonOnly[1].length < 80) {
    return { qty: '', unit: '', name: titleCaseIngredientName(nameColonOnly[1].trim()), note: note };
  }

  var bare = line.replace(/[\s\-–—]+$/,'').trim();
  if (bare && /^[a-zA-Z]/.test(bare) && bare.length < 80 && !ING_JUNK_NAMES.test(bare)) {
    return { qty: '', unit: '', name: titleCaseIngredientName(bare), note: note };
  }
  return null;
}

function isFragmentIngredientName(name) {
  var n = String(name || '').trim();
  if (!n) return false;
  if (/^[\d\u00BC-\u00BE\u2150-\u215E\/\.]+\s*(?:t|ts|tb|c|cu|cup|g|gm)?$/i.test(n)) return true;
  if (/^\d+\s*\/\s*\d+\s*[A-Za-z]{1,3}$/.test(n)) return true;
  if (/^[A-Za-z]{1,4}$/.test(n) && /^(lem|ging|cori|gree|wate|corn|turm|cum|chill)$/i.test(n)) return true;
  return false;
}

function formatIngredientNoteForPaste(note) {
  if (!note) return '';
  if (/^plus$/i.test(note)) return 'extra as needed';
  if (/^or\s+/i.test(note)) return note;
  return note;
}

function formatScannedIngredientLine(line) {
  if (isIngredientSubHeader(line)) return line.replace(/\s+/g, ' ').trim();
  var split = splitIngredientLine(line);
  if (split && split.header) return split.name;
  if (split && split.name) {
    var parts = [split.qty, split.unit, split.name].filter(Boolean);
    var base = parts.join(' ');
    if (!split.note) return base;
    var note = formatIngredientNoteForPaste(split.note);
    if (/^or\s+/i.test(note)) return base + ' (' + note + ')';
    if (note === 'extra as needed') return base;
    return base + ' — ' + note;
  }
  return titleCaseIngredientName(line.replace(/[\s\u2013\u2014\-]+$/,'').replace(/\s*-\s*$/,'').trim());
}

function normalizeMethodSteps(steps) {
  var out = [];
  var marker = /\s*(?:(?:method|step)\s+\d+\s+of\s+\d+)\s*/gi;
  (steps || []).forEach(function(step) {
    step.split(marker).forEach(function(part) {
      var cleaned = part.replace(/\s+\d+\s*\/\s*\d+\s*$/,'').replace(/\s+/g, ' ').trim();
      if (cleaned && cleaned.length > 4) out.push(cleaned);
    });
  });
  return out;
}

function isIngredientLikeLine(line) {
  if (isScanNoiseLine(line) || isNutritionOrMetaLine(line)) return false;
  if (isStepHeaderLine(line)) return false;
  if (/^(?:step\s*)?\d+[\.\):\-]\s+\S/i.test(line)) return false;
  if (/^\d+\s+ingredients?$/i.test(line)) return false;
  if (/^(ingredients?|method|description|nutrition|feedback)$/i.test(line)) return false;
  if (/^\d+[\d\s\/\.\u00BC-\u00BE-]*(g|kg|ml|l|oz|lb|tsp|tbsp|tbs|cup|cups)\b/i.test(line)) return true;
  if (/^[\d\u00BC-\u00BE\/]+\s*(cup|cups|tsp|tbsp|tbs|g|kg|ml|bunch|piece|clove|slice)\b/i.test(line)) return true;
  if (/^\d+\s*(tsp|tbsp|tbs|cup|cups|g|kg|ml|oz|lb|pinch)\b/i.test(line)) return true;
  if (/^[\-\u2013\u2014•]\s*\d/.test(line)) return true;
  if (/^[\w\s.'()-]+[-–—]\s*[\d\u00BC-\u00BE\/]/i.test(line)) return true;
  if (/^[\w\s.'()-]+\s+[\d\u00BC-\u00BE\/]/i.test(line)) return true;
  if (splitIngredientLine(line)) return true;
  return false;
}

function isBareIngredientLine(line) {
  if (!line || isScanNoiseLine(line) || isNutritionOrMetaLine(line)) return false;
  if (isIngredientSubHeader(line) || isStepHeaderLine(line) || detectScanSection(line)) return false;
  var cleaned = line.replace(/[\s\u2013\u2014\-]+$/,'').replace(/\s*-\s*$/,'').trim();
  if (!cleaned || cleaned.length < 3 || cleaned.length > 95) return false;
  if (!/^[a-zA-Z]/.test(cleaned) || /[.!?]/.test(cleaned)) return false;
  if (isIngredientLikeLine(cleaned) || isMethodLikeLine(cleaned)) return false;
  if (cleaned.split(/\s+/).length > 6) return false;
  if (/\b(soak|wash|heat|add|cook|stir|mix|make|take|close|keep|fry|boil|saute|serve|cut|squeeze|prefer|usually|minimum)\b/i.test(cleaned)) return false;
  return /^[a-zA-Z][\w\s'()-]*$/i.test(cleaned);
}

function isIngredientContinuation(line) {
  if (!line || isScanNoiseLine(line) || isNutritionOrMetaLine(line)) return false;
  if (isIngredientLikeLine(line) || isStepHeaderLine(line) || isMethodLikeLine(line)) return false;
  if (isIngredientQtyOnlyLine(line)) return true;
  return line.length > 1 && line.length < 50 && /^[a-z(]/.test(line);
}

function isMethodLikeLine(line) {
  if (isMethodStepLine(line)) return true;
  if (isScanNoiseLine(line) || isNutritionOrMetaLine(line)) return false;
  if (isStepHeaderLine(line)) return true;
  if (/^(?:step\s*)?\d+[\.\):\-]\s+\S/i.test(line)) return true;
  if (line.length < 8 || line.length > 400) return false;
  if (/\b(heat|add|cook|stir|bake|serve|mix|make|knead|spread|cover|allow|rest|press|roll|dust|turn|fold|separate|combine|pour|place|remove|transfer|season|bring|simmer|boil|fry|grill|roast|whisk|drain|cool|chop|slice|preheat|microwave|soak|crush|strain|saut[eé]|check|sprinkle|prick|decorate|layer|dum|grease|puff|split|share)\b/i.test(line)) return true;
  if (/^(?:do\s+the\s+same|both\s+of\s+them|when\s+it\s+starts|in\s+a\s+bowl)\b/i.test(line)) return true;
  return false;
}

function cleanScanContentLine(line, section) {
  var s = stripScanLine(line);
  if (!s) return '';
  if (section !== 'notes' && section !== 'tips' && isScanNoiseLine(s)) return '';
  s = s.replace(/\s{2,}/g, ' ');
  s = s.replace(/(\d)\s+\/\s+(\d)/g, '$1/$2');
  s = s.replace(/^(\d+)\s*\.\s*(\d+)/, '$1.$2');
  if (section === 'ing') s = normalizeBlogIngredientLine(s);
  if (section === 'meth') {
    s = s.replace(/^(step\s*)(\d+)\s*[\.\):\-]\s*/i, '$1$2. ');
    s = s.replace(/\bdon\s+t\b/gi, "don't")
      .replace(/\bcan\s+t\b/gi, "can't")
      .replace(/\bwon\s+t\b/gi, "won't")
      .replace(/\bisn\s+t\b/gi, "isn't")
      .replace(/\bI\s+m\b/gi, "I'm")
      .replace(/\byou\s+re\b/gi, "you're")
      .replace(/\bit\s+s\b/gi, "it's");
  }
  if (section === 'serves') {
    s = s.replace(/^(?:serves?|servings?|yield)\s*:?\s*/i, '').trim();
  }
  return s;
}

function detectScanSection(line) {
  if (/^\d+\s+ingredients?$/i.test(line)) return 'ing';
  if (/^(ingredients?|what you(?:'ll| will) need|you will need)\s*:\s*$/i.test(line)) return 'ing';
  if (/^ingredients?\s*:\s*$/i.test(line)) return 'ing';
  if (/^(prep\s+work|directions?|method|steps?|instructions?|procedure|how\s+to(?:\s+make|\s+cook)?)\s*:?$/i.test(line)) return 'meth';
  if (/^how\s+to\s+make\b/i.test(line) && /:\s*$/.test(line)) return 'meth';
  if (/^(serves?|servings?|yield)\s*:?$/i.test(line)) return 'serves';
  if (/^(?:serves?|servings?|yield)\s*:?\s*[\d\u00BC\-]/i.test(line)) return 'serves';
  if (/^(notes?|cooking\s+notes?|notes?\s*&\s*tips?)\s*:?$/i.test(line)) return 'notes';
  if (/^(tips?|hints?|tricks?|variations?|tips?\s*&\s*notes?)\s*:?$/i.test(line)) return 'tips';
  if (isNutritionOrMetaLine(line)) return 'junk';
  if (/^(copyright|chef|author|photograph|photo\s+by|recipe\s+by|description|feedback)\s*:?$/i.test(line)) return 'junk';
  if (/^(prep\s*time|cook\s*time|total\s*time|storage|garnish)\s*:?$/i.test(line)) return 'junk';
  return null;
}

function expandBundledIngredientLine(line) {
  var trimmed = String(line || '').trim();
  if (!trimmed) return [];
  var parts = trimmed.match(/\b[A-Za-z][A-Za-z\s.'()-]{0,40}?-\d[\d\u00BC-\u00BE\/\.]*(?:\s*(?:tsp|tbsp|tbs|kg|g|nos?|pods?|drops?|handful))?\b/gi);
  if (parts && parts.length > 1) return parts.map(function(p) { return p.trim(); });
  return [trimmed];
}

function collectIngredients(lines, startIdx, endIdx, title) {
  var ings = [];
  var current = '';
  for (var i = startIdx; i < endIdx; i++) {
    var ln = lines[i];
    if (isNutritionOrMetaLine(ln) || detectScanSection(ln) === 'junk') break;
    if (/^method$/i.test(ln) || /^description$/i.test(ln)) break;
    if (title && (ln === title || isRecipeTitleEchoLine(ln, title))) continue;
    if (isRecipeTitleEchoLine(ln, title)) continue;
    if (isIngredientSubHeader(ln)) {
      if (current) ings.push(cleanScanContentLine(current, 'ing'));
      current = '';
      ings.push(ln.replace(/\s+/g, ' ').trim());
      continue;
    }
    if (isIngredientLikeLine(ln)) {
      if (current) ings.push(cleanScanContentLine(current, 'ing'));
      var bundled = expandBundledIngredientLine(ln);
      if (bundled.length > 1) {
        current = '';
        bundled.forEach(function(part) { ings.push(cleanScanContentLine(part, 'ing')); });
      } else {
        current = ln;
      }
    } else if (isBareIngredientLine(ln)) {
      if (current) ings.push(cleanScanContentLine(current, 'ing'));
      current = '';
      expandBundledIngredientLine(ln).forEach(function(part) {
        ings.push(part.replace(/[\s\u2013\u2014\-]+$/,'').replace(/\s*-\s*$/,'').trim());
      });
    } else if (current && isIngredientContinuation(ln)) {
      current += ' ' + ln;
    } else if (current) {
      ings.push(cleanScanContentLine(current, 'ing'));
      current = '';
    }
  }
  if (current) ings.push(cleanScanContentLine(current, 'ing'));
  return ings.filter(Boolean);
}

function collectMethodSteps(lines, startIdx, endIdx, noteOut) {
  var steps = [];
  for (var i = startIdx; i < endIdx; i++) {
    var ln = cleanScanContentLine(lines[i], 'meth');
    if (!ln) continue;
    if (isNutritionOrMetaLine(ln) || isScanNoiseLine(ln)) break;
    if (detectScanSection(ln) === 'junk' || /^ingredients?$/i.test(ln)) break;
    if (/^(?:so\s+)?ur\s+\w+\s+is\s+ready/i.test(ln)) continue;
    if (isMethodAttributionLine(ln) || isRecipeTipOrNoteLine(ln)) {
      if (noteOut) pushAuxLine(noteOut, ln);
      continue;
    }
    if (detectScanSection(ln) === 'notes' || detectScanSection(ln) === 'tips') {
      continue;
    }
    if (/^(?:serves?|servings?|yield)\s*:?\s*[\d\u00BC]/i.test(ln)) {
      if (noteOut) noteOut.serves.push(ln.replace(/^(?:serves?|servings?|yield)\s*:?\s*/i, '').trim());
      continue;
    }
    if (/^serve\s+(hot|with|warm)/i.test(ln) && ln.length < 100) {
      if (noteOut) pushAuxLine(noteOut, ln);
      continue;
    }
    if (isMethodStepLine(ln)) {
      var st = ln.replace(/^(?:step|method)\s+\d+\s+of\s+\d+\s*/i, '').replace(/\s*:?\s*$/, '').trim();
      if (st && !isJunkMethodStep(st)) steps.push(st);
      continue;
    }
    if (isIngredientLikeLine(ln) && !isMethodLikeLine(ln)) continue;
    if (isStepHeaderLine(ln)) {
      var st2 = ln.replace(/^(?:step|method)\s+\d+\s+of\s+\d+\s*/i, '').trim();
      if (st2 && !isJunkMethodStep(st2)) steps.push(st2);
      continue;
    }
    if (ln.length >= 8 && !isJunkMethodStep(ln)) steps.push(ln);
  }
  return expandLongMethodSteps(normalizeMethodSteps(steps.filter(function(s) { return s && !isJunkMethodStep(s); })));
}

function collectPostRecipeSections(lines, startIdx) {
  var out = createAuxCollector();
  var current = null;
  for (var i = startIdx; i < lines.length; i++) {
    var ln = stripScanLine(lines[i]);
    if (!ln) continue;
    if (isScanNoiseLine(ln) || /^(?:love|loading|leave a reply|trending|subscribe|follow my)\b/i.test(ln)) break;
    var hdr = detectScanSection(ln);
    if (hdr === 'notes' || hdr === 'tips' || hdr === 'serves') {
      current = hdr;
      var inline = ln.replace(/^(?:notes?|cooking\s+notes?|tips?|hints?|serves?|servings?|yield|notes?\s*&\s*tips?)\s*:?\s*/i, '').trim();
      if (inline) {
        if (hdr === 'serves' && /\d/.test(inline)) out.serves.push(inline);
        else if (hdr === 'notes') out.notes.push(inline);
        else if (hdr === 'tips') out.tips.push(inline);
      }
      continue;
    }
    if (hdr === 'ing' || hdr === 'meth') break;
    if (hdr === 'junk') { current = null; continue; }
    if (isRecipeTipOrNoteLine(ln)) {
      pushAuxLine(out, ln);
      continue;
    }
    if (current === 'notes') {
      var cn = cleanScanContentLine(ln, 'notes');
      if (cn) out.notes.push(cn);
    } else if (current === 'tips') {
      var ct = cleanScanContentLine(ln, 'notes');
      if (ct) out.tips.push(ct);
    } else if (current === 'serves') {
      var cs = cleanScanContentLine(ln, 'serves');
      if (cs) out.serves.push(cs);
    }
  }
  return out;
}

function extractByLayout(lines) {
  var ingStart = -1, methStart = -1, ingEnd = -1, methEnd = lines.length;
  var title = '';

  for (var i = 0; i < lines.length; i++) {
    var ln = lines[i];
    var hdr = detectScanSection(ln);
    if (!title && i < 3 && isLikelyRecipeTitleLine(ln)) {
      title = ln.replace(/^recipe\s*:\s*/i, '').trim();
    }
    if (ingStart < 0 && hdr === 'ing') ingStart = /^\d+\s+ingredients?$/i.test(ln) ? i + 1 : i + 1;
    if (methStart < 0 && hdr === 'meth') methStart = i + 1;
    if (ingStart >= 0 && ingEnd < 0 && methStart < 0 && (hdr === 'junk' || isNutritionOrMetaLine(ln) || /^description$/i.test(ln))) ingEnd = i;
    if (methStart >= 0 && (hdr === 'junk' || isNutritionOrMetaLine(ln) || /quantities above are a guide/i.test(ln))) {
      methEnd = i;
      break;
    }
  }

  if (ingStart < 0) {
    for (var j = 0; j < lines.length; j++) {
      if (isIngredientLikeLine(lines[j])) {
        ingStart = j;
        break;
      }
    }
    if (ingStart >= 0) {
      for (var k = ingStart; k < lines.length; k++) {
        if (methStart >= 0 && k >= methStart) { ingEnd = methStart; break; }
        if (isNutritionOrMetaLine(lines[k]) || /^method$/i.test(lines[k]) || /^description$/i.test(lines[k])) {
          ingEnd = k;
          break;
        }
      }
      if (ingEnd < 0 && methStart >= 0) ingEnd = methStart;
    }
  }

  var ingLines = [];
  if (ingStart >= 0) {
    var end = ingEnd >= 0 ? ingEnd : (methStart >= 0 ? methStart : lines.length);
    ingLines = collectIngredients(lines, ingStart, end, title);
  }

  var methLines = [];
  var aux = createAuxCollector();
  if (methStart >= 0) {
    methLines = collectMethodSteps(lines, methStart, methEnd, aux);
    aux = mergeAuxSections(aux, collectPostRecipeSections(lines, methEnd));
  }

  return { title: title, ingLines: ingLines, methLines: methLines, aux: aux };
}

function parseServesNumber(servesLines) {
  var joined = (servesLines || []).join(' ');
  var m = joined.match(/(\d+)/);
  return m ? m[1] : '';
}

function parseBlogMetaFromLines(lines) {
  var meta = { prep: null, cook: null, servings: null, warnings: [] };
  (lines || []).forEach(function(ln) {
    var prep = String(ln || '').match(/preparation\s+time\s*:\s*(\d+)\s*(?:mins?|minutes?)?/i);
    if (prep) meta.prep = prep[1];
    var cook = String(ln || '').match(/cooking\s+time\s*:\s*(\d+)(?:\s*-\s*(\d+))?\s*(?:mins?|minutes?)?/i);
    if (cook) meta.cook = cook[2] ? String(Math.round((parseInt(cook[1], 10) + parseInt(cook[2], 10)) / 2)) : cook[1];
    var serv = String(ln || '').match(/(?:serves?|servings?|yield)\s*:\s*(\d+)/i);
    if (serv) meta.servings = serv[1];
  });
  return meta;
}

function applyBlogMetaToForm(meta) {
  if (!meta) return;
  if (meta.prep) setFormNumberIfEmpty('prep-time', meta.prep);
  if (meta.cook) setFormNumberIfEmpty('cook-time', meta.cook);
  if (meta.servings) setFormNumberIfEmpty('servings', meta.servings);
}

/** Structure import text via shared RecipeImportCore pipeline (single path, no partial fallbacks). */
function extractRecipeCore(text) {
  var core = (typeof RecipeImportCore !== 'undefined' ? RecipeImportCore : null);
  if (core && typeof core.segmentRecipeImportText === 'function') {
    var seg = core.segmentRecipeImportText(text);
    return {
      title: seg.title,
      pasteText: seg.normalizedText,
      ingCount: seg.ingCount,
      methCount: seg.methCount,
      notes: seg.notes.slice(),
      tips: seg.tips.slice(),
      serves: seg.serves.slice(),
      warnings: (seg.warnings || []).slice(),
      extraCount: seg.serves.length + seg.notes.length + seg.tips.length,
      hasContent: seg.hasContent,
      segment: seg
    };
  }
  var normalized = preprocessRecipeText(text);
  return {
    title: '',
    pasteText: normalized,
    ingCount: 0,
    methCount: 0,
    notes: [],
    tips: [],
    serves: [],
    warnings: ['Import core module not loaded'],
    extraCount: 0,
    hasContent: normalized.length > 40
  };
}

async function applyScanResult(rawText, statusSuffix) {
  showScanStatus('Cleaning up text…', null);
  var cleaned = await cleanupOcrText(rawText);
  showScanStatus('Structuring recipe sections…', null);
  var extracted = extractRecipeCore(cleaned);
  var pasteEl = document.getElementById('paste-input');
  var parseRes = document.getElementById('parse-result');
  if (parseRes) parseRes.style.display = 'none';

  var finalText = extracted.hasContent ? extracted.pasteText : cleaned;
  if (pasteEl) pasteEl.value = finalText;

  if (extracted.title && isLikelyRecipeTitleLine(extracted.title)) {
    var nameEl = document.getElementById('recipe-name');
    if (nameEl && !nameEl.value.trim()) nameEl.value = extracted.title;
  }

  var srcScanned = document.getElementById('src-scanned');
  if (srcScanned) srcScanned.checked = true;

  populateAuxiliaryFromSections({
    notes: extracted.notes || [],
    tips: extracted.tips || [],
    serves: extracted.serves || []
  });

  if (typeof TcjImportAudit !== 'undefined') {
    TcjImportAudit.recordScanImport({
      parserVersion: PARSER_VERSION,
      pasteText: finalText,
      rawText: rawText,
      path: 'photo-scan',
      warnings: (extracted.warnings || []).slice()
    });
  }

  if (extracted.hasContent) {
    var extraMsg = extracted.extraCount ? ' (+ serves/notes/tips)' : '';
    showScanStatus(
      'Cleaned ' + extracted.ingCount + ' ingredient' + (extracted.ingCount === 1 ? '' : 's') +
      ' and ' + extracted.methCount + ' step' + (extracted.methCount === 1 ? '' : 's') +
      extraMsg + (statusSuffix || '') + ' — parsing now. Review and correct anything that looks wrong.',
      true
    );
    document.getElementById('parse-tips').style.display = 'block';
    setTimeout(function() { if (typeof parseRecipe === 'function') parseRecipe(); }, 300);
  } else {
    showScanStatus('Could not structure recipe sections — cleaned text pasted. Add headings or edit, then click Parse Recipe.' + (statusSuffix || ''), false);
    if (pasteEl) pasteEl.value = cleaned;
    document.getElementById('parse-tips').style.display = 'block';
  }
}

function tesseractLogger(prefix) {
  return function(m) {
    if (m.status === 'recognizing text' && m.progress) {
      showScanStatus(prefix + '… ' + Math.round(m.progress * 100) + '%', null);
    }
  };
}

async function ocrFromSource(source, statusPrefix) {
  var result = await Tesseract.recognize(source, 'eng', { logger: tesseractLogger(statusPrefix) });
  return (result && result.data && result.data.text) ? result.data.text.trim() : '';
}

function pdfItemsToLines(items, yTolerance) {
  var tol = yTolerance || 3;
  var lines = {};
  items.forEach(function(item) {
    var y = Math.round(item.transform[5] / tol) * tol;
    if (!lines[y]) lines[y] = [];
    lines[y].push({ x: item.transform[4], str: item.str });
  });
  return Object.keys(lines).sort(function(a, b) { return Number(b) - Number(a); }).map(function(y) {
    return lines[y].sort(function(a, b) { return a.x - b.x; }).map(function(it) { return it.str; }).join(' ');
  });
}

async function extractPdfPageText(page) {
  var content = await page.getTextContent();
  var items = (content.items || []).filter(function(it) { return it.str && it.str.trim(); });
  if (!items.length) return '';

  var viewport = page.getViewport({ scale: 1 });
  var midX = viewport.width * 0.44;
  var leftItems = items.filter(function(it) { return it.transform[4] < midX; });
  var rightItems = items.filter(function(it) { return it.transform[4] >= midX; });

  if (leftItems.length > 8 && rightItems.length > 8) {
    var leftLines = pdfItemsToLines(leftItems);
    var rightLines = pdfItemsToLines(rightItems);
    return leftLines.join('\n') + '\n' + rightLines.join('\n');
  }

  return pdfItemsToLines(items).join('\n');
}

async function scanRecipePdf(file) {
  var pdfjs = window.pdfjsLib;
  if (!pdfjs) {
    showScanStatus('PDF library still loading — try again in a moment.', false);
    return;
  }
  pdfjs.GlobalWorkerOptions.workerSrc = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';
  showScanStatus('Opening PDF…', null);
  var buf = await file.arrayBuffer();
  var pdf = await pdfjs.getDocument({ data: buf }).promise;
  var maxPages = Math.min(pdf.numPages, 8);
  var allText = '';
  var usedOcr = false;

  for (var p = 1; p <= maxPages; p++) {
    showScanStatus('Reading PDF page ' + p + ' of ' + maxPages + '…', null);
    var page = await pdf.getPage(p);
    var pageText = await extractPdfPageText(page);
    if (pageText && pageText.replace(/\s/g, '').length > 80) {
      allText += pageText + '\n\n';
      continue;
    }
    usedOcr = true;
    var viewport = page.getViewport({ scale: 2 });
    var canvas = document.createElement('canvas');
    canvas.width = viewport.width;
    canvas.height = viewport.height;
    await page.render({ canvasContext: canvas.getContext('2d'), viewport: viewport }).promise;
    var ocrText = await ocrFromSource(canvas, 'OCR page ' + p);
    if (ocrText) allText += ocrText + '\n\n';
  }

  if (!allText.trim()) {
    showScanStatus('No text detected in PDF — try a clearer scan or paste manually.', false);
    return;
  }
  var suffix = ' from ' + maxPages + ' PDF page' + (maxPages === 1 ? '' : 's');
  if (pdf.numPages > 8) suffix += ' (truncated at 8 pages — recipe may continue)';
  if (usedOcr) suffix += ' (OCR fallback)';
  await applyScanResult(allText.trim(), suffix);
}

async function scanRecipePhoto() {
  var input = document.getElementById('scan-file-input');
  if (!input || !input.files || !input.files[0]) {
    showScanStatus('Choose a photo or PDF first.', false); return;
  }
  if (typeof Tesseract === 'undefined') {
    showScanStatus('OCR library still loading — try again in a moment.', false); return;
  }
  var file = input.files[0];
  var isPdf = file.type === 'application/pdf' || /\.pdf$/i.test(file.name);
  try {
    if (isPdf) {
      await scanRecipePdf(file);
      return;
    }
    showScanStatus('Reading photo (OCR)…', null);
    var raw = await ocrFromSource(file, 'Reading photo');
    if (!raw) { showScanStatus('No text detected — try a clearer, flatter photo.', false); return; }
    await applyScanResult(raw);
  } catch(e) {
    showScanStatus((e.message || 'Scan failed') + ' — paste text manually.', false);
  }
}

function showImportStatus(msg, ok) {
  var el = document.getElementById('url-import-status');
  if (!el) return;
  el.textContent = (ok===true?'✅ ':ok===false?'⚠ ':'⏳ ') + msg;
  el.style.display = 'block';
  el.style.color = ok===true?'var(--success)':ok===false?'var(--danger)':'var(--text-muted)';
}

function extractJsonLdRecipe(html) {
  var re = /<script[^>]+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
  var m;
  while ((m = re.exec(html)) !== null) {
    try {
      var json = JSON.parse(m[1]);
      var candidates = json['@graph'] ? json['@graph'] : [json];
      for (var i=0; i<candidates.length; i++) {
        var t = candidates[i]['@type'];
        if (t === 'Recipe' || (Array.isArray(t) && t.indexOf('Recipe') > -1)) return candidates[i];
      }
    } catch(e) { console.warn('url-import', e); }
  }
  return null;
}

function parseDuration(iso) {
  if (!iso) return '';
  var h = (iso.match(/(\d+)H/)||[])[1]||0;
  var m = (iso.match(/(\d+)M/)||[])[1]||0;
  if (h && m) return h + ' hr ' + m + ' min';
  if (h) return h + ' hr';
  return m ? m + ' min' : '';
}

function extractInstructions(instructions) {
  if (!instructions) return '';
  if (typeof instructions === 'string') return instructions;
  return instructions.map(function(step) {
    if (typeof step === 'string') return step;
    if (step.text) return step.text;
    if (step.itemListElement) {
      var prefix = step.name ? step.name + ':' + NL : '';
      return prefix + step.itemListElement.map(function(s){return s.text||String(s);}).join(NL);
    }
    return '';
  }).filter(Boolean).join(NL);
}

function recipeJsonLdHasIngredients(r) {
  if (!r || !r.recipeIngredient) return false;
  var ing = r.recipeIngredient;
  if (Array.isArray(ing)) {
    return ing.filter(function(i) { return String(i || '').trim().length > 1; }).length >= 2;
  }
  return String(ing).trim().length > 1;
}

function recipeJsonLdHasInstructions(r) {
  var ext = (typeof RecipeImportExtract !== 'undefined' ? RecipeImportExtract : null);
  if (ext && ext.analyzeJsonLdRecipe) return ext.analyzeJsonLdRecipe(r).hasInstructions;
  if (!r || !r.recipeInstructions) return false;
  var steps = extractInstructions(r.recipeInstructions);
  return steps.split('\n').filter(function(s) { return s.trim().length > 4; }).length >= 2;
}

function recipeJsonLdIsTrustworthy(r) {
  var ext = (typeof RecipeImportExtract !== 'undefined' ? RecipeImportExtract : null);
  if (ext && ext.analyzeJsonLdRecipe) return ext.analyzeJsonLdRecipe(r).isTrustworthy;
  return recipeJsonLdHasIngredients(r) && recipeJsonLdHasInstructions(r);
}

function applyImportMetaFromPayload(payload) {
  if (!payload) return;
  if (payload.meta) {
    if (payload.meta.prep) setFormNumberIfEmpty('prep-time', payload.meta.prep);
    if (payload.meta.cook) setFormNumberIfEmpty('cook-time', payload.meta.cook);
    if (payload.meta.servings) setFormNumberIfEmpty('servings', payload.meta.servings);
    if (payload.meta.author) {
      var creditName = document.getElementById('credit-name');
      if (creditName && !creditName.value.trim()) creditName.value = String(payload.meta.author).trim();
    }
  }
  if (payload.attribution && payload.attribution.page_title) {
    var nameEl = document.getElementById('recipe-name');
    if (nameEl && !nameEl.value.trim()) nameEl.value = normalizeImportPageTitle(payload.attribution.page_title);
  }
  if (payload.recipe) applyJsonLdMetaToForm(payload.recipe);
}

function importStatusSuffixFromPayload(payload) {
  if (!payload) return ' from blog';
  if (payload.extractor === 'jsonld') return ' via schema';
  if (payload.extractor === 'wprm') return ' via recipe plugin';
  if (payload.mergeMode) return ' (merged schema + blog)';
  if (payload.strategy === 'wp-raw') return ' from blog';
  return ' from blog';
}

async function applyServerImportPayload(payload, url) {
  if (typeof TcjImportAudit !== 'undefined') {
    TcjImportAudit.recordUrlImport({
      url: url,
      parserVersion: payload.parserVersion,
      extractorVersion: payload.extractorVersion,
      extractor: payload.extractor,
      mergeMode: payload.mergeMode,
      pasteText: payload.articleText,
      rawArticle: payload.import_raw_article_text || payload.articleText,
      warnings: payload.warnings || [],
      attribution: payload.attribution || null
    });
  }
  var articleText = payload.articleText || '';
  var suffix = importStatusSuffixFromPayload(payload);
  var warn = (payload.warnings || []).join('; ');
  if (recipeJsonLdIsTrustworthy(payload.recipe) && !payload.mergeMode && payload.extractor === 'jsonld') {
    populateFromJsonLd(payload.recipe, url);
    applyImportMetaFromPayload(payload);
    showImportStatus('Recipe imported via schema. Review all fields below before submitting.' + (warn ? ' ' + warn : ''), true);
    return;
  }
  if (articleText.length > 80) {
    await applyUrlImportToPaste(articleText, payload.pageTitle || '', suffix);
    applyImportMetaFromPayload(payload);
    if (payload.importQuality && payload.importQuality.review_required) {
      window._lastParseConfidence = window._lastParseConfidence || {};
      window._lastParseConfidence.score = payload.importQuality.confidence_score;
      window._lastParseConfidence.submitWarn = true;
      window._lastParseConfidence.allowEnrich = !!payload.importQuality.enrich_allowed;
    }
    showImportStatus(
      'Recipe imported' + suffix + (warn ? ' (' + warn + ')' : '') + '. Review all fields below before submitting.',
      true
    );
    return;
  }
  if (payload.recipe) {
    populateFromJsonLd(payload.recipe, url);
    applyImportMetaFromPayload(payload);
    showImportStatus('Recipe imported via partial schema — ingredients or steps may be incomplete. Review before submitting.', null);
    return;
  }
  showImportStatus('No recipe content found on that page. Try pasting the text manually.', false);
}

async function applySocialCaptionImport(opts) {
  opts = opts || {};
  var platform = opts.platform || 'Social';
  var caption = splitBundledCaption((opts.caption || '').trim());
  if (!caption) {
    maybeShowVideoRecipeHelp(opts.url || '', 'video-only');
    return;
  }
  var cleaned = await cleanupOcrText(caption);
  var pasteEl = document.getElementById('paste-input');
  if (pasteEl) pasteEl.value = cleaned;
  var title = extractTitleFromCaption(cleaned);
  var nameEl = document.getElementById('recipe-name');
  if (nameEl && title && !nameEl.value.trim()) nameEl.value = title;
  if (typeof TcjImportAudit !== 'undefined') {
    TcjImportAudit.recordUrlImport({
      url: opts.url || '',
      pasteText: cleaned,
      extractor: 'social',
      path: 'social-caption',
      warnings: ['Social caption import — free parser only, no paid AI. Review all fields.']
    });
  }
  var isSocialMeta = (typeof RecipeImportCore !== 'undefined' && RecipeImportCore.looksLikeSocialMetadataCaption)
    ? RecipeImportCore.looksLikeSocialMetadataCaption(cleaned)
    : /\d[\d,.\s]*\s+likes?\b/i.test(cleaned) && !/\bingredients?\b/i.test(cleaned);
  var structured = !isSocialMeta && (opts.hasRecipeStructure || looksLikeStructuredRecipe(cleaned));
  if (structured) {
    showImportStatus(
      platform + ' caption loaded and structured. Please review all fields before submitting.',
      true
    );
    setTimeout(function() { parseRecipe(); }, 300);
  } else if (cleaned.length >= 20 && !isSocialMeta) {
    showImportStatus(
      platform + ' text loaded. Review the paste box, then click Parse Recipe.',
      null
    );
  } else {
    maybeShowVideoRecipeHelp(opts.url || '', 'video-only');
    showImportStatus(
      platform + ' caption is brief. If the recipe is in the video, try Google AI Mode, then paste the result and click Parse Recipe.',
      false
    );
  }
}

function applyJsonLdMetaToForm(r) {
  if (!r) return;
  var ext = (typeof RecipeImportExtract !== 'undefined' ? RecipeImportExtract : null);
  var prepEl = document.getElementById('prep-time');
  var cookEl = document.getElementById('cook-time');
  if (prepEl && r.prepTime && !prepEl.value.trim()) {
    var prepMin = ext ? ext.parseIsoDurationMinutes(r.prepTime) : null;
    prepEl.value = prepMin || parseDuration(r.prepTime).replace(/\D/g, '') || prepEl.value;
  }
  if (cookEl && r.cookTime && !cookEl.value.trim()) {
    var cookMin = ext ? ext.parseIsoDurationMinutes(r.cookTime) : null;
    cookEl.value = cookMin || parseDuration(r.cookTime).replace(/\D/g, '') || cookEl.value;
  }
  var servEl = document.getElementById('servings');
  if (servEl && r.recipeYield && !servEl.value.trim()) {
    var yld = typeof r.recipeYield === 'string' ? r.recipeYield : (r.recipeYield[0] || '');
    var num = parseInt(String(yld).replace(/[^\d]/g, ''), 10);
    if (!isNaN(num)) servEl.value = num;
  }
}

function populateFromJsonLd(r, sourceUrl) {
  var nameEl = document.getElementById('recipe-name');
  if (nameEl && r.name && !nameEl.value.trim()) nameEl.value = normalizeImportPageTitle(r.name);

  var ingredients = (r.recipeIngredient || []).join(NL);
  var instructions = extractInstructions(r.recipeInstructions || []);
  var pasteText = (ingredients ? 'INGREDIENTS' + NL + ingredients + NL + NL : '') +
                  (instructions ? 'METHOD' + NL + instructions : '');
  var pasteEl = document.getElementById('paste-input');
  if (pasteEl && pasteText) pasteEl.value = pasteText;

  applyJsonLdMetaToForm(r);

  var creditUrl = document.getElementById('credit-url');
  if (creditUrl && !creditUrl.value) creditUrl.value = sourceUrl;

  var creditName = document.getElementById('credit-name');
  if (creditName && !creditName.value.trim() && r.author) {
    creditName.value = typeof r.author === 'string' ? r.author : (r.author.name || '');
  }

  var srcEl = document.querySelector('input[name="source-type"][value="From Somewhere Else"]');
  if (srcEl) srcEl.checked = true;

  if (pasteText && typeof parseRecipe === 'function') setTimeout(parseRecipe, 200);
}
