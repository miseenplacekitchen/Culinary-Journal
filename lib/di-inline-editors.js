// di-inline-editors.js — searchable clearable combobox, level pickers, tag multi-select for Dish Index table
(function() {
  var esc = function(s) {
    return String(s == null ? '' : s).replace(/[&<>"']/g, function(c) {
      return ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c];
    });
  };

  var SPICE_META = [
    { v: 'Not Applicable', na: true },
    { v: 'Mild', chillies: ['chilli-green'] },
    { v: 'Medium', chillies: ['chilli-yellow', 'chilli-yellow'] },
    { v: 'Hot', chillies: ['chilli-orange', 'chilli-orange', 'chilli-orange'] },
    { v: 'Very Hot', chillies: ['chilli-red', 'chilli-red', 'chilli-red', 'chilli-red'] },
    { v: 'Extremely Hot', chillies: ['chilli-darkred', 'chilli-darkred', 'chilli-darkred', 'chilli-darkred', 'chilli-darkred'] }
  ];

  var SWEET_META = [
    { v: 'Not Applicable', na: true },
    { v: 'Subtly Sweet', cubes: 1 },
    { v: 'Lightly Sweet', cubes: 2 },
    { v: 'Sweet', cubes: 3 },
    { v: 'Very Sweet', cubes: 4 },
    { v: 'Extremely Sweet', cubes: 5 }
  ];

  var DIFF_META = [
    { v: 'Easy', cls: 'diff-easy' },
    { v: 'Intermediate', cls: 'diff-inter' },
    { v: 'Advanced', cls: 'diff-adv' }
  ];

  function chilliesHtml(list) {
    return (list || []).map(function(c) { return '<span class="chilli ' + c + '"></span>'; }).join('');
  }

  function cubesHtml(n) {
    var h = '';
    for (var i = 0; i < n; i++) h += '<span class="sugar-cube"></span>';
    return h;
  }

  function comboCell(field, items, value, placeholder, disabled) {
    var label = value || '';
    (items || []).forEach(function(it) {
      var v = typeof it === 'object' ? it.value : it;
      if (v === value) label = typeof it === 'object' ? (it.label || it.value) : it;
    });
    var opts = (items || []).map(function(it) {
      var v = typeof it === 'object' ? it.value : it;
      var lbl = typeof it === 'object' ? (it.label || it.value) : it;
      return '<button type="button" class="di-combo-opt" data-value="' + esc(v) + '">' + esc(lbl) + '</button>';
    }).join('');
    return '<div class="di-combo' + (disabled ? ' di-combo-disabled' : '') + '" data-field="' + esc(field) + '">' +
      '<input type="text" class="di-combo-input" value="' + esc(label) + '" placeholder="' + esc(placeholder || 'Search…') + '" autocomplete="off"' + (disabled ? ' disabled' : '') + '>' +
      '<button type="button" class="di-combo-clear" title="Clear"' + (disabled ? ' disabled' : '') + ' aria-label="Clear">×</button>' +
      '<input type="hidden" class="rnl-edit" data-field="' + esc(field) + '" value="' + esc(value || '') + '">' +
      '<div class="di-combo-menu" role="listbox">' + opts + '</div>' +
    '</div>';
  }

  function levelCell(field, kind, value) {
    var meta = kind === 'spice' ? SPICE_META : (kind === 'sweet' ? SWEET_META : DIFF_META);
    var btns = meta.map(function(m) {
      var inner = m.na ? '<span class="level-na">N/A</span>'
        : (m.chillies ? '<span class="level-symbols">' + chilliesHtml(m.chillies) + '</span>'
        : (m.cubes ? '<span class="level-symbols">' + cubesHtml(m.cubes) + '</span>'
        : '<span class="level-symbols"><span class="diff-dot ' + m.cls + '"></span></span>'));
      var sel = (value === m.v) ? ' di-level-on' : '';
      return '<button type="button" class="di-level-btn' + sel + (m.na ? ' di-level-na' : '') + '" data-value="' + esc(m.v) + '" title="' + esc(m.v) + '">' + inner + '</button>';
    }).join('');
    return '<div class="di-level-picker" data-field="' + esc(field) + '" data-kind="' + esc(kind) + '">' + btns +
      '<input type="hidden" class="rnl-edit" data-field="' + esc(field) + '" value="' + esc(value || '') + '">' +
    '</div>';
  }

  function tagCell(field, options, values) {
    var set = {};
    (values || []).forEach(function(v) { set[v] = true; });
    var summary = (values && values.length) ? values.slice(0, 2).join(', ') + (values.length > 2 ? ' +' + (values.length - 2) : '') : 'Add tags…';
    var checks = (options || []).map(function(o) {
      var on = set[o.value] ? ' checked' : '';
      return '<label class="di-tag-opt"><input type="checkbox" value="' + esc(o.value) + '"' + on + '> ' + esc(o.label) + '</label>';
    }).join('');
    return '<div class="di-tag-cell" data-field="' + esc(field) + '">' +
      '<button type="button" class="di-tag-trigger">' + esc(summary) + '</button>' +
      '<div class="di-tag-pop">' + checks + '</div>' +
      '<input type="hidden" class="rnl-edit" data-field="' + esc(field) + '" value="' + esc((values || []).join('; ')) + '">' +
    '</div>';
  }

  function closeMenus(except) {
    document.querySelectorAll('.di-combo.open').forEach(function(c) {
      if (c !== except) c.classList.remove('open');
    });
    document.querySelectorAll('.di-tag-cell.open').forEach(function(c) {
      if (c !== except) c.classList.remove('open');
    });
  }

  function filterComboMenu(combo, q) {
    var qq = String(q || '').toLowerCase();
    combo.querySelectorAll('.di-combo-opt').forEach(function(btn) {
      var txt = btn.textContent.toLowerCase();
      btn.style.display = (!qq || txt.indexOf(qq) >= 0) ? '' : 'none';
    });
  }

  function commitCombo(combo, value, label) {
    var hidden = combo.querySelector('.rnl-edit');
    var input = combo.querySelector('.di-combo-input');
    if (hidden) hidden.value = value || '';
    if (input) input.value = label || value || '';
    combo.classList.remove('open');
    if (hidden) hidden.dispatchEvent(new Event('change', { bubbles: true }));
  }

  function bindCombos(root) {
    (root || document).querySelectorAll('.di-combo').forEach(function(combo) {
      if (combo.dataset.bound === '1') return;
      combo.dataset.bound = '1';
      var input = combo.querySelector('.di-combo-input');
      var clear = combo.querySelector('.di-combo-clear');
      var menu = combo.querySelector('.di-combo-menu');
      if (input) {
        input.addEventListener('focus', function() {
          if (combo.classList.contains('di-combo-disabled')) return;
          closeMenus(combo);
          combo.classList.add('open');
          filterComboMenu(combo, input.value);
        });
        input.addEventListener('input', function() {
          if (combo.classList.contains('di-combo-disabled')) return;
          combo.classList.add('open');
          filterComboMenu(combo, input.value);
        });
      }
      if (menu) {
        menu.addEventListener('click', function(e) {
          var btn = e.target.closest('.di-combo-opt');
          if (!btn) return;
          e.stopPropagation();
          commitCombo(combo, btn.dataset.value || '', btn.textContent.trim());
        });
      }
      if (clear) {
        clear.addEventListener('click', function(e) {
          e.stopPropagation();
          if (combo.classList.contains('di-combo-disabled')) return;
          commitCombo(combo, '', '');
        });
      }
    });
  }

  function bindLevelPickers(root) {
    (root || document).querySelectorAll('.di-level-picker').forEach(function(wrap) {
      if (wrap.dataset.bound === '1') return;
      wrap.dataset.bound = '1';
      wrap.querySelectorAll('.di-level-btn').forEach(function(btn) {
        btn.addEventListener('click', function(e) {
          e.stopPropagation();
          var hidden = wrap.querySelector('.rnl-edit');
          var val = btn.dataset.value || '';
          var cur = hidden ? hidden.value : '';
          var next = (cur === val && !btn.classList.contains('di-level-na')) ? '' : val;
          wrap.querySelectorAll('.di-level-btn').forEach(function(b) { b.classList.remove('di-level-on'); });
          if (next) btn.classList.add('di-level-on');
          if (hidden) {
            hidden.value = next;
            hidden.dispatchEvent(new Event('change', { bubbles: true }));
          }
        });
      });
    });
  }

  function bindTagCells(root) {
    (root || document).querySelectorAll('.di-tag-cell').forEach(function(cell) {
      if (cell.dataset.bound === '1') return;
      cell.dataset.bound = '1';
      var trigger = cell.querySelector('.di-tag-trigger');
      var pop = cell.querySelector('.di-tag-pop');
      var hidden = cell.querySelector('.rnl-edit');
      if (trigger) {
        trigger.addEventListener('click', function(e) {
          e.stopPropagation();
          var open = cell.classList.toggle('open');
          if (open) closeMenus(cell);
        });
      }
      if (pop) {
        pop.addEventListener('change', function() {
          var vals = [];
          pop.querySelectorAll('input[type="checkbox"]:checked').forEach(function(cb) {
            if (cb.value) vals.push(cb.value);
          });
          if (hidden) hidden.value = vals.join('; ');
          if (trigger) {
            trigger.textContent = vals.length ? (vals.slice(0, 2).join(', ') + (vals.length > 2 ? ' +' + (vals.length - 2) : '')) : 'Add tags…';
          }
          hidden.dispatchEvent(new Event('change', { bubbles: true }));
        });
      }
    });
  }

  if (!window._diComboDocClose) {
    window._diComboDocClose = true;
    document.addEventListener('click', function() { closeMenus(null); });
  }

  window.diInlineEditors = {
    comboCell: comboCell,
    levelCell: levelCell,
    tagCell: tagCell,
    bindAll: function(root) {
      bindCombos(root);
      bindLevelPickers(root);
      bindTagCells(root);
    }
  };
})();
