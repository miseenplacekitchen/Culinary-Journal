// Dish Index — canonical dish metadata before ingredients + method.
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
  var _editRow = null;
  var _SHELL_VERSION = '20260701c';

  var _RESEARCH = ['idea_only', 'needs_research', 'ready_to_draft', 'verified'];
  var _CONTENT = ['not_started', 'draft_created', 'linked', 'approved', 'duplicate', 'retired'];
  var _SOURCE_TYPES = ['Original', 'Adapted', 'Inspired by', 'Traditional', 'Family recipe'];
  var _DIFFICULTY = ['', 'Easy', 'Medium', 'Hard', 'Expert'];
  var _SPICE = ['Not Applicable', 'Mild', 'Medium', 'Hot', 'Very Hot'];
  var _SWEET = ['Not Applicable', 'Lightly sweet', 'Medium sweet', 'Very sweet'];

  var _TABLE_COLS = [
    { key: 'select', label: '', fixed: true },
    { key: 'recipe_name', label: 'Recipe Name', required: true },
    { key: 'native_name', label: 'Native' },
    { key: 'category', label: 'Category', select: true },
    { key: 'sub_category', label: 'Sub-category', select: true },
    { key: 'division', label: 'Division', select: true },
    { key: 'origin_country', label: 'Country' },
    { key: 'research_status', label: 'Research', select: true },
    { key: 'content_status', label: 'Content', select: true },
    { key: 'linked_recipe_name', label: 'Linked Recipe', readonly: true },
    { key: 'actions', label: 'Actions', fixed: true }
  ];

  var _ARRAY_FIELDS = [
    'alternate_names', 'primary_ingredients', 'dietary_tags', 'meal_type_tags',
    'occasion_tags', 'style_tags', 'health_tags', 'flavor_profile_tags', 'equipment'
  ];

  var _TEXT_FIELDS = [
    'id', 'recipe_name', 'native_name', 'category', 'sub_category', 'division',
    'origin_continent', 'origin_country', 'origin_state', 'origin_locality',
    'introduction', 'description', 'image_url', 'image_source_url',
    'prep_time_minutes', 'cook_time_minutes', 'additional_time_minutes',
    'servings', 'servings_unit', 'difficulty', 'spice_level', 'sweet_level', 'cooking_style',
    'cooking_notes', 'shelf_life_value', 'shelf_life_unit', 'shelf_life_storage',
    'after_open_value', 'after_open_unit',
    'source_type', 'credit_name', 'credit_handle', 'credit_url', 'source_url', 'source_notes',
    'research_status', 'content_status', 'linked_recipe_id', 'notes'
  ];

  var _CSV_HEADERS = [
    'ID', 'Recipe Name', 'Native Name', 'Alternate Names', 'Category', 'Sub-category', 'Division',
    'Continent', 'Country', 'State', 'Locality', 'Primary Ingredients',
    'Dietary Tags', 'Health Tags', 'Meal Type Tags', 'Occasion Tags', 'Style Tags', 'Flavor Profile Tags',
    'Introduction', 'Description', 'Image URL', 'Image Source URL',
    'Prep Time Minutes', 'Cook Time Minutes', 'Additional Time Minutes',
    'Servings', 'Servings Unit', 'Difficulty', 'Spice Level', 'Sweet Level', 'Cooking Style',
    'Equipment', 'Cooking Notes',
    'Shelf Life Value', 'Shelf Life Unit', 'Shelf Life Storage', 'After Open Value', 'After Open Unit',
    'Source Type', 'Credit Name', 'Credit Handle', 'Credit URL', 'Source URL', 'Source Notes',
    'Research Status', 'Content Status', 'Linked Recipe ID', 'Linked Recipe', 'Notes'
  ];

  var _EDITOR_GROUPS = [
    { title: 'Identity', fields: [
      { key: 'recipe_name', label: 'Recipe Name', required: true },
      { key: 'native_name', label: 'Native Name' },
      { key: 'alternate_names', label: 'Alternate Names', array: true, hint: 'Semicolon-separated' }
    ]},
    { title: 'Taxonomy', fields: [
      { key: 'category', label: 'Category', taxonomy: 'category' },
      { key: 'sub_category', label: 'Sub-category', taxonomy: 'sub' },
      { key: 'division', label: 'Division', taxonomy: 'div' }
    ]},
    { title: 'Origin', fields: [
      { key: 'origin_continent', label: 'Continent' },
      { key: 'origin_country', label: 'Country' },
      { key: 'origin_state', label: 'State / Province' },
      { key: 'origin_locality', label: 'Locality' }
    ]},
    { title: 'Story & Media', fields: [
      { key: 'introduction', label: 'Introduction', textarea: true },
      { key: 'description', label: 'Description', textarea: true },
      { key: 'image_url', label: 'Image URL' },
      { key: 'image_source_url', label: 'Image Source URL', hint: 'Original upload URL for crop reference' }
    ]},
    { title: 'Times & Yield', fields: [
      { key: 'prep_time_minutes', label: 'Prep (minutes)', number: true },
      { key: 'cook_time_minutes', label: 'Cook (minutes)', number: true },
      { key: 'additional_time_minutes', label: 'Additional (minutes)', number: true },
      { key: 'servings', label: 'Servings', number: true },
      { key: 'servings_unit', label: 'Servings Unit' },
      { key: 'difficulty', label: 'Difficulty', select: _DIFFICULTY },
      { key: 'spice_level', label: 'Spice Level', select: _SPICE },
      { key: 'sweet_level', label: 'Sweet Level', select: _SWEET },
      { key: 'cooking_style', label: 'Cooking Style' }
    ]},
    { title: 'Tags & Focus', fields: [
      { key: 'primary_ingredients', label: 'Primary Ingredients', array: true, hint: 'Planning hints only — not full recipe ingredients' },
      { key: 'dietary_tags', label: 'Dietary Tags', array: true },
      { key: 'health_tags', label: 'Health Tags', array: true },
      { key: 'meal_type_tags', label: 'Meal Type Tags', array: true },
      { key: 'occasion_tags', label: 'Occasion Tags', array: true },
      { key: 'style_tags', label: 'Style Tags', array: true },
      { key: 'flavor_profile_tags', label: 'Flavor Profile Tags', array: true }
    ]},
    { title: 'Keeping & Equipment', fields: [
      { key: 'equipment', label: 'Equipment', array: true },
      { key: 'cooking_notes', label: 'Cooking Notes', textarea: true },
      { key: 'shelf_life_value', label: 'Shelf Life Value' },
      { key: 'shelf_life_unit', label: 'Shelf Life Unit' },
      { key: 'shelf_life_storage', label: 'Shelf Life Storage' },
      { key: 'after_open_value', label: 'After Open Value' },
      { key: 'after_open_unit', label: 'After Open Unit' }
    ]},
    { title: 'Source & Credit', fields: [
      { key: 'source_type', label: 'Source Type', select: _SOURCE_TYPES },
      { key: 'credit_name', label: 'Credit Name' },
      { key: 'credit_handle', label: 'Credit Handle' },
      { key: 'credit_url', label: 'Credit URL' },
      { key: 'source_url', label: 'Source URL' },
      { key: 'source_notes', label: 'Source Notes', textarea: true }
    ]},
    { title: 'Workflow', fields: [
      { key: 'research_status', label: 'Research Status', select: _RESEARCH },
      { key: 'content_status', label: 'Content Status', select: _CONTENT },
      { key: 'notes', label: 'Admin Notes', textarea: true }
    ]}
  ];

  function h(s) {
    return (typeof esc === 'function') ? esc(s) : String(s == null ? '' : s).replace(/[&<>"']/g, function(c) {
      return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c];
    });
  }
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
    _TEXT_FIELDS.forEach(function(k) { out[k] = r[k] == null ? '' : r[k]; });
    _ARRAY_FIELDS.forEach(function(k) {
      out[k] = Array.isArray(r[k]) ? r[k] : splitList(r[k]);
    });
    return out;
  }

  function listFilters() {
    return {
      p_search: (document.getElementById('rnl-search') || {}).value || null,
      p_research_status: (document.getElementById('rnl-research-filter') || {}).value || null,
      p_content_status: (document.getElementById('rnl-content-filter') || {}).value || null,
      p_linked: (document.getElementById('rnl-linked-filter') || {}).value || null,
      p_category: (document.getElementById('rnl-category-filter') || {}).value || null,
      p_sort_col: _sort.column,
      p_sort_dir: _sort.direction
    };
  }

  async function fetchAllRows() {
    var all = [], offset = 0, limit = 500, total = 0;
    var filters = listFilters();
    do {
      var result = await rpc('admin_list_recipe_name_library', Object.assign({}, filters, {
        p_limit: limit,
        p_offset: offset
      }));
      var rows = (result && result.rows) || [];
      total = parseInt(result && result.total, 10) || rows.length;
      all = all.concat(rows);
      offset += limit;
    } while (all.length < total && offset < 50000);
    return all;
  }

  async function loadCatsAndTaxonomy() {
    try {
      var cats = typeof tcjFetchCategories === 'function' ? await tcjFetchCategories() : [];
      _cats = (cats || []).map(function(c) { return c.name || c; }).filter(Boolean);
    } catch (e) {
      console.warn('Dish Index categories', e);
      _cats = [];
    }
    try {
      _taxRows = await rpc('get_recipe_taxonomy', { p_category: null }) || [];
    } catch (e) {
      console.warn('Dish Index taxonomy', e);
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
        '<strong>Dish Index v' + _SHELL_VERSION + '</strong> — Ground Zero for dish metadata. The table shows key columns only; click <strong>Edit</strong> on any row for all fields (story, image URLs, times, tags, source, shelf life). Export CSV includes all ' + _CSV_HEADERS.length + ' columns for Excel. Ingredients and method stay in Submit a Recipe.' +
      '</div>' +
      '<div class="rm-list-toolbar" style="margin-bottom:12px;flex-wrap:wrap">' +
        '<input type="text" class="ap-search" id="rnl-search" placeholder="Search recipe, native name, country..." style="flex:1;min-width:190px;max-width:300px">' +
        '<select id="rnl-category-filter" class="ing-cat-filter"><option value="">All categories</option></select>' +
        '<select id="rnl-research-filter" class="ing-cat-filter"><option value="">All research</option>' + optHtml(_RESEARCH, '', null) + '</select>' +
        '<select id="rnl-content-filter" class="ing-cat-filter"><option value="">All content</option>' + optHtml(_CONTENT, '', null) + '</select>' +
        '<select id="rnl-linked-filter" class="ing-cat-filter"><option value="">Linked + unlinked</option><option value="linked">Linked only</option><option value="unlinked">Unlinked only</option></select>' +
        '<button type="button" class="ing-add-btn" id="rnl-add-btn">+ Add dish</button>' +
        '<button type="button" class="ing-add-btn" id="rnl-import-btn" style="background:none;border:1px solid var(--accent);color:var(--accent)">Import CSV</button>' +
        '<button type="button" class="ing-add-btn" id="rnl-export-btn" style="background:none;border:1px solid var(--accent);color:var(--accent)">Export CSV</button>' +
        '<button type="button" class="ing-add-btn" id="rnl-print-btn" style="background:none;border:1px solid var(--border);color:var(--text-mid)">Print selected linked</button>' +
        '<input type="file" id="rnl-file" accept=".csv,text/csv" style="display:none">' +
      '</div>' +
      '<div id="rnl-count" style="font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);margin-bottom:8px"></div>' +
      '<div class="ap-table-wrap" style="overflow:auto">' +
        '<table class="ap-table" id="rnl-table"><thead></thead><tbody id="rnl-tbody"><tr><td class="ap-empty-row">Loading...</td></tr></tbody></table>' +
      '</div>' +
      '<div id="rnl-pagination" style="display:none;align-items:center;justify-content:center;gap:8px;margin-top:14px"></div>' +
      '<div id="rnl-editor-backdrop" style="display:none;position:fixed;inset:0;background:rgba(0,0,0,0.55);z-index:1200;padding:24px;overflow:auto">' +
        '<div id="rnl-editor-modal" style="max-width:920px;margin:0 auto;background:var(--bg);border:1px solid var(--border);border-radius:14px;padding:20px 22px 18px"></div>' +
      '</div>';
  }

  function bindShell() {
    if (_bound) return;
    _bound = true;
    var t;
    var search = document.getElementById('rnl-search');
    if (search) search.addEventListener('input', function() { clearTimeout(t); t = setTimeout(function() { _page = 1; loadRows(); }, 300); });
    ['rnl-category-filter', 'rnl-research-filter', 'rnl-content-filter', 'rnl-linked-filter'].forEach(function(id) {
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
    var backdrop = document.getElementById('rnl-editor-backdrop');
    if (backdrop) backdrop.addEventListener('click', function(e) { if (e.target === backdrop) closeRowEditor(); });
  }

  function fillCategoryFilter() {
    var sel = document.getElementById('rnl-category-filter');
    if (!sel || sel.dataset.init === '1') return;
    sel.dataset.init = '1';
    _cats.forEach(function(c) {
      var o = document.createElement('option');
      o.value = c;
      o.textContent = c;
      sel.appendChild(o);
    });
  }

  async function loadRows() {
    var tbody = document.getElementById('rnl-tbody');
    if (tbody) tbody.innerHTML = '<tr><td colspan="' + _TABLE_COLS.length + '" class="ap-empty-row">Loading...</td></tr>';
    try {
      var result = await rpc('admin_list_recipe_name_library', Object.assign({ p_limit: _PAGE_SIZE, p_offset: (_page - 1) * _PAGE_SIZE }, listFilters()));
      _rows = (result && result.rows) || [];
      _total = parseInt(result && result.total, 10) || 0;
      renderTable();
      renderPagination();
    } catch (e) {
      if (tbody) {
        tbody.innerHTML = '<tr><td colspan="' + _TABLE_COLS.length + '" class="ap-empty-row">Error: ' + h(e.message || e) +
          '<br>Run <code>database/sql/fix-recipe-name-library.sql</code> then <code>database/sql/fix-dish-index-columns.sql</code> in Supabase, then refresh.</td></tr>';
      }
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
      count.textContent = _total + ' dish' + (_total === 1 ? '' : 'es') + (_total ? ' (showing ' + start + '-' + end + ')' : '');
    }
    table.querySelector('thead').innerHTML = '<tr>' + _TABLE_COLS.map(function(c) {
      if (c.key === 'select') return '<th style="width:28px"><input type="checkbox" id="rnl-select-all"></th>';
      if (c.fixed || c.readonly) return '<th>' + h(c.label) + '</th>';
      var arrow = _sort.column === c.key ? (_sort.direction === 'asc' ? ' ▲' : ' ▼') : '';
      return '<th class="rnl-sort" data-col="' + h(c.key) + '" style="cursor:pointer;white-space:nowrap">' + h(c.label) + arrow + '</th>';
    }).join('') + '</tr>';
    tbody.innerHTML = '';
    if (!_rows.length) {
      tbody.innerHTML = '<tr><td colspan="' + _TABLE_COLS.length + '" class="ap-empty-row">No dishes yet. Add one or import a CSV.</td></tr>';
      return;
    }
    _rows.forEach(function(r) {
      var tr = document.createElement('tr');
      tr.dataset.id = r.id;
      tr.innerHTML = _TABLE_COLS.map(function(c) { return renderCell(r, c); }).join('');
      tbody.appendChild(tr);
    });
    bindTableEvents();
  }

  function renderCell(r, c) {
    if (c.key === 'select') {
      var disabled = r.linked_recipe_id ? '' : ' disabled title="Only linked dishes can be selected for print"';
      return '<td><input type="checkbox" class="rnl-row-cb" value="' + h(r.id) + '"' + (_selected.has(r.id) ? ' checked' : '') + disabled + '></td>';
    }
    if (c.key === 'actions') {
      var print = r.linked_recipe_id ? '<button class="ap-mini-btn rnl-print-one" data-id="' + h(r.linked_recipe_id) + '">Print</button>' : '';
      return '<td style="white-space:nowrap">' +
        '<button class="ap-mini-btn rnl-edit-btn" style="border-color:var(--accent);color:var(--accent);font-weight:600">Edit all</button>' +
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
    if (c.key === 'category') return '<td>' + selectCell(c.key, _cats, r[c.key], 'Category...') + '</td>';
    if (c.key === 'sub_category') return '<td>' + selectCell(c.key, subsFor(r.category), r[c.key], 'Sub...') + '</td>';
    if (c.key === 'division') return '<td>' + selectCell(c.key, divsFor(r.category, r.sub_category), r[c.key], 'Division...') + '</td>';
    if (c.key === 'research_status') return '<td>' + selectCell(c.key, _RESEARCH, r[c.key] || 'idea_only', '') + '</td>';
    if (c.key === 'content_status') return '<td>' + selectCell(c.key, _CONTENT, r[c.key] || 'not_started', '') + '</td>';
    var val = r[c.key] || '';
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
    document.querySelectorAll('.rnl-edit-btn').forEach(function(btn) { btn.addEventListener('click', openRowEditorFromBtn); });
    document.querySelectorAll('.rnl-create').forEach(function(btn) { btn.addEventListener('click', createRecipe); });
    document.querySelectorAll('.rnl-delete').forEach(function(btn) { btn.addEventListener('click', deleteRow); });
    document.querySelectorAll('.rnl-link').forEach(function(btn) { btn.addEventListener('click', linkRow); });
    document.querySelectorAll('.rnl-unlink').forEach(function(btn) { btn.addEventListener('click', unlinkRow); });
    document.querySelectorAll('.rnl-print-one').forEach(function(btn) {
      btn.addEventListener('click', function() { window.open('print-studio.html?id=' + encodeURIComponent(btn.dataset.id), '_blank'); });
    });
  }

  function openRowEditorFromBtn(e) {
    var tr = e.target.closest('tr');
    var id = tr && tr.dataset.id;
    var r = _rows.find(function(x) { return x.id === id; });
    if (r) openRowEditor(Object.assign({}, r));
  }

  function editorFieldHtml(f, r) {
    var val = f.array ? arrText(r[f.key]) : (r[f.key] == null ? '' : r[f.key]);
    var common = 'width:100%;padding:8px 10px;background:var(--bg);border:1px solid var(--border);border-radius:8px;color:var(--text-high);font-size:13px;font-family:DM Sans,sans-serif';
    var hint = f.hint ? '<div style="font-size:11px;color:var(--text-mid);margin-top:4px">' + h(f.hint) + '</div>' : '';
    if (f.taxonomy === 'category') {
      return '<select data-field="' + h(f.key) + '" style="' + common + '">' + optHtml(_cats, val, 'Category...') + '</select>' + hint;
    }
    if (f.taxonomy === 'sub') {
      return '<select data-field="' + h(f.key) + '" style="' + common + '">' + optHtml(subsFor(r.category), val, 'Sub-category...') + '</select>' + hint;
    }
    if (f.taxonomy === 'div') {
      return '<select data-field="' + h(f.key) + '" style="' + common + '">' + optHtml(divsFor(r.category, r.sub_category), val, 'Division...') + '</select>' + hint;
    }
    if (f.select) {
      return '<select data-field="' + h(f.key) + '" style="' + common + '">' + optHtml(f.select, val, '') + '</select>' + hint;
    }
    if (f.textarea) {
      return '<textarea data-field="' + h(f.key) + '" rows="3" style="' + common + '">' + h(val) + '</textarea>' + hint;
    }
    return '<input data-field="' + h(f.key) + '" value="' + h(val) + '" style="' + common + '">' + hint;
  }

  function openRowEditor(row) {
    _editRow = Object.assign({}, row);
    var modal = document.getElementById('rnl-editor-modal');
    var backdrop = document.getElementById('rnl-editor-backdrop');
    if (!modal || !backdrop) return;
    modal.innerHTML =
      '<div style="display:flex;align-items:flex-start;justify-content:space-between;gap:12px;margin-bottom:14px">' +
        '<div><div style="font-family:Cormorant Garamond,serif;font-size:1.5rem;font-weight:700;color:var(--text-high)">' + h(_editRow.recipe_name || 'New dish') + '</div>' +
        '<div style="font-size:12px;color:var(--text-mid);margin-top:4px">Full Dish Index record — ingredients and method are added later in Submit a Recipe.</div></div>' +
        '<button type="button" class="ap-mini-btn" id="rnl-editor-close">Close</button>' +
      '</div>' +
      _EDITOR_GROUPS.map(function(g) {
        return '<div style="margin-bottom:16px;padding-top:8px;border-top:1px solid var(--border)">' +
          '<div style="font-size:11px;font-weight:600;letter-spacing:0.08em;text-transform:uppercase;color:var(--accent);margin-bottom:10px">' + h(g.title) + '</div>' +
          '<div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(240px,1fr));gap:12px">' +
            g.fields.map(function(f) {
              return '<label style="display:block"><div style="font-size:12px;color:var(--text-mid);margin-bottom:5px">' + h(f.label) + (f.required ? ' *' : '') + '</div>' +
                editorFieldHtml(f, _editRow) + '</label>';
            }).join('') +
          '</div></div>';
      }).join('') +
      '<div style="display:flex;justify-content:flex-end;gap:8px;margin-top:8px">' +
        '<button type="button" class="ing-add-btn" id="rnl-editor-cancel" style="background:none;border:1px solid var(--border);color:var(--text-mid)">Cancel</button>' +
        '<button type="button" class="ing-add-btn" id="rnl-editor-save">Save dish</button>' +
      '</div>';
    backdrop.style.display = 'block';
    document.getElementById('rnl-editor-close').onclick = closeRowEditor;
    document.getElementById('rnl-editor-cancel').onclick = closeRowEditor;
    document.getElementById('rnl-editor-save').onclick = saveRowEditor;
    modal.querySelectorAll('[data-field="category"]').forEach(function(el) {
      el.addEventListener('change', function() {
        _editRow.category = el.value;
        _editRow.sub_category = '';
        _editRow.division = '';
        openRowEditor(_editRow);
      });
    });
    modal.querySelectorAll('[data-field="sub_category"]').forEach(function(el) {
      el.addEventListener('change', function() {
        _editRow.sub_category = el.value;
        _editRow.division = '';
        openRowEditor(_editRow);
      });
    });
  }

  function closeRowEditor() {
    _editRow = null;
    var backdrop = document.getElementById('rnl-editor-backdrop');
    if (backdrop) backdrop.style.display = 'none';
  }

  function collectEditorValues() {
    var modal = document.getElementById('rnl-editor-modal');
    if (!modal || !_editRow) return null;
    var out = Object.assign({}, _editRow);
    modal.querySelectorAll('[data-field]').forEach(function(el) {
      var key = el.dataset.field;
      var fMeta = null;
      _EDITOR_GROUPS.forEach(function(g) {
        g.fields.forEach(function(f) { if (f.key === key) fMeta = f; });
      });
      var raw = el.value || '';
      out[key] = (fMeta && fMeta.array) ? splitList(raw) : raw;
    });
    return out;
  }

  async function saveRowEditor() {
    var payload = collectEditorValues();
    if (!payload || !String(payload.recipe_name || '').trim()) {
      alert('Recipe name is required.');
      return;
    }
    try {
      await rpc('admin_upsert_recipe_name_library', { p_row: rowToPayload(payload) });
      if (typeof auditLog === 'function') auditLog('Dish Index', 'Row Saved', null, null, null, payload.recipe_name);
      closeRowEditor();
      await loadRows();
    } catch (e) {
      alert(e.message || e);
    }
  }

  async function saveCell(el) {
    var tr = el.closest('tr');
    var id = tr && tr.dataset.id;
    var r = _rows.find(function(x) { return x.id === id; });
    if (!r) return;
    var field = el.dataset.field;
    r[field] = el.value;
    if (field === 'category') { r.sub_category = ''; r.division = ''; }
    if (field === 'sub_category') { r.division = ''; }
    el.style.borderColor = 'var(--accent)';
    try {
      await rpc('admin_upsert_recipe_name_library', { p_row: rowToPayload(r) });
      el.style.borderColor = 'var(--border)';
      if (field === 'category' || field === 'sub_category') renderTable();
      if (typeof auditLog === 'function') auditLog('Dish Index', 'Row Updated', null, null, null, r.recipe_name + ' - ' + field);
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
    if (!confirm('Create a pending draft recipe from this Dish Index row?')) return;
    try {
      var recipeId = await rpc('admin_create_recipe_from_name_library', { p_id: id });
      await loadRows();
      if (recipeId && confirm('Draft created. Open it in Submit a Recipe now?')) {
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
    if (!confirm('Unlink this dish from its recipe?')) return;
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
    if (!confirm('Delete this Dish Index row? This does not delete linked recipes.')) return;
    try {
      await rpc('admin_delete_recipe_name_library', { p_id: id });
      _selected.delete(id);
      await loadRows();
    } catch (err) {
      alert(err.message || err);
    }
  }

  function rowToCsvLine(r) {
    return [
      r.id, r.recipe_name, r.native_name, arrText(r.alternate_names),
      r.category, r.sub_category, r.division,
      r.origin_continent, r.origin_country, r.origin_state, r.origin_locality,
      arrText(r.primary_ingredients),
      arrText(r.dietary_tags), arrText(r.health_tags), arrText(r.meal_type_tags), arrText(r.occasion_tags), arrText(r.style_tags), arrText(r.flavor_profile_tags),
      r.introduction, r.description, r.image_url, r.image_source_url,
      r.prep_time_minutes, r.cook_time_minutes, r.additional_time_minutes,
      r.servings, r.servings_unit, r.difficulty, r.spice_level, r.sweet_level, r.cooking_style,
      arrText(r.equipment), r.cooking_notes,
      r.shelf_life_value, r.shelf_life_unit, r.shelf_life_storage, r.after_open_value, r.after_open_unit,
      r.source_type, r.credit_name, r.credit_handle, r.credit_url, r.source_url, r.source_notes,
      r.research_status, r.content_status, r.linked_recipe_id,
      r.linked_recipe_name || '', r.notes
    ].map(csvCell).join(',');
  }

  async function exportCsv() {
    var btn = document.getElementById('rnl-export-btn');
    if (btn) { btn.textContent = 'Exporting...'; btn.disabled = true; }
    try {
      var all = await fetchAllRows();
      var lines = [_CSV_HEADERS.map(csvCell).join(',')];
      all.forEach(function(r) { lines.push(rowToCsvLine(r)); });
      var blob = new Blob(['\ufeff' + lines.join('\r\n')], { type: 'text/csv;charset=utf-8' });
      var url = URL.createObjectURL(blob);
      var a = document.createElement('a');
      a.href = url;
      a.download = 'dish-index-' + new Date().toISOString().slice(0, 10) + '.csv';
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      URL.revokeObjectURL(url);
    } catch (e) {
      alert(e.message || e);
    } finally {
      if (btn) { btn.textContent = 'Export CSV'; btn.disabled = false; }
    }
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
    if (!ids.length) { alert('Select one or more linked dishes first.'); return; }
    if (ids.length === 1) window.open('print-studio.html?id=' + encodeURIComponent(ids[0]), '_blank');
    else window.open('print-studio.html?ids=' + encodeURIComponent(ids.join(',')) + '&collection=' + encodeURIComponent('Dish Index Batch'), '_blank');
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
    if (root.dataset.shellVersion !== _SHELL_VERSION) {
      root.dataset.shellVersion = _SHELL_VERSION;
      root.dataset.built = '';
      _bound = false;
      root.innerHTML = '';
    }
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
