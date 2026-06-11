/**
 * lib/theme-admin-ui.js — Site Management → Themes tab UI
 * Requires: theme-catalog.js, dashboard-shared apiFetch / SUPABASE_URL
 */
async function buildSMThemes(container) {
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);padding:8px 0">Loading\u2026</div>';
  try {
    if (typeof TCJ_flatThemes !== 'function') throw new Error('theme-catalog.js not loaded');

    var res = await apiFetch(SUPABASE_URL + '/rest/v1/site_settings?select=key,value');
    if (!res || !res.ok) throw new Error(res ? res.status + ': ' + await res.text() : 'Session expired');
    var rows = await res.json();
    var S = {};
    if (Array.isArray(rows)) rows.forEach(function (r) { S[r.key] = r.value; });

    var disabledLegacy = [];
    try { disabledLegacy = JSON.parse(S.disabled_themes || '[]'); } catch (_) {}
    var catalog = TCJ_mergeThemeCatalog(S.theme_catalog, disabledLegacy, S.seasonal_default_theme || '');

    async function ssSave(k, v) {
      var r = await apiFetch(SUPABASE_URL + '/rest/v1/site_settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Prefer': 'resolution=merge-duplicates,return=minimal' },
        body: JSON.stringify({ key: k, value: v })
      });
      if (!r || !r.ok) throw new Error(r ? r.status + ': ' + await r.text() : 'Session expired');
    }

    async function persistCatalog() {
      await ssSave('theme_catalog', JSON.stringify(catalog));
      await ssSave('disabled_themes', JSON.stringify(TCJ_disabledNamesFromCatalog(catalog)));
      if (catalog.default_theme) await ssSave('default_theme', catalog.default_theme);
      if (catalog.seasonal_default !== undefined) {
        var flat = TCJ_flatThemes();
        var name = '';
        flat.forEach(function (t) { if (t.key === catalog.seasonal_default) name = t.name; });
        await ssSave('seasonal_default_theme', name || '');
      }
    }

    window._tcjThemeCatalogState = { catalog: catalog, persist: persistCatalog };

    function mk(tag, style, text) {
      var e = document.createElement(tag);
      if (style) e.style.cssText = style;
      if (text !== undefined) e.textContent = text;
      return e;
    }

    function esc(s) {
      return String(s == null ? '' : s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    }

    container.innerHTML = '';

    // ── Site-wide defaults ─────────────────────────────────────
    var globals = mk('div', 'background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:12px;padding:20px;margin-bottom:16px');
    globals.appendChild(mk('div', "font-family:'Cormorant Garamond',serif;font-size:1.05rem;font-weight:700;color:var(--text-high);margin-bottom:4px", 'Site-wide theme defaults'));
    globals.appendChild(mk('div', 'font-size:12px;color:var(--text-mid);margin-bottom:14px;line-height:1.5',
      'Default theme for new members, optional seasonal override, and currency label for paid themes.'));

    var gGrid = mk('div', 'display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:12px');
    var flat = TCJ_flatThemes();

    function themeSelect(label, key, current) {
      var box = mk('div');
      box.appendChild(mk('label', 'display:block;font-size:11px;font-weight:600;color:var(--text-mid);margin-bottom:6px;text-transform:uppercase;letter-spacing:0.06em', label));
      var sel = document.createElement('select');
      sel.style.cssText = 'width:100%;padding:8px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high)';
      var empty = document.createElement('option');
      empty.value = '';
      empty.textContent = key === 'seasonal_default' ? '— No seasonal override —' : '— Select —';
      sel.appendChild(empty);
      flat.forEach(function (t) {
        var o = document.createElement('option');
        o.value = t.key;
        o.textContent = t.name;
        if (t.key === current) o.selected = true;
        sel.appendChild(o);
      });
      sel.addEventListener('change', function () {
        catalog[key] = this.value;
      });
      box.appendChild(sel);
      return box;
    }

    gGrid.appendChild(themeSelect('Default theme', 'default_theme', catalog.default_theme || 'midnight-slate'));
    gGrid.appendChild(themeSelect('Seasonal override', 'seasonal_default', catalog.seasonal_default || ''));
    globals.appendChild(gGrid);
    container.appendChild(globals);

    // ── Toolbar ────────────────────────────────────────────────
    var toolbar = mk('div', 'display:flex;flex-wrap:wrap;gap:10px;align-items:center;margin-bottom:14px');
    var search = document.createElement('input');
    search.placeholder = 'Search themes\u2026';
    search.style.cssText = 'flex:1;min-width:180px;padding:8px 12px;background:var(--bg);border:1px solid var(--border);border-radius:8px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high)';
    toolbar.appendChild(search);

    var catFilter = document.createElement('select');
    catFilter.style.cssText = 'padding:8px 10px;background:var(--bg);border:1px solid var(--border);border-radius:8px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high)';
    function refreshCatFilter() {
      var cur = catFilter.value || 'all';
      catFilter.innerHTML = '';
      var allOpt = document.createElement('option');
      allOpt.value = 'all';
      allOpt.textContent = 'All categories';
      catFilter.appendChild(allOpt);
      TCJ_getAllCategories(catalog).forEach(function (c) {
        var o = document.createElement('option');
        o.value = c.id;
        o.textContent = c.label + (c.builtin ? '' : ' (custom)');
        catFilter.appendChild(o);
      });
      if (cur === 'all' || TCJ_getAllCategories(catalog).some(function (c) { return c.id === cur; })) {
        catFilter.value = cur;
      }
    }
    refreshCatFilter();

    var expandBtn = mk('button', 'padding:8px 12px;background:none;border:1px solid var(--border);border-radius:8px;color:var(--text-mid);font-family:DM Sans,sans-serif;font-size:12px;cursor:pointer', 'Expand all');
    var collapseBtn = mk('button', 'padding:8px 12px;background:none;border:1px solid var(--border);border-radius:8px;color:var(--text-mid);font-family:DM Sans,sans-serif;font-size:12px;cursor:pointer', 'Collapse all');
    toolbar.appendChild(catFilter);
    toolbar.appendChild(expandBtn);
    toolbar.appendChild(collapseBtn);

    var saveBtn = mk('button', 'padding:8px 18px;background:var(--accent);border:none;border-radius:8px;color:#fff;font-family:DM Sans,sans-serif;font-size:12px;font-weight:600;cursor:pointer', 'Save theme settings');
    saveBtn.addEventListener('click', async function () {
      saveBtn.disabled = true;
      saveBtn.textContent = 'Saving\u2026';
      try {
        await persistCatalog();
        saveBtn.textContent = 'Saved';
        saveBtn.style.background = '#4caf76';
        setTimeout(function () {
          saveBtn.textContent = 'Save theme settings';
          saveBtn.style.background = 'var(--accent)';
          saveBtn.disabled = false;
        }, 2000);
      } catch (e) {
        saveBtn.disabled = false;
        saveBtn.textContent = 'Save theme settings';
        alert(e.message);
      }
    });
    toolbar.appendChild(saveBtn);
    container.appendChild(toolbar);

    var list = mk('div', 'display:flex;flex-direction:column;gap:10px');
    container.appendChild(list);
    var collapsed = {};

    function colorField(label, value, onChange) {
      var row = mk('div', 'display:flex;flex-direction:column;gap:4px');
      row.appendChild(mk('span', 'font-size:10px;font-weight:600;color:var(--text-mid);text-transform:uppercase;letter-spacing:0.05em', label));
      var wrap = mk('div', 'display:flex;gap:6px;align-items:center');
      var picker = document.createElement('input');
      picker.type = 'color';
      picker.value = /^#[0-9a-f]{6}$/i.test(value) ? value : '#0f1011';
      picker.style.cssText = 'width:36px;height:28px;padding:0;border:1px solid var(--border);border-radius:6px;cursor:pointer;background:none';
      var text = document.createElement('input');
      text.value = value || '';
      text.placeholder = '#hex or rgba(...)';
      text.style.cssText = 'flex:1;padding:6px 8px;background:var(--bg);border:1px solid var(--border);border-radius:6px;font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-high)';
      function sync(v) { onChange(v); }
      picker.addEventListener('input', function () { text.value = this.value; sync(this.value); });
      text.addEventListener('change', function () { sync(this.value.trim()); });
      wrap.appendChild(picker);
      wrap.appendChild(text);
      row.appendChild(wrap);
      return row;
    }

    function buildThemeCard(themeDef, cfg, isCustom) {
      var key = themeDef.key;
      if (!cfg) cfg = catalog.themes[key];
      if (!cfg) return null;

      var card = mk('div', 'background:rgba(255,255,255,0.03);border:1px solid ' + (cfg.enabled === false ? 'var(--border)' : 'var(--accent)') + ';border-radius:12px;padding:16px 18px;opacity:' + (cfg.enabled === false ? '0.55' : '1'));
      card.dataset.themeKey = key;
      card.dataset.themeName = (themeDef.name || '').toLowerCase();

      var head = mk('div', 'display:flex;flex-wrap:wrap;gap:12px;align-items:flex-start;justify-content:space-between;margin-bottom:12px');
      var left = mk('div', 'display:flex;gap:12px;align-items:flex-start;flex:1;min-width:240px');

      var sw = mk('div', 'display:flex;gap:3px;flex-shrink:0');
      [cfg.colors.bg, cfg.colors.accent, cfg.colors.text].forEach(function (c) {
        var s = mk('div', 'width:28px;height:28px;border-radius:6px;border:1px solid rgba(255,255,255,0.1);background:' + (c || '#333'));
        sw.appendChild(s);
      });
      left.appendChild(sw);

      var titles = mk('div');
      titles.appendChild(mk('div', 'font-family:Cormorant Garamond,serif;font-size:1rem;font-weight:700;color:var(--text-high)', themeDef.name));
      titles.appendChild(mk('div', 'font-size:11px;color:var(--text-mid);margin-top:2px', (themeDef.categoryLabel || 'Custom') + ' · ' + key));
      left.appendChild(titles);
      head.appendChild(left);

      var toggles = mk('div', 'display:flex;flex-wrap:wrap;gap:14px;align-items:center');
      function toggleRow(label, checked, onChange) {
        var row = mk('label', 'display:flex;align-items:center;gap:6px;font-size:12px;color:var(--text-high);cursor:pointer');
        var cb = document.createElement('input');
        cb.type = 'checkbox';
        cb.checked = !!checked;
        cb.style.accentColor = 'var(--accent)';
        cb.addEventListener('change', function () { onChange(this.checked); });
        row.appendChild(cb);
        row.appendChild(document.createTextNode(label));
        return row;
      }
      toggles.appendChild(toggleRow('Enabled', cfg.enabled !== false, function (v) {
        cfg.enabled = v;
        card.style.opacity = v ? '1' : '0.55';
        card.style.borderColor = v ? 'var(--accent)' : 'var(--border)';
      }));
      toggles.appendChild(toggleRow('Featured', cfg.featured, function (v) { cfg.featured = v; }));
      head.appendChild(toggles);
      card.appendChild(head);

      // Pricing row
      var priceRow = mk('div', 'display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:10px;margin-bottom:12px');
      function fieldBox(label, el) {
        var b = mk('div');
        b.appendChild(mk('span', 'display:block;font-size:10px;font-weight:600;color:var(--text-mid);margin-bottom:4px;text-transform:uppercase', label));
        b.appendChild(el);
        return b;
      }
      var pricingSel = document.createElement('select');
      pricingSel.style.cssText = 'width:100%;padding:7px 9px;background:var(--bg);border:1px solid var(--border);border-radius:6px;font-size:12px;color:var(--text-high)';
      [['free', 'Free'], ['paid', 'One-time purchase'], ['premium_bundle', 'Included in Premium']].forEach(function (p) {
        var o = document.createElement('option');
        o.value = p[0];
        o.textContent = p[1];
        if (cfg.pricing === p[0]) o.selected = true;
        pricingSel.appendChild(o);
      });
      pricingSel.addEventListener('change', function () { cfg.pricing = this.value; });
      priceRow.appendChild(fieldBox('Pricing', pricingSel));

      var priceIn = document.createElement('input');
      priceIn.type = 'number';
      priceIn.min = '0';
      priceIn.step = '0.01';
      priceIn.value = cfg.price || 0;
      priceIn.style.cssText = 'width:100%;padding:7px 9px;background:var(--bg);border:1px solid var(--border);border-radius:6px;font-size:12px;color:var(--text-high)';
      priceIn.addEventListener('change', function () { cfg.price = parseFloat(this.value) || 0; });
      priceRow.appendChild(fieldBox('Price (' + (S.currency_symbol || '$') + ')', priceIn));

      var tierSel = document.createElement('select');
      tierSel.style.cssText = pricingSel.style.cssText;
      ['free', 'daily', 'weekly', 'monthly', 'yearly', 'premium', 'event'].forEach(function (t) {
        var o = document.createElement('option');
        o.value = t;
        o.textContent = t.charAt(0).toUpperCase() + t.slice(1);
        if ((cfg.min_tier || 'free') === t) o.selected = true;
        tierSel.appendChild(o);
      });
      tierSel.addEventListener('change', function () { cfg.min_tier = this.value; });
      priceRow.appendChild(fieldBox('Minimum tier', tierSel));

      var descIn = document.createElement('input');
      descIn.value = cfg.description || '';
      descIn.placeholder = 'Short description shown on profile picker';
      descIn.style.cssText = priceIn.style.cssText;
      descIn.addEventListener('change', function () { cfg.description = this.value.trim(); });
      priceRow.appendChild(fieldBox('Description', descIn));
      card.appendChild(priceRow);

      // Colours
      var colorsTitle = mk('div', 'font-size:11px;font-weight:700;color:var(--text-mid);margin:8px 0 8px;text-transform:uppercase;letter-spacing:0.06em', 'Colour palette');
      card.appendChild(colorsTitle);

      var mainColors = mk('div', 'display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:10px;margin-bottom:8px');
      mainColors.appendChild(colorField('Background', cfg.colors.bg, function (v) { cfg.colors.bg = v; }));
      mainColors.appendChild(colorField('Accent', cfg.colors.accent, function (v) { cfg.colors.accent = v; }));
      mainColors.appendChild(colorField('Text', cfg.colors.text, function (v) { cfg.colors.text = v; }));
      card.appendChild(mainColors);

      var extraTitle = mk('div', 'font-size:10px;color:var(--text-mid);margin-bottom:6px', 'Additional (optional — border, surface, nav background)');
      card.appendChild(extraTitle);
      var extraColors = mk('div', 'display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:10px');
      extraColors.appendChild(colorField('Border', cfg.colors.border || '', function (v) { cfg.colors.border = v; }));
      extraColors.appendChild(colorField('Surface', cfg.colors.surface || '', function (v) { cfg.colors.surface = v; }));
      extraColors.appendChild(colorField('Nav background', cfg.colors.nav_bg || '', function (v) { cfg.colors.nav_bg = v; }));
      card.appendChild(extraColors);

      if (isCustom) {
        var del = mk('button', 'margin-top:12px;padding:6px 12px;background:none;border:1px solid #dc5050;border-radius:6px;color:#dc5050;font-size:11px;cursor:pointer', 'Remove custom theme');
        del.addEventListener('click', function () {
          if (!confirm('Remove this custom theme entry?')) return;
          catalog.custom = (catalog.custom || []).filter(function (c) { return c.key !== key; });
          delete catalog.themes[key];
          renderList();
        });
        card.appendChild(del);
      }

      return card;
    }

    function addCustomThemeToCategory(categoryId, name, key) {
      name = (name || '').trim();
      if (!name) { alert('Enter a display name.'); return false; }
      key = (key || '').trim().toLowerCase();
      if (!key) key = TCJ_slugify(name);
      if (!key) { alert('Enter a valid theme key.'); return false; }
      if (catalog.themes[key]) { alert('That key already exists.'); return false; }
      var entry = {
        enabled: true,
        pricing: 'paid',
        price: 2.99,
        min_tier: 'free',
        featured: false,
        description: 'Custom theme',
        category: categoryId,
        colors: { bg: '#0f1011', accent: '#C4973B', text: '#ffffff', border: '', surface: '', nav_bg: '' }
      };
      catalog.custom.push({
        key: key,
        name: name,
        category: categoryId,
        sub: 'Custom',
        swatches: ['#0f1011', '#C4973B', '#ffffff']
      });
      catalog.themes[key] = entry;
      collapsed[categoryId] = false;
      return true;
    }

    function buildCategoryAddForm(categoryId) {
      var form = mk('div', 'margin-top:12px;padding:12px 14px;background:rgba(255,255,255,0.02);border:1px dashed var(--border);border-radius:10px');
      form.appendChild(mk('div', 'font-size:11px;font-weight:600;color:var(--text-mid);margin-bottom:8px;text-transform:uppercase;letter-spacing:0.05em', 'Add theme to this category'));
      var row = mk('div', 'display:grid;grid-template-columns:1fr 1fr auto;gap:8px;align-items:end');
      var nameIn = document.createElement('input');
      nameIn.placeholder = 'Display name';
      nameIn.style.cssText = 'padding:8px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-size:12px;color:var(--text-high)';
      var keyIn = document.createElement('input');
      keyIn.placeholder = 'slug-key (auto)';
      keyIn.style.cssText = nameIn.style.cssText;
      var btn = mk('button', 'padding:8px 14px;background:none;border:1px solid var(--accent);border-radius:7px;color:var(--accent);font-family:DM Sans,sans-serif;font-size:12px;font-weight:600;cursor:pointer;white-space:nowrap', '+ Add');
      btn.addEventListener('click', function () {
        if (addCustomThemeToCategory(categoryId, nameIn.value, keyIn.value)) {
          nameIn.value = '';
          keyIn.value = '';
          refreshCatFilter();
          renderList();
        }
      });
      row.appendChild(nameIn);
      row.appendChild(keyIn);
      row.appendChild(btn);
      form.appendChild(row);
      form.appendChild(mk('div', 'font-size:10px;color:var(--text-mid);margin-top:8px;line-height:1.45',
        'Add CSS to style.css before members can apply this theme on their profile.'));
      return form;
    }

    function renderList() {
      list.innerHTML = '';
      var q = (search.value || '').toLowerCase().trim();
      var cat = catFilter.value;
      var categories = TCJ_getAllCategories(catalog);
      var any = false;

      categories.forEach(function (category) {
        if (cat !== 'all' && cat !== category.id) return;
        any = true;

        var items = TCJ_themesForAdminCategory(catalog, category.id).filter(function (t) {
          if (!q) return true;
          return t.name.toLowerCase().indexOf(q) !== -1 || t.key.indexOf(q) !== -1;
        });

        var isOpen = collapsed[category.id] !== true;
        var sec = mk('div', 'border:1px solid var(--border);border-radius:12px;overflow:hidden;background:rgba(255,255,255,0.02)');

        var head = mk('div', 'display:flex;align-items:center;gap:8px;padding:10px 12px 10px 10px;background:rgba(255,255,255,0.04)');
        var toggle = mk('button', 'flex:1;display:flex;align-items:center;gap:10px;min-width:0;padding:4px 6px;background:none;border:none;cursor:pointer;text-align:left');
        toggle.type = 'button';
        toggle.appendChild(mk('span', 'font-size:14px;color:var(--accent);line-height:1;flex-shrink:0', isOpen ? '\u25BE' : '\u25B8'));
        var titleWrap = mk('div', 'min-width:0');
        titleWrap.appendChild(mk('div', "font-family:'Cormorant Garamond',serif;font-size:1rem;font-weight:700;color:var(--text-high)", category.label));
        titleWrap.appendChild(mk('div', 'font-size:11px;color:var(--text-mid);margin-top:2px',
          items.length + ' theme' + (items.length === 1 ? '' : 's') + (category.builtin ? '' : ' · custom category')));
        toggle.appendChild(titleWrap);
        toggle.addEventListener('click', function () {
          collapsed[category.id] = !collapsed[category.id];
          renderList();
        });
        head.appendChild(toggle);

        if (!category.builtin) {
          var delCat = mk('button', 'font-size:11px;color:#dc5050;padding:4px 10px;border:1px solid rgba(220,80,80,0.35);border-radius:6px;background:none;cursor:pointer;flex-shrink:0', 'Remove');
          delCat.type = 'button';
          delCat.addEventListener('click', function () {
            var inCat = (catalog.custom || []).filter(function (c) {
              var cfg = catalog.themes[c.key];
              return ((cfg && cfg.category) || c.category) === category.id;
            });
            if (inCat.length && !confirm('This category has ' + inCat.length + ' custom theme(s). Remove category and all its custom themes?')) return;
            inCat.forEach(function (c) {
              catalog.custom = catalog.custom.filter(function (x) { return x.key !== c.key; });
              delete catalog.themes[c.key];
            });
            catalog.custom_categories = (catalog.custom_categories || []).filter(function (c) { return c.id !== category.id; });
            refreshCatFilter();
            renderList();
          });
          head.appendChild(delCat);
        }
        sec.appendChild(head);

        if (isOpen) {
          var body = mk('div', 'padding:14px 16px 16px;display:flex;flex-direction:column;gap:10px');
          if (!items.length) {
            body.appendChild(mk('p', 'font-size:12px;color:var(--text-mid);margin:0', 'No themes in this category yet.'));
          } else {
            items.forEach(function (t) {
              var card = buildThemeCard(t, catalog.themes[t.key], !t.builtin);
              if (card) body.appendChild(card);
            });
          }
          body.appendChild(buildCategoryAddForm(category.id));
          sec.appendChild(body);
        }

        list.appendChild(sec);
      });

      if (!any && cat === 'all') {
        list.appendChild(mk('p', 'font-size:13px;color:var(--text-mid);padding:16px 0', 'No themes match your filter.'));
      }
    }

    expandBtn.addEventListener('click', function () {
      TCJ_getAllCategories(catalog).forEach(function (c) { collapsed[c.id] = false; });
      renderList();
    });
    collapseBtn.addEventListener('click', function () {
      TCJ_getAllCategories(catalog).forEach(function (c) { collapsed[c.id] = true; });
      renderList();
    });

    search.addEventListener('input', renderList);
    catFilter.addEventListener('change', renderList);
    renderList();

    // ── Add new category ───────────────────────────────────────
    var addCatSec = mk('div', 'background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:12px;padding:18px;margin-top:16px');
    addCatSec.appendChild(mk('div', "font-family:'Cormorant Garamond',serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:8px", 'Add new category'));
    addCatSec.appendChild(mk('div', 'font-size:12px;color:var(--text-mid);margin-bottom:12px;line-height:1.5',
      'Create a new group for custom themes. You can then add themes inside that category using the form in each section.'));

    var catGrid = mk('div', 'display:grid;grid-template-columns:1fr 1fr auto;gap:8px;align-items:end');
    var catLabelIn = document.createElement('input');
    catLabelIn.placeholder = 'Category name (e.g. Limited Edition)';
    catLabelIn.style.cssText = 'padding:8px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-size:12px;color:var(--text-high)';
    var catIdIn = document.createElement('input');
    catIdIn.placeholder = 'slug-id (auto)';
    catIdIn.style.cssText = catLabelIn.style.cssText;
    var addCatBtn = mk('button', 'padding:8px 16px;background:none;border:1px solid var(--accent);border-radius:8px;color:var(--accent);font-family:DM Sans,sans-serif;font-size:12px;font-weight:600;cursor:pointer', '+ Add category');
    addCatBtn.addEventListener('click', function () {
      var label = (catLabelIn.value || '').trim();
      if (!label) { alert('Enter a category name.'); return; }
      var id = (catIdIn.value || '').trim().toLowerCase();
      if (!id) id = TCJ_slugify(label);
      if (!id) { alert('Enter a valid category id.'); return; }
      if (TCJ_getAllCategories(catalog).some(function (c) { return c.id === id; })) {
        alert('That category id already exists.');
        return;
      }
      if (!catalog.custom_categories) catalog.custom_categories = [];
      catalog.custom_categories.push({ id: id, label: label });
      collapsed[id] = false;
      catLabelIn.value = '';
      catIdIn.value = '';
      refreshCatFilter();
      catFilter.value = id;
      renderList();
    });
    catGrid.appendChild(catLabelIn);
    catGrid.appendChild(catIdIn);
    catGrid.appendChild(addCatBtn);
    addCatSec.appendChild(catGrid);
    container.appendChild(addCatSec);

    container.dataset.built = '1';
  } catch (e) {
    container.dataset.built = '';
    container.innerHTML = '<div style="padding:16px;background:rgba(220,80,80,0.1);border:1px solid rgba(220,80,80,0.4);border-radius:10px;font-family:DM Sans,sans-serif;font-size:13px;color:#dc5050"><strong>Error:</strong> ' + String(e.message).replace(/</g, '&lt;') + '</div>';
  }
}
