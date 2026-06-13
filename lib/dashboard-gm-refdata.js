// dashboard-gm-refdata.js — GM lookup tabs (IM-style editable reference data + merge propagation)
(function (global) {
  var S = {
    inp: "font-family:'DM Sans',sans-serif;font-size:12px;padding:5px 8px;border:1px solid var(--border);border-radius:6px;background:var(--bg);color:var(--text-high);outline:none;width:100%;box-sizing:border-box",
    btn: "padding:5px 12px;border:none;border-radius:6px;font-family:'DM Sans',sans-serif;font-size:11px;font-weight:600;cursor:pointer;background:var(--accent);color:#fff",
    btnGhost: "padding:4px 10px;background:none;border:1px solid var(--border);border-radius:6px;font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-mid);cursor:pointer",
    hdr: "font-family:'DM Sans',sans-serif;font-size:9px;font-weight:600;letter-spacing:.1em;text-transform:uppercase;color:var(--text-mid)"
  };

  function esc(s) {
    return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  var LOOKUPS = [
    { key: 'cat_high_level', table: 'cat_high_level', label: 'High-level categories', order: 'name',
      cols: [{ f: 'slug', l: 'Slug' }, { f: 'name', l: 'Name' }, { f: 'definition', l: 'Definition' }] },
    { key: 'cat_main', table: 'cat_main', label: 'Main categories', order: 'name',
      cols: [{ f: 'slug', l: 'Slug' }, { f: 'name', l: 'Name' }, { f: 'definition', l: 'Definition' }] },
    { key: 'growth_habits', table: 'growth_habits', label: 'Growth habits', order: 'name',
      cols: [{ f: 'slug', l: 'Slug' }, { f: 'name', l: 'Name' }, { f: 'description', l: 'Description' }] },
    { key: 'garden_layers', table: 'garden_layers', label: 'Garden layers', order: 'name',
      cols: [{ f: 'slug', l: 'Slug' }, { f: 'name', l: 'Name' }, { f: 'description', l: 'Description' }] },
    { key: 'lifecycles', table: 'lifecycles', label: 'Lifecycles', order: 'name',
      cols: [{ f: 'slug', l: 'Slug' }, { f: 'name', l: 'Name' }, { f: 'traits', l: 'Traits' }] },
    { key: 'ease_ratings', table: 'ease_ratings', label: 'Ease ratings', order: 'score',
      cols: [{ f: 'score', l: 'Score', type: 'number' }, { f: 'name', l: 'Name' }, { f: 'definition', l: 'Definition' }] },
    { key: 'soil_types', table: 'soil_types', label: 'Soil types', order: 'name',
      cols: [{ f: 'slug', l: 'Slug' }, { f: 'name', l: 'Name' }, { f: 'ph_low', l: 'pH low' }, { f: 'ph_high', l: 'pH high' }] },
    { key: 'sunlight_levels', table: 'sunlight_levels', label: 'Sunlight levels', order: 'name',
      cols: [{ f: 'slug', l: 'Slug' }, { f: 'name', l: 'Name' }, { f: 'hours', l: 'Hours' }] },
    { key: 'seed_saving_groups', table: 'seed_saving_groups', label: 'Seed-saving groups', order: 'grp',
      cols: [{ f: 'grp', l: 'Group', type: 'number' }, { f: 'name', l: 'Name' }, { f: 'notes', l: 'Notes' }] },
    { key: 'tags', table: 'tags', label: 'Tags', order: 'name',
      cols: [{ f: 'slug', l: 'Slug' }, { f: 'name', l: 'Name' }] },
    { key: 'climate_zones', table: 'climate_zones', label: 'Growing climates', order: 'name',
      cols: [{ f: 'slug', l: 'Slug' }, { f: 'name', l: 'Name (public)' }] },
    { key: 'regions', table: 'regions', label: 'Regions', order: 'name', climateCol: true,
      cols: [{ f: 'slug', l: 'Slug' }, { f: 'name', l: 'Name' }, { f: 'is_active', l: 'Active', type: 'bool' }] },
    { key: 'zone_definitions', table: 'zone_definitions', label: 'Permaculture zones', order: 'zone',
      cols: [{ f: 'zone', l: 'Zone', type: 'number' }, { f: 'name', l: 'Name' }, { f: 'description', l: 'Description' }] }
  ];

  function rowPayload(tr, cfg) {
    var row = { id: tr.dataset.id || null };
    cfg.cols.forEach(function (c) {
      var el = tr.querySelector('[data-f="' + c.f + '"]');
      if (!el) return;
      row[c.f] = c.type === 'bool' ? (el.checked ? 'true' : 'false') : el.value;
    });
    if (cfg.climateCol) {
      var cz = tr.querySelector('[data-f="climate_zone_id"]');
      if (cz) row.climate_zone_id = cz.value || null;
    }
    return row;
  }

  async function saveRow(tr, cfg, btn) {
    if (btn) { btn.disabled = true; btn.textContent = '…'; }
    try {
      var payload = rowPayload(tr, cfg);
      await global.rpc('admin_upsert_garden_lookup', { p_table: cfg.table, p_row: payload });
      if (typeof global.auditLog === 'function') {
        global.auditLog('GM Interface > Lookup', 'Saved', cfg.label, null, payload.name || payload.slug, cfg.table);
      }
      if (btn) btn.textContent = 'Saved';
      setTimeout(function () { if (btn) { btn.disabled = false; btn.textContent = 'Save'; } }, 900);
    } catch (e) {
      alert('Save failed: ' + e.message + '\nRun garden-v4-11-lookup-admin-rpcs.sql on Supabase.');
      if (btn) { btn.disabled = false; btn.textContent = 'Save'; }
    }
  }

  async function deleteRow(tr, cfg) {
    var id = tr.dataset.id;
    if (!id) { tr.remove(); return; }
    try {
      var usage = await global.rpc('admin_get_garden_lookup_usage', { p_table: cfg.table, p_id: id });
      var parts = [];
      Object.keys(usage || {}).forEach(function (k) {
        if (k !== 'table' && k !== 'id' && usage[k]) parts.push(k + ': ' + usage[k]);
      });
      var msg = parts.length ? 'In use — ' + parts.join(', ') + '.\n\nMerge into another row (paste target UUID) or cancel.' : 'Delete this row?';
      var reassign = parts.length ? prompt(msg, '') : (confirm('Delete this lookup row?') ? '' : null);
      if (reassign === null) return;
      if (reassign) {
        await global.rpc('admin_delete_garden_lookup', { p_table: cfg.table, p_id: id, p_reassign_to: reassign });
        alert('Merged into target row. References updated.');
      } else {
        await global.rpc('admin_delete_garden_lookup', { p_table: cfg.table, p_id: id, p_reassign_to: null });
      }
      tr.remove();
      if (typeof global.reloadGmInterface === 'function') global.reloadGmInterface();
    } catch (e) {
      alert('Delete/merge failed: ' + e.message);
    }
  }

  function buildRow(r, cfg, core) {
    var tr = document.createElement('tr');
    tr.dataset.id = r.id || '';
    var idCell = document.createElement('td');
    idCell.style.fontSize = '10px';
    idCell.style.color = 'var(--text-muted)';
    idCell.textContent = r.id ? String(r.id).slice(0, 8) + '…' : 'new';
    tr.appendChild(idCell);

    cfg.cols.forEach(function (c) {
      var td = document.createElement('td');
      if (c.type === 'bool') {
        var cb = document.createElement('input');
        cb.type = 'checkbox';
        cb.dataset.f = c.f;
        cb.checked = r[c.f] !== false && r[c.f] !== 'false';
        td.appendChild(cb);
      } else {
        var inp = document.createElement('input');
        inp.type = c.type === 'number' ? 'number' : 'text';
        inp.value = r[c.f] != null ? r[c.f] : '';
        inp.dataset.f = c.f;
        inp.style.cssText = S.inp;
        if (c.f === 'slug') inp.style.fontFamily = 'monospace';
        td.appendChild(inp);
      }
      tr.appendChild(td);
    });

    if (cfg.climateCol) {
      var tdC = document.createElement('td');
      var sel = document.createElement('select');
      sel.dataset.f = 'climate_zone_id';
      sel.style.cssText = S.inp;
      sel.innerHTML = '<option value="">—</option>' + (core.climates || []).map(function (cz) {
        return '<option value="' + esc(cz.id) + '"' + (r.climate_zone_id === cz.id ? ' selected' : '') + '>' + esc(cz.name) + '</option>';
      }).join('');
      tdC.appendChild(sel);
      tr.appendChild(tdC);
    }

    var tdAct = document.createElement('td');
    tdAct.style.whiteSpace = 'nowrap';
    var saveBtn = document.createElement('button');
    saveBtn.type = 'button';
    saveBtn.textContent = 'Save';
    saveBtn.style.cssText = S.btnGhost;
    saveBtn.style.marginRight = '4px';
    saveBtn.addEventListener('click', function () { saveRow(tr, cfg, saveBtn); });
    var delBtn = document.createElement('button');
    delBtn.type = 'button';
    delBtn.textContent = 'Del/Merge';
    delBtn.style.cssText = S.btnGhost;
    delBtn.style.borderColor = '#dc5050';
    delBtn.style.color = '#dc5050';
    delBtn.addEventListener('click', function () { deleteRow(tr, cfg); });
    tdAct.appendChild(saveBtn);
    tdAct.appendChild(delBtn);
    tr.appendChild(tdAct);
    return tr;
  }

  async function renderLookupPanel(cfg, core, container) {
    container.innerHTML = '<div class="ap-loading" style="padding:12px 0">Loading…</div>';
    var selectCols = ['id'].concat(cfg.cols.map(function (c) { return c.f; }));
    if (cfg.climateCol) selectCols.push('climate_zone_id');
    var rows = [];
    try {
      rows = await global.gmFetch('/rest/v1/' + cfg.table + '?select=' + selectCols.join(',') + '&order=' + cfg.order);
    } catch (e) {
      container.innerHTML = '<p style="color:#dc5050;font-size:13px">Could not load ' + esc(cfg.table) + '</p>';
      return;
    }

    var wrap = document.createElement('div');
    var note = document.createElement('p');
    note.style.cssText = "font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-mid);margin:0 0 12px;line-height:1.6";
    note.innerHTML = 'Add or edit dropdown values. <strong>Del/Merge</strong> moves all plant/care/calendar references to a target row (paste UUID) — like IM category rename.';
    wrap.appendChild(note);

    var table = document.createElement('table');
    table.className = 'ap-table';
    table.style.marginTop = '8px';
    var thead = document.createElement('thead');
    var hr = document.createElement('tr');
    ['ID'].concat(cfg.cols.map(function (c) { return c.l; })).concat(cfg.climateCol ? ['Climate'] : []).concat(['']).forEach(function (h) {
      var th = document.createElement('th');
      th.textContent = h;
      hr.appendChild(th);
    });
    thead.appendChild(hr);
    table.appendChild(thead);
    var tbody = document.createElement('tbody');
    (rows || []).forEach(function (r) { tbody.appendChild(buildRow(r, cfg, core)); });
    table.appendChild(tbody);
    wrap.appendChild(table);

    var addBtn = document.createElement('button');
    addBtn.type = 'button';
    addBtn.textContent = '+ Add row';
    addBtn.style.cssText = S.btn;
    addBtn.style.marginTop = '12px';
    addBtn.addEventListener('click', function () {
      tbody.appendChild(buildRow({}, cfg, core));
    });
    wrap.appendChild(addBtn);

    container.innerHTML = '';
    container.appendChild(wrap);
  }

  function render() {
    var active = global.localStorage.getItem('tcj_gm_refdata_tab') || 'cat_high_level';
    var tabs = LOOKUPS.map(function (lk) {
      return '<button type="button" class="ap-inner-tab' + (lk.key === active ? ' active' : '') + '" data-gmref="' + lk.key + '">' + esc(lk.label) + '</button>';
    }).join('');
    return '<p style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);margin:0 0 14px;line-height:1.65">' +
      '<strong>Lookup data management</strong> — same pattern as IM Interface. Rename or merge updates plants, care, and calendar rows that reference the old value.</p>' +
      '<div class="ap-inner-tabs" id="gm-refdata-subtabs" style="margin-bottom:14px;flex-wrap:wrap;display:flex;gap:4px">' + tabs + '</div>' +
      '<div id="gm-refdata-panel"><div class="ap-loading" style="padding:12px 0">Loading…</div></div>';
  }

  function init(core) {
    var bar = document.getElementById('gm-refdata-subtabs');
    var panel = document.getElementById('gm-refdata-panel');
    if (!bar || !panel) return;
    var active = global.localStorage.getItem('tcj_gm_refdata_tab') || 'cat_high_level';
    bar.querySelectorAll('[data-gmref]').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var key = btn.dataset.gmref;
        global.localStorage.setItem('tcj_gm_refdata_tab', key);
        bar.querySelectorAll('[data-gmref]').forEach(function (b) { b.classList.toggle('active', b.dataset.gmref === key); });
        var cfg = LOOKUPS.find(function (x) { return x.key === key; });
        if (cfg) renderLookupPanel(cfg, core, panel);
      });
    });
    var cfg0 = LOOKUPS.find(function (x) { return x.key === active; }) || LOOKUPS[0];
    renderLookupPanel(cfg0, core, panel);
  }

  global.GmRefData = { render: render, init: init, LOOKUPS: LOOKUPS };
})(window);
