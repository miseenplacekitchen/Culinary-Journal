/* The Culinary Journal — shared error handling (replaces silent catch blocks) */
(function (global) {
  var _banners = {};

  function te() {
    return global.TcjErr || {};
  }

  function warn(ctx, err) {
    var msg = err && err.message != null ? err.message : String(err != null ? err : 'unknown');
    console.warn('[TCJ:' + (ctx || 'error') + ']', msg, err);
  }

  /** Intentional degradation (localStorage privacy, selection range, URL parse fallbacks). */
  function ignore() {}

  function lsGet(key) {
    try {
      return global.localStorage.getItem(key);
    } catch (e) {
      return null;
    }
  }

  function lsSet(key, value) {
    try {
      global.localStorage.setItem(key, value);
      return true;
    } catch (e) {
      warn('localStorage.set:' + key, e);
      return false;
    }
  }

  function lsRemove(key) {
    try {
      global.localStorage.removeItem(key);
      return true;
    } catch (e) {
      warn('localStorage.remove:' + key, e);
      return false;
    }
  }

  function parseJson(raw, fallback, ctx) {
    if (raw == null || raw === '') return fallback;
    try {
      return JSON.parse(raw);
    } catch (e) {
      warn(ctx || 'parseJson', e);
      return fallback;
    }
  }

  function rpcFallback(ctx, err, fallback) {
    warn(ctx, err);
    return fallback;
  }

  function toast(msg, isError) {
    if (typeof global.showToast === 'function') {
      global.showToast(msg, isError ? true : undefined);
      return;
    }
    if (typeof global.showToastRp === 'function') {
      global.showToastRp(msg, !!isError);
      return;
    }
    if (typeof global.showImportStatus === 'function') {
      global.showImportStatus(msg, !!isError);
      return;
    }
    if (typeof global.showFatalError === 'function' && isError) {
      global.showFatalError(String(msg));
      return;
    }
    warn('toast', msg);
  }

  function bannerOnce(id, msg, parentId) {
    if (_banners[id]) return;
    _banners[id] = true;
    var el = global.document && global.document.getElementById(id);
    if (!el && global.document) {
      el = global.document.createElement('div');
      el.id = id;
      el.setAttribute('role', 'alert');
      el.style.cssText =
        'margin:12px 0;padding:10px 14px;background:var(--danger-bg,rgba(220,80,80,0.12));' +
        'border:1px solid rgb(from var(--danger,#dc5050) r g b / 0.35);border-radius:8px;' +
        'font-family:DM Sans,sans-serif;font-size:13px;color:var(--danger,#dc5050)';
      el.textContent = msg;
      var parent = parentId ? global.document.getElementById(parentId) : null;
      if (parent) parent.insertBefore(el, parent.firstChild);
      else if (global.document.body) global.document.body.insertBefore(el, global.document.body.firstChild);
    } else if (el) {
      el.textContent = msg;
      el.style.display = 'block';
    }
    warn(id, msg);
  }

  function sectionError(containerId, msg) {
    var el = global.document && global.document.getElementById(containerId);
    if (el) {
      el.innerHTML =
        '<div style="padding:16px;font-family:DM Sans,sans-serif;font-size:13px;color:var(--danger,#dc5050)">' +
        String(msg).replace(/</g, '&lt;') +
        '</div>';
    }
    warn(containerId, msg);
  }

  global.TcjErr = {
    warn: warn,
    ignore: ignore,
    lsGet: lsGet,
    lsSet: lsSet,
    lsRemove: lsRemove,
    parseJson: parseJson,
    rpcFallback: rpcFallback,
    toast: toast,
    bannerOnce: bannerOnce,
    sectionError: sectionError
  };
})(typeof window !== 'undefined' ? window : globalThis);
