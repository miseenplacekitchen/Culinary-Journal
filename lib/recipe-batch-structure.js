/**
 * Batch pipeline — turn fetch-recipe-url style payload into TCJ submitted_recipes shape.
 * Uses the same import core/extract logic as submit-recipe.html (no LLM).
 */
(function (root, factory) {
  var Core = (typeof module !== 'undefined' && module.exports)
    ? require('./recipe-import-core.js')
    : (root.RecipeImportCore || null);
  var Extract = (typeof module !== 'undefined' && module.exports)
    ? require('./recipe-import-extract.js')
    : (root.RecipeImportExtract || null);
  var api = factory(Core, Extract);
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.RecipeBatchStructure = api;
})(typeof globalThis !== 'undefined' ? globalThis : typeof self !== 'undefined' ? self : this, function (Core, Extract) {

  var TCJ_CATEGORIES = (typeof TCJ_CATEGORY_NAMES !== 'undefined' && TCJ_CATEGORY_NAMES.length)
    ? TCJ_CATEGORY_NAMES.slice()
    : [
      'Garden & Earth', 'Feather & Flock', 'Pasture & Hoof', 'Ocean & River',
      'The Grain Field', 'Wrapped & Stuffed', 'Curds, Creams & Eggs', 'Breads & Bakery',
      'Sweet Serenades', 'Sips & Stories', 'Preserved & Pantry'
    ];

  var SPICE_LEVELS = ['Not Applicable', 'Mild', 'Medium', 'Hot', 'Very Hot', 'Extremely Hot'];
  var SWEET_LEVELS = ['Not Applicable', 'Subtly Sweet', 'Lightly Sweet', 'Sweet', 'Very Sweet', 'Extremely Sweet'];

  var QTY_UNIT_RE = new RegExp(
    '^([\\d\\s\\/\\.\\u00BC-\\u00BE\\-]+?)\\s*(tsp|teaspoon|teaspoons|tbsp|tablespoon|tablespoons|cup|cups|g|gm|gram|grams|kg|ml|l|litre|liter|oz|lb|lbs|clove|cloves|nos|no|pinch|bunch|sprig|sprigs|slice|slices|piece|pieces|can|cans|packet|packets)?\\s*\\.?\\s+(.+)$',
    'i'
  );

  function coerceInt(value, defaultVal) {
    defaultVal = defaultVal == null ? 0 : defaultVal;
    if (value == null || value === '') return defaultVal;
    var n = parseInt(String(value).replace(/[^\d]/g, ''), 10);
    return isNaN(n) ? defaultVal : Math.max(0, n);
  }

  function normalizeChoice(value, allowed, fallback) {
    if (!value) return fallback;
    var text = String(value).trim();
    if (allowed.indexOf(text) >= 0) return text;
    var lower = text.toLowerCase();
    for (var i = 0; i < allowed.length; i++) {
      if (allowed[i].toLowerCase() === lower) return allowed[i];
    }
    return fallback;
  }

  function cleanTitle(raw) {
    if (!raw) return '';
    return String(raw)
      .replace(/\s*[-|–—]\s*Veena'?s?\s*Curry\s*World.*$/i, '')
      .replace(/\s*[-|–—]\s*Curry\s*World.*$/i, '')
      .replace(/\s*[-|–—]\s*Recipes?.*$/i, '')
      .replace(/\s+/g, ' ')
      .trim();
  }

  function parseIngredientLine(line) {
    line = String(line || '').trim().replace(/^[-•*]\s+/, '');
    if (!line || line.length < 2) return null;
    if (/^ingredients?\s*:?\s*$/i.test(line)) return null;
    var m = line.match(QTY_UNIT_RE);
    if (m) {
      return {
        qty: m[1].trim(),
        unit: (m[2] || '').trim(),
        ingredient: m[3].trim(),
        note: '',
        category: ''
      };
    }
    return { qty: '', unit: '', ingredient: line, note: '', category: '' };
  }

  function buildIngredientsFromLines(lines) {
    var sections = [];
    var cur = null;
    (lines || []).forEach(function (line) {
      var parsed = parseIngredientLine(line);
      if (!parsed) return;
      if (!cur) {
        cur = { section: 'Ingredients', items: [] };
        sections.push(cur);
      }
      if (parsed.ingredient) cur.items.push(parsed);
    });
    return sections;
  }

  function buildMethodFromSegment(seg) {
    var sections = [];
    if (seg && seg.methodSections && seg.methodSections.length) {
      seg.methodSections.forEach(function (sec) {
        var steps = (sec.steps || []).map(function (s) {
          var text = typeof s === 'string' ? s : (s.text || '');
          text = String(text).trim();
          if (!text || (Core && Core.isJunkMethodStep && Core.isJunkMethodStep(text))) return null;
          return { title: '', text: text };
        }).filter(Boolean);
        if (steps.length) {
          sections.push({
            section: String(sec.name || 'DIRECTIONS').toUpperCase(),
            steps: steps
          });
        }
      });
      if (sections.length) return sections;
    }
    var flat = (seg && seg.method ? seg.method : []).map(function (s) {
      var text = String(s || '').trim();
      if (!text || (Core && Core.isJunkMethodStep && Core.isJunkMethodStep(text))) return null;
      return { title: '', text: text };
    }).filter(Boolean);
    if (!flat.length) return [];
    return [{ section: 'DIRECTIONS', steps: flat }];
  }

  function countIngredientItems(sections) {
    var n = 0;
    (sections || []).forEach(function (sec) {
      n += (sec.items || []).length;
    });
    return n;
  }

  function countMethodSteps(sections) {
    var n = 0;
    (sections || []).forEach(function (sec) {
      n += (sec.steps || []).length;
    });
    return n;
  }

  function inferCategory(name, ingredientLines) {
    if (Core && Core.inferRecipeCategoryFromBlob) {
      return Core.inferRecipeCategoryFromBlob(name, ingredientLines);
    }
    return 'Grains & Comfort';
  }

  function structureFromImportPayload(payload) {
    if (!payload || !payload.ok) {
      return { ok: false, error: payload && payload.error ? payload.error : 'Import payload missing' };
    }

    var pasteText = payload.articleText || '';
    var seg = Core && Core.segmentRecipeImportText
      ? Core.segmentRecipeImportText(pasteText)
      : { ingredients: [], method: [], methodSections: [], title: '', meta: {}, ingCount: 0, methCount: 0 };

    var recipeName = cleanTitle(
      seg.title ||
      payload.pageTitle ||
      (payload.analysis && payload.analysis.name) ||
      ''
    );
    if (!recipeName) recipeName = 'Untitled Recipe';

    var ingredients = buildIngredientsFromLines(seg.ingredients || []);
    var method = buildMethodFromSegment(seg);
    var ingCount = countIngredientItems(ingredients);
    var stepCount = countMethodSteps(method);

    var meta = payload.meta || (payload.analysis && payload.analysis.meta) || {};
    var intro = seg.description || '';
    if (!intro && payload.analysis && payload.analysis.name) {
      intro = 'Imported from ' + (payload.host || 'recipe site') + '.';
    }

    var structured = {
      recipe_name: recipeName,
      category: inferCategory(recipeName, seg.ingredients || []),
      introduction: intro,
      prep_time_minutes: coerceInt(meta.prep),
      cook_time_minutes: coerceInt(meta.cook),
      servings: Math.max(1, coerceInt(meta.servings, 1)),
      spice_level: 'Not Applicable',
      sweet_level: 'Not Applicable',
      origin_continent: '',
      origin_country: '',
      ingredients: ingredients,
      method: method,
      cooking_notes: (seg.notes || []).join('\n').trim(),
      credit_name: meta.author || '',
      credit_handle: ''
    };

    if (seg.spiceLabel) structured.spice_level = normalizeChoice(seg.spiceLabel, SPICE_LEVELS, 'Not Applicable');
    if (seg.sweetLabel) structured.sweet_level = normalizeChoice(seg.sweetLabel, SWEET_LEVELS, 'Not Applicable');
    structured.category = normalizeChoice(structured.category, TCJ_CATEGORIES, structured.category);

    var quality = payload.importQuality || {};
    var minIng = 2;
    var minSteps = 2;
    var passes = ingCount >= minIng && stepCount >= minSteps && recipeName !== 'Untitled Recipe';

    return {
      ok: passes,
      skipped: !passes,
      reason: passes ? null : ('quality gate: ' + ingCount + ' ingredients, ' + stepCount + ' steps'),
      schema_version: 'tcj-website-v1',
      source_url: payload.url || (payload.attribution && payload.attribution.source_url) || '',
      host: payload.host || '',
      extractor: payload.extractor || '',
      extractor_version: payload.extractorVersion || Extract.EXTRACTOR_VERSION,
      parser_version: payload.parserVersion || (Core && Core.PARSER_VERSION),
      import_quality: quality,
      warnings: payload.warnings || [],
      structured: structured,
      paste_snapshot: pasteText.slice(0, 12000)
    };
  }

  async function fetchAndStructureUrl(url, fetchImpl) {
    fetchImpl = fetchImpl || fetch;
    if (!url || !/^https?:\/\//i.test(url)) {
      return { ok: false, error: 'Invalid URL' };
    }
    if (Extract.isLikelyNonRecipeUrl(url)) {
      return { ok: false, error: 'URL looks like a homepage or category page, not a single recipe' };
    }

    var host;
    try { host = new URL(url).hostname; } catch (_) {
      return { ok: false, error: 'Invalid URL' };
    }

    var upstream = await fetchImpl(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; TheCulinaryJournalBot/1.0; +https://theculinaryjournal.site)',
        'Accept': 'text/html,application/xhtml+xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9'
      },
      redirect: 'follow'
    });

    if (!upstream.ok) {
      return {
        ok: false,
        error: Extract.getFetchErrorMessage(upstream.status, host),
        http_status: upstream.status
      };
    }

    var html = await upstream.text();
    if (!html || html.length < 200) {
      return { ok: false, error: 'Empty response from recipe site' };
    }

    var recipe = Extract.extractJsonLdRecipe(html);
    var pageTitle = '';
    var og = html.match(/property=["']og:title["'][^>]*content=["']([^"']+)["']/i);
    if (og && og[1]) pageTitle = Extract.decodeHtmlEntities(og[1]);

    var payload = Extract.buildImportPayload({
      html: html,
      host: host,
      url: url,
      recipe: recipe,
      pageTitle: pageTitle,
      fetchStatus: 'ok'
    });

    return structureFromImportPayload(payload);
  }

  return {
    TCJ_CATEGORIES: TCJ_CATEGORIES,
    structureFromImportPayload: structureFromImportPayload,
    fetchAndStructureUrl: fetchAndStructureUrl
  };
});
