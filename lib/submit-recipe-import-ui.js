/* Submit recipe import UI helpers (confidence banner, clear state) */
(function (global) {
  function computeParseConfidence(ingCount, methSecs, extraWarnings, ingredientLines, parserVersion) {
    parserVersion = parserVersion || global.PARSER_VERSION || 'unknown';
    var core = global.RecipeImportCore || null;
    var stepTexts = [];
    (methSecs || []).forEach(function (s) {
      (s.steps || []).forEach(function (st) {
        var t = (typeof st === 'string') ? st : ((st && (st.text || st.title)) || '');
        if (t) stepTexts.push(String(t).trim());
      });
    });
    if (core && core.computeImportConfidence) {
      return core.computeImportConfidence(ingCount, stepTexts, extraWarnings, ingredientLines);
    }
    return {
      score: 0,
      warnings: extraWarnings || [],
      allowEnrich: false,
      submitWarn: true,
      goodStepCount: 0,
      junkCount: 0,
      parserVersion: parserVersion || 'unknown'
    };
  }

  function showImportConfidenceBanner(confidence, ingCount, stepCount, parserVersion) {
    parserVersion = parserVersion || global.PARSER_VERSION || 'unknown';
    var el = document.getElementById('import-confidence-banner');
    if (!el || !confidence) {
      if (el) el.style.display = 'none';
      return;
    }
    var review = !confidence.allowEnrich || confidence.submitWarn;
    el.className = 'sr-import-confidence ' + (review ? 'review' : 'ok');
    var lines = [
      (review ? 'Review required' : 'Import looks good') + ' — confidence ' + confidence.score + '/100 · parser ' + (confidence.parserVersion || parserVersion || 'unknown'),
      ingCount + ' ingredient' + (ingCount === 1 ? '' : 's') + ', ' + stepCount + ' step' + (stepCount === 1 ? '' : 's') +
        (confidence.warnings.length ? ', ' + confidence.warnings.length + ' warning' + (confidence.warnings.length === 1 ? '' : 's') : '')
    ];
    if (confidence.warnings.length) lines.push(confidence.warnings.join(' · '));
    if (review) lines.push('Category, tags, and times were not auto-filled — verify ingredients and method before submitting.');
    el.innerHTML = lines.join('<br>');
    el.style.display = 'block';
    global._lastImportMeta = {
      parser_version: confidence.parserVersion || parserVersion,
      import_confidence_score: confidence.score,
      import_warnings: confidence.warnings.slice()
    };
  }

  function normalizeImportPageTitle(title) {
    var t = String(title || '').trim();
    if (!t) return '';
    var parts = t.split(/\s*[\|\u2013\u2014]\s*/);
    if (parts.length > 1 && parts[0].length >= 4 && parts[0].length < 90) return parts[0].trim();
    return t;
  }

  function expandPasteSection() {
    var sec = document.getElementById('section-paste');
    if (sec) sec.classList.remove('collapsed');
  }

  function clearImportUiState() {
    var ids = ['url-detect-msg', 'url-import-status', 'scan-status', 'parse-result', 'import-confidence-banner', 'parse-tips', 'sr-msg'];
    ids.forEach(function (id) {
      var el = document.getElementById(id);
      if (!el) return;
      el.style.display = 'none';
    });
    if (typeof global.hideParseReviewNote === 'function') global.hideParseReviewNote();
    global._lastParseConfidence = null;
    global._parseDroppedIng = 0;
    if (global.TcjImportAudit) global.TcjImportAudit.reset();
  }

  global.TcjSubmitImportUi = {
    computeParseConfidence: computeParseConfidence,
    showImportConfidenceBanner: showImportConfidenceBanner,
    normalizeImportPageTitle: normalizeImportPageTitle,
    expandPasteSection: expandPasteSection,
    clearImportUiState: clearImportUiState
  };
  global.computeParseConfidence = computeParseConfidence;
  global.showImportConfidenceBanner = showImportConfidenceBanner;
  global.normalizeImportPageTitle = normalizeImportPageTitle;
  global.expandPasteSection = expandPasteSection;
  global.clearImportUiState = clearImportUiState;
})(typeof window !== 'undefined' ? window : globalThis);
