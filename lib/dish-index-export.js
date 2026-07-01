// dish-index-export.js — Dish Index Excel export (table from B2, dropdown validation)
(function() {
  var START_ROW = 2;
  var START_COL = 2;

  var HEADER_LIST_KEY = {
    'Category': 'categories',
    'Sub-category': 'subCategories',
    'Division': 'divisions',
    'Country': 'countries',
    'State': 'states',
    'Difficulty': 'difficulty',
    'Spice Level': 'spice',
    'Sweet Level': 'sweet',
    'Cooking Style': 'cookingStyles',
    'Source Type': 'sourceTypes',
    'Research Status': 'research',
    'Content Status': 'content',
    'Active': 'active'
  };

  function colLetter(n) {
    var s = '';
    while (n > 0) {
      var m = (n - 1) % 26;
      s = String.fromCharCode(65 + m) + s;
      n = Math.floor((n - 1) / 26);
    }
    return s;
  }

  function uniqueSorted(arr) {
    var m = {};
    (arr || []).forEach(function(v) {
      if (v != null && String(v).trim() !== '') m[String(v).trim()] = true;
    });
    return Object.keys(m).sort(function(a, b) { return a.localeCompare(b); });
  }

  function flattenStates() {
    var out = [];
    if (window.tcjOrigin && typeof window.tcjOrigin.statesForCountry === 'function' && window.CD) {
      Object.keys(window.CD).forEach(function(cont) {
        (window.CD[cont] || []).forEach(function(c) {
          (window.tcjOrigin.statesForCountry(c.name) || []).forEach(function(s) { out.push(s); });
        });
      });
    }
    return uniqueSorted(out);
  }

  function buildLists(context) {
    var rf = window.tcjRecipeFields || {};
    var lists = {
      categories: uniqueSorted(context.categories || []),
      subCategories: uniqueSorted(context.subCategories || []),
      divisions: uniqueSorted(context.divisions || []),
      countries: uniqueSorted(context.countries || []),
      states: uniqueSorted(context.states || []).length ? uniqueSorted(context.states) : flattenStates(),
      difficulty: ['Easy', 'Intermediate', 'Advanced'],
      spice: (rf.SPICE || []).slice(),
      sweet: (rf.SWEET || []).slice(),
      cookingStyles: (rf.COOKING_STYLES || []).map(function(x) {
        return x.value != null ? String(x.value) : '';
      }).filter(function(v) { return v !== ''; }),
      sourceTypes: (context.sourceTypes || ['Original', 'From Somewhere Else', 'Scanned']).slice(),
      research: (context.research || ['idea_only', 'needs_research', 'ready_to_draft', 'verified']).slice(),
      content: (context.content || ['not_started', 'draft_created', 'linked', 'approved', 'duplicate', 'retired']).slice(),
      active: ['true', 'false']
    };
    if (rf.tagOptions) {
      ['meal_type_tags', 'occasion_tags', 'style_tags', 'flavor_profile_tags', 'dietary_tags', 'health_tags'].forEach(function(k) {
        lists[k] = rf.tagOptions(k).map(function(o) { return o.value; });
      });
    }
    return lists;
  }

  function writeOptionsSheet(wb, lists) {
    var ws = wb.addWorksheet('Dropdown options');
    ws.state = 'hidden';
    var refs = {};
    var col = 1;
    Object.keys(lists).forEach(function(key) {
      var items = lists[key] || [];
      ws.getCell(1, col).value = key;
      items.forEach(function(v, i) {
        ws.getCell(i + 2, col).value = v;
      });
      refs[key] = {
        letter: colLetter(col),
        start: 2,
        end: Math.max(2, items.length + 1)
      };
      col++;
    });
    return refs;
  }

  function listFormula(ref) {
    if (!ref || ref.end < ref.start) return null;
    return "'Dropdown options'!$" + ref.letter + "$" + ref.start + ":$" + ref.letter + "$" + ref.end;
  }

  async function buildWorkbook(opts) {
    if (!window.ExcelJS) throw new Error('ExcelJS not loaded — refresh the dashboard.');
    var headers = opts.headers || [];
    var rows = opts.rows || [];
    var rowValues = opts.rowValues;
    var schemaVersion = opts.schemaVersion || '';
    var lists = buildLists(opts.context || {});
    var wb = new window.ExcelJS.Workbook();
    wb.creator = 'The Culinary Journal';
    wb.created = new Date();
    var listRefs = writeOptionsSheet(wb, lists);
    var ws = wb.addWorksheet('Dish Index', { views: [{ state: 'frozen', xSplit: 1, ySplit: 2, topLeftCell: 'B3', activeCell: 'B3' }] });

    ws.getCell(1, 1).value = 'TCJ Dish Index';
    ws.getCell(1, 2).value = 'Schema ' + schemaVersion + ' · table starts B2 · dropdowns on select columns';

    headers.forEach(function(h, i) {
      var cell = ws.getCell(START_ROW, START_COL + i);
      cell.value = h;
      cell.font = { bold: true };
      cell.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FFE8ECF0' } };
    });

    rows.forEach(function(r, ri) {
      var vals = rowValues(r);
      vals.forEach(function(v, ci) {
        ws.getCell(START_ROW + 1 + ri, START_COL + ci).value = v == null ? '' : v;
      });
    });

    var dataStart = START_ROW + 1;
    var dataEnd = Math.max(dataStart + rows.length + 200, dataStart + 50);

    headers.forEach(function(h, i) {
      var listKey = HEADER_LIST_KEY[h];
      if (!listKey || !listRefs[listKey]) return;
      var formula = listFormula(listRefs[listKey]);
      if (!formula) return;
      var letter = colLetter(START_COL + i);
      ws.dataValidations.add(letter + dataStart + ':' + letter + dataEnd, {
        type: 'list',
        allowBlank: true,
        formulae: [formula]
      });
    });

    ws.columns.forEach(function(col, idx) {
      if (idx < START_COL - 1) return;
      var max = 12;
      col.eachCell({ includeEmpty: false }, function(cell) {
        var n = String(cell.value == null ? '' : cell.value).length;
        if (n + 2 > max) max = Math.min(n + 2, 48);
      });
      col.width = max;
    });

    var buf = await wb.xlsx.writeBuffer();
    return new Blob([buf], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
  }

  window.dishIndexExport = { buildWorkbook: buildWorkbook };
})();
