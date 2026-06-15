// Shared admin Interface shell — sidebar nav + hub (IM Interface pattern)
(function (global) {
  'use strict';

  function mk(tag, cls, text) {
    var el = document.createElement(tag);
    if (cls) el.className = cls;
    if (text !== undefined) el.textContent = text;
    return el;
  }

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
      '.ap-inner-tab.tab-interface{font-weight:600}.ap-inner-tab.tab-interface.active{color:var(--accent)}' +
      '.ap-panel-hint{font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);line-height:1.55;margin:-8px 0 16px;max-width:720px}' +
      '.admin-if-banner{font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-mid);background:rgba(91,143,212,0.07);border:1px solid rgba(91,143,212,0.2);border-radius:8px;padding:8px 12px;margin-bottom:12px;line-height:1.45}' +
      '.admin-if-layout{display:grid;grid-template-columns:minmax(168px,200px) minmax(0,1fr);gap:0;min-height:420px;border:1px solid var(--border);border-radius:12px;overflow:hidden;background:rgba(255,255,255,0.02)}' +
      '.admin-if-nav{display:flex;flex-direction:column;padding:10px 0;overflow-y:auto;max-height:calc(100vh - 260px);border-right:1px solid var(--border);background:rgba(0,0,0,0.12)}' +
      '.admin-if-nav-group{font-family:DM Sans,sans-serif;font-size:9px;font-weight:600;letter-spacing:0.11em;text-transform:uppercase;color:var(--text-mid);padding:12px 14px 4px;opacity:0.7}' +
      '.admin-if-nav-btn{display:block;width:100%;text-align:left;padding:8px 14px;border:none;background:none;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);cursor:pointer;border-left:3px solid transparent;line-height:1.35}' +
      '.admin-if-nav-btn:hover{background:rgba(255,255,255,0.04);color:var(--text-high)}' +
      '.admin-if-nav-btn.active{background:rgba(91,143,212,0.1);color:var(--accent);border-left-color:var(--accent);font-weight:600}' +
      '.admin-if-nav-badge{float:right;font-size:10px;font-weight:600;padding:1px 6px;border-radius:10px;background:rgba(212,160,23,0.2);color:#d4a017;margin-left:6px}' +
      '.admin-if-main{display:flex;flex-direction:column;min-width:0}' +
      '.admin-if-main-head{padding:14px 18px 10px;border-bottom:1px solid var(--border);background:rgba(255,255,255,0.02)}' +
      '.admin-if-main-title{font-family:Cormorant Garamond,serif;font-size:1.15rem;font-weight:700;color:var(--text-high)}' +
      '.admin-if-main-sub{font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-mid);margin-top:3px;line-height:1.45}' +
      '.admin-if-main-body{flex:1;padding:16px 18px 20px;overflow-y:auto;max-height:calc(100vh - 320px)}' +
      '.admin-if-loading{font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);padding:12px 0}' +
      '.admin-if-hub-stats{display:grid;grid-template-columns:repeat(auto-fill,minmax(120px,1fr));gap:10px;margin-bottom:16px}' +
      '.admin-if-stat{background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:10px;padding:12px 14px}' +
      '.admin-if-stat-num{font-family:Cormorant Garamond,serif;font-size:1.6rem;font-weight:700;color:var(--accent);line-height:1}' +
      '.admin-if-stat-label{font-family:DM Sans,sans-serif;font-size:9px;font-weight:600;letter-spacing:0.08em;text-transform:uppercase;color:var(--text-mid);margin-top:4px}' +
      '.admin-if-hub-actions{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:10px}' +
      '.admin-if-action{display:flex;flex-direction:column;align-items:flex-start;text-align:left;padding:12px 14px;border:1px solid var(--border);border-radius:10px;background:rgba(255,255,255,0.03);cursor:pointer;font-family:DM Sans,sans-serif;color:inherit;transition:border-color .12s}' +
      '.admin-if-action:hover{border-color:var(--accent)}' +
      '.admin-if-action-label{font-size:13px;font-weight:600;color:var(--text-high);margin-bottom:3px}' +
      '.admin-if-action-desc{font-size:11px;color:var(--text-mid);line-height:1.4}' +
      '@media(max-width:760px){.admin-if-layout{grid-template-columns:1fr}.admin-if-nav{flex-direction:row;flex-wrap:wrap;max-height:none;border-right:none;border-bottom:1px solid var(--border)}.admin-if-nav-group{width:100%}.admin-if-nav-btn{width:auto;display:inline-block;border-left:none;border-bottom:3px solid transparent}.admin-if-nav-btn.active{border-bottom-color:var(--accent);border-left-color:transparent}}';
    document.head.appendChild(s);
  }

  function interfaceBanner(text) {
    ensureStyles();
    return mk('div', 'admin-if-banner', text);
  }

  /** Lightweight row count via PostgREST (Prefer: count=exact). */
  function restCount(table, filterQuery) {
    if (typeof apiFetch === 'undefined' || typeof SUPABASE_URL === 'undefined') {
      return Promise.resolve(0);
    }
    var q = table + '?select=id';
    if (filterQuery) q += '&' + filterQuery;
    return apiFetch(SUPABASE_URL + '/rest/v1/' + q, {
      headers: { Prefer: 'count=exact', Range: '0-0' }
    }).then(function (res) {
      if (!res || !res.ok) return 0;
      var range = res.headers.get('Content-Range') || res.headers.get('content-range') || '';
      var slash = range.lastIndexOf('/');
      if (slash < 0) return 0;
      return parseInt(range.slice(slash + 1), 10) || 0;
    }).catch(function () { return 0; });
  }

  function renderHub(panel, opts) {
    panel.innerHTML = '';
    if (opts.intro) {
      var intro = mk('p', '', opts.intro);
      intro.style.cssText = 'font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);line-height:1.55;margin:0 0 14px;max-width:640px';
      panel.appendChild(intro);
    }
    if (opts.stats && opts.stats.length) {
      var sg = mk('div', 'admin-if-hub-stats');
      opts.stats.forEach(function (st) {
        var card = mk('div', 'admin-if-stat');
        card.appendChild(mk('div', 'admin-if-stat-num', String(st.num != null ? st.num : '—')));
        card.appendChild(mk('div', 'admin-if-stat-label', st.label || ''));
        sg.appendChild(card);
      });
      panel.appendChild(sg);
    }
    if (opts.actions && opts.actions.length) {
      var ag = mk('div', 'admin-if-hub-actions');
      opts.actions.forEach(function (act) {
        var btn = mk('button', 'admin-if-action');
        btn.type = 'button';
        btn.appendChild(mk('span', 'admin-if-action-label', act.label));
        if (act.desc) btn.appendChild(mk('span', 'admin-if-action-desc', act.desc));
        btn.addEventListener('click', act.onClick);
        ag.appendChild(btn);
      });
      panel.appendChild(ag);
    }
  }

  /**
   * Hub section with optional refreshOnShow. loadHub(panel, ctx, isRefresh) → Promise<hubOpts>|hubOpts
   */
  function hubSection(def) {
    return {
      key: def.key || 'hub',
      label: def.label || 'Hub',
      group: def.group || 'Overview',
      title: def.title,
      subtitle: def.subtitle || '',
      refreshOnShow: def.refreshOnShow !== false,
      render: function (panel, ctx, isRefresh) {
        if (!isRefresh) panel.innerHTML = '<div class="admin-if-loading">Loading…</div>';
        var result = typeof def.loadHub === 'function' ? def.loadHub(panel, ctx, isRefresh) : null;
        function apply(opts) {
          if (opts) renderHub(panel, opts);
        }
        if (result && typeof result.then === 'function') {
          return result.then(apply);
        }
        apply(result);
        return result;
      }
    };
  }

  /**
   * Sidebar Interface shell. sections: [{ key, label, group?, subtitle?, badge?, render(panel, ctx) }]
   */
  function buildInterfaceShell(parentEl, config) {
    ensureStyles();
    if (!parentEl || !config || !config.sections || !config.sections.length) return null;

    var storageKey = config.storageKey || 'tcj_if_section';
    var defaultKey = config.defaultKey || config.sections[0].key;
    var sectionMap = {};
    config.sections.forEach(function (s) { sectionMap[s.key] = s; });

    if (parentEl.dataset.ifShell === '1' && parentEl._ifShell) {
      var stored = localStorage.getItem(storageKey) || defaultKey;
      if (!sectionMap[stored]) stored = defaultKey;
      parentEl._ifShell.activate(stored);
      return parentEl._ifShell;
    }

    parentEl.innerHTML = '';
    parentEl.dataset.ifShell = '1';

    if (config.banner !== false) {
      parentEl.appendChild(interfaceBanner(config.banner || 'Configuration — work queues stay in the tabs above.'));
    }

    var layout = mk('div', 'admin-if-layout');
    var nav = mk('nav', 'admin-if-nav');
    var main = mk('main', 'admin-if-main');
    var head = mk('div', 'admin-if-main-head');
    var titleEl = mk('div', 'admin-if-main-title', '');
    var subEl = mk('div', 'admin-if-main-sub', '');
    var body = mk('div', 'admin-if-main-body');
    head.appendChild(titleEl);
    head.appendChild(subEl);
    main.appendChild(head);
    main.appendChild(body);

    var panels = {};
    var shared = config.shared || {};
    var lastGroup = null;
    config.sections.forEach(function (sec) {
      if (sec.group && sec.group !== lastGroup) {
        lastGroup = sec.group;
        nav.appendChild(mk('div', 'admin-if-nav-group', sec.group));
      }
      var btn = mk('button', 'admin-if-nav-btn', sec.label);
      btn.type = 'button';
      btn.dataset.ifSection = sec.key;
      if (sec.badge != null && sec.badge !== '') {
        var badge = mk('span', 'admin-if-nav-badge', String(sec.badge));
        btn.appendChild(badge);
      }
      nav.appendChild(btn);
      panels[sec.key] = null;
    });

    function ensurePanel(key) {
      if (!panels[key]) {
        panels[key] = mk('div', 'admin-if-panel');
        body.appendChild(panels[key]);
      }
      return panels[key];
    }

    layout.appendChild(nav);
    layout.appendChild(main);
    parentEl.appendChild(layout);

    function activate(key) {
      var sec = sectionMap[key];
      if (!sec) return;
      localStorage.setItem(storageKey, key);
      nav.querySelectorAll('.admin-if-nav-btn').forEach(function (b) {
        b.classList.toggle('active', b.dataset.ifSection === key);
      });
      Object.keys(panels).forEach(function (k) {
        if (panels[k]) panels[k].style.display = k === key ? 'block' : 'none';
      });
      titleEl.textContent = sec.title || sec.label;
      subEl.textContent = sec.subtitle || '';
      subEl.style.display = sec.subtitle ? 'block' : 'none';

      var panel = ensurePanel(key);
      var ctx = { activate: activate, panels: panels, nav: nav, shell: shell, shared: shared };

      function markLoaded() { panel.dataset.loaded = '1'; }

      if (panel.dataset.loaded === '1') {
        if (sec.refreshOnShow && typeof sec.render === 'function') {
          try {
            var refreshResult = sec.render(panel, ctx, true);
            if (refreshResult && typeof refreshResult.then === 'function') {
              refreshResult.catch(function (err) {
                panel.innerHTML = '<div style="color:#dc5050;font-family:DM Sans,sans-serif;font-size:13px">' + (err.message || err) + '</div>';
              });
            }
          } catch (err) {
            panel.innerHTML = '<div style="color:#dc5050;font-family:DM Sans,sans-serif;font-size:13px">' + (err.message || err) + '</div>';
          }
        }
        if (typeof sec.onShow === 'function') sec.onShow(panel, ctx);
        return;
      }

      panel.innerHTML = '<div class="admin-if-loading">Loading…</div>';
      try {
        var result = typeof sec.render === 'function' ? sec.render(panel, ctx, false) : null;
        if (result && typeof result.then === 'function') {
          result.then(function () { markLoaded(); }).catch(function (err) {
            panel.innerHTML = '<div style="color:#dc5050;font-family:DM Sans,sans-serif;font-size:13px">' + (err.message || err) + '</div>';
          });
        } else {
          markLoaded();
        }
      } catch (err) {
        panel.innerHTML = '<div style="color:#dc5050;font-family:DM Sans,sans-serif;font-size:13px">' + (err.message || err) + '</div>';
      }
    }

    nav.addEventListener('click', function (e) {
      var btn = e.target.closest('[data-if-section]');
      if (btn) activate(btn.dataset.ifSection);
    });

    var shell = { activate: activate, panels: panels, nav: nav, invalidate: function (key) {
      if (panels[key]) { panels[key].dataset.loaded = ''; panels[key].innerHTML = ''; }
    }, invalidateAll: function () {
      Object.keys(panels).forEach(function (k) { panels[k].dataset.loaded = ''; panels[k].innerHTML = ''; });
    }};

    parentEl._ifShell = shell;

    var start = localStorage.getItem(storageKey) || defaultKey;
    if (!sectionMap[start]) start = defaultKey;
    activate(start);
    return shell;
  }

  /** @deprecated use buildInterfaceShell */
  function buildInnerTabBar(parentEl, defs, storageKey, defaultKey, onActivate) {
    return buildInterfaceShell(parentEl, {
      storageKey: storageKey,
      defaultKey: defaultKey,
      banner: false,
      sections: defs.map(function (d) {
        return {
          key: d.key,
          label: d.label,
          group: 'Sections',
          render: function (panel) {
            if (typeof onActivate === 'function') onActivate(d.key, panel);
          }
        };
      })
    });
  }

  function interfaceIntro(text) {
    ensureStyles();
    var p = mk('p', '', text);
    p.style.cssText = 'font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);line-height:1.6;margin-bottom:16px;max-width:720px';
    return p;
  }

  global.AdminTabNav = {
    ensureStyles: ensureStyles,
    interfaceBanner: interfaceBanner,
    interfaceIntro: interfaceIntro,
    buildInterfaceShell: buildInterfaceShell,
    buildInnerTabBar: buildInnerTabBar,
    renderHub: renderHub,
    hubSection: hubSection,
    restCount: restCount
  };
})(typeof window !== 'undefined' ? window : this);
