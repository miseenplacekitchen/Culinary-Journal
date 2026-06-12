// Shared Garden section chrome — hero + tabs (library-chrome pattern)
(function (global) {
  function esc(s) {
    return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  var TABS = [
    { id: 'directory', href: 'garden-directory.html', label: 'Plant Directory', emoji: '🌱' },
    { id: 'my-garden', href: 'my-garden.html', label: 'My Garden', emoji: '🌿', signedInOnly: true }
  ];

  function buildTabs(active) {
    var sess = null;
    try { sess = JSON.parse(localStorage.getItem('tcj_session') || 'null'); } catch (_) {}
    return TABS.filter(function (t) {
      return !t.signedInOnly || (sess && sess.access_token);
    }).map(function (t) {
      if (active === t.id) {
        return '<span class="lib-tab active" aria-current="page">' + t.emoji + ' ' + esc(t.label) + '</span>';
      }
      return '<a class="lib-tab" href="' + t.href + '">' + t.emoji + ' ' + esc(t.label) + '</a>';
    }).join('');
  }

  function render(opts) {
    opts = opts || {};
    var root = typeof opts.root === 'string' ? document.getElementById(opts.root) : opts.root;
    if (!root) return;
    var active = opts.active || 'directory';
    var showSearch = !!opts.showSearch;
    var searchHtml = showSearch
      ? '<div class="lib-search-wrap"><input type="search" id="' + esc(opts.searchId || 'gd-search') + '" class="lib-search-input" placeholder="Search plants…" aria-label="Search plants"></div>'
      : '';
    root.innerHTML =
      '<div class="lib-hero lib-hero-mise">' +
        '<div class="lib-hero-inner">' +
          '<p class="lib-hero-kicker">Garden &amp; Earth</p>' +
          '<h1 class="lib-hero-title">The <em>Garden</em></h1>' +
          '<p class="lib-hero-desc">Climate-aware growing profiles linked to your kitchen — care cards, seasonal calendars, and governed ingredient bridges. Cultivar lists arrive soon.</p>' +
          searchHtml +
        '</div>' +
      '</div>' +
      '<div class="lib-tabs-row">' + buildTabs(active) + '</div>';
  }

  global.GardenChrome = { render: render, esc: esc };
})(window);
