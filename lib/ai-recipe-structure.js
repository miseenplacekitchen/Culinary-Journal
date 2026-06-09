/**
 * AI recipe structuring — shared prompt + normalizer (Node + browser).
 * Used by /api/ai-structure-recipe to turn social captions/transcripts into CJ form shape.
 */
(function (root, factory) {
  var api = factory();
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.AiRecipeStructure = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {

  var STRUCTURE_VERSION = '1.1.0';

  var CJ_CATEGORIES = [
    'Meat & Fire', 'Ocean & River', 'Garden & Earth', 'Grains & Comfort',
    'Breads & Bakes', 'Sweet Serenades', 'Sips & Stories', 'Preserved & Cherished',
    'Feast Days', 'Little Ones', 'Nourish & Heal', 'Slow & Soulful'
  ];

  var SPICE_LEVELS = ['Not Applicable', 'Mild', 'Medium', 'Hot', 'Very Hot', 'Extremely Hot'];

  function buildStructureMessages(input) {
    input = input || {};
    var parts = [];
    parts.push('Platform: ' + (input.platform || 'unknown'));
    if (input.url) parts.push('Source URL: ' + input.url);
    if (input.pageTitle) parts.push('Title hint: ' + input.pageTitle);
    if (input.creditName) parts.push('Creator: ' + input.creditName);
    if (input.caption) parts.push('\n--- CAPTION ---\n' + String(input.caption).slice(0, 12000));
    if (input.transcript) parts.push('\n--- VIDEO TRANSCRIPT ---\n' + String(input.transcript).slice(0, 12000));
    if (input.extraText) parts.push('\n--- ADDITIONAL TEXT ---\n' + String(input.extraText).slice(0, 8000));

    var system = [
      'You structure cooking content for The Culinary Journal submit form.',
      'Return ONLY one JSON object — no markdown fences, no commentary.',
      '',
      'LANGUAGE (required):',
      '- The source may be in ANY language or script (e.g. Malayalam, Tamil, Hindi, Arabic, Spanish, French, mixed English+local).',
      '- NEVER refuse, translate to English, or skip fields because the language is not English.',
      '- Write recipe_name, native_title, introduction, ingredient names, method steps, section headers, cooking_notes, warnings, and inferred_fields in the DOMINANT language of the source.',
      '- Preserve non-Latin script exactly (e.g. നെയ്ച്ചോറ്, برياني, दाल).',
      '- If the source gives both an English name and a native name, recipe_name = primary name used by the creator; native_title = name in original script when different.',
      '- Section headers may be local (e.g. ചേരുവകൾ, രീതി) or familiar bilingual labels — match the source, not English by default.',
      '- Keep ingredient names and units as in the source; metric (g, ml) and local measures (cup, tsp,പ്പ്) are both fine.',
      '- category_hint and spice_level MUST use only the English allowed values below (site taxonomy).',
      '- Set source_language to an ISO 639-1 code (e.g. ml, ta, hi, ar, en) or full language name.',
      '',
      'STRUCTURE:',
      '- Separate ingredient sections when the source does (e.g. marinade vs main).',
      '- Method sections: PREP WORK / DIRECTIONS / MARINATING or equivalent in the source language.',
      '- Step titles: short imperative phrases (optional). Step text: clear cookable instructions.',
      '- If the source omits quantities or steps, infer plausible values and list each guess in inferred_fields (in the recipe language).',
      '- Never invent allergens; if unsure, add a warning instead of guessing dietary tags.',
      'Valid category_hint values: ' + CJ_CATEGORIES.join('; ') + '.',
      'Valid spice_level values: ' + SPICE_LEVELS.join('; ') + '.'
    ].join('\n');

    var user = parts.join('\n') + '\n\nJSON schema:\n' + JSON.stringify({
      recipe_name: 'string',
      native_title: 'string or empty',
      introduction: 'string (2-4 sentences)',
      servings: 'number or null',
      servings_unit: 'people|portions|pieces',
      prep_time_minutes: 'number or null',
      cook_time_minutes: 'number or null',
      additional_time_minutes: 'number or null',
      cooking_notes: 'string (tips, storage, substitutions)',
      ingredient_sections: [{ section: 'string', items: [{ qty: 'string', unit: 'string', name: 'string', note: 'string' }] }],
      method_sections: [{ section: 'string', steps: [{ title: 'string', text: 'string' }] }],
      category_hint: 'string or empty',
      spice_level: 'string or empty',
      credit_name: 'string or empty',
      source_language: 'string (ISO 639-1 or language name)',
      inferred_fields: ['array of strings describing what was guessed'],
      warnings: ['array of strings for the contributor to verify']
    }, null, 2);

    return { system: system, user: user };
  }

  function parseJsonFromModelText(text) {
    var raw = String(text || '').trim();
    if (!raw) return null;
    var fence = raw.match(/```(?:json)?\s*([\s\S]*?)```/i);
    if (fence) raw = fence[1].trim();
    try { return JSON.parse(raw); } catch (_) {}
    var start = raw.indexOf('{');
    var end = raw.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try { return JSON.parse(raw.slice(start, end + 1)); } catch (_) {}
    }
    return null;
  }

  function cleanStr(s) {
    return String(s == null ? '' : s).replace(/\s+/g, ' ').trim();
  }

  /** Uppercase only Latin section labels; preserve Malayalam, Arabic, etc. */
  function normalizeSectionName(name, fallback) {
    var s = cleanStr(name || fallback || '');
    if (!s) return fallback || 'DIRECTIONS';
    if (/^[\x00-\x7F]+$/.test(s)) return s.toUpperCase();
    return s;
  }

  function normalizeIngredientItem(item) {
    if (!item || typeof item !== 'object') return null;
    var name = cleanStr(item.name || item.ingredient || '');
    if (!name) return null;
    return {
      qty: cleanStr(item.qty || item.quantity || ''),
      unit: cleanStr(item.unit || ''),
      name: name,
      note: cleanStr(item.note || item.notes || '')
    };
  }

  function normalizeMethodStep(step) {
    if (typeof step === 'string') return { title: '', text: cleanStr(step) };
    if (!step || typeof step !== 'object') return null;
    var text = cleanStr(step.text || step.instruction || step.body || '');
    if (!text) return null;
    return { title: cleanStr(step.title || ''), text: text };
  }

  function normalizeAiRecipe(raw, input) {
    input = input || {};
    raw = raw || {};
    var warnings = Array.isArray(raw.warnings) ? raw.warnings.map(cleanStr).filter(Boolean) : [];
    var inferred = Array.isArray(raw.inferred_fields) ? raw.inferred_fields.map(cleanStr).filter(Boolean) : [];

    var ingSecs = [];
    (raw.ingredient_sections || raw.ingredients || []).forEach(function (sec) {
      if (!sec) return;
      if (Array.isArray(sec)) {
        var items = sec.map(normalizeIngredientItem).filter(Boolean);
        if (items.length) ingSecs.push({ name: 'Ingredients', items: items });
        return;
      }
      var items = (sec.items || sec.ingredients || []).map(normalizeIngredientItem).filter(Boolean);
      if (items.length) {
        ingSecs.push({
          name: normalizeSectionName(sec.section || sec.name, 'Ingredients'),
          items: items
        });
      }
    });

    var methSecs = [];
    (raw.method_sections || raw.method || []).forEach(function (sec) {
      if (!sec) return;
      var steps = [];
      if (Array.isArray(sec)) {
        steps = sec.map(normalizeMethodStep).filter(Boolean);
      } else {
        steps = (sec.steps || sec.instructions || []).map(normalizeMethodStep).filter(Boolean);
      }
      if (steps.length) {
        methSecs.push({
          name: normalizeSectionName(sec.section || sec.name, 'DIRECTIONS'),
          steps: steps.map(function (s) { return s.title ? (s.title + ': ' + s.text) : s.text; })
        });
      }
    });

    var category = cleanStr(raw.category_hint || raw.category || '');
    if (category && CJ_CATEGORIES.indexOf(category) < 0) category = '';

    var spice = cleanStr(raw.spice_level || '');
    if (spice && SPICE_LEVELS.indexOf(spice) < 0) spice = '';

    var servings = parseInt(raw.servings, 10);
    if (isNaN(servings) || servings < 1) servings = null;

    function numOrNull(v) {
      var n = parseInt(v, 10);
      return isNaN(n) || n < 0 ? null : n;
    }

    var recipe = {
      recipe_name: cleanStr(raw.recipe_name || raw.name || input.pageTitle || ''),
      native_title: cleanStr(raw.native_title || ''),
      introduction: cleanStr(raw.introduction || raw.description || ''),
      servings: servings,
      servings_unit: cleanStr(raw.servings_unit || 'people') || 'people',
      prep_time_minutes: numOrNull(raw.prep_time_minutes),
      cook_time_minutes: numOrNull(raw.cook_time_minutes),
      additional_time_minutes: numOrNull(raw.additional_time_minutes),
      cooking_notes: cleanStr(raw.cooking_notes || ''),
      tips: Array.isArray(raw.tips) ? raw.tips.map(cleanStr).filter(Boolean) : [],
      category_hint: category,
      spice_level: spice,
      credit_name: cleanStr(raw.credit_name || input.creditName || ''),
      source_language: cleanStr(raw.source_language || raw.language || ''),
      ingredient_sections: ingSecs,
      method_sections: methSecs,
      inferred_fields: inferred,
      warnings: warnings
    };

    var ingCount = ingSecs.reduce(function (n, s) { return n + (s.items || []).length; }, 0);
    var stepCount = methSecs.reduce(function (n, s) { return n + (s.steps || []).length; }, 0);

    var confidence = 40;
    if (ingCount >= 3) confidence += 20;
    if (stepCount >= 3) confidence += 20;
    if (recipe.introduction) confidence += 5;
    if (recipe.servings) confidence += 5;
    if (inferred.length) confidence -= Math.min(25, inferred.length * 4);
    confidence = Math.max(5, Math.min(95, confidence));

    return {
      ok: ingCount >= 2 && stepCount >= 2,
      recipe: recipe,
      ingCount: ingCount,
      stepCount: stepCount,
      confidence: confidence,
      structure_version: STRUCTURE_VERSION,
      review_required: true,
      enrich_allowed: confidence >= 70 && inferred.length <= 2
    };
  }

  return {
    STRUCTURE_VERSION: STRUCTURE_VERSION,
    CJ_CATEGORIES: CJ_CATEGORIES,
    buildStructureMessages: buildStructureMessages,
    parseJsonFromModelText: parseJsonFromModelText,
    normalizeAiRecipe: normalizeAiRecipe
  };
});
