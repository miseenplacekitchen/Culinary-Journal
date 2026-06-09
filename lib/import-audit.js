/**
 * Wave 3 — browser-side import audit trail for submit + admin review.
 */
(function (root) {
  var MAX_SNAPSHOT = 12000;
  var MAX_RAW = 8000;

  function trunc(s, max) {
    s = String(s || '');
    return s.length > max ? s.slice(0, max) + '\n…[truncated]' : s;
  }

  function empty() {
    return {
      import_source_url: '',
      imported_at: null,
      parser_version: null,
      extractor_version: null,
      import_extractor: null,
      import_confidence_score: null,
      import_warnings: [],
      import_paste_snapshot: '',
      import_raw_article_text: '',
      import_merge_mode: false,
      procedure_rewritten: false,
      import_attribution_notice: '',
      import_page_title: '',
      import_path: ''
    };
  }

  var state = empty();

  function reset() {
    state = empty();
  }

  function recordUrlImport(opts) {
    opts = opts || {};
    state.import_source_url = opts.url || '';
    state.imported_at = new Date().toISOString();
    state.parser_version = opts.parserVersion || state.parser_version;
    state.extractor_version = opts.extractorVersion || state.extractor_version;
    state.import_extractor = opts.extractor || state.import_extractor;
    state.import_merge_mode = !!opts.mergeMode;
    state.import_path = opts.path || 'url-api';
    if (opts.rawArticle) state.import_raw_article_text = trunc(opts.rawArticle, MAX_RAW);
    if (opts.pasteText) state.import_paste_snapshot = trunc(opts.pasteText, MAX_SNAPSHOT);
    if (opts.warnings && opts.warnings.length) {
      state.import_warnings = opts.warnings.slice();
    }
    if (opts.attribution) {
      state.import_attribution_notice = opts.attribution.notice || '';
      state.import_page_title = opts.attribution.page_title || '';
      if (!state.import_source_url && opts.attribution.source_url) {
        state.import_source_url = opts.attribution.source_url;
      }
    }
  }

  function recordScanImport(opts) {
    opts = opts || {};
    state.imported_at = new Date().toISOString();
    state.import_extractor = 'scan';
    state.import_path = opts.path || 'photo-scan';
    state.parser_version = opts.parserVersion || state.parser_version;
    if (opts.pasteText) state.import_paste_snapshot = trunc(opts.pasteText, MAX_SNAPSHOT);
    if (opts.rawText) state.import_raw_article_text = trunc(opts.rawText, MAX_RAW);
    if (opts.warnings && opts.warnings.length) state.import_warnings = opts.warnings.slice();
  }

  function recordParse(confidence, pasteText) {
    if (!confidence) return;
    state.parser_version = confidence.parserVersion || state.parser_version;
    state.import_confidence_score = confidence.score;
    if (confidence.warnings && confidence.warnings.length) {
      state.import_warnings = confidence.warnings.slice();
    }
    if (pasteText) state.import_paste_snapshot = trunc(pasteText, MAX_SNAPSHOT);
  }

  function markProcedureRewritten() {
    state.procedure_rewritten = true;
  }

  function clearProcedureRewritten() {
    state.procedure_rewritten = false;
  }

  function collectForSubmit() {
    var out = {};
    Object.keys(state).forEach(function (k) {
      var v = state[k];
      if (v === null || v === undefined || v === '') return;
      if (Array.isArray(v) && !v.length) return;
      out[k] = v;
    });
    return out;
  }

  function getState() {
    return JSON.parse(JSON.stringify(state));
  }

  root.TcjImportAudit = {
    reset: reset,
    recordUrlImport: recordUrlImport,
    recordScanImport: recordScanImport,
    recordParse: recordParse,
    markProcedureRewritten: markProcedureRewritten,
    clearProcedureRewritten: clearProcedureRewritten,
    collectForSubmit: collectForSubmit,
    getState: getState
  };
})(typeof globalThis !== 'undefined' ? globalThis : typeof self !== 'undefined' ? self : this);
