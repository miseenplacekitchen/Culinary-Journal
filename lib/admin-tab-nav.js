// Shared admin tab navigation — IM Interface pattern for all management panels
(function (global) {
  'use strict';

  function ensureStyles() {
    if (document.getElementById('admin-tab-nav-styles')) return;
    var s = document.createElement('style');
    s.id = 'admin-tab-nav-styles';
    s.textContent =
      '.ap-tab-bar{display:flex;align-items:flex-end;flex-wrap:nowrap;gap:0;border-bottom:1px solid var(--border);margin-bottom:18px;overflow-x:auto;scrollbar-width:none}' +
      '.ap-tab-bar::-webkit-scrollbar{display:none}' +
      '.ap-tab-group{display:flex;flex-direction:column;flex-shrink:0;padding-bottom:0}' +
      '.ap-tab-group-label{font-family:DM Sans,sans-serif;font-size:9px;font-weight:600;letter-spacing:0.12em;text-transform:uppercase;color:var(--text-mid);padding:0 12px 5px;opacity:0.75;white-space:nowrap}' +
      '.ap-tab-group-tabs{display:flex;align-items:flex-end;gap:0}' +
      '.ap-tab-divider{width:1px;align-self:stretch;min-height:36px;background:var(--border);margin:0 4px 0 8px;flex-shrink:0;opacity:0.6}' +
      '.ap-tab-group-interface{margin-left:auto;padding-left:8px;border-left:1px solid var(--border)}' +
      '.ap-tab-group-interface .ap-tab-group-label{text-align:right;padding-right:12px}' +
      '.ap-inner-tab.tab-interface{font-weight:600}' +
      '.ap-inner-tab.tab-interface.active{color:var(--accent)}' +
      '.ap-panel-hint{font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);line-height:1.55;margin:-8px 0 16px;max-width:720px}' +
      '.admin-if-banner{font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-mid);background:rgba(91,143,212,0.08);border:1px solid rgba(91,143,212,0.22);border-radius:10px;padding:10px 14px;margin-bottom:16px;line-height:1.5}' +
      '.admin-if-intro{font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);line-height:1.6;margin-bottom:16px;max-width:720px}' +
      '.admin-if-inner-bar{display:flex;gap:0;border-bottom:1px solid var(--border);margin-bottom:18px;overflow-x:auto;scrollbar-width:none}' +
      '.admin-if-inner-bar::-webkit-scrollbar{display:none}' +
      '.admin-if-inner-btn{padding:9px 16px;font-family:DM Sans,sans-serif;font-size:12px;font-weight:500;background:none;border:none;border-bottom:2px solid transparent;cursor:pointer;color:var(--text-mid);margin-bottom:-1px;white-space:nowrap;flex-shrink:0}' +
      '.admin-if-inner-btn:hover{color:var(--text-high)}' +
      '.admin-if-inner-btn.active{color:var(--accent);border-bottom-color:var(--accent);font-weight:600}';
    document.head.appendChild(s);
  }

  function interfaceBanner(text) {
    ensureStyles();
    var d = document.createElement('div');
    d.className = 'admin-if-banner';
    d.textContent = text;
    return d;
  }

  function interfaceIntro(text) {
    ensureStyles();
    var p = document.createElement('p');
    p.className = 'admin-if-intro';
    p.textContent = text;
    return p;
  }

  /** Build IM-style inner tab bar. onActivate(key, panelEl) called when tab selected. */
  function buildInnerTabBar(parentEl, defs, storageKey, defaultKey, onActivate) {
    ensureStyles();
    var active = localStorage.getItem(storageKey) || defaultKey;
    if (!defs.some(function (d) { return d.key === active; })) active = defaultKey;

    var bar = document.createElement('div');
    bar.className = 'admin-if-inner-bar';
    var panels = {};

    function activate(key) {
      if (!panels[key]) return;
      localStorage.setItem(storageKey, key);
      bar.querySelectorAll('.admin-if-inner-btn').forEach(function (b) {
        b.classList.toggle('active', b.dataset.adminIfTab === key);
      });
      Object.keys(panels).forEach(function (k) {
        panels[k].style.display = k === key ? 'block' : 'none';
      });
      if (typeof onActivate === 'function') onActivate(key, panels[key]);
    }

    defs.forEach(function (td) {
      var btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'admin-if-inner-btn' + (td.key === active ? ' active' : '');
      btn.dataset.adminIfTab = td.key;
      btn.textContent = td.label;
      btn.addEventListener('click', function () { activate(td.key); });
      bar.appendChild(btn);

      var panel = document.createElement('div');
      panel.style.display = td.key === active ? 'block' : 'none';
      panels[td.key] = panel;
    });

    parentEl.appendChild(bar);
    Object.values(panels).forEach(function (p) { parentEl.appendChild(p); });

    return { bar: bar, panels: panels, activate: activate, activeKey: active };
  }

  global.AdminTabNav = {
    ensureStyles: ensureStyles,
    interfaceBanner: interfaceBanner,
    interfaceIntro: interfaceIntro,
    buildInnerTabBar: buildInnerTabBar
  };
})(typeof window !== 'undefined' ? window : this);
