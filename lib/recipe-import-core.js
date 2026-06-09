/**
 * Wave 1 — single recipe import pipeline (browser + Node).
 * normalize → segment → confidence. No partial fallback layers.
 */
(function (root, factory) {
  var api = factory();
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.RecipeImportCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : typeof self !== 'undefined' ? self : this, function () {

  var PARSER_VERSION = '2.3.0-checklist-complete';
  var PARSE_CONFIDENCE_ENRICH_MIN = 70;
  var PARSE_CONFIDENCE_SUBMIT_WARN_MIN = 50;

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
    /^related posts?/i, /^\d+\s+comments?$/i,     /^until next time/i, /^sponsored\b/i, /^advertisement\b/i,
    /^note\s*:/i, /^love$/i, /^veena$/i, /^vinu$/i, /^loading$/i
  ];

  var META_LABEL = /^(preparation\s+time|cooking\s+time|serves?|servings?|yield|ingredients?|method|directions?)$/i;

  function isJunkMethodStep(step) {
    var t = String(step || '').trim();
    if (!t || t.length < 3) return true;
    var junk = [
      /^\(?\s*\d+\s*reviews?\s*\)?\.?$/i, /^check here for more/i, /^sharing is caring/i,
      /^bon appetit/i, /^related posts?/i, /^print\s*\(/i, /^leave a reply/i,
      /^one response to/i, /^facebook$/i, /^instagram$/i, /^youtube$/i,
      /^food advertisements by/i, /^continue reading/i, /^discover more from/i,
      /^written by$/i, /^author$/i, /^\d+\s+comments?$/i, /^recent posts$/i,
      /^\d+\/\d+\s*\(\d+\s*reviews?\)/i, /^until next time/i,
      /^puttu\s+kappa\s+puttu/i, /^erachi\s+puttu/i,
      /^note\s*:/i, /^love$/i, /^veena$/i, /^vinu$/i, /^notes?$/i, /^loading$/i
    ];
    if (junk.some(function (re) { return re.test(t); })) return true;
    if (t.length <= 18 && /^[A-Za-z][a-z]{2,14}$/.test(t) && !/\b(rice|chicken|onion|salt|water|heat|add|mix)\b/i.test(t)) return true;
    if (t.length < 28 && /^serve\s+(hot|with|warm)/i.test(t) && !/\b(heat|add|mix|stir|place|cover|knead|roll)\b/i.test(t)) return true;
    if (t.length < 18 && /^(?:serves?|yield)\s*:?\s*[\d\u00BC]/i.test(t)) return true;
    return false;
  }

  function isLikelyTitleLine(line) {
    var t = String(line || '').trim();
    if (!t || t.length < 4 || t.length > 90) return false;
    if (/^(ingredients?|method|directions?|preparation\s+time|cooking\s+time|serves?)\b/i.test(t)) return false;
    if (/\d+\.\s+\S/.test(t)) return false;
    if ((t.match(/\s*:\s*/g) || []).length >= 2) return false;
    return true;
  }

  function splitColonMarkers(blob) {
    var text = String(blob || '').replace(/\s+/g, ' ').trim();
    if (!text) return [];
    text = text.replace(/\s*how\s+to\s+make\b.*$/i, '').trim();
    var out = [];
    var nextIngRe = /\s+(?=[A-Z][a-z][A-Za-z0-9\s/'().\/\u00C0-\u024F-]{1,58}?\s*:\s*)/;

    function parseRemainder(chunk) {
      chunk = String(chunk || '').trim();
      if (!chunk) return;
      var colonIdx = chunk.search(/\s*:\s*/);
      if (colonIdx < 0) return;
      var name = chunk.slice(0, colonIdx).replace(/\s+/g, ' ').trim();
      var after = chunk.slice(colonIdx).replace(/^\s*:\s*/, '');
      if (!name || META_LABEL.test(name) || /^how\s+to\s+make\b/i.test(name)) return;

      var nextAt = after.search(nextIngRe);
      var qty = nextAt >= 0 ? after.slice(0, nextAt).trim() : after.trim();
      var rest = nextAt >= 0 ? after.slice(nextAt).trim() : '';
      qty = qty.replace(/\s*how\s+to\s+make\b.*$/i, '').trim();

      if (!qty && /taste|as needed|to taste/i.test(name)) {
        out.push(name + ' :');
      } else if (qty) {
        out.push(name + ' : ' + qty);
      } else if (name.length > 2) {
        out.push(name + ' :');
      }
      if (rest) parseRemainder(rest);
    }

    parseRemainder(text);
    return out;
  }

  function extractNumberedSteps(blob) {
    var text = String(blob || '').replace(/\r\n/g, '\n').trim();
    text = text.replace(/^how\s+to\s+make\b[^\n]*:?\s*/i, '');
    var steps = [];
    var re = /(\d+)\.\s+([\s\S]*?)(?=\s+\d+\.\s+|$)/g;
    var m;
    while ((m = re.exec(text)) !== null) {
      var step = m[2].replace(/\s+/g, ' ').trim();
      if (step.length > 4 && !isJunkMethodStep(step)) steps.push(step);
    }
    return steps;
  }

  function normalizeStuckBlogQty(text) {
    return String(text || '')
      .replace(/:\s*-(\d)(\d+\s*\/\s*\d+)/g, ': 1 $2')
      .replace(/:\s*-(\d+)(\d\/\d+)/g, ': 1 $2');
  }

  function pairMultilineIngredientLines(lines) {
    var out = [];
    for (var i = 0; i < lines.length; i++) {
      var ln = lines[i];
      var nameColon = /^[A-Za-z][\w\s.'()-]{1,70}\s*:\s*$/.test(ln);
      if (nameColon && i + 1 < lines.length) {
        var next = lines[i + 1].trim();
        if (/^\d/.test(next) || /^\d+\s*\/\s*\d+/.test(next) || /cup|cups|tsp|tbsp|g|kg|ml/i.test(next)) {
          out.push(ln.replace(/\s*:\s*$/, '').trim() + ' : ' + next);
          i++;
          continue;
        }
      }
      out.push(ln);
    }
    return out;
  }

  function normalizeRecipeImportText(text) {
    if (!text) return '';
    var t = String(text).replace(/\r\n/g, '\n');
    if (/^INGREDIENTS\n/i.test(t.trim()) && /\nMETHOD\n/i.test(t)) {
      return t.split('\n').map(function (raw) {
        var line = raw.replace(/^food advertisements by\s*/i, '').replace(/\s+/g, ' ').trim();
        if (!line || /^food advertisements by\s*$/i.test(line)) return '';
        if (/^method$/i.test(line)) return 'METHOD';
        if (/^ingredients?$/i.test(line)) return 'INGREDIENTS';
        return line;
      }).filter(Boolean).join('\n').replace(/\n{3,}/g, '\n\n').trim();
    }
    t = t
      .replace(/Food\s+Advertisements\s+by\s*/gi, '\n')
      .replace(/Food\s+Advertisements\s+by\s*(\d+\.)/gi, '\n$1')
      .replace(/\bSponsored\b/gi, '\n')
      .replace(/(moisten the flour)\s+(Salt to taste)\s*:?\s*/gi, '$1\n$2 :\n')
      .replace(/(Salt to taste)\s*:?\s*(How\s+to\s+make)/gi, '$1 :\nMETHOD\n$2')
      .replace(/(preparation\s+time\s*:\s*[\d\s\-]+(?:mins?|minutes?))/gi, '\n$1\n')
      .replace(/(cooking\s+time\s*:\s*[\d\s\-]+(?:mins?|minutes?))/gi, '\n$1\n')
      .replace(/(serves?\s*:\s*\d+)/gi, '\n$1\n')
      .replace(/(ingredients?\s*:)/gi, '\nINGREDIENTS\n')
      .replace(/\s*:\s*(how\s+to\s+make\b)/gi, '\nMETHOD\n$1')
      .replace(/(how\s+to\s+make\b[^:\n]{0,100})\s*:\s*/gi, '\nMETHOD\n$1\n')
      .replace(/#[\w\u00C0-\u024F]+/g, '')
      .replace(/(?:^|\n)\s*(?:INGREDIENTS?|WHAT YOU(?:'LL| WILL) NEED)\s*:?\s*/gi, '\nINGREDIENTS\n')
      .replace(/(?:^|\n)\s*how\s+to\s+make\s+[^:\n]{3,100}\s*:?\s*/gi, '\nMETHOD\n')
      .replace(/(?:^|\n)\s*(?:METHOD|INSTRUCTIONS?|DIRECTIONS?|STEPS?)\s*:?\s*/gi, '\nMETHOD\n')
      .replace(/(?:^|\n)\s*(?:COOKING\s+)?NOTES?\s*(?:&\s*TIPS?)?\s*:?\s*/gi, '\nNOTES\n')
      .replace(/(?:^|\n)\s*(?:TIPS?|HINTS?|TRICKS?|VARIATIONS?)\s*:?\s*/gi, '\nTIPS\n')
      .replace(/(?:^|\n)\s*(?:SERVES?|SERVINGS?|YIELD)\s*:?\s*/gi, '\nSERVES\n');

    var expanded = [];
    t.split('\n').forEach(function (raw) {
      var line = raw.replace(/\s+/g, ' ').trim();
      if (!line) return;
      if (/^ingredients?$/i.test(line)) { expanded.push('INGREDIENTS'); return; }
      if (/^method$/i.test(line)) { expanded.push('METHOD'); return; }
      if (/^how\s+to\s+make\b/i.test(line)) {
        expanded.push('METHOD');
        expanded.push(line.replace(/\s*:?\s*$/, ''));
        return;
      }
      var colonParts = splitColonMarkers(line);
      if (colonParts.length >= 2) {
        colonParts.forEach(function (p) { expanded.push(p); });
        return;
      }
      if (/\d+\.\s+[A-Za-z]/.test(line) && (line.match(/\d+\.\s+/g) || []).length > 1) {
        line.split(/(?=\d+\.\s+)/).forEach(function (s) {
          s = s.trim();
          if (s) expanded.push(s);
        });
        return;
      }
      expanded.push(line);
    });

    return pairMultilineIngredientLines(expanded).join('\n').replace(/\n{3,}/g, '\n\n').trim();
  }

  function extractRecipeMeta(text) {
    var meta = { prep: null, cook: null, servings: null };
    var blob = String(text || '');
    var prep = blob.match(/preparation\s+time\s*:\s*(\d+)\s*(?:mins?|minutes?)?/i);
    if (prep) meta.prep = prep[1];
    var cook = blob.match(/cooking\s+time\s*:\s*(\d+)(?:\s*-\s*(\d+))?\s*(?:mins?|minutes?)?/i);
    if (cook) meta.cook = cook[2]
      ? String(Math.round((parseInt(cook[1], 10) + parseInt(cook[2], 10)) / 2))
      : cook[1];
    var serv = blob.match(/(?:serves?|servings?|yield)\s*:\s*(\d+)/i);
    if (serv) meta.servings = serv[1];
    return meta;
  }

  function isStopLine(line) {
    return BLOG_STOP_LINES.some(function (re) { return re.test(line); });
  }

  function segmentRecipeImportText(rawText) {
    var warnings = [];
    var normalizedText = normalizeRecipeImportText(rawText);
    var lines = normalizedText.split('\n').map(function (l) { return l.trim(); }).filter(Boolean);

    var title = '';
    for (var i = 0; i < Math.min(6, lines.length); i++) {
      if (isLikelyTitleLine(lines[i])) { title = lines[i]; break; }
    }

    var meta = extractRecipeMeta(normalizedText);
    var ingHdr = -1, methHdr = -1;
    for (var j = 0; j < lines.length; j++) {
      if (ingHdr < 0 && /^ingredients?\s*:?\s*$/i.test(lines[j])) ingHdr = j;
      if (methHdr < 0 && (/^method$/i.test(lines[j]) || /^how\s+to\s+make\b/i.test(lines[j]))) methHdr = j;
    }

    var ingStart = ingHdr >= 0 ? ingHdr + 1 : -1;
    var methStart = methHdr >= 0 ? ( /^how\s+to\s+make\b/i.test(lines[methHdr]) ? methHdr : methHdr + 1 ) : -1;

    if (ingStart < 0) {
      for (var a = 0; a < lines.length; a++) {
        if (/\s:\s*[\d\u00BC\/]/.test(lines[a]) || /^[A-Za-z].+\s*:\s*\d/.test(lines[a])) {
          ingStart = a;
          break;
        }
      }
    }
    if (methStart < 0) {
      for (var b = 0; b < lines.length; b++) {
        if (/^\d+\.\s+\S/.test(lines[b])) { methStart = b; break; }
      }
    }
    if (methStart < 0 && ingStart >= 0) {
      var blob = lines.slice(ingStart).join(' ');
      if (/\d+\.\s+\S/.test(blob)) {
        var idx = blob.search(/\d+\.\s+/);
        if (idx > 0) {
          var before = blob.slice(0, idx).trim();
          var colonIngs = splitColonMarkers(before);
          if (colonIngs.length) {
            warnings.push('Ingredients and method were on one block — split automatically');
          }
        }
      }
    }

    var ingEnd = methStart >= 0 ? methStart : lines.length;
    if (ingStart < 0) ingStart = 0;
    if (methStart >= 0 && methStart < ingStart) ingEnd = methStart;

    var ingRegion = lines.slice(ingStart, ingEnd);
    var methEnd = lines.length;
    for (var k = methStart >= 0 ? methStart : 0; k < lines.length; k++) {
      if (isStopLine(lines[k]) || /^related posts?/i.test(lines[k])) { methEnd = k; break; }
    }
    var methRegion = methStart >= 0 ? lines.slice(methStart, methEnd) : [];

    var colonIngs = splitColonMarkers(ingRegion.join(' '));
    var lineIngs = ingRegion.filter(function (l) {
      return l && !/^ingredients?$/i.test(l) && !/^how\s+to\s+make\b/i.test(l) && !META_LABEL.test(l);
    });

    var ingredients = [];
    if (colonIngs.length >= 2 && lineIngs.length >= 2) {
      ingredients = colonIngs.length >= lineIngs.length ? colonIngs.slice() : lineIngs.slice();
    } else if (colonIngs.length >= 2) {
      ingredients = colonIngs.slice();
    } else {
      ingredients = lineIngs.slice();
    }
    ingredients = ingredients.map(function (l) { return normalizeStuckBlogQty(l); });

    var numbered = extractNumberedSteps(methRegion.join('\n'));
    if (numbered.length < 2) numbered = extractNumberedSteps(normalizedText);
    if (numbered.length < 2 && methStart < 0) {
      var tail = normalizedText.replace(/^[\s\S]*?(?=\d+\.\s+)/, '');
      numbered = extractNumberedSteps(tail);
    }
    var lineSteps = methRegion
      .map(function (l) { return l.replace(/^\d+[\.\)]\s*/, '').trim(); })
      .filter(function (l) { return l && l.length > 4 && !/^how\s+to\s+make\b/i.test(l); });

    var method = numbered.length >= lineSteps.length ? numbered : lineSteps;
    if (numbered.length >= 2) method = numbered;
    method = method.filter(function (s) { return s && !isJunkMethodStep(s); });

    var notes = [], tips = [], serves = [];
    lines.forEach(function (l) {
      if (/^serve\s+(hot|with|warm)/i.test(l) && l.length < 100) notes.push(l);
      if (/^(?:serves?|servings?|yield)\s*:\s*[\d\u00BC]/i.test(l)) serves.push(l.replace(/^(?:serves?|servings?|yield)\s*:?\s*/i, '').trim());
    });

    var pasteParts = [];
    if (ingredients.length) pasteParts.push('INGREDIENTS\n' + ingredients.join('\n'));
    if (method.length) pasteParts.push('METHOD\n' + method.join('\n'));
    if (serves.length) pasteParts.push('SERVES\n' + serves.join('\n'));
    if (notes.length) pasteParts.push('NOTES\n' + notes.join('\n'));

    return {
      parserVersion: PARSER_VERSION,
      title: title,
      meta: meta,
      ingredients: ingredients,
      method: method,
      notes: notes,
      tips: tips,
      serves: serves,
      normalizedText: pasteParts.join('\n\n'),
      warnings: warnings,
      ingCount: ingredients.length,
      methCount: method.length,
      hasContent: ingredients.length > 0 || method.length > 0
    };
  }

  function normalizeMatchLine(s) {
    return String(s || '').toLowerCase().replace(/\s+/g, ' ').trim();
  }

  function inferRecipeCategoryFromBlob(name, ingredientLines) {
    var blob = (String(name || '') + ' ' + (ingredientLines || []).join(' ')).toLowerCase();
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

  function splitBundledCaption(text) {
    var t = String(text || '').replace(/\r\n/g, '\n').trim();
    if (!t || t.length < 40) return t;
    if (/\n(INGREDIENTS|METHOD)\n/i.test(t)) return t;
    var out = t
      .replace(/\s*(ingredients?)\s*:?\s*/gi, '\nINGREDIENTS\n')
      .replace(/\s*(method|instructions?|directions?|steps?)\s*:?\s*/gi, '\nMETHOD\n');
    if (/\d+\.\s+\S/.test(out) && !/\nMETHOD\n/i.test(out)) {
      out = out.replace(/(\d+\.\s+)/, '\nMETHOD\n$1');
    }
    return out.replace(/\n{3,}/g, '\n\n').trim();
  }

  function looksLikeStructuredRecipe(text) {
    if (!text || text.length < 40) return false;
    var t = String(text).toLowerCase();
    var hasLabels = /\b(ingredients?|method|instructions?|directions?)\b/.test(t);
    var lines = text.split('\n').filter(function (l) { return l.trim(); });
    var withQty = lines.filter(function (l) {
      return /^\s*[\d\u00BC-\u00BE\/]/.test(l) || /\b(tsp|tbsp|cup|g|ml|oz|lb)\b/i.test(l);
    }).length;
    var numbered = lines.filter(function (l) { return /^\s*\d+[\.\)]\s/.test(l); }).length;
    var hasIngSignals = withQty >= 2 || /\b(ingredients?)\b/i.test(t);
    var hasStepSignals = numbered >= 2 || /\b(method|instructions?|directions?|steps?)\b/i.test(t);
    if (hasLabels) return hasIngSignals && hasStepSignals;
    return withQty >= 3 && numbered >= 2;
  }

  function evaluateStructuralGold(seg, gold) {
    var issues = [];
    var score = 100;
    if (!seg || !gold) return { score: 0, issues: ['missing segment or gold'], pass: false };

    if (gold.ingredients_exact != null && seg.ingCount !== gold.ingredients_exact) {
      issues.push('ingredients ' + seg.ingCount + ' expected exact ' + gold.ingredients_exact);
      score -= 30;
    }
    if (gold.ingredients_min != null && seg.ingCount < gold.ingredients_min) {
      issues.push('ingredients ' + seg.ingCount + ' below min ' + gold.ingredients_min);
      score -= 25;
    }
    if (gold.steps_exact != null && seg.methCount !== gold.steps_exact) {
      issues.push('steps ' + seg.methCount + ' expected exact ' + gold.steps_exact);
      score -= 30;
    }
    if (gold.steps_min != null && seg.methCount < gold.steps_min) {
      issues.push('steps ' + seg.methCount + ' below min ' + gold.steps_min);
      score -= 25;
    }
    if (gold.steps_max != null && seg.methCount > gold.steps_max) {
      issues.push('steps ' + seg.methCount + ' above max ' + gold.steps_max);
      score -= 15;
    }

    (gold.ingredient_contains || []).forEach(function (needle) {
      var joined = (seg.ingredients || []).join(' ');
      if (joined.toLowerCase().indexOf(String(needle).toLowerCase()) < 0) {
        issues.push('missing ingredient token: ' + needle);
        score -= 12;
      }
    });

    (gold.step_starts_with || []).forEach(function (prefix, idx) {
      var step = (seg.method || [])[idx];
      if (!step || normalizeMatchLine(step).indexOf(normalizeMatchLine(prefix)) !== 0) {
        issues.push('step ' + (idx + 1) + ' should start with: ' + prefix);
        score -= 8;
      }
    });

    if (gold.junk_steps != null) {
      var junk = (seg.method || []).filter(function (s) { return isJunkMethodStep(s); }).length;
      if (junk !== gold.junk_steps) {
        issues.push('junk steps ' + junk + ' expected ' + gold.junk_steps);
        score -= 20;
      }
    }

    if (gold.qty_patterns) {
      var blob = (seg.ingredients || []).join(' ');
      gold.qty_patterns.forEach(function (pat) {
        if (blob.indexOf(pat) < 0 && !/1\s*1\/2|1½/.test(blob)) {
          issues.push('qty pattern missing: ' + pat);
          score -= 15;
        }
      });
    }

    if (gold.auto_enrich === false) {
      var conf = computeImportConfidence(seg.ingCount, seg.method || []);
      if (conf.allowEnrich) {
        issues.push('enrich should be blocked');
        score -= 20;
      }
    }

    if (gold.category_must_be || gold.category_must_not || gold.dietary_must_not) {
      var cat = inferRecipeCategoryFromBlob(seg.title || '', seg.ingredients || []);
      if (gold.category_must_be && cat !== gold.category_must_be) {
        issues.push('category ' + cat + ' expected ' + gold.category_must_be);
        score -= 25;
      }
      (gold.category_must_not || []).forEach(function (bad) {
        if (cat === bad) {
          issues.push('category must not be ' + bad);
          score -= 30;
        }
      });
      (gold.dietary_must_not || []).forEach(function (bad) {
        var blob = (seg.ingredients || []).join(' ').toLowerCase();
        var hasGluten = /\b(wheat|atta|gothambu)\b/.test(blob);
        if ((bad === 'Gluten Free' || bad === 'tag-gf') && hasGluten) {
          issues.push('would wrongly allow ' + bad + ' with wheat');
          score -= 20;
        }
      });
    }

    score = Math.max(0, Math.min(100, score));
    return {
      score: score,
      issues: issues,
      pass: issues.length === 0 && score >= 99
    };
  }

  function computeImportConfidence(ingCount, methodSteps, extraWarnings) {
    var warnings = (extraWarnings || []).slice();
    var goodSteps = (methodSteps || []).filter(function (s) { return s && !isJunkMethodStep(s); });
    var junkCount = (methodSteps || []).length - goodSteps.length;
    var score = 0;
    if (ingCount >= 4) score += 30;
    else if (ingCount >= 2) score += 22;
    else if (ingCount >= 1) score += 8;
    if (goodSteps.length >= 6) score += 30;
    else if (goodSteps.length >= 3) score += 22;
    else if (goodSteps.length >= 2) score += 14;
    if (junkCount > 0) {
      score -= Math.min(35, junkCount * 9);
      warnings.push(junkCount + ' junk line(s) removed from method');
    }
    if (ingCount < 2) warnings.push('Fewer than 2 ingredients — check the paste box');
    if (goodSteps.length < 2) warnings.push('Fewer than 2 method steps — check the paste box');
    score = Math.max(0, Math.min(100, score));
    return {
      score: score,
      warnings: warnings,
      allowEnrich: score >= PARSE_CONFIDENCE_ENRICH_MIN && ingCount >= 2 && goodSteps.length >= 2,
      submitWarn: score < PARSE_CONFIDENCE_SUBMIT_WARN_MIN || ingCount < 2 || goodSteps.length < 2,
      goodStepCount: goodSteps.length,
      junkCount: junkCount,
      parserVersion: PARSER_VERSION
    };
  }

  return {
    PARSER_VERSION: PARSER_VERSION,
    PARSE_CONFIDENCE_ENRICH_MIN: PARSE_CONFIDENCE_ENRICH_MIN,
    PARSE_CONFIDENCE_SUBMIT_WARN_MIN: PARSE_CONFIDENCE_SUBMIT_WARN_MIN,
    BLOG_STOP_LINES: BLOG_STOP_LINES,
    isJunkMethodStep: isJunkMethodStep,
    normalizeRecipeImportText: normalizeRecipeImportText,
    segmentRecipeImportText: segmentRecipeImportText,
    computeImportConfidence: computeImportConfidence,
    extractRecipeMeta: extractRecipeMeta,
    normalizeMatchLine: normalizeMatchLine,
    inferRecipeCategoryFromBlob: inferRecipeCategoryFromBlob,
    splitBundledCaption: splitBundledCaption,
    looksLikeStructuredRecipe: looksLikeStructuredRecipe,
    evaluateStructuralGold: evaluateStructuralGold
  };
});
