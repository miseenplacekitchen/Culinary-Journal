/* Paste parse pipeline — extracted from submit-recipe.html */

// ── IMPROVED PASTE AREA HELPERS ───────────────────────────────────
<!-- extracted to lib/submit-recipe-paste-preprocess.js -->

function countValidParsedIngredients(ingSecs) {
  var total = 0;
  (ingSecs || []).forEach(function(sec) {
    (sec.items || []).forEach(function(item) {
      var i = reparseEmbeddedIngredientName(item || {});
      if (i && String(i.name || '').trim() && isValidParsedIngredient(i)) total++;
    });
  });
  return total;
}

function clearParseAutoMetadata() {
  document.querySelectorAll('input[name="category"],input[name="spice"],input[name="sweet"]').forEach(function(r) {
    r.checked = false;
  });
  ['tag-vegan','tag-veg','tag-gf','tag-df','tag-nf','tag-sf','tag-ef','tag-halal','tag-kosher',
   'tag-everyday','tag-trad','tag-quick','tag-comfort','tag-fp-mild',
   'tag-mt-breakfast','tag-mt-brunch','tag-mt-lunch','tag-mt-dinner','tag-mt-snack','tag-mt-drink',
   'tag-mt-soup','tag-mt-salad','tag-mt-main','tag-mt-side','tag-mt-appetizer','tag-mt-bread',
   'tag-mt-rice','tag-mt-dessert','tag-mt-frozen','tag-mt-preserve'].forEach(function(id) {
    var el = document.getElementById(id);
    if (el) el.checked = false;
  });
  var sub = document.getElementById('subsection-levels-tags');
  if (sub) sub.classList.remove('collapsed');
  var levelsPanel = document.getElementById('panel-levels');
  if (levelsPanel) levelsPanel.classList.remove('collapsed');
}

function buildIngSecsFromImportLines(lines) {
  var ingSecs = [];
  var cur = null;
  (lines || []).forEach(function(line) {
    var p = splitIngredientLine(line);
    if (p && p.header) {
      cur = { name: formatIngredientSectionName(p.name), items: [] };
      ingSecs.push(cur);
    } else if (p && (p.name || p.qty || p.unit)) {
      if (!cur) { cur = { name: 'INGREDIENTS', items: [] }; ingSecs.push(cur); }
      cur.items.push({
        qty: p.qty || '', unit: p.unit || '', name: p.name || '', note: p.note || ''
      });
    } else if (line && line.length > 1 && !/^ingredients?$/i.test(line)) {
      if (!cur) { cur = { name: 'INGREDIENTS', items: [] }; ingSecs.push(cur); }
      cur.items.push({ qty: '', unit: '', name: line, note: '' });
    }
  });
  if (!ingSecs.length) ingSecs.push({ name: 'INGREDIENTS', items: [] });
  return ingSecs;
}

function normalizeSegmentStep(step) {
  if (!step) return '';
  return typeof step === 'string' ? step : (step.text || '');
}

function buildMethSecsFromSegment(seg) {
  if (seg && seg.methodSections && seg.methodSections.length) {
    var fromSeg = seg.methodSections.map(function(sec) {
      return {
        name: String(sec.name || 'DIRECTIONS').toUpperCase(),
        steps: (sec.steps || []).map(normalizeSegmentStep).filter(Boolean)
      };
    }).filter(function(sec) { return (sec.steps || []).length > 0; });
    if (fromSeg.length) return fromSeg;
  }
  var flat = (seg && seg.method ? seg.method.slice() : []).filter(Boolean);
  return flat.length ? [{ name: 'DIRECTIONS', steps: flat }] : [];
}

function methSecsHaveSteps(methSecs) {
  return (methSecs || []).some(function(sec) { return (sec.steps || []).length > 0; });
}

function buildMethSecsWithPasteFallback(seg) {
  var methSecs = buildMethSecsFromSegment(seg);
  if (methSecsHaveSteps(methSecs)) return methSecs;
  var fromPaste = extractMethodSectionsFromPaste();
  if (!fromPaste.length) return methSecs;
  return fromPaste.map(function(sec) {
    return {
      name: String(sec.name || 'DIRECTIONS').toUpperCase(),
      steps: (sec.steps || []).map(function(st) {
        return typeof st === 'string' ? st : (st.text || '');
      }).filter(Boolean)
    };
  }).filter(function(sec) { return (sec.steps || []).length > 0; });
}

function finalizeParsedRecipe(ctx) {
  var ingSecs = ctx.ingSecs || [];
  var methSecs = filterMethSecsJunk(ctx.methSecs || []);
  var text = ctx.text || '';
  var titleCand = ctx.titleCand || '';
  var extraWarnings = ctx.extraWarnings || [];

  var validIngCount = countValidParsedIngredients(ingSecs);
  var rawIngCount = ingSecs.reduce(function(n, s) { return n + (s.items || []).length; }, 0);
  var core = (typeof RecipeImportCore !== 'undefined' ? RecipeImportCore : null);
  var flatSteps = [];
  methSecs.forEach(function(s) { flatSteps = flatSteps.concat(s.steps || []); });
  var flatIngLines = (ctx.importIngredientLines || []).slice();
  if (!flatIngLines.length) {
    ingSecs.forEach(function(sec) {
      if (sec.name && sec.name !== 'Ingredients') flatIngLines.push(sec.name + ':');
      (sec.items || []).forEach(function(it) {
        flatIngLines.push([it.qty, it.unit, it.name].filter(Boolean).join(' ').trim());
      });
    });
  }
  var confidence = (core && core.computeImportConfidence)
    ? core.computeImportConfidence(validIngCount, flatSteps, extraWarnings, flatIngLines)
    : computeParseConfidence(validIngCount, methSecs, extraWarnings, flatIngLines);
  if (rawIngCount > validIngCount) {
    confidence.warnings.push((rawIngCount - validIngCount) + ' ingredient line(s) look invalid');
    confidence.score = Math.max(0, confidence.score - Math.min(15, (rawIngCount - validIngCount) * 5));
    confidence.allowEnrich = confidence.score >= PARSE_CONFIDENCE_ENRICH_MIN && validIngCount >= 2 && confidence.goodStepCount >= 2;
  }
  window._lastParseConfidence = confidence;
  window._parseDroppedIng = 0;
  if (typeof TcjImportAudit !== 'undefined') {
    TcjImportAudit.recordParse(confidence, text);
  }

  var enrichResult = enrichAndApplyParsedMetadata({
    ingSecs: ingSecs,
    methSecs: methSecs,
    text: text,
    title: titleCand,
    skipEnrich: !confidence.allowEnrich
  });
  if (enrichResult && !enrichResult.skipped) {
    ingSecs = enrichResult.ingSecs || ingSecs;
    methSecs = enrichResult.methSecs || methSecs;
  } else if (enrichResult && enrichResult.skipped && !confidence.allowEnrich) {
    showParseReviewNote(
      'Import confidence ' + confidence.score + '/100 — verify ingredients, method, category, and tags before submitting.'
    );
  }

  var ingHost = document.getElementById('ingredient-sections');
  var methHost = document.getElementById('method-sections');
  if (ingHost) { ingHost.innerHTML = ''; ingSectionCount = 0; }
  if (methHost) { methHost.innerHTML = ''; methodSectionCount = 0; }

  var ingCount = 0;
  var stepCount = 0;
  var droppedIng = 0;

  if (ingSecs.length) {
    ingSecs.forEach(function(sec) {
      addIngSection(sec.name);
      var c = ingHost.lastChild.querySelector('.ing-rows');
      c.innerHTML = '';
      sec.items.forEach(function(item) {
        item = reparseEmbeddedIngredientName(item || {});
        if (!item || !(item.name || '').trim() || !isValidParsedIngredient(item)) {
          if (item && (item.name || item.qty || item.unit)) droppedIng++;
          return;
        }
        addIngRow(c, item.qty, item.unit, item.name, item.note || '', '');
        try { applyIngredientDbMatch(c.lastElementChild, { parsedNote: item.note || '', allowFuzzy: true }); } catch(e) { console.warn('tcj', e); }
        ingCount++;
      });
    });
  } else {
    addIngSection('Ingredients');
  }

  if (methSecs.length) {
    methSecs.forEach(function(sec) {
      addMethodSection(sec.name);
      var c = methHost.lastChild.querySelector('.step-rows');
      c.innerHTML = '';
      sec.steps.forEach(function(s) { addStep(c, s); stepCount++; });
    });
  } else {
    addMethodSection('PREP WORK');
    addMethodSection('DIRECTIONS');
  }

  if (droppedIng > 0) {
    confidence.warnings.push(droppedIng + ' ingredient row(s) dropped as invalid — check paste box');
    confidence.score = Math.max(0, confidence.score - Math.min(20, droppedIng * 6));
    confidence.allowEnrich = confidence.score >= PARSE_CONFIDENCE_ENRICH_MIN && ingCount >= 2 && stepCount >= 2;
    window._lastParseConfidence = confidence;
    window._parseDroppedIng = droppedIng;
  }

  var res = document.getElementById('parse-result');
  if (res) {
    if (ingCount > 0 || stepCount > 0) {
      var needsReview = !confidence.allowEnrich || confidence.submitWarn;
      res.className = 'sr-parse-result ' + (needsReview ? 'warn' : 'success');
      var enrichMsg = enrichResult && enrichResult.summary && enrichResult.summary.length
        ? ' Auto-filled: ' + enrichResult.summary.join(', ') + '. Uncheck anything inaccurate.'
        : (needsReview ? ' Metadata not auto-filled — review ingredients and method carefully.' : '');
      res.textContent = (needsReview ? '\u26A0' : '\u2713') + ' Detected ' + ingCount + ' ingredient' + (ingCount === 1 ? '' : 's')
        + ' across ' + ingSecs.length + ' section' + (ingSecs.length === 1 ? '' : 's')
        + ' and ' + stepCount + ' step' + (stepCount === 1 ? '' : 's') + '.' + enrichMsg
        + (enrichResult && enrichResult.summary ? ' See Import Review below for checklist.' : ' Source text kept in paste box.');
      showImportConfidenceBanner(confidence, ingCount, stepCount);
      var scrollTarget = needsReview ? document.getElementById('section-paste') : document.getElementById('section-ingredients');
      if (scrollTarget) setTimeout(function() { scrollTarget.scrollIntoView({ behavior:'smooth', block:'start' }); }, 400);
    } else {
      showImportConfidenceBanner(null);
      res.className = 'sr-parse-result warn';
      res.textContent = 'Text was detected but could not be structured automatically. Check the paste box and add clear Ingredients / Method headings.';
    }
    res.style.display = 'block';
  }
}

function parseRecipeViaSegment(seg, rawText) {
  var titleCand = seg.title || '';
  if (titleCand) {
    var nameEl = document.getElementById('recipe-name');
    if (nameEl && !nameEl.value.trim()) nameEl.value = titleCand.replace(/^recipe\s*:\s*/i, '').trim();
  }
  if (seg.meta) applyBlogMetaToForm(seg.meta);
  if (seg.description) setFormTextIfEmpty('introduction', seg.description);
  if (seg.spiceLabel) ensureFormRadio('spice', seg.spiceLabel);
  if (seg.sweetLabel) ensureFormRadio('sweet', seg.sweetLabel);
  populateAuxiliaryFromSections({ notes: seg.notes || [], tips: seg.tips || [], serves: seg.serves || [] });
  var ingSecs = buildIngSecsFromImportLines(seg.ingredients);
  ingSecs.forEach(function(sec) { sec.items = consolidateParsedItems(sec.items); });
  ingSecs = ingSecs.filter(function(sec) { return (sec.items || []).length > 0; });
  finalizeParsedRecipe({
    ingSecs: ingSecs,
    methSecs: buildMethSecsWithPasteFallback(seg),
    text: seg.normalizedText || rawText,
    titleCand: titleCand,
    extraWarnings: (seg.warnings || []).slice(),
    importIngredientLines: (seg.ingredients || []).slice(),
    fromSegment: true
  });
}

function parseRecipe() {
  const el = document.getElementById('paste-input');
  const raw = el ? el.value.trim() : '';
  if (!raw) { showMsg('Please paste recipe text first.', 'error'); return; }

  const core = (typeof RecipeImportCore !== 'undefined' ? RecipeImportCore : null);
  expandPasteSection();

  if (core && core.segmentRecipeImportText) {
    const seg = core.segmentRecipeImportText(raw);
    /* Keep the contributor's full paste — do not replace with the shorter structured extract. */
    if (seg.meta) applyBlogMetaToForm(seg.meta);
    populateAuxiliaryFromSections({ notes: seg.notes || [], tips: seg.tips || [], serves: seg.serves || [] });
    if (seg.hasContent && !(seg.ingCount === 0 && seg.methCount === 0)) {
      parseRecipeViaSegment(seg, raw);
      return;
    }
  }

  const text = preprocessRecipeText(raw);
  /* Legacy path: keep original paste text in the box; parser uses preprocessed copy only. */

  // ── Legacy line parser (unusual layouts only) ─────────────────────────────
  const stripBullet = s => s.replace(/^[\u2022\u00b7\u2023\u2043*\-\u2013\u2014\u25AA\u25CF\u25CB\u2713\u2714]\s+/, '').trim();
  const rawLines    = pairMultilineIngredientLines(text.split('\n').map(l => stripBullet(l.trim())).filter(l => l.length > 0));
  applyBlogMetaToForm(parseBlogMetaFromLines(rawLines));

  importAuxSectionsFromRawLines(rawLines);

  // Detect recipe title from first short line (before sections) — never an ingredient line
  const titleCand = rawLines[0];
  if (titleCand && isLikelyRecipeTitleLine(titleCand)) {
    const nameEl = document.getElementById('recipe-name');
    if (nameEl && !nameEl.value.trim()) nameEl.value = titleCand.replace(/^recipe\s*:\s*/i,'').trim();
  }

  // ── Section header patterns ───────────────────────────────────────────────
  // Method headers — trigger method mode
  const METH_HDR = /^(prep\s+work|directions?|method|steps?|instructions?|procedure|how\s+to\s+(?:make|cook|prepare)(?:\s+.+)?|to\s+(?:make|cook|serve)|to\s+assemble)\s*:?\s*$/i;

  // Ingredient sub-section headers — named groups, e.g. "For the Marinade:" / "For Marination"
  const ING_SUB = /^(?:for\s+(?:the\s+)?(.+?)|(?:the\s+)?(.+?))\s*:$/i;
  const ING_SUB_WORDS = /^(sauce|filling|topping|garnish|marinade|marinate|marination|batter|crust|glaze|frosting|icing|dressing|stuffing|coating|base|pastry|dough|syrup|broth|stock|spice\s*mix|spice\s*blend|masala|tadka|tempering|tempering\s*spices|paste|chutney|raita|salsa|pickle|pickle\s*brine|gravy|curry\s*base|to\s+serve|serving|assembly|to\s+assemble)\s*:?$/i;

  // Explicit ingredient header
  const ING_HDR  = /^(ingredients?)\s*:?\s*$/i;

  // ── Parsing state ─────────────────────────────────────────────────────────
  let ingSecs    = [];
  let methSecs   = [];
  let curIng     = null;
  let curMeth    = null;
  let inMethod   = false;
  let absorbAux  = false;

  const pushIng  = () => { if (curIng  && curIng.items.length)  ingSecs.push(curIng);   curIng  = null; };
  const pushMeth = () => { if (curMeth && curMeth.steps.length) methSecs.push(curMeth); curMeth = null; };

  const startIngSection = (name) => {
    pushIng();
    curIng = { name: formatIngredientSectionName(name || 'Ingredients'), items: [] };
  };
  const startMethSection = (name) => {
    pushMeth();
    curMeth = { name: (name || 'DIRECTIONS').toUpperCase(), steps: [] };
  };

  const pushMethodStep = (stepText) => {
    if (!stepText || isJunkMethodStep(stepText)) return;
    expandMethodStepText(stepText).forEach(function(part) {
      if (part && !isJunkMethodStep(part)) curMeth.steps.push(part);
    });
  };

  let pendingPartial = null;
  const flushPendingPartial = () => {
    if (pendingPartial) {
      if (pendingPartial.name && isValidParsedIngredient(pendingPartial)) {
        if (!curIng) startIngSection('Ingredients');
        curIng.items.push(pendingPartial);
      } else if (!pendingPartial.name && (pendingPartial.qty || pendingPartial.unit || pendingPartial.note)) {
        if (curIng && curIng.items.length) {
          var lastItem = curIng.items[curIng.items.length - 1];
          if (!lastItem.qty && !lastItem.unit) {
            lastItem.qty = pendingPartial.qty || '';
            lastItem.unit = pendingPartial.unit || '';
            if (pendingPartial.note) {
              lastItem.note = lastItem.note ? lastItem.note + '; ' + pendingPartial.note : pendingPartial.note;
            }
          }
        }
      }
    }
    pendingPartial = null;
  };
  const pushIngredientItem = (item) => {
    if (!item) return;
    item.name = (item.name || '').trim();
    if (pendingPartial) {
      if (item.name && !isQtyUnitFragment(item.name) && !isFragmentIngredientName(item.name) && !isEmbeddedPrefixIngredientName(item.name)) {
        if (!item.qty && !item.unit) {
          item.qty = pendingPartial.qty || '';
          item.unit = pendingPartial.unit || '';
          item.note = item.note || pendingPartial.note || '';
        }
        pendingPartial = null;
      } else {
        if (isValidParsedIngredient(pendingPartial)) {
          if (!curIng) startIngSection('Ingredients');
          curIng.items.push(pendingPartial);
        }
        pendingPartial = null;
      }
    }
    if (!item.name && (item.qty || item.unit)) {
      if (!item.qty && item.unit) return;
      pendingPartial = { qty: item.qty || '', unit: item.unit || '', name: '', note: item.note || '' };
      return;
    }
    if (item.name && isQtyUnitFragment(item.name)) {
      var frag = extractQtyUnitFragment(item.name);
      if (frag && !frag.rest) {
        pendingPartial = { qty: frag.qty, unit: frag.unit, name: '', note: item.note || '' };
        return;
      }
      if (frag && frag.rest) {
        item.qty = item.qty || frag.qty;
        item.unit = item.unit || frag.unit;
        item.name = frag.rest;
      }
    }
    item = reparseEmbeddedIngredientName(item);
    item.name = normalizeIngredientAlias(titleCaseIngredientName(item.name))
      .replace(/\s+as\s+needed$/i, '').replace(/\s+as\s+reqd$/i, '').trim();
    if (!item.unit) item.unit = inferIngredientUnit(item.name, item.qty);
    item.name = stripRedundantUnitFromName(item.name, item.unit);
    if (!item.qty && !item.note && /\b(water|lemon juice)\b/i.test(item.name)) item.note = 'as needed';
    if (isValidParsedIngredient(item)) {
      if (!curIng) startIngSection('Ingredients');
      curIng.items.push(item);
    }
  };

  const methLineIdx = rawLines.findIndex(function(l) { return METH_HDR.test(l); });
  const ingLineIdx  = rawLines.findIndex(function(l) { return ING_HDR.test(l); });

  if (ingLineIdx < 0 && methLineIdx > 0) {
    startIngSection('Ingredients');
  }

  const looksLikeIngLine = (line) => {
    if (isBareIngredientLine(line)) return true;
    if (splitIngredientLine(line)) return true;
    if (line.length < 3 || line.length > 120) return false;
    if (/[.!?]{2,}/.test(line)) return false;
    if (/^(?:step\s*)?\d+[\.\)]\s/i.test(line)) return false;
    if (/\b(tsp|tbsp|cup|cups|g|kg|ml|oz|lb|pinch|clove|slice|piece)\b/i.test(line)) return true;
    if (/^[\d\u00BC-\u00BE\/]/.test(line)) return true;
    return /^[a-zA-Z][\w\s\-'(),]{2,}$/.test(line) && line.split(/\s+/).length <= 10;
  };

  for (let lineIdx = 0; lineIdx < rawLines.length; lineIdx++) {
    const line = rawLines[lineIdx];
    if (methLineIdx >= 0 && lineIdx > methLineIdx) inMethod = true;
    else if (methLineIdx >= 0 && lineIdx < methLineIdx) inMethod = false;
    else if (ingLineIdx >= 0 && lineIdx >= ingLineIdx && lineIdx < (methLineIdx >= 0 ? methLineIdx : rawLines.length)) inMethod = false;

    if (line === titleCand && isLikelyRecipeTitleLine(titleCand) && !inMethod && !ING_HDR.test(line) && (ingLineIdx < 0 || lineIdx < ingLineIdx)) continue;
    // Skip metadata-style lines [source]: ...
    if (/^\[[^\]]+\]\s*:/i.test(line)) continue;
    // Skip very long lines that look like story prose (over 180 chars with no numbers)
    if (line.length > 180 && !/\d/.test(line)) continue;
    if (!inMethod && isOrphanAltQtyLine(line)) {
      var altText = line.replace(/^\(|\)$/g, '').trim();
      if (pendingPartial) {
        pendingPartial.note = pendingPartial.note ? pendingPartial.note + '; ' + altText : altText;
      } else if (curIng && curIng.items.length) {
        var prevItem = curIng.items[curIng.items.length - 1];
        prevItem.note = prevItem.note ? prevItem.note + '; ' + altText : altText;
      } else {
        pendingPartial = { qty: '', unit: '', name: '', note: altText };
      }
      continue;
    }

    // ── Header detection ─────────────────────────────────────────────────────
    if (METH_HDR.test(line)) {
      flushPendingPartial();
      var methLabel = /^method$/i.test(line.trim()) ? 'DIRECTIONS' : line.replace(/\s*:?\s*$/,'');
      pushIng(); startMethSection(methLabel);
      inMethod = true; continue;
    }
    if (ING_HDR.test(line)) {
      flushPendingPartial();
      pushMeth(); startIngSection('Ingredients');
      inMethod = false; continue;
    }
    // Named ingredient sub-section: "For the Marinade:" / "For Marination" / "Sauce:" etc.
    if (!inMethod && (isIngredientSubHeader(line) || ING_SUB_WORDS.test(line) || ING_SUB.test(line))) {
      flushPendingPartial();
      const label = line.replace(/\s*:?\s*$/, '');
      startIngSection(label);
      continue;
    }
    if (inMethod && /^(?:notes?|cooking\s+notes?(?:\s*&\s*tips?)?|tips?|hints?|tricks?|variations?)\s*:?$/i.test(line)) {
      absorbAux = true;
      continue;
    }
    if (inMethod && /^(?:step\s*)?\d+[\.\):\-]\s*(?:notes?|cooking\s+notes?|tips?)\s*:?$/i.test(line)) {
      absorbAux = true;
      continue;
    }
    if (absorbAux) {
      if (/^(?:ingredients?|method|directions?|instructions?|steps?)\s*:?$/i.test(line)) {
        absorbAux = false;
      } else if (line) {
        if (isRecipeTipOrNoteLine(line) || isMethodAttributionLine(line) || absorbAux) {
          appendCookingNote(line);
        }
        continue;
      }
    }
    if (inMethod && /^(?:serves?|servings?|yield)\s*:?\s*[\d\u00BC]/i.test(line)) {
      var serveN = parseServesNumber([line]);
      if (serveN) setFormNumberIfEmpty('servings', serveN);
      continue;
    }
    if (inMethod && /^serve\s+(hot|with|warm)/i.test(line) && line.length < 90) {
      appendCookingNote(line);
      continue;
    }
    if (inMethod && /^(to\s+serve|serving\s+suggestion)\s*:?$/i.test(line)) {
      absorbAux = true;
      continue;
    }
    if (inMethod && isMethodSectionHeader(line, rawLines[lineIdx + 1])) {
      flushPendingPartial();
      startMethSection(line.replace(/\s*:?\s*$/, ''));
      continue;
    }

    // ── Content lines ─────────────────────────────────────────────────────────
    if (inMethod) {
      if (!curMeth) startMethSection('DIRECTIONS');
      if (/^(?:so\s+)?ur\s+\w+\s+is\s+ready/i.test(line)) continue;
      if (isMethodAttributionLine(line)) {
        appendCookingNote(line);
        continue;
      }
      const stepChunks = line.replace(/^(?:step\s*)?\d+[\.\)]\s*/i, '').trim();
      if (stepChunks) {
        stepChunks.split(/\s*(?:(?:method|step)\s+\d+\s+of\s+\d+)\s*/i).forEach(function(chunk) {
          const t = chunk.replace(/\s+\d+\s*\/\s*\d+\s*$/,'').trim();
          pushMethodStep(t);
        });
      }

    } else {
      if (!curIng) startIngSection('Ingredients');
      const parsed = splitIngredientLine(line);
      if (parsed && parsed.header) {
        flushPendingPartial();
        startIngSection(parsed.name);
      } else if (parsed && (parsed.name || parsed.qty || parsed.unit)) {
        pushIngredientItem({
          qty: parsed.qty || '', unit: parsed.unit || '',
          name: parsed.name || '', note: parsed.note || ''
        });
      } else if (looksLikeIngLine(line) && !isQtyUnitFragment(line) && !isFragmentIngredientName(line) && !isEmbeddedPrefixIngredientName(line) && !isRecipeTitleEchoLine(line)) {
        pushIngredientItem({ qty: '', unit: '', name: line, note: '' });
      } else if (/^(?:step\s*)?\d+[\.\):\-]\s+\S/i.test(line)) {
        flushPendingPartial();
        inMethod = true;
        pushIng();
        startMethSection('DIRECTIONS');
        const stepText = line.replace(/^(?:step\s*)?\d+[\.\):\-]\s*/i, '').trim();
        pushMethodStep(stepText);
      }
    }
  }
  flushPendingPartial();
  pushIng(); pushMeth();

  ingSecs.forEach(function(sec) {
    sec.items = consolidateParsedItems(sec.items);
  });
  methSecs.forEach(function(sec) {
    sec.steps = expandLongMethodSteps(sec.steps);
  });
  methSecs = filterMethSecsJunk(methSecs);

  // Fallback: split blocks when headers were missed
  if (!ingSecs.some(s => s.items.length) && methSecs.every(s => !s.steps.length)) {
    const ingIdx = rawLines.findIndex(l => ING_HDR.test(l));
    const methIdx = rawLines.findIndex(l => METH_HDR.test(l));
    if (ingIdx >= 0 && methIdx > ingIdx) {
      ingSecs = []; methSecs = []; curIng = null; curMeth = null;
      startIngSection('Ingredients');
      for (let i = ingIdx + 1; i < methIdx; i++) {
        const ln = rawLines[i];
        if (isRecipeTitleEchoLine(ln)) continue;
        const p = splitIngredientLine(ln);
        if (p && p.header) startIngSection(p.name);
        else if (p && (p.name || p.qty || p.unit)) {
          pushIngredientItem({ qty: p.qty || '', unit: p.unit || '', name: p.name || '', note: p.note || '' });
        }
        else if (looksLikeIngLine(ln) && !isQtyUnitFragment(ln)) {
          pushIngredientItem({ qty:'', unit:'', name: ln, note:'' });
        }
      }
      pushIng();
      startMethSection('DIRECTIONS');
      for (let i = methIdx + 1; i < rawLines.length; i++) {
        const ln = rawLines[i].replace(/^(?:step\s*)?\d+[\.\):\-]\s*/i, '').trim();
        if (ln && ln.length < 300) {
          ln.split(/\s*(?:(?:method|step)\s+\d+\s+of\s+\d+)\s*/i).forEach(function(chunk) {
            const t = chunk.replace(/\s+\d+\s*\/\s*\d+\s*$/,'').trim();
            if (t && t.length < 300) pushMethodStep(t);
          });
        }
      }
      pushMeth();
      methSecs = filterMethSecsJunk(methSecs);
    }
  }

  finalizeParsedRecipe({
    ingSecs: ingSecs,
    methSecs: methSecs,
    text: text,
    titleCand: titleCand,
    extraWarnings: []
  });
}

function clearPaste() {
  document.getElementById('paste-input').value = '';
  document.getElementById('source-url-input').value = '';
  hideVideoRecipeHelp();
  clearImportUiState();
}
