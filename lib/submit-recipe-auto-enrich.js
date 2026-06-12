/* Auto-enrich parsed recipe metadata — extracted from submit-recipe.html */

// ── AUTO-ENRICH PARSED RECIPE (local, no API) ───────────────────────────────
var AUTO_REVIEW_MARKER = '--- Auto review on parse (remove when done) ---';
var PARSER_VERSION = (typeof RecipeImportCore !== 'undefined' && RecipeImportCore.PARSER_VERSION)
  ? RecipeImportCore.PARSER_VERSION : '2.3.0-checklist-complete';
var PARSE_CONFIDENCE_ENRICH_MIN = 70;

function isIngredientQtyOnlyLine(line) {
  line = String(line || '').trim();
  if (!line || line.length > 90) return false;
  if (/^(?:or\s+)?(enough|as\s+needed|to\s+taste)/i.test(line)) return false;
  return /^\d[\d\s\/\.\u00BC-\u00BE-]*(cup|cups|tsp|tbsp|tbs|g|kg|gm|ml|oz|lb|pinch|nos?|handful|bunch)\b/i.test(line)
    || /^\d+\s*\/\s*\d+\s*(cup|cups|tsp|tbsp|tbs|g|kg|ml)\b/i.test(line)
    || /^\d[\d\s\/\.\u00BC-\u00BE-]+\s+or\s+/i.test(line);
}

function isIngredientNameColonLine(line) {
  return /^[A-Za-z][\w\s.'()-]{1,70}\s*:\s*$/.test(String(line || '').trim());
}

function pairMultilineIngredientLines(lines) {
  var out = [];
  for (var i = 0; i < lines.length; i++) {
    var ln = lines[i];
    if (isIngredientNameColonLine(ln) && i + 1 < lines.length) {
      var next = lines[i + 1].trim();
      if (isIngredientQtyOnlyLine(next) || /^\d/.test(next)) {
        out.push(ln.replace(/\s*:\s*$/, '').trim() + ' : ' + next);
        i++;
        continue;
      }
    }
    out.push(ln);
  }
  return out;
}

function methHasCleanNumberedList(methSecs) {
  var steps = [];
  (methSecs || []).forEach(function(s) { steps = steps.concat(s.steps || []); });
  if (steps.length < 3) return false;
  var numbered = steps.filter(function(st) { return /^(?:step\s*)?\d+[\.\):\-]\s+/i.test(String(st || '')); });
  return numbered.length >= Math.max(3, Math.ceil(steps.length * 0.55));
}

// computeParseConfidence, showImportConfidenceBanner, normalizeImportPageTitle,
// expandPasteSection, clearImportUiState → lib/submit-recipe-import-ui.js

async function deleteAutosaveDraftFromDb() {
  if (!session || !session.access_token || !session.user || !session.user.id) return;
  try {
    await fetch(
      SUPABASE_URL + '/rest/v1/recipe_drafts?user_id=eq.' + encodeURIComponent(session.user.id) +
      '&local_key=eq.' + encodeURIComponent(DRAFT_KEY),
      { method: 'DELETE', headers: { 'apikey': SUPABASE_KEY, 'Authorization': 'Bearer ' + session.access_token } }
    );
  } catch(e) { console.warn('tcj', e); }
  _draftDbId = null;
}

function performStartFresh() {
  _draftRestoring = true;
  clearTimeout(_draftSyncTimer);
  try { lsRemove(DRAFT_BACKUP_KEY); } catch(_) {}
  try { lsRemove(DRAFT_KEY); } catch(_) {}
  deleteAutosaveDraftFromDb();
  window._activeDraftId = null;
  hideVideoRecipeHelp();
  var draftPrompt = document.getElementById('draft-restore-prompt');
  if (draftPrompt) draftPrompt.style.display = 'none';
  resetSubmitFormBasics();
  clearImportUiState();
  expandPasteSection();
  try { window.history.replaceState({}, document.title, window.location.pathname); } catch(_) {}
}

function startFreshImport() {
  if (!confirm('Clear this form and start a new recipe? Your saved drafts in My Recipes & Drafts are not deleted.')) return;
  performStartFresh();
  showMsg('Form cleared — paste or import a new recipe.', 'info');
}

function flattenParseItems(ingSecs) {
  var out = [];
  (ingSecs || []).forEach(function(sec) {
    (sec.items || []).forEach(function(item) { out.push(item); });
  });
  return out;
}

function flattenParseSteps(methSecs) {
  var out = [];
  (methSecs || []).forEach(function(sec) {
    (sec.steps || []).forEach(function(st) { out.push(String(st || '').trim()); });
  });
  return out.filter(Boolean);
}

function parseQtyToNumber(qty) {
  var s = String(qty || '').trim();
  if (!s) return 0;
  var mixed = s.match(/^(\d+)\s+(\d+)\/(\d+)$/);
  if (mixed) return parseInt(mixed[1], 10) + parseInt(mixed[2], 10) / parseInt(mixed[3], 10);
  var frac = s.match(/^(\d+)\/(\d+)$/);
  if (frac) return parseInt(frac[1], 10) / parseInt(frac[2], 10);
  var n = parseFloat(s);
  return isNaN(n) ? 0 : n;
}

function classifyMethodStep(step) {
  var t = String(step || '').toLowerCase();
  if (/\b(fold|cover with a kitchen|keep in a bowl|until serving|hold|store covered)\b/.test(t)) return 'holding';
  if (/\b(heat|tawa|griddle|pan|fry|bake|boil|simmer|puff|turn it|flip|cook|grill|roast|steam|broil)\b/.test(t)) return 'cook';
  if (/\b(combine|mix|knead|cover|rest|soak|marinate|chop|prepare|divide|roll|dust|spread|layer|press|make|allow)\b/.test(t)) return 'prep';
  return 'prep';
}

function regroupIngredientSections(ingSecs) {
  var all = [];
  (ingSecs || []).forEach(function(sec) {
    (sec.items || []).forEach(function(item) { all.push(item); });
  });
  if (!all.length) return ingSecs || [];

  var main = [], dusting = [], layering = [], garnish = [];
  all.forEach(function(item) {
    var note = String(item.note || '').toLowerCase();
    var name = String(item.name || '').toLowerCase();
    if (/for dusting|dusting/.test(note) || (/rice flour/.test(name) && /dusting/.test(note))) {
      dusting.push(item);
    } else if (/for layering|layering|between layers/.test(note) || (name === 'oil' && !item.qty)) {
      layering.push(item);
    } else if (/garnish|to serve|for serving/.test(note)) {
      garnish.push(item);
    } else {
      main.push(item);
    }
  });

  if (!dusting.length && !layering.length && !garnish.length) return ingSecs;

  var out = [];
  var mainName = 'Ingredients';
  if (main.length && main.some(function(i) { return /flour|dough/i.test(i.name || ''); })) mainName = 'Main Dough';
  if (main.length) out.push({ name: mainName, items: main });
  if (layering.length) out.push({ name: 'For Layering', items: layering });
  if (dusting.length) out.push({ name: 'Dusting', items: dusting });
  if (garnish.length) out.push({ name: 'Garnish', items: garnish });
  return out.length ? out : ingSecs;
}

function reorganizeMethodSections(methSecs) {
  if (!methSecs || !methSecs.length) return methSecs;
  if (methHasCleanNumberedList(methSecs)) return methSecs;
  if (methSecs.length === 1 && (methSecs[0].steps || []).length >= 4) return methSecs;
  if (methSecs.length === 1 && /^directions$/i.test(String(methSecs[0].name || '').trim())) return methSecs;
  if (window._lastParseConfidence && !window._lastParseConfidence.allowEnrich) return methSecs;
  var total = methSecs.reduce(function(n, s) { return n + (s.steps || []).length; }, 0);
  if (total < 4) return methSecs;
  if (methSecs.length > 1 && methSecs.some(function(s) { return /prep\s*work/i.test(s.name || ''); })) return methSecs;

  var prep = [], cook = [], holding = [];
  methSecs.forEach(function(sec) {
    (sec.steps || []).forEach(function(st) {
      var kind = classifyMethodStep(st);
      if (kind === 'holding') holding.push(st);
      else if (kind === 'cook') cook.push(st);
      else prep.push(st);
    });
  });
  if (!prep.length || !cook.length) return methSecs;

  var out = [{ name: 'PREP WORK', steps: prep }];
  if (cook.length) out.push({ name: 'DIRECTIONS', steps: cook });
  if (holding.length) out.push({ name: 'FINISHING', steps: holding });
  return out;
}

function inferRecipeCategory(name, items, steps, useSteps) {
  if (!useSteps && typeof RecipeImportCore !== 'undefined' && RecipeImportCore.inferRecipeCategoryFromBlob) {
    var lines = items.map(function (i) { return (i.name || '') + (i.note ? ' ' + i.note : ''); });
    return RecipeImportCore.inferRecipeCategoryFromBlob(name, lines);
  }
  var blob = (name + ' ' + items.map(function(i) {
    return (i.name || '') + ' ' + (i.note || '');
  }).join(' ')).toLowerCase();
  if (useSteps && steps && steps.length) blob += ' ' + steps.join(' ').toLowerCase();

  var rules = [
    { re: /\b(biriyani|biryani|pilaf|pulao|fried rice)\b/, value: 'Grains & Comfort' },
    { re: /\b(puttu|idiyappam|idli)\b/, value: 'Breads & Bakes' },
    { re: /\b(roti|rotti|chapati|paratha|naan|flatbread|bread|loaf|roll|pita|kulcha|dosa|appam)\b/, value: 'Breads & Bakes' },
    { re: /\b(cake|cookie|brownie|muffin|cupcake|halwa|ladoo|barfi|kheer|pudding|dessert|sweet|pie|tart)\b/, value: 'Sweet Serenades' },
    { re: /\b(soup|rasam|shorba|broth|stew)\b/, value: 'Slow & Soulful' },
    { re: /\b(pickle|chutney|jam|preserve|ferment|canning)\b/, value: 'Preserved & Cherished' },
    { re: /\b(salad|raita)\b/, value: 'Garden & Earth' },
    { re: /\b(smoothie|juice|lassi|chai|tea|coffee|cocktail|drink|shake)\b/, value: 'Sips & Stories' },
    { re: /\b(fish|prawn|shrimp|crab|lobster|salmon|tuna|seafood|meen)\b/, value: 'Ocean & River' },
    { re: /\b(chicken|mutton|lamb|beef|pork|meat|steak|bacon|sausage)\b/, value: 'Meat & Fire' },
    { re: /\b(breakfast|pancake|waffle|omelette|porridge)\b/, value: 'Rise & Shine' }
  ];
  for (var i = 0; i < rules.length; i++) {
    if (rules[i].re.test(blob)) return rules[i].value;
  }
  if (/\b(rice|dal|lentil|grain)\b/.test(blob)) return 'Grains & Comfort';
  if (/\b(vegetable|sabzi|curry|thoran)\b/.test(blob)) return 'Garden & Earth';
  return 'Grains & Comfort';
}

function inferSpiceSweetLevels(items, name) {
  var blob = (name + ' ' + items.map(function(i) {
    return (i.name || '') + ' ' + (i.note || '');
  }).join(' ')).toLowerCase();

  var spiceHits = 0;
  var spicyWords = ['chilli', 'chili', 'chilly', 'pepper', 'cayenne', 'jalapeno', 'habanero', 'schezwan', 'sambal', 'harissa', 'gochugaru', 'paprika', 'wasabi', 'hot sauce'];
  spicyWords.forEach(function(w) { if (blob.indexOf(w) >= 0) spiceHits++; });
  var spice = 'Not Applicable';
  if (spiceHits === 1) spice = 'Mild';
  else if (spiceHits === 2) spice = 'Medium';
  else if (spiceHits === 3) spice = 'Hot';
  else if (spiceHits === 4) spice = 'Very Hot';
  else if (spiceHits >= 5) spice = 'Extremely Hot';

  var sweetHits = 0;
  var sweetWords = ['sugar', 'jaggery', 'honey', 'syrup', 'milkmaid', 'condensed milk', 'chocolate', 'cocoa', 'sweet', 'molasses', 'maple'];
  sweetWords.forEach(function(w) { if (blob.indexOf(w) >= 0) sweetHits++; });
  var sweet = 'Not Applicable';
  if (/\b(cake|cookie|dessert|halwa|ladoo|kheer|pudding|sweet)\b/i.test(name)) {
    if (sweetHits >= 3) sweet = 'Very Sweet';
    else if (sweetHits >= 2) sweet = 'Sweet';
    else sweet = 'Lightly Sweet';
  } else if (sweetHits >= 2) sweet = 'Lightly Sweet';
  else if (sweetHits === 1) sweet = 'Subtly Sweet';

  return { spice: spice, sweet: sweet };
}

function ingredientBlob(items) {
  return items.map(function(i) {
    return ((i.name || '') + ' ' + (i.note || '')).toLowerCase();
  }).join(' ');
}

function inferDietaryAndHealth(items) {
  if (!items || items.length < 3) return [];
  var blob = ingredientBlob(items);
  var tags = [];
  if (/\b(vegan|plant.?based)\b/i.test(blob)) { tags.push('tag-vegan', 'tag-veg'); }
  else if (/\b(vegetarian|veg\s+only)\b/i.test(blob)) { tags.push('tag-veg'); }
  if (/\b(gluten.?free|celiac)\b/i.test(blob)) tags.push('tag-gf');
  if (/\b(dairy.?free|lactose.?free)\b/i.test(blob)) tags.push('tag-df');
  if (/\b(nut.?free)\b/i.test(blob)) tags.push('tag-nf');
  if (/\b(egg.?free)\b/i.test(blob)) tags.push('tag-ef');
  if (/\b(shellfish.?free|seafood.?free)\b/i.test(blob)) tags.push('tag-sf');
  if (/\b(kid.?friendly|kids)\b/i.test(blob)) tags.push('tag-kf');
  return tags;
}

function inferMealOccasionStyleTags(name, category, items, times) {
  var tags = ['tag-everyday', 'tag-trad'];
  var blob = (name + ' ' + category).toLowerCase();
  if (/\b(roti|rotti|chapati|paratha|naan|bread|flatbread)\b/.test(blob)) tags.push('tag-mt-bread');
  else if (/\b(biriyani|biryani|rice|pulao|pilaf)\b/.test(blob)) tags.push('tag-mt-rice');
  else if (category === 'Sweet Serenades') tags.push('tag-mt-dessert');
  else if (/\b(soup)\b/.test(blob)) tags.push('tag-mt-soup');
  else if (/\b(salad|raita)\b/.test(blob)) tags.push('tag-mt-salad');
  else if (/\b(drink|juice|lassi|chai|tea|coffee)\b/.test(blob)) tags.push('tag-mt-drink');
  else if (category === 'Meat & Fire' || category === 'Ocean & River') tags.push('tag-mt-main');
  else if (category === 'Breads & Bakes') tags.push('tag-mt-bread');
  else tags.push('tag-mt-side');

  if ((times.prep + times.cook) <= 30) tags.push('tag-quick');
  if (/\b(comfort|home|simple)\b/.test(blob) || category === 'Grains & Comfort') tags.push('tag-comfort');
  if (!/\b(chilli|chili|spice)\b/.test(ingredientBlob(items))) tags.push('tag-fp-mild');
  return tags;
}

function estimateRecipeTimes(items, steps) {
  var prep = 0, cook = 0;
  steps.forEach(function(step) {
    var kind = classifyMethodStep(step);
    var t = String(step || '').toLowerCase();
    if (kind === 'cook') cook += /\b(heat|simmer|bake|roast|dum)\b/.test(t) ? 5 : 3;
    else if (/\b(knead|roll|layer|marinate)\b/.test(t)) prep += 4;
    else prep += 2;
  });
  prep = Math.max(10, Math.min(120, prep || 15));
  cook = Math.max(5, Math.min(180, cook || 10));

  var cupTotal = 0, riceCups = 0;
  items.forEach(function(i) {
    if ((i.unit || '').toLowerCase().indexOf('cup') >= 0) {
      var n = parseQtyToNumber(i.qty);
      cupTotal += n;
      if (/rice/i.test(i.name || '')) riceCups += n;
    }
  });
  var servings = 4;
  if (riceCups > 0) servings = Math.max(2, Math.round(riceCups * 3));
  else if (cupTotal > 0) servings = Math.max(2, Math.round(cupTotal * 4));

  return { prep: prep, cook: cook, servings: servings };
}

function parseDurationTokenToMinutes(num, unit) {
  var n = parseInt(num, 10);
  if (isNaN(n)) return 0;
  var u = String(unit || 'min').toLowerCase();
  if (/hour|hr/.test(u)) return n * 60;
  if (/day/.test(u)) return n * 1440;
  if (/week/.test(u)) return n * 10080;
  return n;
}

function passiveValueForStyle(totalMinutes, extraUnit) {
  if (!totalMinutes) return 0;
  if (extraUnit === 'hr') return Math.max(1, Math.round(totalMinutes / 60 * 10) / 10);
  if (extraUnit === 'day') return Math.max(1, Math.round(totalMinutes / 1440 * 10) / 10);
  if (extraUnit === 'week') return Math.max(1, Math.round(totalMinutes / 10080 * 10) / 10);
  return totalMinutes;
}

function extractPassiveTimeDetails(text, steps, items) {
  var blob = (text || '') + ' ' + (steps || []).join(' ');
  var hasMarinadeIng = (items || []).some(function(i) {
    return /marinade|marination/i.test((i.name || '') + ' ' + (i.note || ''));
  });

  var patterns = [
    { re: /\bmarinat(?:e|ion|ing)?\b[^.]{0,70}?(\d+)\s*(?:to|-)\s*(\d+)\s*(hours?|hrs?|minutes?|mins?|days?)/i, stage: 'marinating', range: true },
    { re: /\bmarinat(?:e|ion|ing)?\b[^.]{0,70}?(\d+)\s*(hours?|hrs?|minutes?|mins?|days?)/i, stage: 'marinating', range: false },
    { re: /\b(?:prove|proof|rise|rising)\b[^.]{0,70}?(\d+)\s*(?:to|-)\s*(\d+)\s*(hours?|hrs?|minutes?|mins?)/i, stage: 'bread', range: true },
    { re: /\b(?:prove|proof|rise|rising)\b[^.]{0,70}?(\d+)\s*(hours?|hrs?|minutes?|mins?)/i, stage: 'bread', range: false },
    { re: /\b(?:ferment|fermentation)\b[^.]{0,70}?(\d+)\s*(?:to|-)\s*(\d+)\s*(hours?|hrs?|days?|weeks?)/i, stage: 'fermentation', range: true },
    { re: /\b(?:ferment|fermentation)\b[^.]{0,70}?(\d+)\s*(hours?|hrs?|days?|weeks?)/i, stage: 'fermentation', range: false },
    { re: /\b(?:brine|brining)\b[^.]{0,70}?(\d+)\s*(?:to|-)\s*(\d+)\s*(hours?|hrs?|minutes?|mins?|days?)/i, stage: 'brining', range: true },
    { re: /\b(?:brine|brining)\b[^.]{0,70}?(\d+)\s*(hours?|hrs?|minutes?|mins?|days?)/i, stage: 'brining', range: false },
    { re: /\b(?:soak|soaking)\b[^.]{0,70}?(\d+)\s*(?:to|-)\s*(\d+)\s*(hours?|hrs?|minutes?|mins?)/i, stage: 'soak', range: true },
    { re: /\b(?:soak|soaking)\b[^.]{0,70}?(\d+)\s*(hours?|hrs?|minutes?|mins?)/i, stage: 'soak', range: false },
    { re: /\b(?:rest|resting|allow to rest)\b[^.]{0,70}?(\d+)\s*(?:to|-)\s*(\d+)\s*(hours?|hrs?|minutes?|mins?)/i, stage: 'rest', range: true },
    { re: /\b(?:rest|resting|allow to rest)\b[^.]{0,70}?(\d+)\s*(hours?|hrs?|minutes?|mins?)/i, stage: 'rest', range: false },
    { re: /\bovernight\b/i, stage: hasMarinadeIng ? 'marinating' : 'rest', overnight: true }
  ];

  for (var i = 0; i < patterns.length; i++) {
    var p = patterns[i];
    if (p.overnight) {
      if (p.re.test(blob)) {
        return {
          minutes: 480,
          stage: p.stage,
          label: 'Overnight (' + (p.stage === 'marinating' ? 'marinating' : 'resting') + ', estimated as 8 hours)'
        };
      }
      continue;
    }
    var m = blob.match(p.re);
    if (!m) continue;
    var mins = 0;
    var label = '';
    if (p.range) {
      var a = parseDurationTokenToMinutes(m[1], m[3]);
      var b = parseDurationTokenToMinutes(m[2], m[3]);
      mins = Math.round((a + b) / 2);
      label = p.stage + ' (' + m[1] + ' to ' + m[2] + ' ' + m[3] + ' from source)';
    } else {
      mins = parseDurationTokenToMinutes(m[1], m[2]);
      label = p.stage + ' (' + m[1] + ' ' + m[2] + ' from source)';
    }
    return { minutes: mins, stage: p.stage, label: label };
  }
  return { minutes: 0, stage: '', label: '' };
}

function inferCookingStyle(name, items, steps, text, passive) {
  var blob = (name + ' ' + (text || '') + ' ' + (steps || []).join(' ') + ' ' + ingredientBlob(items)).toLowerCase();
  var passiveStage = passive && passive.stage;

  if (passiveStage === 'marinating' || (/\b(marinat|marination|marinade)\b/.test(blob) && /\bmarinat/.test(blob))) return 'marinating';
  if (passiveStage === 'brining' || /\b(brine|brining)\b/.test(blob)) return 'brining';
  if (passiveStage === 'fermentation' || /\b(ferment|kimchi|kombucha|sourdough starter)\b/.test(blob)) return 'fermentation';
  if (/\b(jam|chutney|marmalade|conserve|fruit preserve)\b/.test(blob) && !/\b(roti|chapati|flatbread)\b/.test(blob)) return 'jam';
  if (/\b(pickle|pickling|achar|aachar)\b/.test(blob)) {
    return /\b(quick|refrigerator|fridge|instant)\b/.test(blob) ? 'pickling-q' : 'pickling-t';
  }
  if (/\b(canning|water bath canner|pressure canner|sterilise jars|sterilize jars)\b/.test(blob)) return 'canning';
  if (/\b(dehydrat|dehydrator|sun.?dry)\b/.test(blob)) return 'dehydrating';
  if (/\b(curing|cold smoke|gravlax|cured meat)\b/.test(blob)) return 'curing';

  if (passiveStage === 'bread' || /\b(yeast|prove|proof|second rise|first rise)\b/.test(blob)) return 'bread';
  if (/\b(roti|rotti|chapati|paratha|naan|rumali|flatbread|tawa|griddle)\b/.test(blob)) return 'griddle';
  if (/\b(bake|baking|oven \d|cake|cookie|muffin|pastry|pie crust)\b/.test(blob)) return 'baking';
  if (/\b(candy|fudge|toffee|confection)\b/.test(blob)) return 'candy';

  if (/\b(pressure cook|instant pot|whistle|pressure cooker)\b/.test(blob)) return 'pressure';
  if (/\b(slow cook|crockpot|crock pot|brais(e|ing) for hours)\b/.test(blob)) return 'slow-cook';
  if (/\b(sous vide)\b/.test(blob)) return 'sous-vide';
  if (/\b(smoker|hot smoke|smoking at)\b/.test(blob)) return 'smoking-hot';
  if (/\b(grill|bbq|barbecue)\b/.test(blob)) return 'bbq';
  if (/\b(deep.?fry|deep fry)\b/.test(blob)) return 'deep-fry';
  if (/\b(air fry|airfryer)\b/.test(blob)) return 'air-fry';
  if (/\b(stir.?fry|wok)\b/.test(blob)) return 'stir-fry';
  if (/\b(steam|steamer|\bdum\b|idli steamer)\b/.test(blob)) return 'steam-poach';
  if (/\b(roast|roasting)\b/.test(blob) && /\b(oven|\d+\s*°|degrees)\b/.test(blob)) return 'roasting';
  if (/\b(raw|no.?cook|uncooked salad)\b/.test(blob) && !/\b(cook|heat|bake|fry)\b/.test(blob)) return 'raw';

  return '';
}

function inferOriginRegion(text) {
  var url = ((document.getElementById('credit-url') || {}).value || '') +
            ((document.getElementById('source-url-input') || {}).value || '');
  var blob = (text || '') + ' ' + url;
  if (/kothiyavunu|malayali|villagecookingkerala|sandhyahariharan|curryworld|kerala\s+recipes|kerala\s+ruchi/i.test(blob)) {
    return (typeof REGION_HINTS !== 'undefined' ? REGION_HINTS : []).find(function(r) {
      return r.name === 'South Indian (Kerala)';
    }) || null;
  }
  if (/yummytummy|mariasmenu/i.test(blob)) {
    return (typeof REGION_HINTS !== 'undefined' ? REGION_HINTS : []).find(function(r) {
      return r.name === 'South Indian (Tamil Nadu)';
    }) || null;
  }
  if (/\bkerala\b/i.test(blob)) return REGION_HINTS ? REGION_HINTS[0] : null;
  if (/\btamil\s+nadu\b/i.test(blob)) return REGION_HINTS ? REGION_HINTS[1] : null;
  if (/\bnorth\s+indian\b|\bpunjab/i.test(blob)) return REGION_HINTS ? REGION_HINTS[2] : null;
  return null;
}

function trimIntroToWordLimit(text, maxWords) {
  var words = String(text || '').trim().split(/\s+/).filter(Boolean);
  if (words.length <= maxWords) return words.join(' ');
  return words.slice(0, maxWords).join(' ') + '…';
}

function buildAutoIntroduction(name, items, category) {
  var n = String(name || '').trim();
  var flours = items.filter(function(i) { return /flour/i.test(i.name || ''); }).map(function(i) { return i.name; });
  var intro = '';
  if (/\b(roti|rotti|chapati|paratha|rumali)\b/i.test(n)) {
    intro = 'A thin flatbread made from a soft dough and cooked on a very hot tawa.';
    if (flours.length) intro += ' Prepared with ' + flours.join(' and ') + '.';
  } else if (/\b(biriyani|biryani)\b/i.test(n)) {
    intro = 'A layered rice dish prepared with aromatic spices and the ingredients listed below.';
  } else if (category) {
    intro = 'A ' + category.toLowerCase() + ' recipe prepared from the ingredients and method below.';
  }
  return trimIntroToWordLimit(intro, 100);
}

function normalizeAutoRecipeName(name) {
  return String(name || '').trim().replace(/\brotti\b/gi, 'Roti');
}

function buildClarityNotes(name, items, meta) {
  var lines = [];
  lines.push('Estimated values (confirm or edit): Prep ' + meta.times.prep + ' min, Cook ' + meta.times.cook + ' min, Servings ' + meta.times.servings + '.');
  if (meta.cookingStyle) {
    lines.push('Cooking style auto-selected: ' + (meta.cookingStyleLabel || meta.cookingStyle) + '.');
  }
  if (meta.passive && meta.passive.minutes) {
    lines.push('Passive stage: ' + (meta.passive.label || (meta.passive.minutes + ' min from source')) + '.');
  }
  if (meta.needsShelfLife) {
    lines.push('Shelf life (sealed and after opening) not in source. Admin should confirm storage and shelf life.');
  }
  items.forEach(function(i) {
    if (!i.qty && !/to taste|as needed|less than/i.test(i.note || '')) {
      lines.push('Quantity not in source: ' + (i.name || 'ingredient') + (i.note ? ' (' + i.note + ')' : '') + '.');
    }
  });
  if (!meta.origin) lines.push('Origin not detected from source. Confirm continent, country, and region.');
  if (/\b(roti|rotti)\b/i.test(name)) lines.push('Confirm recipe title spelling: Rumali Roti vs Rumali Rotti.');
  return lines.join('\n');
}

function cookingStyleLabel(key) {
  var el = document.querySelector('#cooking-style option[value="' + key + '"]');
  return el ? el.textContent.trim() : key;
}

function ensureFormRadio(name, value) {
  document.querySelectorAll('input[name="' + name + '"]').forEach(function(r) {
    r.checked = (r.value === value);
  });
}

function ensureTagChecked(id) {
  var el = document.getElementById(id);
  if (el) el.checked = true;
}

function setFormTextIfEmpty(id, value) {
  var el = document.getElementById(id);
  if (el && value && !String(el.value || '').trim()) el.value = value;
}

function setFormNumber(id, value) {
  var el = document.getElementById(id);
  if (el && value != null && value !== '') el.value = value;
}

function setFormNumberIfEmpty(id, value) {
  var el = document.getElementById(id);
  if (el && value != null && value !== '' && !String(el.value || '').trim()) el.value = value;
}

function expandLevelsTagsSection() {
  var sub = document.getElementById('subsection-levels-tags');
  if (!sub) return;
  sub.classList.remove('collapsed');
  var head = sub.querySelector(':scope > .sr-panel-head');
  if (head) head.setAttribute('aria-expanded', 'true');
  var details = document.getElementById('section-details');
  if (details) details.classList.remove('collapsed');
}

function stripAutoReviewFromNotes(text) {
  if (!text || text.indexOf(AUTO_REVIEW_MARKER) < 0) return String(text || '').trim();
  return text.split(AUTO_REVIEW_MARKER)[0].replace(/\s+$/, '');
}

function cleanupPersonalNotesField() {
  var el = document.getElementById('personal-notes');
  if (!el) return;
  var cleaned = stripAutoReviewFromNotes(el.value);
  if (cleaned !== el.value) el.value = cleaned;
}

function hideParseReviewNote() {
  var el = document.getElementById('parse-review-panel');
  if (el) el.style.display = 'none';
}

function showParseReviewNote(block, opts) {
  opts = opts || {};
  var el = document.getElementById('parse-review-panel');
  if (!el || !block) {
    hideParseReviewNote();
    return;
  }
  cleanupPersonalNotesField();
  var title = opts.title || 'Import review — verify before submitting';
  var safe = String(block).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  el.innerHTML = '<div class="sr-parse-review-title">' + title + '</div>' + safe.replace(/\n/g, '<br>');
  el.style.display = 'block';
}

function enrichAndApplyParsedMetadata(ctx) {
  var items = flattenParseItems(ctx.ingSecs);
  var steps = flattenParseSteps(ctx.methSecs);
  if (!items.length && !steps.length) return null;
  if (ctx.skipEnrich) {
    clearParseAutoMetadata();
    return {
      skipped: true,
      ingSecs: ctx.ingSecs,
      methSecs: ctx.methSecs
    };
  }

  var name = normalizeAutoRecipeName(
    (document.getElementById('recipe-name') && document.getElementById('recipe-name').value.trim()) ||
    ctx.title || ''
  );
  var nameEl = document.getElementById('recipe-name');
  if (nameEl && name) nameEl.value = normalizeAutoRecipeName(nameEl.value.trim() || name);

  var category = inferRecipeCategory(name, items, steps, false);
  var levels = inferSpiceSweetLevels(items, name);
  var times = estimateRecipeTimes(items, steps);
  var passive = extractPassiveTimeDetails(ctx.text, steps, items);
  var cookingStyle = inferCookingStyle(name, items, steps, ctx.text, passive);
  var styleCfg = (typeof COOKING_STYLE_CFG !== 'undefined' ? COOKING_STYLE_CFG : {})[cookingStyle] || {};
  var origin = inferOriginRegion(ctx.text);
  var intro = buildAutoIntroduction(name, items, category);

  var csEl = document.getElementById('cooking-style');
  if (csEl) {
    csEl.value = cookingStyle;
    if (typeof applyCookingStyle === 'function') applyCookingStyle(cookingStyle);
  }

  ensureFormRadio('category', category);
  var taxGuess = inferSubCategoryDivision(name, items, category);
  loadTaxonomyForCategory(category, taxGuess.sub || '', taxGuess.div || '');
  ensureFormRadio('spice', levels.spice);
  ensureFormRadio('sweet', levels.sweet);
  setFormTextIfEmpty('introduction', intro);
  setFormNumberIfEmpty('prep-time', times.prep);
  setFormNumberIfEmpty('cook-time', times.cook);
  setFormNumberIfEmpty('servings', times.servings);
  if (passive.minutes) {
    var extraUnit = styleCfg.extraUnit || window._extraUnit || 'min';
    setFormNumberIfEmpty('additional-time', passiveValueForStyle(passive.minutes, extraUnit));
  }

  if (origin && typeof applyRegion === 'function' && !window.fCountry) applyRegion(origin);

  inferDietaryAndHealth(items).forEach(ensureTagChecked);
  inferMealOccasionStyleTags(name, category, items, times).forEach(ensureTagChecked);

  if (typeof updateTotalTime === 'function') updateTotalTime();
  expandLevelsTagsSection();
  showParseReviewNote(buildClarityNotes(name, items, {
    times: times,
    passive: passive,
    origin: origin,
    cookingStyle: cookingStyle,
    cookingStyleLabel: cookingStyleLabel(cookingStyle),
    needsShelfLife: !!styleCfg.shelfLife
  }), { title: 'Auto-filled values — confirm or edit' });

  var summary = [
    category,
    levels.spice === 'Not Applicable' ? 'Spice N/A' : ('Spice: ' + levels.spice),
    'Prep ' + times.prep + 'm [est.]',
    'Cook ' + times.cook + 'm [est.]',
    'Serves ' + times.servings + ' [est.]'
  ];
  if (cookingStyle) summary.push(cookingStyleLabel(cookingStyle));
  if (passive.minutes && styleCfg.extraLabel) {
    summary.push(styleCfg.extraLabel + ' ' + passiveValueForStyle(passive.minutes, styleCfg.extraUnit || 'min') + ' ' + (styleCfg.extraUnit || 'min'));
  } else if (passive.minutes) {
    summary.push('Passive ' + passive.minutes + 'm');
  }
  if (origin && origin.name) summary.push('Origin: ' + origin.name);
  if (styleCfg.shelfLife) summary.push('Shelf life: confirm manually');

  var regroup = (window._lastParseConfidence && window._lastParseConfidence.score >= 70);
  var keepMethodLayout = ctx.fromSegment || methHasCleanNumberedList(ctx.methSecs)
    || (ctx.methSecs && ctx.methSecs.length === 1 && (ctx.methSecs[0].steps || []).length >= 4);
  return {
    summary: summary,
    ingSecs: regroup ? regroupIngredientSections(ctx.ingSecs) : ctx.ingSecs,
    methSecs: keepMethodLayout ? ctx.methSecs : reorganizeMethodSections(ctx.methSecs)
  };
}

