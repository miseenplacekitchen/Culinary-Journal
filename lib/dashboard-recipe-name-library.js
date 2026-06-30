// Recipe Name Library — dish index before full recipe content exists.
// Requires dashboard-recipes.js/dashboard-shared.js helpers: rpc(), esc().
window.recipeNameLibrary = (function() {
  var _rows = [];
  var _total = 0;
  var _page = 1;
  var _PAGE_SIZE = 50;
  var _sort = { column: 'recipe_name', direction: 'asc' };
  var _selected = new Set();
  var _cats = [];
  var _taxRows = [];
  var _bound = false;
  var _COLS = [
    { key: 'select', label: '', fixed: true },
    { key: 'recipe_name', label: 'Recipe Name', required: true },
    { key: 'native_name', label: 'Native' },
    { key: 'category', label: 'Category', select: true },
    { key: 'sub_category', label: 'Sub-category', select: true },
    { key: 'division', label: 'Division', select: true },
    { key: 'origin_country', label: 'Country' },
    { key: 'origin_state', label: 'State' },
    { key: 'primary_ingredients', label: 'Primary Ingredients', array: true },
    { key: 'dietary_tags', label: 'Dietary Tags', array: true },
    { key: 'meal_type_tags', label: 'Meal Tags', array: true },
    { key: 'occasion_tags', label: 'Occasion Tags', array: true },
    { key: 'research_status', label: 'Research', select: true },
    { key: 'content_status', label: 'Content', select: true },
    { key: 'linked_recipe_name', label: 'Linked Recipe', readonly: true },
    { key: 'actions', label: 'Actions', fixed: true }
  ];
  var _RESEARCH = ['idea_only','needs_research','ready_to_draft','verified'];
  var _CONTENT = ['not_started','draft_created','linked','approved','duplicate','retired'];

  function h(s) { return (typeof esc === 'function') ? esc(s) : String(s == null ? '' : s).replace(/[&<>"']/g, function(c) { return ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'})[c]; }); }
  function arrText(v) { return Array.isArray(v) ? v.join('; ') : (v || ''); }
  function splitList(v) {
    return String(v || '').split(/[;,]/).map(function(s) { return s.trim(); }).filter(Boolean);
  }
  function csvCell(v) { return '"' + String(v == null ? '' : v).replace(/"/g, '""') + '"'; }

  function parseCsv(text) {
    var rows = [], row = [], cell = '', q = false;
    for (var i = 0; i < text.length; i++) {
      var ch = text[i], nx = text[i + 1];
      if (q) {
        if (ch === '"' && nx === '"') { cell += '"'; i++; }
        else if (ch === '"') q = false;
        else cell += ch;
      } else {
        if (ch === '"') q = true;
        else if (ch === ',') { row.push(cell); cell = ''; }
        else if (ch === '\n') { row.push(cell); rows.push(row); row = []; cell = ''; }
        else if (ch !== '\r') cell += ch;
      }
    }
    row.push(cell);
    if (row.length > 1 || row[0]) rows.push(row);
    return rows;
  }

  function rowToPayload(r) {
    var out = {};
    [
      'id','recipe_name','native_name','category','sub_category','division',
      'origin_continent','origin_country','origin_state','origin_locality',
      'source_notes','research_status','content_status','linked_recipe_id','notes'
    ].forEach(function(k) { out[k] = r[k] || ''; });
    ['alternate_names','primary_ingredients','dietary_tags','meal_type_tags','occasion_tags','style_tags'].forEach(function(k) {
      out[k] = Array.isArray(r[k]) ? r[k] : splitList(r[k]);
    });
    return out;
  }

  async function loadCatsAndTaxonomy() {
    try {
      var cats = typeof tcjFetchCategories === 'function' ? await tcjFetchCategories() : [];
      _cats = (cats || []).map(function(c) { return c.name || c; }).filter(Boolean);
    } catch (e) {
      console.warn('Recipe Name Library categories', e);
      _cats = [];
    }
    try {
      _taxRows = await rpc('get_recipe_taxonomy', { p_category: null }) || [];
    } catch (e) {
      console.warn('Recipe Name Library taxonomy', e);
      _taxRows = [];
    }
  }

  function subsFor(cat) {
    var set = {};
    _taxRows.forEach(function(r) {
      if (String(r.subcategory_category || '').trim() === String(cat || '').trim() && r.subcategory_name) set[r.subcategory_name] = true;
    });
    return Object.keys(set).sort();
  }

  function divsFor(cat, sub) {
    var set = {};
    _taxRows.forEach(function(r) {
      if (String(r.subcategory_category || '').trim() === String(cat || '').trim() &&
          String(r.subcategory_name || '').trim() === String(sub || '').trim() &&
          r.division_name) set[r.division_name] = true;
    });
    return Object.keys(set).sort();
  }

  function optHtml(values, active, blank) {
    var html = blank ? '<option value="">' + h(blank) + '</option>' : '';
    values.forEach(function(v) {
      html += '<option value="' + h(v) + '"' + (v === active ? ' selected' : '') + '>' + h(v) + '</option>';
    });
    return html;
  }

  function renderShell(root) {
    root.innerHTML =
      '<div style="font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);margin-bottom:12px;line-height:1.55">' +
        '<strong>Recipe Name Library v20260630a</strong> — master dish index before full recipe content. Add/import names, prefill taxonomy/tags, then link or create a recipe when ready.' +
      '</div>' +
      '<div class="rm-list-toolbar" style="margin-bottom:12px;flex-wrap:wrap">' +
        '<input type="text" class="ap-search" id="rnl-search" placeholder="Search recipe, native name, country..." style="flex:1;min-width:190px;max-width:300px">' +
        '<select id="rnl-category-filter" class="ing-cat-filter"><option value="">All categories</option></select>' +
        '<select id="rnl-research-filter" class="ing-cat-filter"><option value="">All research</option>' + optHtml(_RESEARCH, '', null) + '</select>' +
        '<select id="rnl-content-filter" class="ing-cat-filter"><option value="">All content</option>' + optHtml(_CONTENT, '', null) + '</select>' +
        '<select id="rnl-linked-filter" class="ing-cat-filter"><option value="">Linked + unlinked</option><option value="linked">Linked only</option><option value="unlinked">Unlinked only</option></select>' +
        '<button type="button" class="ing-add-btn" id="rnl-add-btn">+ Add name</button>' +
        '<button type="button" class="ing-add-btn" id="rnl-import-btn" style="background:none;border:1px solid var(--accent);color:var(--accent)">Import CSV</button>' +
        '<button type="button" class="ing-add-btn" id="rnl-export-btn" style="background:none;border:1px solid var(--accent);color:var(--accent)">Export CSV</button>' +
        '<button type="button" class="ing-add-btn" id="rnl-print-btn" style="background:none;border:1px solid var(--border);color:var(--text-mid)">Print selected linked</button>' +
        '<input type="file" id="rnl-file" accept=".csv,text/csv" style="display:none">' +
      '</div>' +
      '<div id="rnl-count" style="font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);margin-bottom:8px"></div>' +
      '<div class="ap-table-wrap" style="overflow:auto">' +
        '<table class="ap-table" id="rnl-table"><thead></thead><tbody id="rnl-tbody"><tr><td class="ap-empty-row">Loading...</td></tr></tbody></table>' +
      '</div>' +
      '<div id="rnl-pagination" style="display:none;align-items:center;justify-content:center;gap:8px;margin-top:14px"></div>';
  }

  function bindShell() {
    if (_bound) return;
    _bound = true;
    var t;
    var search = document.getElementById('rnl-search');
    if (search) search.addEventListener('input', function() { clearTimeout(t); t = setTimeout(function() { _page = 1; loadRows(); }, 300); });
    ['rnl-category-filter','rnl-research-filter','rnl-content-filter','rnl-linked-filter'].forEach(function(id) {
      var el = document.getElementById(id);
      if (el) el.addEventListener('change', function() { _page = 1; loadRows(); });
    });
    var add = document.getElementById('rnl-add-btn');
    if (add) add.addEventListener('click', addRow);
    var exp = document.getElementById('rnl-export-btn');
    if (exp) exp.addEventListener('click', exportCsv);
    var imp = document.getElementById('rnl-import-btn');
    var file = document.getElementById('rnl-file');
    if (imp && file) imp.addEventListener('click', function() { file.click(); });
    if (file) file.addEventListener('change', importCsv);
    var print = document.getElementById('rnl-print-btn');
    if (print) print.addEventListener('click', printSelected);
  }

  function fillCategoryFilter() {
    var sel = document.getElementById('rnl-category-filter');
    if (!sel || sel.dataset.init === '1') return;
    sel.dataset.init = '1';
    _cats.forEach(function(c) {
      var o = document.createElement('option');
      o.value = c; o.textContent = c;
      sel.appendChild(o);
    });
  }

  async function loadRows() {
    var tbody = document.getElementById('rnl-tbody');
    if (tbody) tbody.innerHTML = '<tr><td colspan="' + _COLS.length + '" class="ap-empty-row">Loading...</td></tr>';
    try {
      var result = await rpc('admin_list_recipe_name_library', {
        p_limit: _PAGE_SIZE,
        p_offset: (_page - 1) * _PAGE_SIZE,
        p_search: (document.getElementById('rnl-search') || {}).value || null,
        p_research_status: (document.getElementById('rnl-research-filter') || {}).value || null,
        p_content_status: (document.getElementById('rnl-content-filter') || {}).value || null,
        p_linked: (document.getElementById('rnl-linked-filter') || {}).value || null,
        p_category: (document.getElementById('rnl-category-filter') || {}).value || null,
        p_sort_col: _sort.column,
        p_sort_dir: _sort.direction
      });
      _rows = (result && result.rows) || [];
      _total = parseInt(result && result.total, 10) || 0;
      renderTable();
      renderPagination();
    } catch (e) {
      if (tbody) tbody.innerHTML = '<tr><td colspan="' + _COLS.length + '" class="ap-empty-row">Error: ' + h(e.message || e) + '<br>Run <code>database/sql/fix-recipe-name-library.sql</code> in Supabase, then refresh.</td></tr>';
    }
  }

  function renderTable() {
    var table = document.getElementById('rnl-table');
    var tbody = document.getElementById('rnl-tbody');
    var count = document.getElementById('rnl-count');
    if (!table || !tbody) return;
    if (count) {
      var start = _total ? ((_page - 1) * _PAGE_SIZE) + 1 : 0;
      var end = Math.min(_page * _PAGE_SIZE, _total);
      count.textContent = _total + ' recipe name' + (_total === 1 ? '' : 's') + (_total ? ' (showing ' + start + '-' + end + ')' : '');
    }
    table.querySelector('thead').innerHTML = '<tr>' + _COLS.map(function(c) {
      if (c.key === 'select') return '<th style="width:28px"><input type="checkbox" id="rnl-select-all"></th>';
      if (c.fixed || c.readonly) return '<th>' + h(c.label) + '</th>';
      var arrow = _sort.column === c.key ? (_sort.direction === 'asc' ? ' ▲' : ' ▼') : '';
      return '<th class="rnl-sort" data-col="' + h(c.key) + '" style="cursor:pointer;white-space:nowrap">' + h(c.label) + arrow + '</th>';
    }).join('') + '</tr>';
    tbody.innerHTML = '';
    if (!_rows.length) {
      tbody.innerHTML = '<tr><td colspan="' + _COLS.length + '" class="ap-empty-row">No recipe names yet. Add one or import a CSV.</td></tr>';
      return;
    }
    _rows.forEach(function(r) {
      var tr = document.createElement('tr');
      tr.dataset.id = r.id;
      tr.innerHTML = _COLS.map(function(c) { return renderCell(r, c); }).join('');
      tbody.appendChild(tr);
    });
    bindTableEvents();
  }

  function renderCell(r, c) {
    if (c.key === 'select') {
      var disabled = r.linked_recipe_id ? '' : ' disabled title="Only linked recipes can be selected for print"';
      return '<td><input type="checkbox" class="rnl-row-cb" value="' + h(r.id) + '"' + (_selected.has(r.id) ? ' checked' : '') + disabled + '></td>';
    }
    if (c.key === 'actions') {
      var print = r.linked_recipe_id ? '<button class="ap-mini-btn rnl-print-one" data-id="' + h(r.linked_recipe_id) + '">Print</button>' : '';
      return '<td style="white-space:nowrap">' +
        (r.linked_recipe_id ? '<button class="ap-mini-btn rnl-unlink">Unlink</button>' : '<button class="ap-mini-btn rnl-create">Create recipe</button>') +
        print +
        '<button class="ap-mini-btn rnl-link">Link ID</button>' +
        '<button class="ap-mini-btn rnl-delete" style="color:#dc5050">Delete</button>' +
      '</td>';
    }
    if (c.key === 'linked_recipe_name') {
      var txt = r.linked_recipe_id ? ((r.linked_recipe_code ? r.linked_recipe_code + ' - ' : '') + (r.linked_recipe_name || r.linked_recipe_id) + (r.linked_recipe_status ? ' (' + r.linked_recipe_status + ')' : '')) : 'Unlinked';
      return '<td style="min-width:180px;color:' + (r.linked_recipe_id ? 'var(--text-high)' : 'var(--text-mid)') + '">' + h(txt) + '</td>';
    }
    if (c.key === 'category') {
      return '<td>' + selectCell(c.key, _cats, r[c.key], 'Category...') + '</td>';
    }
    if (c.key === 'sub_category') {
      return '<td>' + selectCell(c.key, subsFor(r.category), r[c.key], 'Sub...') + '</td>';
    }
    if (c.key === 'division') {
      return '<td>' + selectCell(c.key, divsFor(r.category, r.sub_category), r[c.key], 'Division...') + '</td>';
    }
    if (c.key === 'research_status') {
      return '<td>' + selectCell(c.key, _RESEARCH, r[c.key] || 'idea_only', '') + '</td>';
    }
    if (c.key === 'content_status') {
      return '<td>' + selectCell(c.key, _CONTENT, r[c.key] || 'not_started', '') + '</td>';
    }
    var val = c.array ? arrText(r[c.key]) : (r[c.key] || '');
    return '<td><input class="rnl-edit" data-field="' + h(c.key) + '" value="' + h(val) + '" style="min-width:130px;width:100%;padding:5px 7px;background:var(--bg);border:1px solid var(--border);border-radius:6px;color:var(--text-high);font-size:12px"></td>';
  }

  function selectCell(field, options, active, blank) {
    return '<select class="rnl-edit" data-field="' + h(field) + '" style="min-width:130px;width:100%;padding:5px 7px;background:var(--bg);border:1px solid var(--border);border-radius:6px;color:var(--text-high);font-size:12px">' +
      optHtml(options, active || '', blank) + '</select>';
  }

  function bindTableEvents() {
    document.querySelectorAll('#rnl-table .rnl-sort').forEach(function(th) {
      th.addEventListener('click', function() {
        var col = th.dataset.col;
        if (_sort.column === col) _sort.direction = _sort.direction === 'asc' ? 'desc' : 'asc';
        else _sort = { column: col, direction: 'asc' };
        loadRows();
      });
    });
    var all = document.getElementById('rnl-select-all');
    if (all) all.addEventListener('change', function() {
      document.querySelectorAll('.rnl-row-cb:not(:disabled)').forEach(function(cb) {
        cb.checked = all.checked;
        if (cb.checked) _selected.add(cb.value); else _selected.delete(cb.value);
      });
    });
    document.querySelectorAll('.rnl-row-cb').forEach(function(cb) {
      cb.addEventListener('change', function() { if (cb.checked) _selected.add(cb.value); else _selected.delete(cb.value); });
    });
    document.querySelectorAll('#rnl-tbody .rnl-edit').forEach(function(el) {
      el.addEventListener('change', function() { saveCell(el); });
    });
    document.querySelectorAll('.rnl-create').forEach(function(btn) { btn.addEventListener('click', createRecipe); });
    document.querySelectorAll('.rnl-delete').forEach(function(btn) { btn.addEventListener('click', deleteRow); });
    document.querySelectorAll('.rnl-link').forEach(function(btn) { btn.addEventListener('click', linkRow); });
    document.querySelectorAll('.rnl-unlink').forEach(function(btn) { btn.addEventListener('click', unlinkRow); });
    document.querySelectorAll('.rnl-print-one').forEach(function(btn) { btn.addEventListener('click', function() { window.open('print-studio.html?id=' + encodeURIComponent(btn.dataset.id), '_blank'); }); });
  }

  async function saveCell(el) {
    var tr = el.closest('tr');
    var id = tr && tr.dataset.id;
    var r = _rows.find(function(x) { return x.id === id; });
    if (!r) return;
    var field = el.dataset.field;
    r[field] = ['alternate_names','primary_ingredients','dietary_tags','meal_type_tags','occasion_tags','style_tags'].indexOf(field) !== -1 ? splitList(el.value) : el.value;
    if (field === 'category') { r.sub_category = ''; r.division = ''; }
    if (field === 'sub_category') { r.division = ''; }
    el.style.borderColor = 'var(--accent)';
    try {
      await rpc('admin_upsert_recipe_name_library', { p_row: rowToPayload(r) });
      el.style.borderColor = 'var(--border)';
      if (field === 'category' || field === 'sub_category') renderTable();
      if (typeof auditLog === 'function') auditLog('Recipe Name Library', 'Row Updated', null, null, null, r.recipe_name + ' - ' + field);
    } catch (e) {
      el.style.borderColor = '#dc5050';
      alert(e.message || e);
    }
  }

  async function addRow() {
    var name = prompt('Recipe name');
    if (!name || !name.trim()) return;
    try {
      await rpc('admin_upsert_recipe_name_library', { p_row: { recipe_name: name.trim(), research_status: 'idea_only', content_status: 'not_started' } });
      await loadRows();
    } catch (e) {
      alert(e.message || e);
    }
  }

  async function createRecipe(e) {
    var id = e.target.closest('tr').dataset.id;
    if (!confirm('Create a pending draft recipe from this library row?')) return;
    try {
      var recipeId = await rpc('admin_create_recipe_from_name_library', { p_id: id });
      await loadRows();
      if (recipeId && confirm('Draft created. Open it in Print/recipe editor flow now?')) {
        window.open('submit-recipe.html?adminReview=' + encodeURIComponent(recipeId) + '&embedded=1', '_blank');
      }
    } catch (err) {
      alert(err.message || err);
    }
  }

  async function linkRow(e) {
    var id = e.target.closest('tr').dataset.id;
    var recipeId = prompt('Paste linked submitted_recipes recipe UUID');
    if (!recipeId) return;
    try {
      await rpc('admin_link_recipe_name_library', { p_id: id, p_recipe_id: recipeId.trim() });
      await loadRows();
    } catch (err) {
      alert(err.message || err);
    }
  }

  async function unlinkRow(e) {
    var id = e.target.closest('tr').dataset.id;
    if (!confirm('Unlink this library name from its recipe?')) return;
    try {
      await rpc('admin_link_recipe_name_library', { p_id: id, p_recipe_id: null });
      _selected.delete(id);
      await loadRows();
    } catch (err) {
      alert(err.message || err);
    }
  }

  async function deleteRow(e) {
    var id = e.target.closest('tr').dataset.id;
    if (!confirm('Delete this recipe name library row? This does not delete linked recipes.')) return;
    try {
      await rpc('admin_delete_recipe_name_library', { p_id: id });
      _selected.delete(id);
      await loadRows();
    } catch (err) {
      alert(err.message || err);
    }
  }

  function exportCsv() {
    var headers = ['ID','Recipe Name','Native Name','Alternate Names','Category','Sub-category','Division','Continent','Country','State','Locality','Primary Ingredients','Dietary Tags','Meal Type Tags','Occasion Tags','Style Tags','Research Status','Content Status','Linked Recipe ID','Linked Recipe','Notes','Source Notes'];
    var lines = [headers.map(csvCell).join(',')];
    _rows.forEach(function(r) {
      lines.push([
        r.id, r.recipe_name, r.native_name, arrText(r.alternate_names),
        r.category, r.sub_category, r.division,
        r.origin_continent, r.origin_country, r.origin_state, r.origin_locality,
        arrText(r.primary_ingredients), arrText(r.dietary_tags), arrText(r.meal_type_tags), arrText(r.occasion_tags), arrText(r.style_tags),
        r.research_status, r.content_status, r.linked_recipe_id,
        r.linked_recipe_name || '', r.notes, r.source_notes
      ].map(csvCell).join(','));
    });
    var blob = new Blob(['\ufeff' + lines.join('\r\n')], { type: 'text/csv;charset=utf-8' });
    var url = URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url;
    a.download = 'recipe-name-library-' + new Date().toISOString().slice(0, 10) + '.csv';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }

  async function importCsv(e) {
    var file = e.target.files && e.target.files[0];
    e.target.value = '';
    if (!file) return;
    var text = await file.text();
    var parsed = parseCsv(text.replace(/^\ufeff/, ''));
    if (parsed.length < 2) { alert('CSV has no rows.'); return; }
    var headers = parsed.shift().map(function(hd) { return hd.trim(); });
    var rows = parsed.map(function(cols) {
      var o = {};
      headers.forEach(function(hd, i) { o[hd] = cols[i] || ''; });
      return o;
    });
    try {
      var result = await rpc('admin_import_recipe_name_library', { p_rows: rows });
      alert('Import complete: ' + (result.inserted || 0) + ' inserted, ' + (result.updated || 0) + ' updated, ' + (result.skipped || 0) + ' skipped.');
      await loadRows();
    } catch (err) {
      alert(err.message || err);
    }
  }

  function printSelected() {
    var ids = _rows.filter(function(r) { return _selected.has(r.id) && r.linked_recipe_id; }).map(function(r) { return r.linked_recipe_id; });
    if (!ids.length) { alert('Select one or more linked recipe names first.'); return; }
    if (ids.length === 1) window.open('print-studio.html?id=' + encodeURIComponent(ids[0]), '_blank');
    else window.open('print-studio.html?ids=' + encodeURIComponent(ids.join(',')), '_blank');
  }

  function renderPagination() {
    var el = document.getElementById('rnl-pagination');
    if (!el) return;
    var pages = Math.max(1, Math.ceil(_total / _PAGE_SIZE));
    if (_total <= _PAGE_SIZE) { el.style.display = 'none'; return; }
    el.style.display = 'flex';
    el.innerHTML = '<button type="button" class="ap-pg-btn" id="rnl-prev" ' + (_page <= 1 ? 'disabled' : '') + '>Prev</button>' +
      '<span style="font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);padding:0 12px">Page ' + _page + ' of ' + pages + '</span>' +
      '<button type="button" class="ap-pg-btn" id="rnl-next" ' + (_page >= pages ? 'disabled' : '') + '>Next</button>';
    document.getElementById('rnl-prev').onclick = function() { if (_page > 1) { _page--; loadRows(); } };
    document.getElementById('rnl-next').onclick = function() { if (_page < pages) { _page++; loadRows(); } };
  }

  async function loadRecipeNameLibraryTab() {
    var root = document.getElementById('recipe-name-library-root');
    if (!root) return;
    if (!root.dataset.built) {
      await loadCatsAndTaxonomy();
      renderShell(root);
      fillCategoryFilter();
      bindShell();
      root.dataset.built = '1';
    }
    await loadRows();
  }

  return { loadRecipeNameLibraryTab: loadRecipeNameLibraryTab };
})();
