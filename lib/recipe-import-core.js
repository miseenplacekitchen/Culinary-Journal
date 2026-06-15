/**
 * Wave 1 — single recipe import pipeline (browser + Node).
 * normalize → segment → confidence. No partial fallback layers.
 */
(function (root, factory) {
  var api = factory();
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.RecipeImportCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : typeof self !== 'undefined' ? self : this, function () {

  var PARSER_VERSION = '2.3.4-emoji-social-paste';
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
    /^related posts?/i, /^\d+\s+comments?$/i, /^until next time/i, /^sponsored\b/i, /^advertisement\b/i,
    /^note\s*:/i, /^love$/i, /^veena$/i, /^vinu$/i, /^loading$/i,
    /^tips?\s*:?\s*$/i, /^notes?\s*(?:&\s*tips?)?\s*:?\s*$/i, /^clarity\s*check\s*:?\s*$/i,
    /^clarity_check$/i, /^optional\s+notes\s*:?\s*$/i, /^mode\s*:/i,
    /^\d[\d,.\s]*\s+likes?\b/i, /^\d[\d,.\s]*\s+comments?\b/i, /\bon instagram\b/i,
    /\bview this (?:post|reel|video)\b/i, /^follow\s+@/i, /^see more on instagram\b/i
  ];

  var ING_GROUP_PHRASES = /^(chicken\s+marinade|fried\s+garnish|layering\s+and\s+finishing|optional\s+for\s+serving|for\s+(?:the\s+)?marinade|for\s+(?:the\s+)?gravy|main\s+dough|dough\s+preparation)$/i;
  var ING_GROUP_WORDS = /^(rice|masala|marinade|garnish|dough|sauce|filling|optional|layering|dusting|stock|broth|tempering)$/i;

  var META_LABEL = /^(preparation\s+time|prep\s+time|cooking\s+time|cook\s+time|serves?|servings?|yield|ingredients?|method|directions?|spice\s+level|sweet\s+level|recipe\s+name)$/i;

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
    if (/^please\s+confirm/i.test(t)) return true;
    if (/^confirm\s+/i.test(t)) return true;
    if (/^this\s+may\s+be\s+a\s+typo/i.test(t)) return true;
    if (/^clarity\s*check/i.test(t)) return true;
    if (/^spice\s*level/i.test(t) || /^sweet\s*level/i.test(t)) return true;
    if (/^serv(es|ings?)$/i.test(t)) return true;
    if (/^\(?\d+\s+to\s+\d+\)?\s+is\s+an\s+estimate/i.test(t)) return true;
    if (t.length <= 18 && /^[A-Za-z][a-z]{2,14}$/.test(t) && !/\b(rice|chicken|onion|salt|water|heat|add|mix)\b/i.test(t)) return true;
    if (t.length < 28 && /^serve\s+(hot|with|warm)/i.test(t) && !/\b(heat|add|mix|stir|place|cover|knead|roll)\b/i.test(t)) return true;
    if (t.length < 18 && /^(?:serves?|yield)\s*:?\s*[\d\u00BC]/i.test(t)) return true;
    return false;
  }

  function isPostRecipeBoundary(line) {
    var t = String(line || '').trim();
    if (!t) return false;
    return /^(?:tips?|notes?|cooking\s+notes?|clarity_check|clarity\s+check|optional\s+notes|spice_level|sweet_level|mode)\s*:?$/i.test(t)
      || /^please\s+confirm/i.test(t)
      || /^this\s+may\s+be\s+a\s+typo/i.test(t);
  }

  function isIngredientGroupHeader(line, nextLine) {
    var t = String(line || '').trim().replace(/\s*:?\s*$/, '');
    if (!t || t.length > 55 || t.length < 3) return false;
    if (/\d/.test(t) || /^\d+\./.test(t)) return false;
    if (/^ingredients?$/i.test(t) || META_LABEL.test(t) || /^method$/i.test(t)) return false;
    if (ING_GROUP_PHRASES.test(t) || ING_GROUP_WORDS.test(t)) return true;
    if (/^for\s+(?:the\s+)?[a-z]/i.test(t)) return true;
    if (nextLine) {
      var n = String(nextLine).trim();
      if (/^[\d\u00BC½]/.test(n) || /\s:\s*[\d\u00BC\/]/.test(n) || /\s+-\s+[\d\u00BC\/]/.test(n)) return true;
      if (/^(handful|pinch|to taste|\d)/i.test(n)) return true;
      if (/^[A-Za-z].+\s*:\s*\d/.test(n)) return true;
    }
    return false;
  }

  function spiceSweetFromRating(n, kind) {
    var num = parseInt(n, 10);
    if (!num || num < 1 || num > 5) return null;
    if (kind === 'spice') {
      return ['', 'Mild', 'Medium', 'Hot', 'Very Hot', 'Extremely Hot'][num];
    }
    return ['', 'Subtly Sweet', 'Lightly Sweet', 'Sweet', 'Very Sweet', 'Extremely Sweet'][num];
  }

  function parseDurationToMinutes(text) {
    var s = String(text || '').trim().toLowerCase();
    if (!s) return null;
    s = s.replace(/\[[^\]]+\]/g, '').replace(/\([^)]*source[^)]*\)/gi, '').trim();
    var hm = s.match(/(\d+)\s*h(?:r|our)?s?(?:\s*(\d+)\s*m(?:in(?:ute)?s?)?)?/);
    if (hm) {
      var h = parseInt(hm[1], 10) || 0;
      var m = parseInt(hm[2], 10) || 0;
      return String(h * 60 + m);
    }
    var range = s.match(/(\d+)\s*(?:-|–|to)\s*(\d+)\s*(?:mins?|minutes?)/);
    if (range) return String(Math.round((parseInt(range[1], 10) + parseInt(range[2], 10)) / 2));
    var min = s.match(/(\d+)\s*(?:mins?|minutes?)/);
    if (min) return min[1];
    var plain = s.match(/^(\d+)$/);
    if (plain) return plain[1];
    return null;
  }

  function stripAnnotationScaffolding(text) {
    return String(text || '')
      .replace(/\s*\[(?:estimated|from source)\]/gi, '')
      .replace(/\s*\(from source\)/gi, '');
  }

  function extractAuxFromRaw(rawText) {
    var blob = String(rawText || '');
    var lines = blob.split('\n').map(function (l) { return l.trim(); }).filter(Boolean);
    var out = { title: '', description: '', spiceLabel: null, sweetLabel: null };
    lines.forEach(function (ln, idx) {
      if (/^recipe\s+name\s*:/i.test(ln)) out.title = ln.replace(/^recipe\s+name\s*:\s*/i, '').trim();
      else if (!out.title && idx < 3 && isLikelyTitleLine(ln)) out.title = ln;
    });
    var sp = blob.match(/spice\s*level\s*:\s*(?:[^\d\n]*?)?(\d)\s*\/\s*5/i);
    if (sp) out.spiceLabel = spiceSweetFromRating(sp[1], 'spice');
    var sw = blob.match(/sweet\s*level\s*:\s*(?:[^\d\n]*?)?(\d)\s*\/\s*5/i);
    if (sw) out.sweetLabel = spiceSweetFromRating(sw[1], 'sweet');
    var ingIdx = -1;
    for (var i = 0; i < lines.length; i++) {
      if (/^ingredients?\s*:?\s*$/i.test(lines[i])) { ingIdx = i; break; }
    }
    var desc = [];
    var end = ingIdx >= 0 ? ingIdx : Math.min(lines.length, 12);
    for (var d = 0; d < end; d++) {
      var ln = lines[d];
      if (!ln || ln === out.title) continue;
      if (/^recipe\s+name\s*:/i.test(ln)) continue;
      if (/^(prep|cook|serv|spice|sweet)\s+/i.test(ln)) continue;
      if (/level\s*:/i.test(ln)) continue;
      if (ln.length > 35 && /[a-z]{4,}/i.test(ln) && !/^ingredients?$/i.test(ln)) desc.push(stripAnnotationScaffolding(ln));
    }
    if (desc.length) out.description = desc.join(' ').trim().slice(0, 800);
    return out;
  }

  function countRealIngredients(ingredients) {
    var n = 0;
    for (var i = 0; i < (ingredients || []).length; i++) {
      if (!isIngredientGroupHeader(ingredients[i], ingredients[i + 1])) n++;
    }
    return n;
  }

  function normalizeIngredientListWithHeaders(ingredients) {
    var out = [];
    for (var i = 0; i < (ingredients || []).length; i++) {
      var ln = ingredients[i];
      if (isIngredientGroupHeader(ln, ingredients[i + 1])) {
        out.push(String(ln).replace(/\s*:?\s*$/, '') + ':');
      } else {
        out.push(ln);
      }
    }
    return out;
  }

  function looksLikeMethodProseStep(line) {
    var t = String(line || '').trim();
    if (!t || t.length < 8 || t.length > 900) return false;
    if (/^\d+[\.\):\-]\s/.test(t)) return false;
    if (/^method$/i.test(t) || /^ingredients?$/i.test(t) || META_LABEL.test(t)) return false;
    if (isPostRecipeBoundary(t) || isStopLine(t) || isJunkMethodStep(t)) return false;
    if (isIngredientGroupHeader(t, '')) return false;
    return /\b(mix|add|heat|stir|cook|bake|combine|wash|drain|fry|layer|serve|rest|cover|bring|simmer|preheat|knead|roll|fold|place|remove|transfer|season|garnish|whisk|blend|chop|slice|marinate|divide|spread|repeat|drizzle|seal|fluff|saute|sauté|parboil|boil|steam|toast|brown|reduce|allow|set\s+aside|keep\s+aside|preheat|grease|line|fill|spread|top|bottom|finish|assemble)\b/i.test(t);
  }

  function isMethodStageHeader(line, nextLine) {
    var t = String(line || '').trim().replace(/\s*:?\s*$/, '');
    if (!t || t.length > 65 || t.length < 4) return false;
    if (/^\d+[\.\):\-]\s/.test(t)) return false;
    if (/^method$/i.test(t) || /^ingredients?$/i.test(t) || /^prep\s+work$/i.test(t) || /^directions?$/i.test(t) || /^instructions?$/i.test(t) || /^procedure$/i.test(t) || META_LABEL.test(t)) return false;
    if (isPostRecipeBoundary(t) || isStopLine(t)) return false;
    if (isIngredientGroupHeader(line, nextLine)) return false;
    var n = String(nextLine || '').trim();
    if (n && (/^\d+[\.\):\-]\s+\S/.test(n) || looksLikeMethodProseStep(n))) return true;
    if (/^(?:for\s+the\s+|now\s+the\s+)?[a-z][\w\s]{2,48}$/i.test(t) && /(preparation|cooking|layering|marinating|assembly|garnish|finishing|rolling|holding|dough)/i.test(t)) return true;
    return false;
  }

  function parseMethodStepLine(ln) {
    var t = String(ln || '').trim();
    if (!t) return null;
    var numMatch = t.match(/^(\d+)[\.\):\-]\s*(.+)$/);
    if (numMatch) {
      var numbered = numMatch[2].trim();
      if (!numbered || isJunkMethodStep(numbered)) return null;
      return { num: numMatch[1], text: numbered };
    }
    if (looksLikeMethodProseStep(t)) return { num: null, text: t };
    return null;
  }

  function buildMethodSections(methRegion) {
    var sections = [];
    var cur = null;
    var flat = [];
    (methRegion || []).forEach(function (ln, idx) {
      if (!ln || /^method$/i.test(ln) || /^how\s+to\s+make\b/i.test(ln)) return;
      if (/^(?:prep\s+work|directions?|instructions?|procedure|steps?)$/i.test(ln)) return;
      var next = methRegion[idx + 1] || '';
      if (isMethodStageHeader(ln, next)) {
        cur = { name: ln.replace(/\s*:?\s*$/, ''), steps: [] };
        sections.push(cur);
        return;
      }
      var step = parseMethodStepLine(ln);
      if (step) {
        if (!cur) {
          cur = { name: 'DIRECTIONS', steps: [] };
          sections.push(cur);
        }
        cur.steps.push(step);
        flat.push(step.text);
      }
    });
    sections = sections.filter(function (sec) { return (sec.steps || []).length > 0; });
    if (!sections.length && flat.length) {
      sections.push({ name: 'DIRECTIONS', steps: flat.map(function (txt) { return { num: null, text: txt }; }) });
    }
    return { sections: sections, flat: flat };
  }

  function buildIngredientPasteBlock(ingredients) {
    var parts = ['INGREDIENTS'];
    (ingredients || []).forEach(function (ln, idx) {
      if (isIngredientGroupHeader(ln, ingredients[idx + 1]) || /:\s*$/.test(String(ln || ''))) {
        parts.push(String(ln).replace(/\s*:?\s*$/, ''));
      } else {
        parts.push(ln);
      }
    });
    return parts.join('\n');
  }

  function stepEntryText(step) {
    return typeof step === 'string' ? step : (step && step.text ? step.text : '');
  }

  function buildMethodPasteBlock(methodSections) {
    var parts = ['METHOD'];
    (methodSections || []).forEach(function (sec) {
      if (sec.name && !/^directions$/i.test(sec.name)) parts.push(sec.name);
      (sec.steps || []).forEach(function (step, idx) {
        var text = stepEntryText(step);
        if (!text) return;
        var num = (step && step.num) ? step.num : String(idx + 1);
        parts.push(num + '. ' + text);
      });
    });
    return parts.join('\n');
  }

  function countImportPollution(ingredientLines, methodSteps) {
    var headerAsIngredient = 0;
    var commentaryAsStep = 0;
    var junkSteps = 0;
    (ingredientLines || []).forEach(function (l, i) {
      var t = String(l || '').trim();
      if (isIngredientGroupHeader(l, ingredientLines[i + 1]) && !/:\s*$/.test(t)) headerAsIngredient++;
    });
    (methodSteps || []).forEach(function (s) {
      if (isJunkMethodStep(s)) junkSteps++;
      if (/please\s+confirm|this\s+may\s+be\s+a\s+typo|clarity\s*check/i.test(String(s || ''))) commentaryAsStep++;
    });
    return { headerAsIngredient: headerAsIngredient, commentaryAsStep: commentaryAsStep, junkSteps: junkSteps };
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

  function stripLeadingEmoji(line) {
    var s = String(line || '').trim();
    return s.replace(/^(?:[\uD800-\uDBFF][\uDC00-\uDFFF]|[\u2600-\u27BF]|\uFE0F|\u200D|\u{1F300}-\u{1FAFF})+\s*/u, '').trim();
  }

  function looksLikeSocialMetadataCaption(text) {
    if (!text || text.length < 20) return false;
    var t = String(text).toLowerCase();
    var hits = 0;
    if (/\d[\d,.\s]*\s+likes?\b/.test(t)) hits++;
    if (/\d[\d,.\s]*\s+comments?\b/.test(t)) hits++;
    if (/\bon instagram\b/.test(t) || /\binstagram\.com\b/.test(t)) hits++;
    if (/\bview this (?:post|reel|video)\b/.test(t)) hits++;
    if (/\bfollow\s+@/.test(t)) hits++;
    if (hits >= 2) return true;
    if (hits >= 1 && !/\b(ingredients?|method|instructions?|directions?)\b/.test(t)) return true;
    return false;
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
    var t = stripAnnotationScaffolding(String(text).replace(/\r\n/g, '\n'));
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
      .replace(/(?:^|\n)\s*(?:METHOD|INSTRUCTIONS?|DIRECTIONS?|STEPS?|PROCEDURE|PREP\s+WORK)\s*:?\s*/gi, '\nMETHOD\n')
      .replace(/(?:^|\n)\s*(?:COOKING\s+)?NOTES?\s*(?:&\s*TIPS?)?\s*:?\s*/gi, '\nNOTES\n')
      .replace(/(?:^|\n)\s*(?:TIPS?|HINTS?|TRICKS?|VARIATIONS?)\s*:?\s*/gi, '\nTIPS\n')
      .replace(/(?:^|\n)\s*clarity\s*check\s*:?\s*/gi, '\nCLARITY_CHECK\n')
      .replace(/(?:^|\n)\s*(?:SERVES?|SERVINGS?|YIELD)\s*:\s*([^\n]+)/gi, '\nSERVES\n$1\n');

    var expanded = [];
    t.split('\n').forEach(function (raw) {
      var line = stripLeadingEmoji(raw.replace(/\s+/g, ' ').trim());
      if (!line) return;
      if (/^[-•*–—]\s+/.test(line)) line = line.replace(/^[-•*–—]\s+/, '');
      if (/^ingredients?$/i.test(line)) { expanded.push('INGREDIENTS'); return; }
      if (/^method$/i.test(line)) { expanded.push('METHOD'); return; }
      if (/^(?:prep\s+work|directions?|instructions?|procedure|steps?)$/i.test(line)) { expanded.push('METHOD'); return; }
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
    var meta = { prep: null, cook: null, servings: null, servingsRange: null };
    var blob = stripAnnotationScaffolding(String(text || ''));
    var prepM = blob.match(/(?:preparation|prep)\s+time\s*:\s*([^\n]+)/i);
    if (prepM) meta.prep = parseDurationToMinutes(prepM[1]);
    var cookM = blob.match(/(?:cooking|cook)\s+time\s*:\s*([^\n]+)/i);
    if (cookM) meta.cook = parseDurationToMinutes(cookM[1]);
    var servRange = blob.match(/(?:serves?|servings?|yield)\s*:\s*(\d+)\s*(?:to|-|–)\s*(\d+)/i);
    if (servRange) {
      meta.servingsRange = servRange[1] + '-' + servRange[2];
      meta.servings = servRange[1];
    } else {
      var serv = blob.match(/(?:serves?|servings?|yield)\s*:\s*(\d+)/i);
      if (serv) meta.servings = serv[1];
    }
    return meta;
  }

  function isStopLine(line) {
    return BLOG_STOP_LINES.some(function (re) { return re.test(line); });
  }

  function segmentRecipeImportText(rawText) {
    var warnings = [];
    var auxRaw = extractAuxFromRaw(rawText);
    var meta = extractRecipeMeta(rawText);
    var normalizedText = normalizeRecipeImportText(rawText);
    var lines = normalizedText.split('\n').map(function (l) { return l.trim(); }).filter(Boolean);

    var title = auxRaw.title || '';
    for (var i = 0; i < Math.min(6, lines.length); i++) {
      if (!title && isLikelyTitleLine(lines[i])) { title = lines[i]; break; }
    }
    var ingHdr = -1, methHdr = -1;
    for (var j = 0; j < lines.length; j++) {
      var hdr = stripLeadingEmoji(lines[j]);
      if (ingHdr < 0 && /^ingredients?\s*:?\s*$/i.test(hdr)) ingHdr = j;
      if (methHdr < 0 && (
        /^method$/i.test(hdr) || /^how\s+to\s+make\b/i.test(hdr) ||
        /^instructions?$/i.test(hdr) || /^directions?$/i.test(hdr) ||
        /^procedure$/i.test(hdr) || /^steps?$/i.test(hdr) || /^prep\s+work$/i.test(hdr)
      )) methHdr = j;
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
        if (/^\d+[\.\):\-]\s+\S/.test(lines[b])) { methStart = b; break; }
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

    var sectionIdx = { tips: -1, notes: -1, clarity: -1, serves: -1 };
    for (var si = 0; si < lines.length; si++) {
      if (/^tips?$/i.test(lines[si])) sectionIdx.tips = si;
      if (/^notes?$/i.test(lines[si])) sectionIdx.notes = si;
      if (/^clarity_check$/i.test(lines[si])) sectionIdx.clarity = si;
      if (/^serves?$/i.test(lines[si])) sectionIdx.serves = si;
    }

    var ingRegion = lines.slice(ingStart, ingEnd);
    var methEnd = lines.length;
    for (var k = methStart >= 0 ? methStart : 0; k < lines.length; k++) {
      if (isStopLine(lines[k]) || isPostRecipeBoundary(lines[k]) || /^related posts?/i.test(lines[k])) {
        methEnd = k;
        break;
      }
    }
    [sectionIdx.tips, sectionIdx.notes, sectionIdx.clarity].forEach(function (idx) {
      if (idx >= 0 && idx < methEnd) methEnd = idx;
    });
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
    ingredients = normalizeIngredientListWithHeaders(ingredients.map(function (l) { return normalizeStuckBlogQty(l); }));

    var methodBundle = buildMethodSections(methRegion);
    var methodSections = methodBundle.sections;
    var method = methodBundle.flat.slice();
    if (method.length < 2) {
      var numbered = extractNumberedSteps(methRegion.join('\n'));
      if (numbered.length < 2) numbered = extractNumberedSteps(normalizedText);
      if (numbered.length < 2 && methStart < 0) {
        var tail = normalizedText.replace(/^[\s\S]*?(?=\d+\.\s+)/, '');
        numbered = extractNumberedSteps(tail);
      }
      method = numbered.filter(function (s) { return s && !isJunkMethodStep(s); });
    }
    if (!methodSections.length && method.length) {
      methodSections = [{ name: 'DIRECTIONS', steps: method.map(function (txt) { return { num: null, text: txt }; }) }];
    }

    var notes = [], tips = [], serves = [];
    lines.forEach(function (l) {
      if (/^serve\s+(hot|with|warm)/i.test(l) && l.length < 100) notes.push(l);
      if (/^(?:serves?|servings?|yield)\s*:\s*[\d\u00BC]/i.test(l)) serves.push(l.replace(/^(?:serves?|servings?|yield)\s*:?\s*/i, '').trim());
    });
    if (sectionIdx.serves >= 0 && sectionIdx.serves + 1 < lines.length) {
      var svLine = stripAnnotationScaffolding(lines[sectionIdx.serves + 1]);
      if (svLine && !/^(?:method|ingredients?)$/i.test(svLine)) serves.push(svLine);
    }
    if (meta.servingsRange && serves.indexOf(meta.servingsRange) < 0) serves.push(meta.servingsRange);
    else if (meta.servings && !serves.length) serves.push(meta.servings);

    if (sectionIdx.tips >= 0) {
      var tipsEnd = lines.length;
      [sectionIdx.notes, sectionIdx.clarity].forEach(function (idx) {
        if (idx > sectionIdx.tips && idx < tipsEnd) tipsEnd = idx;
      });
      for (var ti = sectionIdx.tips + 1; ti < tipsEnd; ti++) {
        var tl = lines[ti];
        if (!tl || isPostRecipeBoundary(tl) || /^\d+\.\s/.test(tl)) continue;
        if (tl.length > 4) tips.push(tl);
      }
    }
    if (sectionIdx.clarity >= 0) {
      warnings.push('Clarity Check notes were excluded from method steps — review source if needed');
    }

    var pasteParts = [];
    if (ingredients.length) pasteParts.push(buildIngredientPasteBlock(ingredients));
    if (methodSections.length) pasteParts.push(buildMethodPasteBlock(methodSections));
    else if (method.length) pasteParts.push('METHOD\n' + method.join('\n'));
    if (serves.length) pasteParts.push('SERVES\n' + serves.join('\n'));
    if (tips.length) pasteParts.push('TIPS\n' + tips.join('\n'));
    if (notes.length) pasteParts.push('NOTES\n' + notes.join('\n'));

    var realIngCount = countRealIngredients(ingredients);

    return {
      parserVersion: PARSER_VERSION,
      title: title,
      meta: meta,
      description: auxRaw.description || '',
      spiceLabel: auxRaw.spiceLabel,
      sweetLabel: auxRaw.sweetLabel,
      ingredients: ingredients,
      method: method,
      methodSections: methodSections,
      notes: notes,
      tips: tips,
      serves: serves,
      normalizedText: pasteParts.join('\n\n'),
      warnings: warnings,
      ingCount: realIngCount,
      methCount: method.length,
      hasContent: realIngCount > 0 || method.length > 0
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
      { re: /\b(mocktail|cocktail|martini|margarita|mojito|daiquiri|sangria|spritz|negroni|old fashioned|highball|sour|punch|liqueur|spirit|vodka|gin|rum|whiskey|whisky|bourbon|tequila|brandy|wine|beer|cider|prosecco|champagne|mezcal|aperol|campari|bitters|shandy)\b/, value: 'Sips & Stories' },
      { re: /\b(protein shake|protein drink|smoothie|juice|lassi|chai|tea|coffee|drink|shake|hot chocolate|cocoa|mocktail)\b/, value: 'Sips & Stories' },
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

    if (gold.ingredients_max != null && seg.ingCount > gold.ingredients_max) {
      issues.push('ingredients ' + seg.ingCount + ' above max ' + gold.ingredients_max);
      score -= 20;
    }
    if (gold.tips_min != null && (seg.tips || []).length < gold.tips_min) {
      issues.push('tips ' + (seg.tips || []).length + ' below min ' + gold.tips_min);
      score -= 20;
    }
    (gold.ingredient_must_not || []).forEach(function (bad) {
      var hasBad = (seg.ingredients || []).some(function (l) {
        var t = String(l || '').trim();
        return t === bad || (t.replace(/:\s*$/, '') === bad && !/:\s*$/.test(t));
      });
      if (hasBad) {
        issues.push('ingredient list must not contain bare header row: ' + bad);
        score -= 25;
      }
    });
    if (gold.meta_prep_minutes != null) {
      var prepN = seg.meta && seg.meta.prep ? parseInt(seg.meta.prep, 10) : null;
      if (prepN !== gold.meta_prep_minutes) {
        issues.push('prep minutes ' + prepN + ' expected ' + gold.meta_prep_minutes);
        score -= 15;
      }
    }
    if (gold.meta_cook_minutes != null) {
      var cookN = seg.meta && seg.meta.cook ? parseInt(seg.meta.cook, 10) : null;
      if (cookN !== gold.meta_cook_minutes) {
        issues.push('cook minutes ' + cookN + ' expected ' + gold.meta_cook_minutes);
        score -= 15;
      }
    }
    if (gold.spice_label && seg.spiceLabel !== gold.spice_label) {
      issues.push('spice label ' + seg.spiceLabel + ' expected ' + gold.spice_label);
      score -= 10;
    }
    if (gold.sweet_label && seg.sweetLabel !== gold.sweet_label) {
      issues.push('sweet label ' + seg.sweetLabel + ' expected ' + gold.sweet_label);
      score -= 10;
    }
    if (gold.ing_sections_min != null) {
      var ingSecCount = (seg.ingredients || []).filter(function (l, i) {
        return isIngredientGroupHeader(l, seg.ingredients[i + 1]) || /:\s*$/.test(String(l || ''));
      }).length;
      if (ingSecCount < gold.ing_sections_min) {
        issues.push('ingredient sections ' + ingSecCount + ' below min ' + gold.ing_sections_min);
        score -= 20;
      }
    }
    if (gold.method_sections_min != null) {
      var methSecCount = (seg.methodSections || []).length;
      if (methSecCount < gold.method_sections_min) {
        issues.push('method sections ' + methSecCount + ' below min ' + gold.method_sections_min);
        score -= 20;
      }
    }

    if (gold.auto_enrich === false) {
      var conf = computeImportConfidence(seg.ingCount, seg.method || [], [], seg.ingredients || []);
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

  function computeImportConfidence(ingCount, methodSteps, extraWarnings, ingredientLines) {
    var warnings = (extraWarnings || []).slice();
    var goodSteps = (methodSteps || []).filter(function (s) { return s && !isJunkMethodStep(s); });
    var junkCount = (methodSteps || []).length - goodSteps.length;
    var pollution = countImportPollution(ingredientLines || [], methodSteps || []);
    junkCount += pollution.junkSteps;
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
    if (pollution.headerAsIngredient > 0) {
      score -= Math.min(30, pollution.headerAsIngredient * 10);
      warnings.push(pollution.headerAsIngredient + ' section heading(s) may have been treated as ingredients');
    }
    if (pollution.commentaryAsStep > 0) {
      score -= Math.min(35, pollution.commentaryAsStep * 10);
      warnings.push(pollution.commentaryAsStep + ' review/note line(s) found in method — check steps');
    }
    if (ingCount < 2) warnings.push('Fewer than 2 ingredients — check the paste box');
    if (goodSteps.length < 2) warnings.push('Fewer than 2 method steps — check the paste box');
    score = Math.max(0, Math.min(100, score));
    var polluted = pollution.headerAsIngredient > 0 || pollution.commentaryAsStep > 0;
    return {
      score: score,
      warnings: warnings,
      allowEnrich: score >= PARSE_CONFIDENCE_ENRICH_MIN && ingCount >= 2 && goodSteps.length >= 2 && !polluted,
      submitWarn: score < PARSE_CONFIDENCE_SUBMIT_WARN_MIN || ingCount < 2 || goodSteps.length < 2 || polluted,
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
    isIngredientGroupHeader: isIngredientGroupHeader,
    isMethodStageHeader: isMethodStageHeader,
    looksLikeMethodProseStep: looksLikeMethodProseStep,
    buildMethodSections: buildMethodSections,
    normalizeRecipeImportText: normalizeRecipeImportText,
    segmentRecipeImportText: segmentRecipeImportText,
    computeImportConfidence: computeImportConfidence,
    extractRecipeMeta: extractRecipeMeta,
    normalizeMatchLine: normalizeMatchLine,
    inferRecipeCategoryFromBlob: inferRecipeCategoryFromBlob,
    splitBundledCaption: splitBundledCaption,
    looksLikeStructuredRecipe: looksLikeStructuredRecipe,
    looksLikeSocialMetadataCaption: looksLikeSocialMetadataCaption,
    stripLeadingEmoji: stripLeadingEmoji,
    evaluateStructuralGold: evaluateStructuralGold
  };
});
