// Shared Library section chrome — hero, tabs, search (library-directory pattern)
(function (global) {
  var TYPES = {
    ingredient:    { label: 'Ingredients',        emoji: '🌿', desc: 'Ingredient-first guides — how each one works in your favour, without overwhelm. Linked from recipes when a profile exists.', tagField: 'category' },
    spice:         { label: 'Spice Directory',    emoji: '🌶', desc: 'Every spice and herb — flavour, heat, technique, and the science of why it works.', tagField: 'heat_level' },
    tool:          { label: 'Tools & Appliances', emoji: '🔪', desc: 'Every piece of kitchen equipment — what it does, how to use it properly, and how to care for it.', tagField: 'tool_category' },
    cut:           { label: 'Cuts & Prep',        emoji: '🥩', desc: 'Meat and seafood anatomy — every cut, how to clean it, how to prep it, the best way to cook it.', tagField: 'protein_type' },
    preservation:  { label: 'Preservation',       emoji: '🫙', desc: 'Every preservation technique — the science, the safety, and the step by step.', tagField: 'technique_type' }
  };

  var PAGES = {
    conversions: { href: 'conversions.html',      label: 'Conversions & Weights', emoji: '⚖️', desc: 'Instant kitchen maths — volumes, weights, temperatures, and recipe scaling without rounding surprises.' },
    baby:        { href: 'baby.html',             label: 'Baby & Toddler',        emoji: '👶', desc: 'Age-appropriate recipes and food guidance. Allergen warnings are shown automatically. Always consult your paediatrician before introducing new foods.' },
    submit:      { href: 'library-submit.html',   label: 'Submit a Profile',      emoji: '📝', desc: 'Contribute a library profile for review. All required fields and images must be complete before publishing.' },
    guide:       { href: 'preservation.html',     label: 'Technique Guide',       emoji: '📖', desc: 'In-depth preservation encyclopedia — canning, freezing, fermenting, curing, and critical safety guidance.', hidden: true }
  };

  function esc(s) {
    return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  function titleHtml(label) {
    var i = label.indexOf(' ');
    if (i < 0) return esc(label);
    return esc(label.slice(0, i)) + '<br><em>' + esc(label.slice(i + 1)) + '</em>';
  }

  function buildTabs(active) {
    var html = Object.keys(TYPES).map(function (type) {
      var info = TYPES[type];
      var isActive = active === type;
      if (isActive) {
        return '<span class="lib-tab active" aria-current="page">' + info.emoji + ' ' + esc(info.label) + '</span>';
      }
      return '<a class="lib-tab" href="library-directory.html?type=' + type + '">' + info.emoji + ' ' + esc(info.label) + '</a>';
    }).join('');

    ['conversions', 'baby'].forEach(function (key) {
      var p = PAGES[key];
      if (active === key) {
        html += '<span class="lib-tab active" aria-current="page">' + p.emoji + ' ' + esc(p.label) + '</span>';
      } else {
        html += '<a class="lib-tab" href="' + p.href + '">' + p.emoji + ' ' + esc(p.label) + '</a>';
      }
    });

    if (active === 'submit') {
      html += '<span class="lib-tab active" aria-current="page">' + PAGES.submit.emoji + ' ' + esc(PAGES.submit.label) + '</span>';
    } else {
      try {
        var sess = JSON.parse(localStorage.getItem('tcj_session') || 'null');
        if (sess && sess.access_token) {
          html += '<a class="lib-tab" href="' + PAGES.submit.href + '">' + PAGES.submit.emoji + ' ' + esc(PAGES.submit.label) + '</a>';
        }
      } catch (_) { TcjErr.warn('degrade', _); }
    }

    if (active === 'encyclopedia') {
      html += '<span class="lib-tab active" aria-current="page">📖 Technique encyclopedia</span>';
    } else if (active === 'preservation') {
      html += '<a class="lib-tab lib-tab-muted" href="preservation.html">📖 Technique encyclopedia</a>';
    }

    return html;
  }

  function metaFor(active) {
    if (TYPES[active]) return TYPES[active];
    if (PAGES[active]) return PAGES[active];
    return TYPES.ingredient;
  }

  function render(opts) {
    opts = opts || {};
    var root = typeof opts.root === 'string' ? document.getElementById(opts.root) : opts.root;
    if (!root) return;
    var active = opts.active || 'ingredient';
    var meta = metaFor(active);
    var compact = !!opts.compact;
    var showSearch = !!opts.showSearch;
    var title = opts.titleHtml || titleHtml(meta.label);
    var desc = opts.desc != null ? opts.desc : meta.desc;
    var extra = opts.extraHtml || '';

    if (opts.submitOnly) {
      root.innerHTML =
        '<div class="lib-shell lib-shell-submit">' +
          '<header class="lib-hero lib-hero-submit">' +
            '<a class="lib-submit-back" href="library-directory.html?type=ingredient">← Library directory</a>' +
            '<div class="lib-eyebrow">The Library</div>' +
            '<h1 class="lib-title" id="lib-chrome-title">' + title + '</h1>' +
            '<p class="lib-desc ls-subtitle" id="lib-chrome-desc">' + esc(desc) + '</p>' +
            extra +
          '</header>' +
        '</div>';
      return;
    }

    if (compact) {
      root.innerHTML = '<div class="lib-shell lib-shell-compact"><div class="lib-tabs" role="navigation" aria-label="Library sections">' + buildTabs(active) + '</div></div>';
      return;
    }

    root.innerHTML =
      '<div class="lib-shell">' +
        '<header class="lib-hero">' +
          '<div class="lib-eyebrow">The Library</div>' +
          '<h1 class="lib-title" id="lib-chrome-title">' + title + '</h1>' +
          '<p class="lib-desc" id="lib-chrome-desc">' + esc(desc) + '</p>' +
          extra +
        '</header>' +
        '<nav class="lib-tabs" role="navigation" aria-label="Library sections">' + buildTabs(active) + '</nav>' +
        (showSearch
          ? '<div class="lib-search-wrap">' +
              '<div class="lib-search">' +
                '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" aria-hidden="true" style="color:var(--text-muted);flex-shrink:0"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg>' +
                '<input type="search" id="' + esc(opts.searchId || 'lib-search-input') + '" placeholder="Search…" autocomplete="off">' +
              '</div>' +
            '</div>'
          : '') +
      '</div>';
  }

  global.LibraryChrome = {
    TYPES: TYPES,
    PAGES: PAGES,
    titleHtml: titleHtml,
    buildTabs: buildTabs,
    render: render,
    metaFor: metaFor
  };
})(window);
