// dashboard-gm-interface.js — Garden Management sacred ground (GM Interface)
// Pattern: Ingredient Management → IM Interface. Admin sees ids/slugs; public site shows names only.

var _gmLineage = [
  { v: 'heirloom', l: 'Heirloom', emoji: '🏆' },
  { v: 'open_pollinated', l: 'Open-pollinated', emoji: '🌱' },
  { v: 'hybrid', l: 'Hybrid (F1)', emoji: '🧬' },
  { v: 'indigenous', l: 'Indigenous / regional', emoji: '🌏' }
];

function gmEsc(s) {
  return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function gmAccordion(title, bodyHtml, open) {
  var openAttr = open !== false ? '' : ' style="display:none"';
  var arrow = open !== false ? '▲' : '▼';
  return '<div class="gm-acc" style="margin-bottom:12px;border:1px solid var(--border);border-radius:10px;overflow:hidden">' +
    '<div class="gm-acc-hdr" onclick="var b=this.nextElementSibling;var a=this.querySelector(\'.gm-arr\');var o=b.style.display!==\'none\';b.style.display=o?\'none\':\'block\';a.textContent=o?\'▼\':\'▲\'" ' +
    'style="display:flex;justify-content:space-between;padding:10px 14px;background:rgba(255,255,255,0.03);cursor:pointer">' +
    '<div style="font-family:Cormorant Garamond,serif;font-size:1.05rem;font-weight:700">' + gmEsc(title) + '</div>' +
    '<span class="gm-arr" style="color:var(--text-mid)">' + arrow + '</span></div>' +
    '<div class="gm-acc-body" style="padding:14px"' + openAttr + '>' + bodyHtml + '</div></div>';
}

async function gmFetchTable(path, cols) {
  var res = await supaFetch(path);
  if (!res.ok) throw new Error(path + ' ' + res.status);
  return res.json();
}

async function loadGmInterface() {
  var root = document.getElementById('gm-interface-content');
  if (!root) return;
  if (root.dataset.built === '1') return;
  root.innerHTML = '<div class="ap-loading" style="padding:24px">Loading GM Interface…</div>';

  var climates = [], plants = [], hinges = [], pages = [];
  try {
    climates = await gmFetchTable('/rest/v1/climate_zones?select=id,slug,name&order=name', []);
    plants = await gmFetchTable('/rest/v1/plants?select=id,slug,common_name,is_published&order=common_name', []);
    hinges = await gmFetchTable('/rest/v1/plant_ingredients?select=plant_id,ingredient_id,part', []);
    pages = await gmFetchTable('/rest/v1/site_pages?or=(path.eq.garden-directory.html,path.eq.garden-plant.html,path.eq.my-garden.html)&select=path,name,visibility', []);
  } catch (e) {
    root.innerHTML = '<p style="color:var(--warn,#c97);font-family:DM Sans,sans-serif">GM Interface could not reach Garden tables. Run <code>RUN-GARDEN-V3.sql</code> on Supabase first.</p>';
    console.warn('loadGmInterface', e);
    return;
  }

  var policy = '<p style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);line-height:1.7;margin:0 0 12px">' +
    '<strong>Public site rule:</strong> members see <em>names</em> only (climate name, plant name, variety name, lineage labels). ' +
    'Slugs, UUIDs, and internal keys stay here in GM Interface and in SQL — never on garden-directory, garden-plant, or my-garden.</p>' +
    '<p style="font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-muted);margin:0">Variety layer (<code>plant_varieties</code>) + docx import queue ship in Garden v4.</p>';

  var climateRows = climates.length ? climates.map(function (c) {
    return '<tr><td style="font-family:monospace;font-size:11px">' + gmEsc(c.slug) + '</td>' +
      '<td style="font-family:monospace;font-size:10px;color:var(--text-muted)">' + gmEsc(String(c.id).slice(0, 8)) + '…</td>' +
      '<td><strong>' + gmEsc(c.name) + '</strong></td></tr>';
  }).join('') : '<tr><td colspan="3" class="ap-empty-row">No climates seeded yet.</td></tr>';

  var climateHtml = '<p style="font-size:13px;color:var(--text-mid);margin:0 0 12px">Growing climates are the primary location key (not cities). Inbox “Brisbane” → <code>humid-subtropical</code>; “Kerala” → <code>tropical-monsoon</code>.</p>' +
    '<table class="ap-table" style="margin-top:8px"><thead><tr><th>Slug (admin)</th><th>ID</th><th>Display name (public)</th></tr></thead><tbody>' + climateRows + '</tbody></table>' +
    '<p style="font-size:12px;color:var(--text-muted);margin-top:10px">Edit via SQL until climate editor ships. Slug changes need coordinated seed + variety data.</p>';

  var speciesRows = plants.map(function (p) {
    var h = hinges.filter(function (x) { return x.plant_id === p.id; }).length;
    return '<tr><td style="font-family:monospace;font-size:11px">' + gmEsc(p.slug) + '</td>' +
      '<td style="font-family:monospace;font-size:10px;color:var(--text-muted)">' + gmEsc(String(p.id).slice(0, 8)) + '…</td>' +
      '<td>' + gmEsc(p.common_name) + '</td>' +
      '<td>' + (p.is_published ? 'Yes' : 'No') + '</td>' +
      '<td>' + h + '</td></tr>';
  }).join('') || '<tr><td colspan="5" class="ap-empty-row">No species.</td></tr>';

  var speciesHtml = '<table class="ap-table"><thead><tr><th>Slug</th><th>ID</th><th>Name</th><th>Published</th><th>Kitchen hinges</th></tr></thead><tbody>' +
    speciesRows + '</tbody></table>';

  var lineageHtml = '<ul style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);line-height:1.8;margin:0;padding-left:18px">' +
    _gmLineage.map(function (l) {
      return '<li>' + l.emoji + ' <code>' + l.v + '</code> → public label: <strong>' + gmEsc(l.l) + '</strong></li>';
    }).join('') + '</ul>';

  var pageRows = pages.map(function (pg) {
    return '<tr><td>' + gmEsc(pg.path) + '</td><td>' + gmEsc(pg.name) + '</td><td>' + gmEsc(pg.visibility) + '</td>' +
      '<td><button type="button" class="ing-add-btn" style="font-size:11px;padding:4px 10px" onclick="switchView(\'site-mgmt\');switchSMTab(\'sm-pages\')">Site Mgmt →</button></td></tr>';
  }).join('');

  var pagesHtml = '<p style="font-size:13px;color:var(--text-mid)">Page visibility is owned by <strong>Site Management → Pages</strong>, not GM Interface.</p>' +
    '<table class="ap-table" style="margin-top:8px"><thead><tr><th>Path</th><th>Name</th><th>Visibility</th><th></th></tr></thead><tbody>' + pageRows + '</tbody></table>';

  var health = [];
  if (!climates.length) health.push('No climate zones — seed humid-subtropical + tropical-monsoon.');
  if (!plants.length) health.push('No species rows.');
  plants.forEach(function (p) {
    if (!hinges.some(function (h) { return h.plant_id === p.id; })) {
      health.push('Missing kitchen hinge: ' + p.common_name);
    }
  });
  if (plants.length === 1) health.push('Only 1 published species — inbox has 208 Variety Assessments waiting for import.');

  var healthHtml = health.length
    ? '<ul style="color:var(--warn,#c97);font-size:13px;line-height:1.7">' + health.map(function (h) { return '<li>' + gmEsc(h) + '</li>'; }).join('') + '</ul>'
    : '<p style="color:#6dc86d;font-size:13px">No blocking issues detected.</p>';

  var importHtml = '<p style="font-size:13px;color:var(--text-mid)">Pipeline (v4): <code>brainstorm-inbox/Variety Assessments/*.docx</code> → parse → staging → approve → <code>plants</code> + <code>plant_varieties</code> per climate.</p>' +
    '<p style="font-size:12px;color:var(--text-muted)">208 assessments on disk. Tomato docx alone has 56+ Brisbane cultivars.</p>';

  var lookupsHtml = '<p style="font-size:13px;color:var(--text-mid)">Seed from inbox PDFs: A.1 categories, A.2 main categories, A.12 habits, A.13 layers, B.2 ease, C.2 soil, C.4 sun, F.6 seed groups, lifecycles, calendar legends.</p>' +
    '<p style="font-size:12px;color:var(--text-muted)">Bundle: <code>fix-garden-lookups-from-manual.sql</code> (planned).</p>';

  root.innerHTML =
    gmAccordion('Display policy', policy, true) +
    gmAccordion('Health checks', healthHtml, true) +
    gmAccordion('Climates (sacred ground)', climateHtml, true) +
    gmAccordion('Species registry', speciesHtml, false) +
    gmAccordion('Variety lineage labels', lineageHtml, false) +
    gmAccordion('Lookup vocabularies', lookupsHtml, false) +
    gmAccordion('Import queue', importHtml, false) +
    gmAccordion('Garden site pages', pagesHtml, false);

  root.dataset.built = '1';
}
