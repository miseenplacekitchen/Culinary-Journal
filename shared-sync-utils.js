/* Household shared-edit conflict UI — grocery, pantry, meal planner */
(function (global) {
  var _modalEl = null;

  function esc(s) {
    return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  function ensureModal() {
    if (_modalEl || !global.document) return _modalEl;
    _modalEl = document.createElement('div');
    _modalEl.id = 'tcj-sync-conflict-modal';
    _modalEl.style.cssText = 'display:none;position:fixed;inset:0;background:rgba(0,0,0,0.55);z-index:10050;align-items:center;justify-content:center;padding:20px;backdrop-filter:blur(4px)';
    _modalEl.innerHTML =
      '<div style="background:var(--bg,#fff);border:1px solid var(--border,#ddd);border-radius:14px;max-width:420px;width:100%;padding:22px;font-family:DM Sans,sans-serif">' +
      '<div style="font-family:Cormorant Garamond,serif;font-size:1.25rem;font-weight:600;color:var(--text-high,#111);margin-bottom:8px">Partner updated this list</div>' +
      '<p id="tcj-sync-conflict-msg" style="font-size:13px;color:var(--text-mid,#555);line-height:1.5;margin:0 0 16px"></p>' +
      '<div style="display:flex;flex-direction:column;gap:8px">' +
      '<button type="button" id="tcj-sync-use-theirs" style="padding:10px;border-radius:9px;border:none;background:var(--accent,#5b8fd4);color:#fff;font-size:13px;cursor:pointer">Use partner\'s version</button>' +
      '<button type="button" id="tcj-sync-keep-mine" style="padding:10px;border-radius:9px;border:1px solid var(--border,#ddd);background:none;color:var(--text-high,#111);font-size:13px;cursor:pointer">Keep my version (overwrite)</button>' +
      '</div></div>';
    document.body.appendChild(_modalEl);
    return _modalEl;
  }

  function showConflict(opts) {
    opts = opts || {};
    var modal = ensureModal();
    if (!modal) return Promise.resolve('theirs');
    var msg = document.getElementById('tcj-sync-conflict-msg');
    if (msg) {
      msg.textContent = (opts.householdName ? opts.householdName + ' — ' : '') +
        'Your partner saved changes while you were editing. Choose which version to keep.';
    }
    modal.style.display = 'flex';
    return new Promise(function (resolve) {
      function done(choice) {
        modal.style.display = 'none';
        document.getElementById('tcj-sync-use-theirs').onclick = null;
        document.getElementById('tcj-sync-keep-mine').onclick = null;
        resolve(choice);
      }
      document.getElementById('tcj-sync-use-theirs').onclick = function () { done('theirs'); };
      document.getElementById('tcj-sync-keep-mine').onclick = function () { done('mine'); };
    });
  }

  function parseSaveResult(res, bodyText) {
    if (!res || !res.ok) return { ok: false };
    try {
      var j = JSON.parse(bodyText || '{}');
      if (j && j.conflict) return { ok: false, conflict: true, data: j };
      if (j && j.ok === false && j.conflict) return { ok: false, conflict: true, data: j };
      if (j && (j.ok === true || j.updated_at)) return { ok: true, updated_at: j.updated_at };
    } catch (_) {}
    return { ok: res.ok };
  }

  function storeServerTs(key, updatedAt) {
    if (!updatedAt) return;
    try { localStorage.setItem(key, String(new Date(updatedAt).getTime())); } catch (_) {}
  }

  function getServerTs(key) {
    try {
      var v = localStorage.getItem(key);
      if (!v) return null;
      var n = parseInt(v, 10);
      return isNaN(n) ? null : new Date(n).toISOString();
    } catch (_) { return null; }
  }

  global.SharedSyncUtils = {
    showConflict: showConflict,
    parseSaveResult: parseSaveResult,
    storeServerTs: storeServerTs,
    getServerTs: getServerTs
  };
})(typeof window !== 'undefined' ? window : globalThis);
