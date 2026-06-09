/**
 * Wave 1 — single recipe import pipeline (browser + Node).
 * normalize → segment → confidence. No partial fallback layers.
 */
(function (root, factory) {
  var api = factory();
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.RecipeImportCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : typeof self !== 'undefined' ? self : this, function () {

  var PARSER_VERSION = '1.2.0-wave1';
  var PARSE_CONFIDENCE_ENRICH_MIN = 60;

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
    /^related posts?/i, /^\d+\s+comments?$/i, /^until next time/i
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
      /^puttu\s+kappa\s+puttu/i, /^erachi\s+puttu/i
    ];
    if (junk.some(function (re) { return re.test(t); })) return true;
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
    t = t
      .replace(/Food\s+Advertisements\s+by\s*(\d+\.)/gi, '\n$1')
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

    var ingredients = colonIngs.length >= lineIngs.length ? colonIngs.slice() : lineIngs.slice();
    if (colonIngs.length >= 2 && lineIngs.length >= 2) {
      var seen = {};
      ingredients = [];
      colonIngs.concat(lineIngs).forEach(function (l) {
        var key = l.toLowerCase();
        if (!seen[key]) { seen[key] = true; ingredients.push(l); }
      });
    }

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
      goodStepCount: goodSteps.length,
      junkCount: junkCount,
      parserVersion: PARSER_VERSION
    };
  }

  return {
    PARSER_VERSION: PARSER_VERSION,
    PARSE_CONFIDENCE_ENRICH_MIN: PARSE_CONFIDENCE_ENRICH_MIN,
    BLOG_STOP_LINES: BLOG_STOP_LINES,
    isJunkMethodStep: isJunkMethodStep,
    normalizeRecipeImportText: normalizeRecipeImportText,
    segmentRecipeImportText: segmentRecipeImportText,
    computeImportConfidence: computeImportConfidence,
    extractRecipeMeta: extractRecipeMeta
  };
});
