/**
 * Wave 2 — shared HTML/JSON-LD extraction (browser + Node).
 * Hostname registry, WPRM/plugin paths, JSON-LD merge, fetch UX helpers.
 */
(function (root, factory) {
  var Core = (typeof module !== 'undefined' && module.exports)
    ? require('./recipe-import-core.js')
    : (root.RecipeImportCore || null);
  var api = factory(Core);
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.RecipeImportExtract = api;
})(typeof globalThis !== 'undefined' ? globalThis : typeof self !== 'undefined' ? self : this, function (RecipeImportCore) {

  var EXTRACTOR_VERSION = '2.1.0-wp-raw';

  var HOST_WP_RAW = [
    'curryworld.me', 'kothiyavunu.com', 'malayali.me', 'villagecookingkerala.com',
    'sandhyahariharan.co.uk', 'yummyntasty.com'
  ];
  var HOST_WPRM = [
    'vegrecipesofindia.com', 'yummytummyaarthi.com', 'mariasmenu.com',
    'saffrontrail.com', 'mykoreankitchen.com'
  ];
  var HOST_JSONLD_FIRST = [
    'allrecipes.com', 'taste.com.au', 'coles.com.au', 'woolworths.com.au',
    'nilgiris.com.au', 'kevinandamanda.com', 'thewanderlustkitchen.com'
  ];
  var HOST_SOCIAL = ['instagram.com', 'tiktok.com', 'facebook.com'];
  var HOST_BOT_BLOCK_MSG = {
    'allrecipes.com': 'Allrecipes blocks automated fetching. Paste the recipe text or use photo scan.',
    'taste.com.au': 'Taste blocks automated fetching. Paste the recipe text or use photo scan.',
    'coles.com.au': 'Coles may block server fetch. Paste the recipe or try photo scan.',
    'woolworths.com.au': 'Woolworths may block server fetch. Paste the recipe or try photo scan.'
  };

  var BLOG_NAV_LINES = /^(beef|chicken|mutton|egg|rice|bread|breakfast|cakes|snacks|soups|drinks|sea food|pickles|sweets|useful tips|my cooking|post delivery|healthy salads|indian vegetable|kerala sadya|spice mixes|chutneys|curryworld menu|biriyani|chinese dishes)/i;

  function normalizeHost(host) {
    return String(host || '').toLowerCase().replace(/^www\./, '');
  }

  function hostMatchesList(host, list) {
    var h = normalizeHost(host);
    return list.some(function (d) { return h === d || h.endsWith('.' + d); });
  }

  function resolveHostStrategy(host) {
    var h = normalizeHost(host);
    if (hostMatchesList(h, HOST_SOCIAL)) return { strategy: 'social', family: 'social', host: h };
    if (hostMatchesList(h, HOST_WPRM)) return { strategy: 'wprm', family: 'wprm', host: h };
    if (hostMatchesList(h, HOST_JSONLD_FIRST)) return { strategy: 'jsonld-first', family: 'jsonld', host: h };
    if (hostMatchesList(h, HOST_WP_RAW)) return { strategy: 'wp-raw', family: 'wp-raw', host: h };
    return { strategy: 'generic', family: 'generic', host: h };
  }

  function getFetchErrorMessage(status, host) {
    var h = normalizeHost(host);
    var custom = HOST_BOT_BLOCK_MSG[h];
    if (custom && (status === 402 || status === 403 || status === 451)) return custom;
    if (status === 402 || status === 403) {
      return 'This site blocked our import bot (HTTP ' + status + '). Paste the recipe text manually or use photo scan.';
    }
    if (status === 404) return 'Page not found (404). Check the URL points to a single recipe, not a category or homepage.';
    if (status === 429) return 'Too many requests — wait a moment and try again, or paste the recipe manually.';
    if (status >= 500) return 'The recipe site returned a server error (' + status + '). Try again later or paste manually.';
    return 'Could not fetch page (HTTP ' + status + '). Paste the recipe text manually.';
  }

  function isLikelyNonRecipeUrl(url) {
    try {
      var u = new URL(url);
      var path = (u.pathname || '/').toLowerCase();
      if (/\/(category|categories|tag|tags|author|page|search|privacy|terms|about)\b/.test(path)) return true;
      if (path === '/' || path === '') return true;
      if (/\/\d{4}\/\d{2}\/?$/.test(path)) return true;
    } catch (_) {}
    return false;
  }

  function decodeHtmlEntities(s) {
    return String(s || '')
      .replace(/\\u([0-9a-fA-F]{4})/g, function (_, h) { return String.fromCharCode(parseInt(h, 16)); })
      .replace(/\\n/g, '\n')
      .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
      .replace(/&#39;/g, "'").replace(/&quot;/g, '"')
      .replace(/&#(\d+);/g, function (_, n) { return String.fromCharCode(parseInt(n, 10)); })
      .replace(/&#x([0-9a-fA-F]+);/gi, function (_, h) { return String.fromCharCode(parseInt(h, 16)); });
  }

  /** Strip in-article ads/noise common on Kerala WP blogs — never truncate recipe body here. */
  function stripWpNoiseHtml(html) {
    return String(html || '')
      .replace(/<!--\s*Start GADSWPV[\s\S]*?<!--\s*End GADSWPV[\s\S]*?-->/gi, '\n')
      .replace(/<div[^>]*id=["']ga_\d+["'][^>]*>[\s\S]*?<\/div>/gi, '\n')
      .replace(/<div[^>]*style=["'][^"']*text-align:\s*right[^"']*["'][^>]*>[\s\S]*?Food Advertisements[\s\S]*?<\/div>/gi, '\n')
      .replace(/Food Advertisements\s+by\s*/gi, '\n')
      .replace(/<ins[^>]*class=["'][^"']*adsbygoogle[^"']*["'][^>]*>[\s\S]*?<\/ins>/gi, ' ')
      .replace(/<div[^>]*class=["'][^"']*\bcode-block\b[^"']*["'][^>]*>[\s\S]*?<\/div>/gi, ' ');
  }

  function htmlFragmentToText(fragment) {
    if (!fragment) return '';
    return fragment
      .replace(/<script[\s\S]*?<\/script>/gi, ' ')
      .replace(/<style[\s\S]*?<\/style>/gi, ' ')
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<\/(p|div|h[1-6]|li|tr|section|article|ol|ul)>/gi, '\n')
      .replace(/<li[^>]*>/gi, '\n')
      .replace(/<[^>]+>/g, ' ')
      .replace(/&nbsp;/gi, ' ')
      .replace(/&#8230;/gi, '…')
      .replace(/&#8211;|&ndash;/gi, '–')
      .replace(/&#8212;|&mdash;/gi, '—')
      .replace(/&#8220;|&ldquo;/gi, '"')
      .replace(/&#8221;|&rdquo;/gi, '"')
      .replace(/&#8216;|&lsquo;/gi, "'")
      .replace(/&#8217;|&rsquo;/gi, "'")
      .replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>')
      .replace(/[ \t]+\n/g, '\n')
      .replace(/\n{3,}/g, '\n\n')
      .replace(/[ \t]{2,}/g, ' ')
      .trim();
  }

  function cutHtmlAtStops(chunk) {
    var stops = [
      /<footer\b/i, /class="[^"]*\bcomments-area\b/i, /id=["']comments["']/i,
      /class="[^"]*\bsharedaddy\b/i, /class="[^"]*\bjp-relatedposts\b/i,
      /class="[^"]*\bpost-navigation\b/i, /Share this:/i, /Leave a Reply/i,
      /Recent Posts/i, /Loading Comments/i, /Related Posts/i
    ];
    var cut = chunk.length;
    stops.forEach(function (re) {
      var idx = chunk.search(re);
      if (idx > 150 && idx < cut) cut = idx;
    });
    return chunk.slice(0, cut);
  }

  function extractPluginRecipeHtml(html) {
    if (!html) return '';
    var patterns = [
      /<div[^>]*class="[^"]*\bwprm-recipe-container\b[^"]*"[^>]*>([\s\S]*?)<\/div>\s*(?:<div[^>]*class="[^"]*\bwprm-recipe-container|<footer\b|<\/article>)/i,
      /<div[^>]*id=["']wprm-recipe-container-\d+["'][^>]*>([\s\S]*?)<\/div>/i,
      /<div[^>]*class="[^"]*\btasty-recipes[^"]*"[^>]*>([\s\S]*?)<\/div>\s*(?:<div[^>]*class="[^"]*\btasty|<footer\b)/i,
      /<div[^>]*class="[^"]*\bjetpack-recipe[^"]*"[^>]*>([\s\S]*?)<\/div>/i,
      /<div[^>]*class="[^"]*\bmv-create-card\b[^"]*"[^>]*>([\s\S]*?)<\/div>/i
    ];
    for (var i = 0; i < patterns.length; i++) {
      var m = html.match(patterns[i]);
      if (m && m[1] && m[1].length > 120) return cutHtmlAtStops(m[1]);
    }
    return '';
  }

  function extractWprmListItems(html, classHint) {
    var re = new RegExp('class="[^"]*' + classHint + '[^"]*"[^>]*>([\\s\\S]*?)<\\/(?:ul|ol|div)', 'i');
    var m = html.match(re);
    if (!m) return [];
    var items = [];
    var liRe = /<li[^>]*>([\s\S]*?)<\/li>/gi;
    var lm;
    while ((lm = liRe.exec(m[1])) !== null) {
      var t = htmlFragmentToText(lm[1]).replace(/\s+/g, ' ').trim();
      if (t.length > 1) items.push(t);
    }
    return items;
  }

  function wprmHtmlToStructuredText(html) {
    var ings = extractWprmListItems(html, 'wprm-recipe-ingredient');
    var steps = extractWprmListItems(html, 'wprm-recipe-instruction');
    if (!ings.length && !steps.length) return '';
    var parts = [];
    if (ings.length) parts.push('INGREDIENTS\n' + ings.join('\n'));
    if (steps.length) parts.push('METHOD\n' + steps.map(function (s, i) { return (i + 1) + '. ' + s; }).join('\n'));
    return parts.join('\n\n');
  }

  function extractArticleHtml(html, strategy) {
    if (!html) return '';
    if (strategy === 'wp-raw') html = stripWpNoiseHtml(html);
    if (strategy === 'wprm' || strategy === 'generic' || strategy === 'jsonld-first' || strategy === 'wp-raw') {
      var plugin = extractPluginRecipeHtml(html);
      if (plugin.length > 120) return plugin;
      var wprmText = wprmHtmlToStructuredText(html);
      if (wprmText.length > 80) return '<pre>' + wprmText + '</pre>';
    }
    var markers = [
      /<div[^>]*class="[^"]*\bentry-content\b[^"]*"[^>]*>([\s\S]*)/i,
      /<div[^>]*class="[^"]*\bwp-block-post-content\b[^"]*"[^>]*>([\s\S]*)/i,
      /<div[^>]*class="[^"]*\bpost-content\b[^"]*"[^>]*>([\s\S]*)/i,
      /<article[^>]*>([\s\S]*?)<\/article>/i,
      /<div[^>]*itemprop=["']articleBody["'][^>]*>([\s\S]*)/i,
      /<main[^>]*>([\s\S]*?)<\/main>/i
    ];
    for (var i = 0; i < markers.length; i++) {
      var m = html.match(markers[i]);
      if (!m || !m[1] || m[1].length < 200) continue;
      var chunk = cutHtmlAtStops(m[1]);
      if (chunk.length > 200) return chunk;
    }
    return '';
  }

  function isWpNoiseLine(line) {
    var l = String(line || '').trim();
    if (!l) return true;
    if (/^food advertisements by\s*$/i.test(l)) return true;
    if (/^gourmetads/i.test(l)) return true;
    return false;
  }

  function trimBlogRecipeText(text) {
    if (!text) return '';
    var stopLines = (RecipeImportCore && RecipeImportCore.BLOG_STOP_LINES) || [];
    var lines = text.split('\n').map(function (l) { return l.trim(); }).filter(function (l) {
      return l && !isWpNoiseLine(l);
    });
    var start = 0;
    var ingIdx = lines.findIndex(function (l) {
      return /^ingredients?\s*:?\s*$/i.test(l.replace(/[\u00A0\u200B]/g, ' ').trim());
    });
    if (ingIdx >= 0) start = ingIdx;
    else {
      start = lines.findIndex(function (l) {
        return l.length > 10 && l.length < 90 && !BLOG_NAV_LINES.test(l)
          && !stopLines.some(function (re) { return re.test(l); });
      });
      if (start < 0) start = 0;
    }
    var end = lines.length;
    var sawRecipeBody = false;
    for (var i = start; i < lines.length; i++) {
      if (/^how\s+to\s+make\b/i.test(lines[i]) || /^method$/i.test(lines[i])) sawRecipeBody = true;
      if (/^\d+\.\s+\S/.test(lines[i])) sawRecipeBody = true;
      if (isWpNoiseLine(lines[i])) continue;
      if (sawRecipeBody && /food advertisements/i.test(lines[i])) continue;
      if (stopLines.some(function (re) { return re.test(lines[i]); })) { end = i; break; }
      if (/^share on /i.test(lines[i])) { end = i; break; }
    }
    return lines.slice(start, end).join('\n');
  }

  function prepareArticlePasteText(html, host) {
    var strat = resolveHostStrategy(host || '');
    var cleanedHtml = strat.strategy === 'wp-raw' ? stripWpNoiseHtml(html) : html;
    var fragment = extractArticleHtml(cleanedHtml, strat.strategy);
    var raw = fragment ? htmlFragmentToText(fragment) : '';
    if (raw.length < 150) {
      var fallback = htmlFragmentToText(String(cleanedHtml || html || '').slice(0, 120000));
      if (fallback.length > raw.length) raw = fallback;
    }
    var trimmed = trimBlogRecipeText(raw);
    if (!trimmed && raw.length > 80) trimmed = trimBlogRecipeText(raw);
    var normalized = (RecipeImportCore && RecipeImportCore.normalizeRecipeImportText)
      ? RecipeImportCore.normalizeRecipeImportText(trimmed)
      : trimmed;
    return { trimmed: trimmed, normalized: normalized, strategy: strat };
  }

  function segmentArticleText(text) {
    if (!RecipeImportCore || !RecipeImportCore.segmentRecipeImportText) {
      return { normalizedText: text, warnings: ['RecipeImportCore not loaded'], ingCount: 0, methCount: 0 };
    }
    return RecipeImportCore.segmentRecipeImportText(text);
  }

  function extractArticleTextFromHtml(html, host) {
    var prep = prepareArticlePasteText(html, host);
    var seg = segmentArticleText(prep.normalized);
    return seg.normalizedText || prep.normalized;
  }

  function extractJsonLdRecipe(html) {
    var re = /<script[^>]+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi;
    var m;
    while ((m = re.exec(html)) !== null) {
      try {
        var json = JSON.parse(m[1]);
        var candidates = json['@graph'] ? json['@graph'] : [json];
        for (var i = 0; i < candidates.length; i++) {
          var t = candidates[i]['@type'];
          if (t === 'Recipe' || (Array.isArray(t) && t.indexOf('Recipe') >= 0)) return candidates[i];
        }
      } catch (_) {}
    }
    return null;
  }

  function parseIsoDurationMinutes(iso) {
    if (!iso || typeof iso !== 'string') return null;
    var h = parseInt((iso.match(/(\d+)H/i) || [])[1], 10) || 0;
    var m = parseInt((iso.match(/(\d+)M/i) || [])[1], 10) || 0;
    var total = h * 60 + m;
    return total > 0 ? String(total) : null;
  }

  function flattenInstructions(instructions) {
    if (!instructions) return [];
    if (typeof instructions === 'string') return [instructions.trim()].filter(Boolean);
    if (!Array.isArray(instructions)) return [];
    var out = [];
    instructions.forEach(function (step) {
      if (typeof step === 'string') { if (step.trim()) out.push(step.trim()); return; }
      if (!step || typeof step !== 'object') return;
      if (step.text) { out.push(String(step.text).trim()); return; }
      if (step['@type'] === 'HowToSection' && step.itemListElement) {
        (step.itemListElement || []).forEach(function (s) {
          if (s && s.text) out.push(String(s.text).trim());
        });
        return;
      }
      if (step.itemListElement) {
        step.itemListElement.forEach(function (s) {
          if (s && (s.text || s.name)) out.push(String(s.text || s.name).trim());
        });
      }
    });
    return out.filter(Boolean);
  }

  function normalizeIngredients(ing) {
    if (!ing) return [];
    if (Array.isArray(ing)) return ing.map(function (i) { return String(i || '').trim(); }).filter(function (s) { return s.length > 1; });
    return String(ing).trim() ? [String(ing).trim()] : [];
  }

  function analyzeJsonLdRecipe(recipe) {
    if (!recipe) {
      return { hasRecipe: false, hasIngredients: false, hasInstructions: false, isComplete: false, isTrustworthy: false, ingredients: [], instructions: [], meta: {} };
    }
    var ingredients = normalizeIngredients(recipe.recipeIngredient);
    var instructions = flattenInstructions(recipe.recipeInstructions);
    var hasIngredients = ingredients.length >= 2;
    var hasInstructions = instructions.length >= 2;
    var meta = {
      prep: parseIsoDurationMinutes(recipe.prepTime),
      cook: parseIsoDurationMinutes(recipe.cookTime),
      total: parseIsoDurationMinutes(recipe.totalTime),
      servings: null,
      author: null,
      image: null
    };
    if (recipe.recipeYield) {
      var yld = typeof recipe.recipeYield === 'string' ? recipe.recipeYield : (recipe.recipeYield[0] || '');
      var num = parseInt(String(yld).replace(/[^\d]/g, ''), 10);
      if (!isNaN(num)) meta.servings = String(num);
    }
    if (recipe.author) {
      meta.author = typeof recipe.author === 'string' ? recipe.author : (recipe.author.name || '');
    }
    if (recipe.image) {
      meta.image = typeof recipe.image === 'string' ? recipe.image : (recipe.image.url || recipe.image[0] || '');
    }
    return {
      hasRecipe: true,
      hasIngredients: hasIngredients,
      hasInstructions: hasInstructions,
      isComplete: hasIngredients && hasInstructions,
      isTrustworthy: hasIngredients && hasInstructions && ingredients.length >= 3,
      ingredients: ingredients,
      instructions: instructions,
      meta: meta,
      name: recipe.name || ''
    };
  }

  function jsonLdToPasteText(analysis) {
    if (!analysis || !analysis.hasRecipe) return '';
    var parts = [];
    if (analysis.ingredients.length) parts.push('INGREDIENTS\n' + analysis.ingredients.join('\n'));
    if (analysis.instructions.length) {
      parts.push('METHOD\n' + analysis.instructions.map(function (s, i) {
        return /^\d+[\.\)]\s/.test(s) ? s : (i + 1) + '. ' + s;
      }).join('\n'));
    }
    return parts.join('\n\n');
  }

  function mergeJsonLdWithArticle(recipe, articleText) {
    var analysis = analyzeJsonLdRecipe(recipe);
    var seg = segmentArticleText(articleText || '');
    var warnings = (seg.warnings || []).slice();
    var ingredients = analysis.hasIngredients ? analysis.ingredients.slice() : (seg.ingredients || []).slice();
    var method = analysis.hasInstructions ? analysis.instructions.slice() : (seg.method || []).slice();
    var mergeMode = false;

    if (analysis.hasIngredients && !analysis.hasInstructions && seg.methCount >= 2) {
      method = seg.method.slice();
      mergeMode = true;
      warnings.push('Merged schema ingredients with blog method steps');
    } else if (!analysis.hasIngredients && analysis.hasInstructions && seg.ingCount >= 2) {
      ingredients = seg.ingredients.slice();
      mergeMode = true;
      warnings.push('Merged blog ingredients with schema method steps');
    } else if (!analysis.isComplete && seg.hasContent) {
      if (seg.ingCount >= (ingredients.length || 0)) ingredients = seg.ingredients.slice();
      if (seg.methCount >= (method.length || 0)) method = seg.method.slice();
      if (analysis.hasRecipe) {
        mergeMode = true;
        warnings.push('Schema partial — used blog text where stronger');
      }
    }

    var parts = [];
    if (ingredients.length) parts.push('INGREDIENTS\n' + ingredients.join('\n'));
    if (method.length) parts.push('METHOD\n' + method.join('\n'));
    if (seg.serves && seg.serves.length) parts.push('SERVES\n' + seg.serves.join('\n'));

    var meta = analysis.meta || {};
    if (!meta.prep && seg.meta && seg.meta.prep) meta.prep = seg.meta.prep;
    if (!meta.cook && seg.meta && seg.meta.cook) meta.cook = seg.meta.cook;
    if (!meta.servings && seg.meta && seg.meta.servings) meta.servings = seg.meta.servings;

    return {
      pasteText: parts.join('\n\n'),
      mergeMode: mergeMode,
      warnings: warnings,
      ingCount: ingredients.length,
      methCount: method.length,
      meta: meta,
      analysis: analysis,
      extractor: mergeMode ? 'jsonld-merge' : (analysis.isComplete ? 'jsonld' : 'article')
    };
  }

  function extractRawArticleText(html, host) {
    return prepareArticlePasteText(html, host).trimmed;
  }

  function buildImportPayload(opts) {
    var html = opts.html || '';
    var host = opts.host || '';
    var recipe = opts.recipe || extractJsonLdRecipe(html);
    var strat = resolveHostStrategy(host);
    var warnings = [];
    var prep = prepareArticlePasteText(html, host);
    var rawArticleText = prep.trimmed;
    var analysis = analyzeJsonLdRecipe(recipe);
    var extractor = strat.strategy;
    var mergeMode = false;
    var pasteText = '';
    var meta = analysis.meta || {};
    var seg = null;

    if (analysis.isTrustworthy) {
      pasteText = jsonLdToPasteText(analysis);
      extractor = 'jsonld';
      seg = segmentArticleText(pasteText);
    } else if (analysis.hasRecipe && prep.normalized.length > 80) {
      var merged = mergeJsonLdWithArticle(recipe, prep.normalized);
      pasteText = merged.pasteText;
      mergeMode = merged.mergeMode;
      warnings = warnings.concat(merged.warnings);
      meta = merged.meta;
      extractor = merged.extractor;
      seg = segmentArticleText(pasteText);
    } else if (analysis.isComplete) {
      pasteText = jsonLdToPasteText(analysis);
      extractor = 'jsonld';
      seg = segmentArticleText(pasteText);
    } else {
      seg = segmentArticleText(prep.normalized);
      pasteText = seg.normalizedText || prep.normalized;
      if (strat.strategy === 'wp-raw' && seg.methCount < 2 && prep.normalized.length > 80) {
        warnings.push('Few method steps extracted — review paste box before submitting');
      }
    }

    if (!seg) seg = segmentArticleText(pasteText);

    return {
      ok: true,
      url: opts.url || '',
      host: strat.host,
      extractor: extractor,
      extractorVersion: EXTRACTOR_VERSION,
      parserVersion: RecipeImportCore ? RecipeImportCore.PARSER_VERSION : null,
      fetchStatus: opts.fetchStatus || 'ok',
      mergeMode: mergeMode,
      warnings: warnings,
      recipe: recipe,
      articleText: pasteText,
      import_raw_article_text: rawArticleText.slice(0, 8000),
      pageTitle: opts.pageTitle || '',
      hasArticleText: pasteText.length > 80,
      analysis: analysis,
      ingCount: seg.ingCount,
      methCount: seg.methCount,
      meta: meta,
      attribution: {
        source_url: opts.url || '',
        site_host: strat.host,
        page_title: opts.pageTitle || '',
        notice: 'Credit the original creator and keep the source URL when sharing this recipe.'
      }
    };
  }

  return {
    EXTRACTOR_VERSION: EXTRACTOR_VERSION,
    resolveHostStrategy: resolveHostStrategy,
    getFetchErrorMessage: getFetchErrorMessage,
    isLikelyNonRecipeUrl: isLikelyNonRecipeUrl,
    decodeHtmlEntities: decodeHtmlEntities,
    htmlFragmentToText: htmlFragmentToText,
    extractArticleHtml: extractArticleHtml,
    extractArticleTextFromHtml: extractArticleTextFromHtml,
    extractRawArticleText: extractRawArticleText,
    trimBlogRecipeText: trimBlogRecipeText,
    extractJsonLdRecipe: extractJsonLdRecipe,
    parseIsoDurationMinutes: parseIsoDurationMinutes,
    flattenInstructions: flattenInstructions,
    analyzeJsonLdRecipe: analyzeJsonLdRecipe,
    jsonLdToPasteText: jsonLdToPasteText,
    mergeJsonLdWithArticle: mergeJsonLdWithArticle,
    buildImportPayload: buildImportPayload,
    extractPluginRecipeHtml: extractPluginRecipeHtml,
    wprmHtmlToStructuredText: wprmHtmlToStructuredText,
    stripWpNoiseHtml: stripWpNoiseHtml,
    prepareArticlePasteText: prepareArticlePasteText
  };
});
