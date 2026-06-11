// The Culinary Journal — Dashboard Module
// This file is loaded by dashboard.html
// Requires: supabase-config.js to be loaded first

var TCJ_REFUND_BANNER = 'No refunds on completed purchases. Core features stay free. Billing error or access fault? Email us within 7 days.';
var TCJ_REFUND_POLICY = 'Most of The Culinary Journal is free to use with a free account. If you choose a paid extra (such as a theme, optional plan, or subscription), that purchase is final once completed — we do not offer change-of-mind refunds.\n\nExceptions: If a payment was charged in error, duplicated, or you could not access what you paid for due to a technical fault on our side, contact us within 7 days at miseenplacekitchen.official@gmail.com and we will review it fairly.\n\nSubscriptions: You may cancel anytime; access continues until the end of the paid period. Cancelling does not refund the current period.\n\nBy completing a purchase you agree to this policy. See subscription-terms.html for full subscription terms.';
var TCJ_BILLING_EMAIL_KEYS = { purchase_confirmation: 1, subscription_confirmation: 1 };
var TCJ_EMAIL_PLACEHOLDERS = {
  welcome: ['name', 'site_url', 'recipes_url'],
  recipe_approved: ['name', 'recipe_name', 'recipe_id', 'recipe_url', 'site_url'],
  recipe_rejected: ['name', 'recipe_name', 'rejection_reason', 'site_url'],
  account_deactivated: ['name', 'reason'],
  request_fulfilled: ['name', 'recipe_name', 'recipe_url', 'site_url'],
  note_approved: ['name', 'recipe_name'],
  follow_new_recipe: ['name', 'author', 'recipe_name', 'recipe_url', 'site_url'],
  custom: ['name', 'subject', 'message'],
  purchase_confirmation: ['name', 'product_name', 'tier_label', 'amount_line', 'site_url'],
  subscription_confirmation: ['name', 'product_name', 'tier_label', 'amount_line', 'site_url']
};
var TCJ_EMAIL_SITE_URL = 'https://www.theculinaryjournal.site';

function tcjEmailSampleVars(key) {
  var base = {
    name: 'Alex Member',
    site_url: TCJ_EMAIL_SITE_URL,
    recipes_url: TCJ_EMAIL_SITE_URL + '/recipes.html',
    recipe_name: 'Kerala Beef Curry',
    recipe_id: '00000000-0000-0000-0000-000000000001',
    recipe_url: TCJ_EMAIL_SITE_URL + '/recipe-page.html?id=00000000-0000-0000-0000-000000000001',
    rejection_reason: 'Photo quality needs improvement before we can publish.',
    reason: 'Policy violation',
    author: 'Chef Maria',
    product_name: 'Premium theme',
    tier_label: 'Premium',
    amount_line: '$4.99/month',
    subject: 'A note from The Culinary Journal',
    message: 'Thanks for being part of our community.'
  };
  return base;
}

function tcjRenderEmailPreview(subject, body, vars) {
  vars = vars || {};
  vars.name = vars.name || 'Member';
  vars.site_url = vars.site_url || TCJ_EMAIL_SITE_URL;
  function escText(s) { return String(s || '').replace(/[\r\n\t]/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 200); }
  function escHtml(s) {
    return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }
  function escUrl(s) {
    s = String(s || '');
    return s.indexOf(TCJ_EMAIL_SITE_URL) === 0 ? s : '#';
  }
  var sub = subject || '';
  var html = body || '';
  Object.keys(vars).forEach(function(k) {
    var re = new RegExp('{{' + k + '}}', 'g');
    var isUrl = k.slice(-4) === '_url' || k.slice(-5) === '_link';
    sub = sub.replace(re, escText(vars[k]));
    html = html.replace(re, isUrl ? escUrl(vars[k]) : escHtml(vars[k]));
  });
  sub = sub.replace(/\{\{[^}]+\}\}/g, '');
  html = html.replace(/\{\{[^}]+\}\}/g, '');
  return { subject: sub, body: html };
}

async function tcjGetAdminEmail() {
  try {
    var rows = await rpc('get_my_profile', {});
    var p = Array.isArray(rows) && rows[0] ? rows[0] : null;
    return (p && p.email) ? String(p.email).trim() : '';
  } catch (_) { return ''; }
}

function switchSMTab(tab) {
  try {
    localStorage.setItem('tcj_active_sm_tab', tab);
    // Update active class on tab buttons
    document.querySelectorAll('#v-site-mgmt .ap-inner-tab').forEach(function(t){
      t.classList.toggle('active', t.dataset.tab === tab);
    });
    // Show/hide panels
    ['sm-pages','sm-features','sm-ann','sm-content','sm-themes','sm-email','sm-settings'].forEach(function(p){
      var el = document.getElementById('upanel-' + p);
      if (el) el.style.display = p === tab ? 'block' : 'none';
    });
    // Load content if not already built
    var container = document.getElementById('upanel-' + tab);
    if (!container) return;
    if (container.dataset.built === '1') return; // Only skip if fully loaded
    container.dataset.built = 'loading';
    if (tab === 'sm-pages')         buildSMPages(container);
    else if (tab === 'sm-features')  buildSMFeatures(container);
    else if (tab === 'sm-ann')       buildSMAnnouncements(container);
    else if (tab === 'sm-content')   buildSMContent(container);
    else if (tab === 'sm-themes')    buildSMThemes(container);
    else if (tab === 'sm-email')     buildSMEmail(container);
    else if (tab === 'sm-settings')  buildSMSettings(container);
  } catch(e) {
    alert('Site Management tab error: ' + e.message);
  }
}


// ── SITE MANAGEMENT BUILD FUNCTIONS ──────────────────────────────

var _SM_TIER_OPTS = [
  {v:'free',l:'Free'},{v:'daily',l:'Daily'},{v:'weekly',l:'Weekly'},
  {v:'monthly',l:'Monthly'},{v:'yearly',l:'Yearly'},{v:'premium',l:'Premium'},{v:'event',l:'Event'}
];
var _SM_SOFT_LAUNCH_PUBLIC = ['index.html','recipes.html','recipe-page.html','login.html','reset-password.html'];

async function buildSMPages(container) {
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);padding:8px 0">Loading\u2026</div>';
  try {
    var pagesRes = apiFetch(SUPABASE_URL + '/rest/v1/site_pages?order=sort_order');
    var settingsRes = apiFetch(SUPABASE_URL + '/rest/v1/site_settings?select=key,value');
    var res = await pagesRes; var sRes = await settingsRes;
    if (!res || !res.ok) throw new Error(res ? res.status + ': ' + await res.text() : 'Session expired');
    var pages = await res.json();
    var S = {};
    if (sRes && sRes.ok) { var sRows = await sRes.json(); if (Array.isArray(sRows)) sRows.forEach(function(r){ S[r.key] = r.value; }); }
    if (!Array.isArray(pages) || !pages.length) {
      container.dataset.built = '';
      container.innerHTML = '<div style="padding:16px;font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)">No pages found. Run sm_rpc_functions.sql then sm_compat_rpcs.sql to set up Site Management.</div>';
      return;
    }
    container.innerHTML = '';
    var launchCard = document.createElement('div');
    launchCard.style.cssText = 'background:rgba(196,151,59,0.08);border:1px solid rgba(196,151,59,0.25);border-radius:12px;padding:16px 20px;margin-bottom:16px';
    launchCard.innerHTML = '<div style="font-family:Cormorant Garamond,serif;font-size:1.05rem;font-weight:700;color:var(--accent);margin-bottom:6px">Soft Launch Preset</div>' +
      '<div style="font-size:12px;color:var(--text-mid);line-height:1.55;margin-bottom:12px">Hides every page except Home, Recipes, Recipe Page, and Login. Open features one-by-one when ready. Dashboard stays hidden.</div>';
    var launchBtn = document.createElement('button');
    launchBtn.className = 'ing-add-btn';
    launchBtn.textContent = 'Apply soft launch (hide all except core)';
    launchBtn.addEventListener('click', async function() {
      if (!confirm('Hide all pages except index, recipes, recipe-page, login, and reset-password?')) return;
      launchBtn.disabled = true;
      try {
        for (var i = 0; i < pages.length; i++) {
          var pg = pages[i];
          var vis = _SM_SOFT_LAUNCH_PUBLIC.indexOf(pg.path) !== -1 ? 'public' : 'hidden';
          var pr = await apiFetch(SUPABASE_URL + '/rest/v1/site_pages?path=eq.' + encodeURIComponent(pg.path), {
            method: 'PATCH', headers: { 'Content-Type': 'application/json', 'Prefer': 'return=minimal' },
            body: JSON.stringify({ visibility: vis, coming_soon: false })
          });
          if (!pr || !pr.ok) throw new Error('Failed on ' + pg.path);
        }
        alert('Soft launch preset applied.');
        container.dataset.built = '';
        buildSMPages(container);
      } catch (e) { alert(e.message); launchBtn.disabled = false; }
    });
    launchCard.appendChild(launchBtn);
    container.appendChild(launchCard);
    if (S.billing_no_refunds_banner) {
      var refundNote = document.createElement('p');
      refundNote.style.cssText = 'font-size:11px;color:var(--text-mid);margin-bottom:14px;padding:10px 14px;background:rgba(220,80,80,0.08);border:1px solid rgba(220,80,80,0.2);border-radius:8px';
      refundNote.textContent = S.billing_no_refunds_banner;
      container.appendChild(refundNote);
    }
    var wrap = document.createElement('div'); wrap.style.cssText = 'overflow-x:auto;border:1px solid var(--border);border-radius:12px';
    var tbl = document.createElement('table'); tbl.className = 'ap-table';
    tbl.innerHTML = '<thead><tr style="border-bottom:1px solid var(--border)"><th class="ap-th">Page</th><th class="ap-th">Path</th><th class="ap-th">Visibility</th><th class="ap-th">Min Tier</th><th class="ap-th" style="text-align:center">Coming Soon</th><th class="ap-th">Save</th></tr></thead>';
    var tbody = document.createElement('tbody');
    pages.forEach(function(p) {
      var path = p.path || '';
      var tr = document.createElement('tr');
      tr.className = 'sm-page-row';
      tr.style.borderBottom = '1px solid rgba(255,255,255,0.04)';
      var vis = '<select id="smv-'+esc(path)+'" style="padding:5px 8px;background:var(--bg);border:1px solid var(--border);border-radius:6px;font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-high)">'+
        [{v:'public',l:'Public — Everyone'},{v:'registered',l:'Registered Members'},{v:'paid',l:'Paid Members Only'},{v:'hidden',l:'Hidden'}].map(function(o){return '<option value="'+o.v+'"'+(p.visibility===o.v?' selected':'')+'>'+o.l+'</option>';}).join('')+'</select>';
      var minTier = p.min_tier || 'free';
      var tierSel = '<select id="smt-'+esc(path)+'" style="padding:5px 8px;background:var(--bg);border:1px solid var(--border);border-radius:6px;font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-high)">'+
        _SM_TIER_OPTS.map(function(o){return '<option value="'+o.v+'"'+(minTier===o.v?' selected':'')+'>'+o.l+'</option>';}).join('')+'</select>';
      var nameCell = document.createElement('td');
      nameCell.className = 'ap-td';
      nameCell.style.cssText = 'font-size:13px;font-weight:500;color:var(--text-high)';
      nameCell.appendChild(document.createTextNode(p.name || ''));
      var seoBtn = document.createElement('button');
      seoBtn.type = 'button';
      seoBtn.textContent = 'SEO';
      seoBtn.style.cssText = 'margin-left:8px;padding:2px 8px;background:none;border:1px solid var(--border);border-radius:5px;color:var(--text-mid);font-family:DM Sans,sans-serif;font-size:10px;cursor:pointer';
      seoBtn.addEventListener('click', (function(pagePath, btn) { return function() {
        var row = document.getElementById('seo-row-' + pagePath);
        if (!row) return;
        var open = row.style.display !== 'none';
        row.style.display = open ? 'none' : 'table-row';
        btn.style.borderColor = open ? 'var(--border)' : 'var(--accent)';
        btn.style.color = open ? 'var(--text-mid)' : 'var(--accent)';
      };})(path, seoBtn));
      nameCell.appendChild(seoBtn);
      tr.appendChild(nameCell);
      var pathTd = document.createElement('td');
      pathTd.className = 'ap-td';
      pathTd.style.cssText = 'font-size:11px;color:var(--text-mid)';
      pathTd.textContent = path;
      tr.appendChild(pathTd);
      var visTd = document.createElement('td'); visTd.className = 'ap-td'; visTd.innerHTML = vis; tr.appendChild(visTd);
      var tierTd = document.createElement('td'); tierTd.className = 'ap-td'; tierTd.innerHTML = tierSel; tr.appendChild(tierTd);
      var csTd = document.createElement('td');
      csTd.className = 'ap-td';
      csTd.style.textAlign = 'center';
      csTd.innerHTML = '<input type="checkbox" id="smcs-'+esc(path)+'"'+(p.coming_soon?' checked':'')+' style="width:15px;height:15px;accent-color:var(--accent)">';
      tr.appendChild(csTd);
      var saveTd = document.createElement('td'); saveTd.className = 'ap-td';
      var btn = document.createElement('button'); btn.textContent = 'Save';
      btn.style.cssText = "padding:5px 12px;background:var(--accent);border:none;border-radius:6px;color:#fff;font-family:'DM Sans',sans-serif;font-size:11px;cursor:pointer";
      btn.addEventListener('click', (function(pagePath, b) { return async function() {
        b.disabled=true; b.textContent='\u2026';
        try {
          var mtEl = document.getElementById('seo-t-'+pagePath);
          var mdEl = document.getElementById('seo-d-'+pagePath);
          var body = {
            visibility: document.getElementById('smv-'+pagePath).value,
            coming_soon: document.getElementById('smcs-'+pagePath).checked,
            min_tier: document.getElementById('smt-'+pagePath).value,
            meta_title: mtEl ? (mtEl.value || null) : null,
            meta_desc: mdEl ? (mdEl.value || null) : null
          };
          var r=await apiFetch(SUPABASE_URL+'/rest/v1/site_pages?path=eq.'+encodeURIComponent(pagePath),{method:'PATCH',headers:{'Content-Type':'application/json','Prefer':'return=representation'},body:JSON.stringify(body)});
          var rBody = await r.json(); if(!Array.isArray(rBody)||!rBody.length) throw new Error('Row not found — no changes saved');
          b.textContent='\u2713 Saved'; setTimeout(function(){var c=document.getElementById('upanel-sm-pages');if(c){c.dataset.built='';buildSMPages(c);}},1500);
        } catch(e){b.textContent='Save';b.disabled=false;alert('Save failed: '+e.message);}
      };})(path,btn));
      saveTd.appendChild(btn);
      tr.appendChild(saveTd);
      tbody.appendChild(tr);
      var seoWrap = document.createElement('tr');
      seoWrap.className = 'sm-page-seo-row';
      seoWrap.id = 'seo-row-' + path;
      seoWrap.style.cssText = 'border-bottom:1px solid rgba(255,255,255,0.04);display:none';
      var seoCel = document.createElement('td');
      seoCel.setAttribute('colspan','6');
      seoCel.style.cssText = 'padding:0 8px 10px';
      var seoGrid = document.createElement('div');
      seoGrid.style.cssText = 'display:grid;grid-template-columns:1fr 1fr;gap:8px;padding:8px 0';
      var seoMakeLabeledInput = function(labelText, inputId, inputValue) {
        var w = document.createElement('div');
        var lbl = document.createElement('label');
        lbl.style.cssText = 'display:block;font-size:10px;text-transform:uppercase;color:var(--text-mid);margin-bottom:3px';
        lbl.textContent = labelText;
        var inp = document.createElement('input');
        inp.id = inputId; inp.value = inputValue;
        inp.style.cssText = 'width:100%;box-sizing:border-box;padding:5px 8px;background:var(--bg);border:1px solid var(--border);border-radius:6px;font-size:11px;color:var(--text-high)';
        w.appendChild(lbl); w.appendChild(inp);
        return w;
      };
      seoGrid.appendChild(seoMakeLabeledInput('Meta Title', 'seo-t-'+path, p.meta_title || ''));
      seoGrid.appendChild(seoMakeLabeledInput('Meta Description', 'seo-d-'+path, p.meta_desc || ''));
      seoCel.appendChild(seoGrid);
      seoWrap.appendChild(seoCel);
      tbody.appendChild(seoWrap);
    });
    tbl.appendChild(tbody); wrap.appendChild(tbl); container.appendChild(wrap);
    container.dataset.built = '1';
  } catch(e) {
    container.dataset.built = '';
    container.innerHTML = '<div style="padding:16px;background:rgba(220,80,80,0.1);border:1px solid rgba(220,80,80,0.4);border-radius:10px;font-family:DM Sans,sans-serif;font-size:13px;color:#dc5050"><strong>Error:</strong> '+String(e.message).replace(/</g,'&lt;')+'</div>';
  }
}

function _smAnnToLocalInput(iso) {
  if (!iso) return '';
  var d = new Date(iso);
  if (isNaN(d.getTime())) return '';
  var pad = function(n) { return String(n).padStart(2, '0'); };
  return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + 'T' + pad(d.getHours()) + ':' + pad(d.getMinutes());
}

async function buildSMAnnouncements(container) {
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);padding:8px 0">Loading\u2026</div>';
  try {
    var anns = await rpc('admin_get_announcements', {}) || [];
    if (!Array.isArray(anns)) anns = [];
    container.innerHTML = '';
    var form = document.createElement('div');
    form.style.cssText = 'background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:12px;padding:16px 20px;margin-bottom:16px';
    form.innerHTML = '<div style="font-family:Cormorant Garamond,serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:12px">New Announcement</div>' +
      '<div style="display:grid;grid-template-columns:1fr 100px;gap:10px;margin-bottom:10px">' +
      '<input id="sm-ann-new-text" placeholder="Announcement text\u2026" style="padding:7px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high)">' +
      '<select id="sm-ann-new-type" style="padding:7px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high)"><option value="info">Info</option><option value="success">Success</option><option value="warning">Warning</option><option value="error">Error</option></select></div>' +
      '<div style="display:grid;grid-template-columns:1fr auto;gap:10px;align-items:center;margin-bottom:10px">' +
      '<div><label style="display:block;font-size:10px;text-transform:uppercase;color:var(--text-mid);margin-bottom:4px">Expires (optional)</label>' +
      '<input id="sm-ann-new-exp" type="datetime-local" style="width:100%;padding:7px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high)"></div>' +
      '<label style="display:flex;align-items:center;gap:8px;font-size:12px;color:var(--text-high);margin-top:18px"><input type="checkbox" id="sm-ann-new-active" checked style="width:15px;height:15px;accent-color:var(--accent)"> Active on create</label></div>';
    var addBtn = document.createElement('button');
    addBtn.className = 'ing-add-btn';
    addBtn.textContent = 'Add Announcement';
    addBtn.addEventListener('click', async function() {
      var text = (document.getElementById('sm-ann-new-text').value || '').trim();
      if (!text) return;
      addBtn.disabled = true;
      try {
        await rpc('admin_save_announcement', {
          p_id: 0,
          p_text: text,
          p_type: document.getElementById('sm-ann-new-type').value,
          p_active: document.getElementById('sm-ann-new-active').checked,
          p_expires_at: document.getElementById('sm-ann-new-exp').value || null
        });
        var c = document.getElementById('upanel-sm-ann');
        if (c) { c.dataset.built = ''; buildSMAnnouncements(c); }
      } catch (e) { addBtn.disabled = false; alert('Add failed: ' + e.message); }
    });
    form.appendChild(addBtn);
    container.appendChild(form);
    if (!anns.length) {
      var p = document.createElement('p');
      p.style.cssText = 'font-size:13px;color:var(--text-mid)';
      p.textContent = 'No announcements yet.';
      container.appendChild(p);
    } else {
      var TC = { info: '#5B8FD4', success: '#4caf76', warning: '#d4a017', error: '#dc5050' };
      anns.forEach(function(a) {
        var card = document.createElement('div');
        card.style.cssText = 'background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:10px;padding:12px 16px;margin-bottom:8px';
        var view = document.createElement('div');
        view.style.cssText = 'display:flex;gap:10px;justify-content:space-between;align-items:flex-start';
        var left = document.createElement('div');
        left.style.flex = '1';
        var annType = document.createElement('span');
        annType.style.cssText = 'font-size:10px;font-weight:700;padding:2px 7px;border-radius:5px;background:rgba(0,0,0,0.3);color:' + (TC[a.type] || 'var(--text-mid)');
        annType.textContent = (a.type || 'info').toUpperCase();
        var annText = document.createElement('div');
        annText.style.cssText = 'font-size:13px;color:var(--text-high);margin-top:6px';
        annText.textContent = a.text || '';
        left.appendChild(annType);
        left.appendChild(annText);
        if (!a.active) {
          var inactive = document.createElement('div');
          inactive.style.cssText = 'font-size:11px;color:var(--text-mid);margin-top:4px';
          inactive.textContent = 'Inactive — not shown on site';
          left.appendChild(inactive);
        }
        if (a.expires_at) {
          var exp = document.createElement('div');
          exp.style.cssText = 'font-size:11px;color:var(--text-mid);margin-top:2px';
          exp.textContent = 'Expires: ' + new Date(a.expires_at).toLocaleString('en-GB', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
          left.appendChild(exp);
        }
        var btns = document.createElement('div');
        btns.style.cssText = 'display:flex;gap:6px;flex-shrink:0;flex-wrap:wrap';
        var toggleBtn = document.createElement('button');
        toggleBtn.style.cssText = 'padding:4px 10px;background:none;border:1px solid var(--border);border-radius:6px;color:var(--text-mid);font-size:11px;cursor:pointer';
        toggleBtn.textContent = a.active ? 'Pause' : 'Activate';
        toggleBtn.addEventListener('click', async function() {
          try {
            await rpc('admin_save_announcement', { p_id: a.id, p_text: a.text, p_type: a.type, p_active: !a.active, p_expires_at: a.expires_at || null });
            var c = document.getElementById('upanel-sm-ann');
            if (c) { c.dataset.built = ''; buildSMAnnouncements(c); }
          } catch (e) { alert('Update failed: ' + e.message); }
        });
        var editBtn = document.createElement('button');
        editBtn.style.cssText = 'padding:4px 10px;background:none;border:1px solid var(--border);border-radius:6px;color:var(--text-mid);font-size:11px;cursor:pointer';
        editBtn.textContent = 'Edit';
        editBtn.addEventListener('click', function() {
          view.style.display = 'none';
          editPanel.style.display = 'block';
        });
        var dBtn = document.createElement('button');
        dBtn.style.cssText = 'padding:4px 10px;background:none;border:1px solid #dc5050;border-radius:6px;color:#dc5050;font-size:11px;cursor:pointer';
        dBtn.textContent = 'Delete';
        dBtn.addEventListener('click', async function() {
          if (!confirm('Delete this announcement?')) return;
          try {
            await rpc('admin_delete_announcement', { p_id: a.id });
            var c = document.getElementById('upanel-sm-ann');
            if (c) { c.dataset.built = ''; buildSMAnnouncements(c); }
          } catch (e) { alert('Delete failed: ' + e.message); }
        });
        btns.appendChild(toggleBtn);
        btns.appendChild(editBtn);
        btns.appendChild(dBtn);
        view.appendChild(left);
        view.appendChild(btns);
        var editPanel = document.createElement('div');
        editPanel.style.display = 'none';
        editPanel.innerHTML =
          '<div style="display:grid;grid-template-columns:1fr 100px;gap:8px;margin-bottom:8px">' +
          '<input id="sm-ann-edit-text-' + a.id + '" style="padding:7px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-size:12px;color:var(--text-high)">' +
          '<select id="sm-ann-edit-type-' + a.id + '" style="padding:7px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-size:12px;color:var(--text-high)"><option value="info">Info</option><option value="success">Success</option><option value="warning">Warning</option><option value="error">Error</option></select></div>' +
          '<div style="margin-bottom:8px"><label style="display:block;font-size:10px;text-transform:uppercase;color:var(--text-mid);margin-bottom:4px">Expires</label>' +
          '<input id="sm-ann-edit-exp-' + a.id + '" type="datetime-local" style="width:100%;max-width:280px;padding:7px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-size:12px;color:var(--text-high)"></div>' +
          '<div style="display:flex;gap:8px"><button type="button" class="sm-ann-save-edit" style="padding:5px 12px;background:var(--accent);border:none;border-radius:6px;color:#fff;font-size:11px;cursor:pointer">Save</button>' +
          '<button type="button" class="sm-ann-cancel-edit" style="padding:5px 12px;background:none;border:1px solid var(--border);border-radius:6px;color:var(--text-mid);font-size:11px;cursor:pointer">Cancel</button></div>';
        card.appendChild(view);
        card.appendChild(editPanel);
        document.getElementById('sm-ann-edit-text-' + a.id).value = a.text || '';
        document.getElementById('sm-ann-edit-type-' + a.id).value = a.type || 'info';
        document.getElementById('sm-ann-edit-exp-' + a.id).value = _smAnnToLocalInput(a.expires_at);
        editPanel.querySelector('.sm-ann-save-edit').addEventListener('click', async function() {
          try {
            await rpc('admin_save_announcement', {
              p_id: a.id,
              p_text: document.getElementById('sm-ann-edit-text-' + a.id).value.trim(),
              p_type: document.getElementById('sm-ann-edit-type-' + a.id).value,
              p_active: a.active,
              p_expires_at: document.getElementById('sm-ann-edit-exp-' + a.id).value || null
            });
            var c = document.getElementById('upanel-sm-ann');
            if (c) { c.dataset.built = ''; buildSMAnnouncements(c); }
          } catch (e) { alert('Save failed: ' + e.message); }
        });
        editPanel.querySelector('.sm-ann-cancel-edit').addEventListener('click', function() {
          editPanel.style.display = 'none';
          view.style.display = 'flex';
        });
        container.appendChild(card);
      });
    }
    container.dataset.built = '1';
  } catch (e) {
    container.dataset.built = '';
    container.innerHTML = '<div style="padding:16px;background:rgba(220,80,80,0.1);border:1px solid rgba(220,80,80,0.4);border-radius:10px;font-family:DM Sans,sans-serif;font-size:13px;color:#dc5050"><strong>Error:</strong> ' + String(e.message).replace(/</g, '&lt;') + '</div>';
  }
}

function tcjAppendQueueRows(parent, rows, showError) {
  if (!rows.length) return;
  var ul = document.createElement('ul');
  ul.style.cssText = 'margin:0 0 10px;padding-left:18px;font-size:11px;color:var(--text-high);list-style:disc';
  rows.forEach(function(q) {
    var li = document.createElement('li');
    li.style.marginBottom = '6px';
    var line = (q.template_key || '?') + ' \u2192 ' + (q.to_email || '');
    if (q.attempts) line += ' (' + q.attempts + ' attempts)';
    li.appendChild(document.createTextNode(line));
    if (showError && q.error_msg) {
      var err = document.createElement('div');
      err.style.cssText = 'color:#dc5050;font-size:10px;margin-top:2px;word-break:break-word';
      err.textContent = q.error_msg;
      li.appendChild(err);
    }
    var rowBtns = document.createElement('span');
    rowBtns.style.cssText = 'display:inline-flex;gap:6px;margin-left:8px';
    var delBtn = document.createElement('button');
    delBtn.type = 'button';
    delBtn.textContent = 'Delete';
    delBtn.style.cssText = 'padding:2px 8px;font-size:10px;background:none;border:1px solid var(--border);border-radius:5px;color:var(--text-mid);cursor:pointer';
    delBtn.addEventListener('click', async function() {
      if (!confirm('Remove this queue item?')) return;
      try {
        await rpc('admin_delete_email_queue', { p_id: q.id });
        var c = document.getElementById('upanel-sm-email');
        if (c) { c.dataset.built = ''; buildSMEmail(c); }
      } catch (e) { alert(e.message); }
    });
    rowBtns.appendChild(delBtn);
    li.appendChild(rowBtns);
    ul.appendChild(li);
  });
  parent.appendChild(ul);
}

async function buildSMEmail(container) {
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);padding:8px 0">Loading\u2026</div>';
  try {
    var queueBox = document.createElement('div');
    queueBox.style.cssText = 'background:rgba(91,143,212,0.08);border:1px solid rgba(91,143,212,0.25);border-radius:12px;padding:16px 20px;margin-bottom:20px';
    try {
      var pending = await rpc('admin_get_email_queue', { p_status: 'pending', p_limit: 10 }) || [];
      var failed  = await rpc('admin_get_email_queue', { p_status: 'failed', p_limit: 10 }) || [];
      var sent    = await rpc('admin_get_email_queue', { p_status: 'sent', p_limit: 5 }) || [];
      queueBox.innerHTML = '<div style="font-family:Cormorant Garamond,serif;font-size:1.1rem;font-weight:700;color:#5B8FD4;margin-bottom:8px">Email Queue</div>' +
        '<div style="font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);line-height:1.6;margin-bottom:10px">' +
        '<strong>' + pending.length + '</strong> pending · <strong style="color:#dc5050">' + failed.length + '</strong> failed · <strong>' + sent.length + '</strong> recent sent</div>' +
        '<div style="font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-mid);margin-bottom:12px;line-height:1.5">Worker: <code>send-queued-emails</code> + Resend. Password reset &amp; email confirmation use <strong>Supabase Auth</strong> templates — not editable here.</div>';
      if (pending.length) {
        var pLbl = document.createElement('div');
        pLbl.style.cssText = 'font-size:10px;font-weight:700;text-transform:uppercase;color:var(--text-mid);margin-bottom:4px';
        pLbl.textContent = 'Pending';
        queueBox.appendChild(pLbl);
        tcjAppendQueueRows(queueBox, pending, false);
      }
      if (failed.length) {
        var fLbl = document.createElement('div');
        fLbl.style.cssText = 'font-size:10px;font-weight:700;text-transform:uppercase;color:#dc5050;margin:8px 0 4px';
        fLbl.textContent = 'Failed (with error)';
        queueBox.appendChild(fLbl);
        tcjAppendQueueRows(queueBox, failed, true);
      }
      var retryBtn = document.createElement('button');
      retryBtn.className = 'ing-add-btn';
      retryBtn.textContent = 'Retry all failed';
      retryBtn.addEventListener('click', async function() {
        retryBtn.disabled = true;
        try {
          var n = await rpc('admin_reset_failed_emails', {});
          alert('Reset ' + (n || 0) + ' failed email(s) to pending.');
          container.dataset.built = '';
          buildSMEmail(container);
        } catch (e) { alert(e.message); retryBtn.disabled = false; }
      });
      queueBox.appendChild(retryBtn);
      var sendNowBtn = document.createElement('button');
      sendNowBtn.className = 'ing-add-btn';
      sendNowBtn.style.marginLeft = '8px';
      sendNowBtn.textContent = 'Send pending now';
      sendNowBtn.addEventListener('click', async function() {
        sendNowBtn.disabled = true;
        try {
          await rpc('admin_invoke_edge_function', { p_function: 'send-queued-emails' });
          alert('Email worker triggered. Refresh in ~15 seconds.');
          container.dataset.built = '';
          buildSMEmail(container);
        } catch (e) { alert(e.message); sendNowBtn.disabled = false; }
      });
      queueBox.appendChild(sendNowBtn);
    } catch (qe) {
      queueBox.innerHTML = '<div style="font-size:12px;color:var(--text-mid)">Email queue unavailable — run fix-phase6-batch.sql and fix-email-system.sql</div>';
    }

    var res = await apiFetch(SUPABASE_URL+'/rest/v1/email_templates?order=key');
    if (!res||!res.ok) throw new Error(res?res.status+': '+await res.text():'Session expired');
    var templates = await res.json();
    if(!Array.isArray(templates)||!templates.length){container.dataset.built='';container.innerHTML='<div style="padding:16px;font-size:13px;color:var(--text-mid)">No email templates. Run email_templates.sql and fix-email-system.sql in Supabase.</div>';return;}
    container.innerHTML='';
    container.appendChild(queueBox);
    var tplNote = document.createElement('p');
    tplNote.style.cssText = 'font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);margin-bottom:16px;line-height:1.55';
    tplNote.innerHTML = 'Each template lists its own placeholders below. Lifecycle emails queue automatically when you approve recipes, complete onboarding, deactivate accounts, fulfil requests, and approve cooking tips — after running <code>fix-email-system.sql</code>. Billing templates should match <strong>Settings → Billing &amp; Refund Policy</strong>.';
    container.appendChild(tplNote);

    var adminEmail = await tcjGetAdminEmail();

    function appendEmailTemplateBlock(t) {
      var sec=document.createElement('div');sec.style.cssText='background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:12px;padding:16px 20px;margin-bottom:14px';
      var secTitle = document.createElement('div');
      secTitle.style.cssText = 'font-family:Cormorant Garamond,serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:4px';
      secTitle.textContent = (t.name || t.key || '') + ' (' + t.key + ')';
      sec.appendChild(secTitle);
      var phList = TCJ_EMAIL_PLACEHOLDERS[t.key] || ['name', 'site_url'];
      var phNote = document.createElement('p');
      phNote.style.cssText = 'font-size:10px;color:var(--text-mid);margin:0 0 10px;line-height:1.45';
      phNote.textContent = 'Placeholders: ' + phList.map(function(p){ return '{{' + p + '}}'; }).join(', ');
      sec.appendChild(phNote);
      if (TCJ_BILLING_EMAIL_KEYS[t.key]) {
        var billHint = document.createElement('p');
        billHint.style.cssText = 'font-size:11px;color:var(--text-mid);margin:-4px 0 10px;line-height:1.5';
        billHint.textContent = 'Sent after a purchase or tier upgrade.';
        sec.appendChild(billHint);
      }
      var subWrap = document.createElement('div'); subWrap.style.marginBottom = '8px';
      var subLbl = document.createElement('label'); subLbl.style.cssText = 'display:block;font-size:10px;color:var(--text-mid);margin-bottom:3px'; subLbl.textContent = 'Subject';
      var subInp = document.createElement('input'); subInp.id = 'em-s-'+t.key; subInp.value = t.subject||'';
      subInp.style.cssText = 'width:100%;box-sizing:border-box;padding:7px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-size:12px;color:var(--text-high)';
      subWrap.appendChild(subLbl); subWrap.appendChild(subInp); sec.appendChild(subWrap);
      var bodyWrap = document.createElement('div'); bodyWrap.style.marginBottom = '10px';
      var bodyLbl = document.createElement('label'); bodyLbl.style.cssText = 'display:block;font-size:10px;color:var(--text-mid);margin-bottom:3px'; bodyLbl.textContent = 'Body (inner HTML — outer shell is fixed in the worker)';
      var ta = document.createElement('textarea'); ta.id = 'em-b-'+t.key; ta.rows = TCJ_BILLING_EMAIL_KEYS[t.key] ? 8 : 4;
      ta.style.cssText = 'width:100%;box-sizing:border-box;padding:7px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-size:12px;color:var(--text-high);resize:vertical';
      ta.value = t.body || '';
      bodyWrap.appendChild(bodyLbl); bodyWrap.appendChild(ta); sec.appendChild(bodyWrap);
      var previewBox = document.createElement('div');
      previewBox.id = 'em-preview-' + t.key;
      previewBox.style.cssText = 'display:none;margin-bottom:10px;padding:12px;background:rgba(0,0,0,0.25);border:1px solid var(--border);border-radius:8px;font-size:12px;line-height:1.5';
      sec.appendChild(previewBox);
      var btnRow = document.createElement('div');
      btnRow.style.cssText = 'display:flex;flex-wrap:wrap;gap:8px';
      var btn=document.createElement('button');btn.className='ing-add-btn';btn.textContent='Save';
      btn.addEventListener('click',(function(key,b){return async function(){b.disabled=true;b.textContent='Saving\u2026';
        try{var r=await apiFetch(SUPABASE_URL+'/rest/v1/email_templates',{method:'POST',headers:{'Content-Type':'application/json','Prefer':'resolution=merge-duplicates,return=minimal'},body:JSON.stringify({key:key,name:key.replace(/_/g,' ').replace(/\b\w/g,function(c){return c.toUpperCase();}),subject:document.getElementById('em-s-'+key).value,body:document.getElementById('em-b-'+key).value})});
        if(!r||!r.ok)throw new Error(r?r.status+': '+await r.text():'Session expired');
        b.textContent='\u2713 Saved';setTimeout(function(){var c=document.getElementById('upanel-sm-email');if(c){c.dataset.built='';buildSMEmail(c);}},1500);}
        catch(e){b.textContent='Save';b.disabled=false;alert('Save failed: '+e.message);}
      }})(t.key,btn));
      btnRow.appendChild(btn);
      var prevBtn = document.createElement('button');
      prevBtn.type = 'button';
      prevBtn.className = 'ing-add-btn';
      prevBtn.style.background = 'none';
      prevBtn.style.border = '1px solid var(--border)';
      prevBtn.style.color = 'var(--text-mid)';
      prevBtn.textContent = 'Preview';
      prevBtn.addEventListener('click', (function(key, box) {
        return function() {
          var subj = document.getElementById('em-s-' + key);
          var bodyEl = document.getElementById('em-b-' + key);
          var rendered = tcjRenderEmailPreview(subj ? subj.value : '', bodyEl ? bodyEl.value : '', tcjEmailSampleVars(key));
          box.style.display = 'block';
          box.innerHTML = '<div style="font-weight:600;margin-bottom:6px">Subject: ' + rendered.subject.replace(/</g, '&lt;') + '</div>' + rendered.body;
        };
      })(t.key, previewBox));
      btnRow.appendChild(prevBtn);
      var testBtn = document.createElement('button');
      testBtn.type = 'button';
      testBtn.className = 'ing-add-btn';
      testBtn.style.background = 'none';
      testBtn.style.border = '1px solid var(--border)';
      testBtn.style.color = 'var(--text-mid)';
      testBtn.textContent = 'Send test to me';
      testBtn.addEventListener('click', (function(key, tmplKey) {
        return async function() {
          if (!adminEmail) { alert('No admin email on your profile.'); return; }
          if (!confirm('Queue a test "' + tmplKey + '" email to ' + adminEmail + '?')) return;
          testBtn.disabled = true;
          try {
            await rpc('queue_email', {
              p_template_key: tmplKey,
              p_to_email: adminEmail,
              p_to_name: 'Admin test',
              p_variables: tcjEmailSampleVars(tmplKey)
            });
            alert('Test email queued. Click "Send pending now" to deliver.');
          } catch (e) { alert(e.message); }
          testBtn.disabled = false;
        };
      })(t.key, t.key));
      btnRow.appendChild(testBtn);
      sec.appendChild(btnRow);
      container.appendChild(sec);
    }

    var billingTpl = templates.filter(function(t){ return TCJ_BILLING_EMAIL_KEYS[t.key]; });
    var otherTpl   = templates.filter(function(t){ return !TCJ_BILLING_EMAIL_KEYS[t.key]; });
    if (billingTpl.length) {
      var billHdr = document.createElement('div');
      billHdr.style.cssText = 'font-family:Cormorant Garamond,serif;font-size:1.15rem;font-weight:700;color:var(--accent);margin:8px 0 12px';
      billHdr.textContent = 'Billing & purchases';
      container.appendChild(billHdr);
      billingTpl.forEach(appendEmailTemplateBlock);
    }
    if (otherTpl.length) {
      var otherHdr = document.createElement('div');
      otherHdr.style.cssText = 'font-family:Cormorant Garamond,serif;font-size:1.15rem;font-weight:700;color:var(--text-high);margin:18px 0 12px';
      otherHdr.textContent = 'Recipes, accounts & notifications';
      container.appendChild(otherHdr);
      otherTpl.forEach(appendEmailTemplateBlock);
    }
    container.dataset.built='1';
  } catch(e){container.dataset.built='';container.innerHTML='<div style="padding:16px;background:rgba(220,80,80,0.1);border:1px solid rgba(220,80,80,0.4);border-radius:10px;font-family:DM Sans,sans-serif;font-size:13px;color:#dc5050"><strong>Error:</strong> '+String(e.message).replace(/</g,'&lt;')+'</div>';}
}

async function buildSMSettings(container) {
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);padding:8px 0">Loading\u2026</div>';
  try {
    var res = await apiFetch(SUPABASE_URL+'/rest/v1/site_settings?select=key,value');
    if (!res||!res.ok) throw new Error(res?res.status+': '+await res.text():'Session expired');
    var rows = await res.json(); var S={};
    if(Array.isArray(rows)) rows.forEach(function(r){S[r.key]=r.value;});
    async function ssSave(k,v){var r=await apiFetch(SUPABASE_URL+'/rest/v1/site_settings',{method:'POST',headers:{'Content-Type':'application/json','Prefer':'resolution=merge-duplicates,return=minimal'},body:JSON.stringify({key:k,value:v})});if(!r||!r.ok)throw new Error(r?r.status+': '+await r.text():'Session expired');}
    container.innerHTML='';
    function mk(tag,s,t){var e=document.createElement(tag);if(s)e.style.cssText=s;if(t!==undefined)e.textContent=t;return e;}
    function card(title){var d=mk('div','background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:12px;padding:20px;margin-bottom:16px');d.appendChild(mk('div',"font-family:'Cormorant Garamond',serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:14px",title));return d;}
    function inp(id,lbl,val){var w=mk('div','margin-bottom:12px');w.appendChild(mk('label','display:block;font-size:10px;text-transform:uppercase;color:var(--text-mid);margin-bottom:4px',lbl));var i=mk('input','width:100%;box-sizing:border-box;padding:7px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-size:12px;color:var(--text-high)');i.id='ss-'+id;i.value=val||'';w.appendChild(i);return w;}
    function saveBtn(keys,lbl){var b=document.createElement('button');b.className='ing-add-btn';b.style.marginTop='4px';b.textContent=lbl||'Save';
      b.addEventListener('click',async function(){b.disabled=true;b.textContent='Saving\u2026';
        try{for(var k=0;k<keys.length;k++){var el=document.getElementById('ss-'+keys[k]);if(el)await ssSave(keys[k],el.value||'');}
        b.textContent='\u2713 Saved';setTimeout(function(){var c=document.getElementById('upanel-sm-settings');if(c){c.dataset.built='';buildSMSettings(c);}},1500);}
        catch(e){b.textContent=lbl||'Save';b.disabled=false;alert('Save failed: '+e.message);}});return b;}
    var m=card('Maintenance Mode');
    var mr=mk('div','display:flex;align-items:center;justify-content:space-between;margin-bottom:12px');
    mr.appendChild(mk('span','font-size:13px;color:var(--text-high)','Maintenance Mode'));
    var mc=mk('input','width:16px;height:16px;accent-color:#dc5050;cursor:pointer');mc.type='checkbox';mc.checked=S.maintenance_enabled==='true';
    mc.addEventListener('change',async function(){var prev=this.checked;try{await ssSave('maintenance_enabled',String(this.checked));}catch(e){this.checked=!prev;alert(e.message);}});
    mr.appendChild(mc);m.appendChild(mr);m.appendChild(inp('maintenance_message','Maintenance Message',S.maintenance_message));m.appendChild(saveBtn(['maintenance_message'],'Save'));container.appendChild(m);
    var w=card('Watermark');var wg=mk('div','display:grid;grid-template-columns:1fr 1fr;gap:10px');
    wg.appendChild(inp('watermark_font','Font',S.watermark_font));wg.appendChild(inp('watermark_opacity','Opacity',S.watermark_opacity));
    w.appendChild(wg);w.appendChild(saveBtn(['watermark_font','watermark_opacity'],'Save Watermark'));container.appendChild(w);
    var f=card('Footer');f.appendChild(inp('footer_copyright','Copyright',S.footer_copyright));f.appendChild(saveBtn(['footer_copyright'],'Save Footer'));container.appendChild(f);
        var seo=card('SEO — Site-wide Defaults');
    seo.appendChild(inp('seo_site_title','Default Page Title',S.seo_site_title));
    seo.appendChild(inp('seo_site_description','Default Meta Description',S.seo_site_description));
    seo.appendChild(inp('seo_og_image','Social Share Image URL',S.seo_og_image));
    seo.appendChild(saveBtn(['seo_site_title','seo_site_description','seo_og_image'],'Save SEO'));
    container.appendChild(seo);
    var bill = card('Billing & Refund Policy');
    bill.appendChild(mk('p','font-size:11px;color:var(--text-mid);margin-bottom:12px;line-height:1.55','Shown on the upgrade page and subscription-terms.html. Most of the site stays free — this covers optional paid extras (themes, plans). Fair but clear: no change-of-mind refunds; technical billing errors reviewed within 7 days.'));
    var rpWrap = mk('div','margin-bottom:12px');
    rpWrap.appendChild(mk('label','display:block;font-size:10px;text-transform:uppercase;color:var(--text-mid);margin-bottom:4px','Refund Policy (full text)'));
    var rpTa = mk('textarea','width:100%;box-sizing:border-box;padding:7px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-size:12px;color:var(--text-high);resize:vertical');
    rpTa.id = 'ss-refund_policy'; rpTa.rows = 8; rpTa.value = S.refund_policy || '';
    rpWrap.appendChild(rpTa); bill.appendChild(rpWrap);
    bill.appendChild(inp('billing_no_refunds_banner','Short banner (upgrade page)',S.billing_no_refunds_banner));
    var draftBtn = document.createElement('button');
    draftBtn.className = 'ing-add-btn';
    draftBtn.style.cssText = 'margin-right:8px;margin-top:4px;background:transparent;border:1px solid var(--accent);color:var(--accent)';
    draftBtn.textContent = 'Insert recommended wording';
    draftBtn.addEventListener('click', function() {
      if (rpTa.value && !confirm('Replace current refund policy text with the recommended draft?')) return;
      rpTa.value = TCJ_REFUND_POLICY;
      var ban = document.getElementById('ss-billing_no_refunds_banner');
      if (ban) ban.value = TCJ_REFUND_BANNER;
    });
    bill.appendChild(draftBtn);
    var emailLink = mk('p','font-size:11px;color:var(--text-mid);margin-top:10px;line-height:1.55');
    emailLink.innerHTML = 'Purchase confirmation emails live under <strong>Email Templates</strong> (Billing &amp; purchases). Keep wording in sync when you edit this section.';
    bill.appendChild(emailLink);
    var billSave = saveBtn(['billing_no_refunds_banner'],'Save Billing Copy');
    billSave.addEventListener('click', async function() {
      billSave.disabled = true; billSave.textContent = 'Saving\u2026';
      try {
        await ssSave('refund_policy', rpTa.value || '');
        var ban = document.getElementById('ss-billing_no_refunds_banner');
        if (ban) await ssSave('billing_no_refunds_banner', ban.value || '');
        billSave.textContent = '\u2713 Saved';
        setTimeout(function(){ var c = document.getElementById('upanel-sm-settings'); if (c) { c.dataset.built = ''; buildSMSettings(c); } }, 1500);
      } catch (e) { billSave.textContent = 'Save Billing Copy'; billSave.disabled = false; alert(e.message); }
    });
    bill.appendChild(billSave);
    container.appendChild(bill);
    container.dataset.built='1';
  } catch(e){container.dataset.built='';container.innerHTML='<div style="padding:16px;background:rgba(220,80,80,0.1);border:1px solid rgba(220,80,80,0.4);border-radius:10px;font-family:DM Sans,sans-serif;font-size:13px;color:#dc5050"><strong>Error:</strong> '+String(e.message).replace(/</g,'&lt;')+'</div>';}
}


// ═══════════════════════════════════════════════════════════════
// FINANCE MANAGEMENT
// ═══════════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════════════
// Library Management
// ══════════════════════════════════════════════════════════════════════

var LIB_CURRENT_TYPE = 'ingredient';
var LIB_CURRENT_STATUS = null;
var LIB_IMAGE_STATUS = null;
var LIB_SEARCH = '';
var LIB_SORT = 'updated_desc';
var LIB_OFFSET = 0;
var LIB_PAGE_SIZE = 25;
var LIB_TOTAL = 0;
var LIB_SELECTED = {};
var _libEdProfileId = null;
var _libEdSlug = null;
var _libIngSearchTimer = null;

var LIB_TYPE_MAP = {
  'lm-ingredients':  { type:'ingredient',   label:'Ingredients',   emoji:'🌿' },
  'lm-spices':       { type:'spice',         label:'Spices',        emoji:'🌶' },
  'lm-tools':        { type:'tool',          label:'Tools',         emoji:'🔪' },
  'lm-cuts':         { type:'cut',           label:'Cuts & Prep',   emoji:'🥩' },
  'lm-preservation': { type:'preservation',  label:'Preservation',  emoji:'🫙' },
};

function switchLibTab(tab) {
  localStorage.setItem('tcj_active_lib_tab', tab);
  document.querySelectorAll('#v-library-mgmt .ap-inner-tab').forEach(function(b) {
    b.classList.toggle('active', b.dataset.tab === tab);
  });
  LIB_OFFSET = 0;
  LIB_SELECTED = {};
  if (tab === 'lm-submissions') { loadLibSubmissions(); return; }
  if (tab === 'lm-coverage') { loadLibCoverage(); return; }
  var info = LIB_TYPE_MAP[tab];
  if (info) { LIB_CURRENT_TYPE = info.type; loadLibProfiles(); }
}

function libSelectedIds() {
  return Object.keys(LIB_SELECTED).filter(function(k) { return LIB_SELECTED[k]; });
}

function libToggleSelectAll(checked) {
  document.querySelectorAll('#lm-panel [data-lib-check]').forEach(function(cb) {
    cb.checked = checked;
    LIB_SELECTED[cb.dataset.lid] = checked;
  });
  libUpdateBulkBar();
}

function libUpdateBulkBar() {
  var n = libSelectedIds().length;
  var bar = document.getElementById('lib-bulk-bar');
  if (bar) {
    bar.classList.toggle('visible', n > 0);
    var cnt = document.getElementById('lib-bulk-count');
    if (cnt) cnt.textContent = n + ' selected';
  }
}

async function loadLibSubmissions(status) {
  var panel = document.getElementById('lm-panel');
  if (!panel) return;
  panel.innerHTML = '<div class="ap-loading">Loading submissions…</div>';
  var filter = status || 'pending';
  try {
    var rows = await rpc('admin_get_library_submissions', { p_status: filter, p_limit: 50 });
    buildLibSubmissionsPanel(panel, Array.isArray(rows) ? rows : [], filter);
  } catch (e) {
    panel.innerHTML = '<div class="ap-empty">Error: ' + esc(e.message || e) + '</div>';
  }
}

function buildLibSubmissionsPanel(panel, items, filter) {
  var html = '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px;flex-wrap:wrap;gap:8px">' +
    '<div style="display:flex;gap:8px">' +
    ['pending', 'approved', 'rejected'].map(function (s) {
      return '<button onclick="loadLibSubmissions(\'' + s + '\')" style="font-family:DM Sans,sans-serif;font-size:12px;padding:5px 12px;border-radius:6px;border:1px solid var(--border);background:' +
        (filter === s ? 'var(--accent)' : 'none') + ';color:' + (filter === s ? '#0C0702' : 'var(--text-mid)') + ';cursor:pointer">' +
        s.charAt(0).toUpperCase() + s.slice(1) + '</button>';
    }).join('') +
    '</div><span style="font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-mid)">Approve publishes profile live</span></div>';
  if (!items.length) {
    panel.innerHTML = html + '<div class="ap-empty">No ' + filter + ' submissions.</div>';
    return;
  }
  html += '<div class="ap-table"><table style="width:100%;border-collapse:collapse"><thead><tr>' +
    ['Type', 'Name', 'Submitted', 'Preview', 'Actions'].map(function (h) {
      return '<th style="text-align:left;font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-muted);padding:8px 12px;border-bottom:1px solid var(--border)">' + h + '</th>';
    }).join('') + '</tr></thead><tbody>';
  items.forEach(function (sub) {
    var p = sub.payload || {};
    var name = p.name || sub.slug || '—';
    var when = sub.created_at ? new Date(sub.created_at).toLocaleString('en-GB', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' }) : '—';
    var preview = [p.flavour_profile, p.flavour_wheel, p.what_its_for, p.characteristics].filter(Boolean)[0] || p.chefs_notes || '';
    preview = String(preview).slice(0, 120) + (String(preview).length > 120 ? '…' : '');
    var actions = '<button data-action="lib-sub-view" data-sid="' + esc(sub.id) + '" style="font-size:11px;padding:4px 10px;border-radius:6px;border:1px solid var(--border);background:none;color:var(--accent);cursor:pointer;margin-right:6px">View</button>';
    if (filter === 'pending') {
      actions += '<button data-action="lib-sub-approve" data-sid="' + esc(sub.id) + '" style="font-size:11px;padding:4px 10px;border-radius:6px;border:1px solid #6dc86d;background:rgba(100,200,100,.1);color:#6dc86d;cursor:pointer;margin-right:6px">Approve</button>' +
        '<button data-action="lib-sub-reject" data-sid="' + esc(sub.id) + '" style="font-size:11px;padding:4px 10px;border-radius:6px;border:1px solid var(--border);background:none;color:var(--text-mid);cursor:pointer">Reject</button>';
    } else {
      actions += '<span style="font-size:11px;color:var(--text-mid)">' + esc(sub.status) + '</span>';
    }
    html += '<tr style="border-bottom:1px solid rgba(255,255,255,.04)">' +
      '<td style="padding:8px 12px;font-size:12px;color:var(--text-mid)">' + esc(sub.profile_type || '') + '</td>' +
      '<td style="padding:8px 12px;font-size:13px;color:var(--text-high)">' + esc(name) + '</td>' +
      '<td style="padding:8px 12px;font-size:11px;color:var(--text-mid)">' + esc(when) + '</td>' +
      '<td style="padding:8px 12px;font-size:11px;color:var(--text-mid);max-width:240px">' + esc(preview) + '</td>' +
      '<td style="padding:8px 12px">' + actions + '</td></tr>';
  });
  html += '</tbody></table></div>';
  panel.innerHTML = html;
  panel._libSubItems = items;
  panel.onclick = function (e) {
    var btn = e.target.closest('[data-action]');
    if (!btn) return;
    var sid = btn.dataset.sid;
    if (btn.dataset.action === 'lib-sub-view') openLibSubReview(sid);
    if (btn.dataset.action === 'lib-sub-approve') reviewLibSubmission(sid, 'approve');
    if (btn.dataset.action === 'lib-sub-reject') reviewLibSubmission(sid, 'reject', true);
  };
}

function openLibSubReview(sid) {
  var panel = document.getElementById('lm-panel');
  var sub = (panel && panel._libSubItems || []).find(function (s) { return s.id === sid; });
  if (!sub) return;
  var overlay = document.getElementById('lib-sub-overlay');
  if (!overlay) return;
  var p = sub.payload || {};
  document.getElementById('lib-sub-title').textContent = (p.name || sub.slug || 'Submission') + ' (' + (sub.profile_type || '') + ')';
  document.getElementById('lib-sub-body').textContent = JSON.stringify(p, null, 2);
  document.getElementById('lib-sub-notes').value = '';
  overlay.dataset.sid = sid;
  overlay.classList.add('open');
}

function closeLibSubReview() {
  var overlay = document.getElementById('lib-sub-overlay');
  if (overlay) overlay.classList.remove('open');
}

async function reviewLibSubmission(id, action, fromModal) {
  var notes = '';
  if (action === 'reject') {
    if (fromModal) {
      notes = (document.getElementById('lib-sub-notes') || {}).value || '';
    } else {
      notes = prompt('Rejection notes for submitter (optional):', '');
      if (notes === null) return;
    }
  }
  if (action === 'approve' && !confirm('Approve and publish this profile to the library?')) return;
  try {
    await rpc('admin_review_library_submission', { p_id: id, p_action: action, p_notes: notes || null });
    closeLibSubReview();
    alert(action === 'approve' ? 'Published to library.' : 'Submission rejected.');
    loadLibSubmissions('pending');
  } catch (e) { alert('Error: ' + (e.message || e)); }
}

async function loadLibProfiles(status, imageStatus, resetPage) {
  if (status !== undefined) LIB_CURRENT_STATUS = status || null;
  if (imageStatus !== undefined) LIB_IMAGE_STATUS = imageStatus || null;
  if (resetPage) LIB_OFFSET = 0;
  var panel = document.getElementById('lm-panel');
  if (!panel) return;
  panel.innerHTML = '<div class="ap-loading">Loading…</div>';
  try {
    var stats = await rpc('admin_get_library_image_stats', { p_type: LIB_CURRENT_TYPE }).catch(function () { return null; });
    var data = await rpc('admin_get_library_profiles', {
      p_type: LIB_CURRENT_TYPE,
      p_status: LIB_CURRENT_STATUS,
      p_limit: LIB_PAGE_SIZE,
      p_offset: LIB_OFFSET,
      p_image_status: LIB_IMAGE_STATUS,
      p_search: LIB_SEARCH || null,
      p_sort: LIB_SORT
    });
    var items = Array.isArray(data) ? data : (data && data.items) || [];
    LIB_TOTAL = Array.isArray(data) ? items.length : ((data && data.total) || items.length);
    buildLibPanel(panel, items, stats);
  } catch(e) {
    panel.innerHTML = '<div class="ap-empty">Error loading profiles: ' + esc(e.message || e) +
      '<div style="margin-top:8px;font-size:11px">Run <code>fix-library-management.sql</code> in Supabase if RPCs are missing.</div></div>';
  }
}

function buildLibPanel(panel, items, stats) {
  var info = Object.values(LIB_TYPE_MAP).find(function(t){ return t.type === LIB_CURRENT_TYPE; }) || {};
  var statsHtml = '';
  if (stats && stats.total) {
    statsHtml = '<div style="font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-mid);margin-bottom:12px;display:flex;gap:12px;flex-wrap:wrap">' +
      '<span>Mise coverage: <strong style="color:var(--text-high)">' + (stats.approved || 0) + '</strong> / ' + stats.total + ' approved</span>' +
      '<span style="color:var(--text-muted)">' + (stats.missing || 0) + ' missing · ' + (stats.draft || 0) + ' draft</span></div>';
  }
  var pageStart = LIB_TOTAL ? LIB_OFFSET + 1 : 0;
  var pageEnd = Math.min(LIB_OFFSET + items.length, LIB_TOTAL);
  var pageHtml = '<div style="font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-mid);display:flex;align-items:center;gap:8px">' +
    '<span>' + pageStart + '–' + pageEnd + ' of <strong>' + LIB_TOTAL + '</strong></span>' +
    '<button data-action="lib-page-prev" ' + (LIB_OFFSET <= 0 ? 'disabled' : '') +
    ' style="font-size:11px;padding:3px 10px;border:1px solid var(--border);border-radius:5px;background:none;color:var(--text-mid);cursor:pointer">Prev</button>' +
    '<button data-action="lib-page-next" ' + (LIB_OFFSET + LIB_PAGE_SIZE >= LIB_TOTAL ? 'disabled' : '') +
    ' style="font-size:11px;padding:3px 10px;border:1px solid var(--border);border-radius:5px;background:none;color:var(--text-mid);cursor:pointer">Next</button></div>';

  var html = statsHtml +
    '<div id="lib-bulk-bar" class="bulk-toolbar">' +
    '<span class="bulk-count" id="lib-bulk-count">0 selected</span>' +
    '<button class="bulk-apply-btn" data-action="lib-bulk-publish">Publish</button>' +
    '<button class="bulk-clear-btn" data-action="lib-bulk-unpublish">Unpublish</button>' +
    '<button class="bulk-clear-btn" data-action="lib-bulk-approve-img">Approve mise</button>' +
    '<select class="bulk-field-sel" id="lib-bulk-vis"><option value="public">Visibility: public</option><option value="members">members</option><option value="paid">paid</option></select>' +
    '<button class="bulk-apply-btn" data-action="lib-bulk-vis">Set visibility</button>' +
    '<button class="bulk-del-btn" data-action="lib-bulk-delete">Delete</button>' +
    '<button class="bulk-clear-btn" data-action="lib-bulk-clear">Clear</button></div>' +
    '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;flex-wrap:wrap;gap:8px">' +
    '<div style="display:flex;gap:8px;flex-wrap:wrap;align-items:center">' +
    '<input type="search" id="lib-search-inp" placeholder="Search name, AKA, slug…" value="' + esc(LIB_SEARCH) + '" ' +
    'style="font-family:DM Sans,sans-serif;font-size:12px;padding:6px 12px;border-radius:8px;border:1px solid var(--border);background:var(--input-bg);color:var(--text-high);min-width:200px">' +
    '<select id="lib-sort-sel" style="font-family:DM Sans,sans-serif;font-size:12px;padding:6px 10px;border-radius:8px;border:1px solid var(--border);background:var(--bg);color:var(--text-high)">' +
    '<option value="updated_desc"' + (LIB_SORT === 'updated_desc' ? ' selected' : '') + '>Updated ↓</option>' +
    '<option value="updated_asc"' + (LIB_SORT === 'updated_asc' ? ' selected' : '') + '>Updated ↑</option>' +
    '<option value="name_asc"' + (LIB_SORT === 'name_asc' ? ' selected' : '') + '>Name A–Z</option>' +
    '<option value="name_desc"' + (LIB_SORT === 'name_desc' ? ' selected' : '') + '>Name Z–A</option>' +
    '<option value="status_asc"' + (LIB_SORT === 'status_asc' ? ' selected' : '') + '>Status</option></select>' +
    ['All','draft','published'].map(function(s){
      return '<button data-action="lib-filter-status" data-status="' + (s === 'All' ? '' : s) + '" ' +
        'style="font-family:DM Sans,sans-serif;font-size:12px;padding:5px 12px;border-radius:6px;border:1px solid var(--border);background:' +
        ((s==='All'&&!LIB_CURRENT_STATUS)||(s===LIB_CURRENT_STATUS)?'var(--accent)':'none') +
        ';color:' + ((s==='All'&&!LIB_CURRENT_STATUS)||(s===LIB_CURRENT_STATUS)?'#0C0702':'var(--text-mid)') +
        ';cursor:pointer">' + s + '</button>';
    }).join('') +
    '</div>' +
    '<div style="display:flex;gap:8px;align-items:center;flex-wrap:wrap">' + pageHtml +
    '<button data-action="lib-import-csv" style="font-family:DM Sans,sans-serif;font-size:12px;padding:8px 14px;border-radius:8px;border:1px solid var(--border);background:none;color:var(--text-mid);cursor:pointer">Import CSV</button>' +
    '<button data-action="lib-new" style="font-family:DM Sans,sans-serif;font-size:12px;font-weight:600;padding:8px 16px;border-radius:8px;background:var(--accent);color:#0C0702;border:none;cursor:pointer">+ New Profile</button></div></div>' +
    '<div style="display:flex;gap:6px;flex-wrap:wrap;margin-bottom:16px">' +
    ['All','missing','draft','approved'].map(function(s) {
      var active = (s === 'All' && !LIB_IMAGE_STATUS) || s === LIB_IMAGE_STATUS;
      return '<button data-action="lib-filter-img" data-img="' + (s === 'All' ? '' : s) + '" ' +
        'style="font-family:DM Sans,sans-serif;font-size:11px;padding:4px 10px;border-radius:6px;border:1px solid var(--border);background:' +
        (active ? 'rgba(196,151,59,0.15)' : 'none') + ';color:' + (active ? 'var(--accent)' : 'var(--text-mid)') + ';cursor:pointer">' +
        (s === 'All' ? 'All images' : s) + '</button>';
    }).join('') + '</div>';

  if (!items.length) {
    html += '<div class="ap-empty">No ' + (info.label||'profiles') + ' found.</div>';
    panel.innerHTML = html;
    libBindPanelEvents(panel);
    return;
  }

  var ingCol = LIB_CURRENT_TYPE === 'ingredient'
    ? '<th style="text-align:left;font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-muted);padding:8px 12px;border-bottom:1px solid var(--border)">Governed link</th>'
    : '';
  html += '<div class="ap-table"><table style="width:100%;border-collapse:collapse">' +
    '<thead><tr>' +
    '<th style="padding:8px 6px;border-bottom:1px solid var(--border)"><input type="checkbox" class="ing-check" data-action="lib-check-all" title="Select all on page"></th>' +
    ['Mise','Hero','Name','Mise status','Status','Visibility','Updated'].map(function(h){
      return '<th style="text-align:left;font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-muted);padding:8px 12px;border-bottom:1px solid var(--border)">' + h + '</th>';
    }).join('') + ingCol +
    '<th style="text-align:left;font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-muted);padding:8px 12px;border-bottom:1px solid var(--border)">Actions</th>' +
    '</tr></thead><tbody>';

  items.forEach(function(p) {
    var statusColor = p.status==='published' ? '#6dc86d' : 'var(--text-muted)';
    var imgSt = p.image_status || (p.mise_image_url ? 'draft' : 'missing');
    var imgStColor = imgSt === 'approved' ? '#6dc86d' : (imgSt === 'draft' ? '#c4973b' : 'var(--text-muted)');
    var miseThumb = p.mise_image_url
      ? '<img src="' + esc(p.mise_image_url) + '" style="width:100%;height:100%;object-fit:cover;border-radius:50%">'
      : '<span style="font-size:18px">' + (info.emoji || '·') + '</span>';
    var heroThumb = p.image_url
      ? '<img src="' + esc(p.image_url) + '" style="width:100%;height:100%;object-fit:cover">'
      : '<span style="font-size:14px;opacity:0.5">' + (info.emoji || '') + '</span>';
    var approveBtn = (imgSt === 'draft' && p.mise_image_url)
      ? '<button data-action="lib-mise-approve" data-lid="' + esc(p.id) + '" style="font-size:10px;padding:3px 8px;border:1px solid #6dc86d;background:none;color:#6dc86d;border-radius:5px;cursor:pointer;margin-left:4px">Approve</button>'
      : '';
    var checked = LIB_SELECTED[p.id] ? ' checked' : '';
    var ingCell = '';
    if (LIB_CURRENT_TYPE === 'ingredient') {
      var gid = p.governed_ingredient_id || '';
      ingCell = '<td style="padding:8px 12px;position:relative;min-width:200px">' +
        '<input type="hidden" id="lib-ing-id-' + esc(p.id) + '" value="' + esc(gid) + '">' +
        '<input type="text" id="lib-ing-q-' + esc(p.id) + '" placeholder="Search ingredient…" autocomplete="off" ' +
        'data-action="lib-ing-search" data-lid="' + esc(p.id) + '" ' +
        'style="width:100%;padding:4px 8px;background:var(--bg);border:1px solid var(--border);border-radius:6px;font-size:11px;color:var(--text-high)">' +
        '<div id="lib-ing-ac-' + esc(p.id) + '" style="display:none;position:absolute;z-index:20;background:var(--bg);border:1px solid var(--border);border-radius:8px;max-height:160px;overflow-y:auto;min-width:220px;box-shadow:0 8px 24px rgba(0,0,0,.35)"></div>' +
        '<div id="lib-ing-prev-' + esc(p.id) + '" style="font-size:10px;color:var(--text-muted);margin-top:4px"></div>' +
        '<button data-action="lib-link" data-lid="' + esc(p.id) + '" style="margin-top:4px;font-size:10px;padding:3px 8px;border:1px solid var(--accent);background:none;color:var(--accent);border-radius:5px;cursor:pointer">Link</button></td>';
    }
    html += '<tr style="border-bottom:1px solid rgba(255,255,255,.04)">' +
      '<td style="padding:8px 6px"><input type="checkbox" class="ing-check" data-lib-check data-lid="' + esc(p.id) + '"' + checked + '></td>' +
      '<td style="padding:8px 12px"><div style="width:44px;height:44px;border-radius:50%;background:var(--surface);overflow:hidden;display:flex;align-items:center;justify-content:center;border:1px solid var(--border)">' + miseThumb + '</div></td>' +
      '<td style="padding:8px 12px"><div style="width:40px;height:40px;border-radius:6px;background:var(--surface);overflow:hidden;display:flex;align-items:center;justify-content:center">' + heroThumb + '</div></td>' +
      '<td style="padding:8px 12px;font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-high)">' + esc(p.name) + '</td>' +
      '<td style="padding:8px 12px"><span style="font-size:10px;font-family:DM Sans,sans-serif;color:' + imgStColor + ';text-transform:uppercase;letter-spacing:.06em">' + esc(imgSt) + '</span>' + approveBtn + '</td>' +
      '<td style="padding:8px 12px"><span style="font-size:11px;font-family:DM Sans,sans-serif;color:' + statusColor + ';text-transform:uppercase;letter-spacing:.06em">' + esc(p.status) + '</span></td>' +
      '<td style="padding:8px 12px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-muted)">' + esc(p.visibility||'public') + '</td>' +
      '<td style="padding:8px 12px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-muted)">' + (p.updated_at ? new Date(p.updated_at).toLocaleDateString() : '—') + '</td>' +
      ingCell +
      '<td style="padding:8px 12px;white-space:nowrap">' +
      '<button data-action="lib-edit" data-lid="' + esc(p.id) + '" style="font-family:DM Sans,sans-serif;font-size:11px;background:none;border:none;cursor:pointer;color:var(--accent);margin-right:8px">Edit</button>' +
      '<button data-action="lib-toggle" data-lid="' + esc(p.id) + '" data-lstatus="' + esc(p.status) + '" ' +
      'style="font-family:DM Sans,sans-serif;font-size:11px;background:none;border:none;cursor:pointer;color:var(--text-mid)">' +
      (p.status==='published'?'Unpublish':'Publish') + '</button>' +
      '<button data-action="lib-delete" data-lid="' + esc(p.id) + '" data-lname="' + esc(p.name) + '" ' +
      'style="font-family:DM Sans,sans-serif;font-size:11px;background:none;border:none;cursor:pointer;color:var(--text-danger);margin-left:8px">Delete</button>' +
      '</td></tr>';
  });

  html += '</tbody></table></div>';
  panel.innerHTML = html;
  libBindPanelEvents(panel);
  if (LIB_CURRENT_TYPE === 'ingredient') {
    items.forEach(function(p) { if (p.governed_ingredient_id) libRefreshGovernedPreview(p.id); });
  }
  libUpdateBulkBar();
}

function libBindPanelEvents(panel) {
  panel.onclick = function(e) {
    var btn = e.target.closest('[data-action]');
    if (btn) {
      var action = btn.dataset.action;
      var lid = btn.dataset.lid;
      var lstatus = btn.dataset.lstatus;
      var lname = btn.dataset.lname;
      if (action === 'lib-new') { openLibEditor(null); return; }
      if (action === 'lib-import-csv') { openLibCsvModal(); return; }
      if (action === 'lib-edit' && lid) { openLibEditor(lid); return; }
      if (action === 'lib-toggle' && lid) libTogglePublish(lid, lstatus);
      if (action === 'lib-delete' && lid) libDelete(lid, lname);
      if (action === 'lib-link' && lid) libLinkGoverned(lid);
      if (action === 'lib-mise-approve' && lid) {
        rpc('admin_set_library_image_status', { p_type: LIB_CURRENT_TYPE, p_id: lid, p_status: 'approved' })
          .then(function() { loadLibProfiles(undefined, undefined, false); })
          .catch(function(err) { alert(err.message); });
      }
      if (action === 'lib-filter-status') {
        LIB_CURRENT_STATUS = btn.dataset.status || null;
        loadLibProfiles(undefined, undefined, true);
      }
      if (action === 'lib-filter-img') {
        LIB_IMAGE_STATUS = btn.dataset.img || null;
        loadLibProfiles(undefined, undefined, true);
      }
      if (action === 'lib-page-prev') {
        LIB_OFFSET = Math.max(0, LIB_OFFSET - LIB_PAGE_SIZE);
        loadLibProfiles();
      }
      if (action === 'lib-page-next') {
        LIB_OFFSET += LIB_PAGE_SIZE;
        loadLibProfiles();
      }
      if (action === 'lib-check-all') libToggleSelectAll(btn.checked);
      if (action === 'lib-bulk-publish') libBulkAction('publish');
      if (action === 'lib-bulk-unpublish') libBulkAction('unpublish');
      if (action === 'lib-bulk-approve-img') libBulkAction('approve_image');
      if (action === 'lib-bulk-vis') {
        var vis = (document.getElementById('lib-bulk-vis') || {}).value || 'public';
        libBulkAction('set_visibility', vis);
      }
      if (action === 'lib-bulk-delete') libBulkAction('delete');
      if (action === 'lib-bulk-clear') { LIB_SELECTED = {}; libToggleSelectAll(false); }
    }
    var cb = e.target.closest('[data-lib-check]');
    if (cb && cb.dataset.lid) {
      LIB_SELECTED[cb.dataset.lid] = cb.checked;
      libUpdateBulkBar();
    }
  };
  var searchInp = document.getElementById('lib-search-inp');
  if (searchInp) {
    searchInp.onkeydown = function(ev) {
      if (ev.key === 'Enter') {
        LIB_SEARCH = searchInp.value.trim();
        loadLibProfiles(undefined, undefined, true);
      }
    };
    searchInp.onchange = function() {
      LIB_SEARCH = searchInp.value.trim();
      loadLibProfiles(undefined, undefined, true);
    };
  }
  var sortSel = document.getElementById('lib-sort-sel');
  if (sortSel) {
    sortSel.onchange = function() {
      LIB_SORT = sortSel.value;
      loadLibProfiles(undefined, undefined, true);
    };
  }
  panel.oninput = function(e) {
    var inp = e.target.closest('[data-action="lib-ing-search"]');
    if (!inp) return;
    clearTimeout(_libIngSearchTimer);
    _libIngSearchTimer = setTimeout(function() { libIngAutocomplete(inp.dataset.lid, inp.value); }, 280);
  };
}

async function libIngAutocomplete(profileId, query) {
  var ac = document.getElementById('lib-ing-ac-' + profileId);
  if (!ac) return;
  if (!query || query.length < 2) { ac.style.display = 'none'; return; }
  try {
    var rows = await rpc('admin_get_ingredients', { p_search: query, p_limit: 8, p_offset: 0 });
    var list = Array.isArray(rows) ? rows : [];
    if (!list.length) { ac.style.display = 'none'; return; }
    ac.innerHTML = list.map(function(r) {
      var id = r.ID || r.id;
      var name = r['Ingredient Name'] || r.ingredient_name || '';
      return '<div data-ing-pick="' + id + '" data-ing-name="' + esc(name) + '" data-lid="' + esc(profileId) + '" ' +
        'style="padding:8px 12px;font-size:12px;cursor:pointer;border-bottom:1px solid var(--border)">' +
        esc(name) + ' <span style="color:var(--text-muted);font-size:10px">#' + id + '</span></div>';
    }).join('');
    ac.style.display = 'block';
    ac.onclick = function(ev) {
      var pick = ev.target.closest('[data-ing-pick]');
      if (!pick) return;
      var hid = document.getElementById('lib-ing-id-' + pick.dataset.lid);
      var q = document.getElementById('lib-ing-q-' + pick.dataset.lid);
      if (hid) hid.value = pick.dataset.ingPick;
      if (q) q.value = pick.dataset.ingName + ' (#' + pick.dataset.ingPick + ')';
      ac.style.display = 'none';
    };
  } catch (_) { ac.style.display = 'none'; }
}

async function libRefreshGovernedPreview(profileId) {
  var el = document.getElementById('lib-ing-prev-' + profileId);
  if (!el) return;
  try {
    var prev = await rpc('admin_get_library_governed_preview', { p_profile_id: profileId });
    if (!prev || !prev.linked) { el.textContent = 'No governed link'; return; }
    if (!prev.valid) { el.textContent = 'Invalid ID #' + (prev.ingredient_id || '?'); el.style.color = '#dc5050'; return; }
    el.style.color = 'var(--text-muted)';
    el.textContent = '📚 ' + (prev.recipe_count || 0) + ' recipes match "' + (prev.ingredient_name || '') + '"';
  } catch (_) {}
}

async function libLinkGoverned(profileId) {
  var hid = document.getElementById('lib-ing-id-' + profileId);
  var ingId = hid ? parseInt(hid.value, 10) : 0;
  if (!ingId) { alert('Search and select a governed ingredient first'); return; }
  try {
    var res = await rpc('admin_link_library_ingredient', { p_profile_id: profileId, p_ingredient_id: ingId });
    alert('Linked to ' + (res.ingredient_name || 'ingredient') + ' (#' + ingId + ')');
    libRefreshGovernedPreview(profileId);
    loadLibProfiles(undefined, undefined, false);
  } catch (err) { alert(err.message || err); }
}

async function libBulkAction(action, value) {
  var ids = libSelectedIds();
  if (!ids.length) { alert('Select profiles first'); return; }
  if (action === 'delete' && !confirm('Delete ' + ids.length + ' profile(s)? This cannot be undone.')) return;
  try {
    var res = await rpc('admin_bulk_library_profiles', {
      p_type: LIB_CURRENT_TYPE,
      p_ids: ids,
      p_action: action,
      p_value: value || null
    });
    LIB_SELECTED = {};
    alert('Updated ' + (res.updated || 0) + ' profile(s).');
    loadLibProfiles(undefined, undefined, false);
  } catch (e) { alert(e.message || e); }
}

async function libTogglePublish(id, currentStatus) {
  var newStatus = currentStatus === 'published' ? 'draft' : 'published';
  try {
    await rpc('admin_publish_library_profile', { p_type: LIB_CURRENT_TYPE, p_id: id, p_status: newStatus });
    loadLibProfiles(undefined, undefined, false);
  } catch(e) { alert('Error: ' + (e.message||e)); }
}

async function libDelete(id, name) {
  if (!confirm('Delete "' + name + '"? This cannot be undone.')) return;
  try {
    await rpc('admin_delete_library_profile', { p_type: LIB_CURRENT_TYPE, p_id: id });
    loadLibProfiles(undefined, undefined, false);
  } catch(e) { alert('Error: ' + (e.message||e)); }
}

function closeLibEditor() {
  var overlay = document.getElementById('lib-ed-overlay');
  if (overlay) overlay.classList.remove('open');
  _libEdProfileId = null;
  _libEdSlug = null;
}

function libEdVal(id) {
  var el = document.getElementById(id);
  if (!el) return null;
  if (el.type === 'checkbox') return el.checked;
  return String(el.value || '').trim();
}

function libEdSet(id, v) {
  var el = document.getElementById(id);
  if (!el || v === null || v === undefined) return;
  if (el.type === 'checkbox') el.checked = !!v;
  else el.value = v;
}

function renderLibEditorTypeFields(type) {
  var wrap = document.getElementById('lib-ed-type-fields');
  if (!wrap || !window.TCJ_LIB_TYPE_FIELDS) return;
  wrap.innerHTML = '';
  var fields = TCJ_LIB_TYPE_FIELDS[type] || [];
  fields.forEach(function(f) {
    var row = document.createElement('div');
    row.className = 'ing-field' + (f.type === 'textarea' ? ' full' : '');
    var lbl = document.createElement('label');
    lbl.textContent = f.label;
    row.appendChild(lbl);
    if (f.type === 'checkbox') {
      var cb = document.createElement('input');
      cb.type = 'checkbox'; cb.id = 'lib-ed-' + f.id.replace('f-', '');
      row.appendChild(cb);
    } else if (f.type === 'select') {
      var sel = document.createElement('select');
      sel.id = 'lib-ed-' + f.id.replace('f-', '');
      (f.opts || []).forEach(function(o) {
        var opt = document.createElement('option');
        opt.value = o; opt.textContent = o;
        sel.appendChild(opt);
      });
      row.appendChild(sel);
    } else if (f.type === 'textarea') {
      var ta = document.createElement('textarea');
      ta.id = 'lib-ed-' + f.id.replace('f-', '');
      row.appendChild(ta);
    } else {
      var inp = document.createElement('input');
      inp.type = 'text'; inp.id = 'lib-ed-' + f.id.replace('f-', '');
      if (f.ph) inp.placeholder = f.ph;
      row.appendChild(inp);
    }
    wrap.appendChild(row);
  });
}

function libEdGetVal(formId) {
  return function(fid) {
    var elId = 'lib-ed-' + fid.replace('f-', '');
    var el = document.getElementById(elId);
    if (!el) return null;
    if (el.type === 'checkbox') return el.checked;
    return String(el.value || '').trim();
  };
}

function libEdMapFormIds() {
  var map = {
    'f-name': 'name', 'f-aka': 'aka', 'f-local': 'local', 'f-img-url': 'img-url',
    'f-mise-url': 'mise-url', 'f-image-status': 'image-status', 'f-chefs': 'chefs',
    'f-brand': 'brand', 'f-dyk': 'dyk', 'f-status': 'status', 'f-visibility': 'visibility',
    'f-governed-id': 'governed-id'
  };
  return function(fid) {
    var suffix = map[fid];
    if (!suffix) suffix = fid.replace('f-', '');
    var el = document.getElementById('lib-ed-' + suffix);
    if (!el) return null;
    if (el.type === 'checkbox') return el.checked;
    return String(el.value || '').trim();
  };
}

async function openLibEditor(id) {
  var overlay = document.getElementById('lib-ed-overlay');
  if (!overlay) return;
  _libEdProfileId = id;
  _libEdSlug = null;
  document.getElementById('lib-ed-title').textContent = id ? 'Edit profile' : 'New profile';
  renderLibEditorTypeFields(LIB_CURRENT_TYPE);
  ['name','aka','local','img-url','mise-url','chefs','brand','dyk','governed-id'].forEach(function(k) {
    var el = document.getElementById('lib-ed-' + k);
    if (el) el.value = '';
  });
  var st = document.getElementById('lib-ed-status');
  var vis = document.getElementById('lib-ed-visibility');
  var imgSt = document.getElementById('lib-ed-image-status');
  if (st) st.value = 'draft';
  if (vis) vis.value = 'public';
  if (imgSt) imgSt.value = 'missing';
  var govRow = document.getElementById('lib-ed-governed-row');
  if (govRow) govRow.style.display = LIB_CURRENT_TYPE === 'ingredient' ? 'block' : 'none';
  if (id) {
    try {
      var profile = await rpc('admin_get_library_profile', { p_type: LIB_CURRENT_TYPE, p_id: id });
      _libEdSlug = profile.slug;
      tcjLibFillForm(profile, function(fid, v) {
        var suffix = fid.replace('f-', '');
        if (fid === 'f-governed-id') suffix = 'governed-id';
        libEdSet('lib-ed-' + suffix, v);
      }, LIB_CURRENT_TYPE);
      if (profile.internal_notes) libEdSet('lib-ed-internal-notes', profile.internal_notes);
    } catch (e) {
      alert('Could not load profile: ' + (e.message || e));
      return;
    }
  }
  overlay.classList.add('open');
}

async function saveLibEditor() {
  var getVal = libEdMapFormIds();
  var name = getVal('f-name');
  if (!name) { alert('Name is required'); return; }
  if (!getVal('f-img-url')) { alert('Hero image URL is required'); return; }
  var payload = tcjLibBuildPayload(LIB_CURRENT_TYPE, getVal, { slug: _libEdSlug || undefined });
  var notesEl = document.getElementById('lib-ed-internal-notes');
  if (notesEl && notesEl.value.trim()) payload.internal_notes = notesEl.value.trim();
  try {
    var wasNew = !_libEdProfileId;
    await rpc('admin_upsert_library_profile', {
      p_type: LIB_CURRENT_TYPE,
      p_id: _libEdProfileId || null,
      p_payload: payload
    });
    closeLibEditor();
    loadLibProfiles(undefined, undefined, wasNew);
  } catch (e) { alert('Save error: ' + (e.message || e)); }
}

var _libCsvData = null;

function openLibCsvModal() {
  _libCsvData = null;
  var modal = document.getElementById('lib-csv-modal');
  if (!modal) return;
  document.getElementById('lib-csv-type-label').textContent = LIB_CURRENT_TYPE;
  document.getElementById('lib-csv-preview-section').style.display = 'none';
  document.getElementById('lib-csv-error').style.display = 'none';
  document.getElementById('lib-csv-import-btn').disabled = true;
  document.getElementById('lib-csv-status').textContent = '';
  document.getElementById('lib-csv-file-input').value = '';
  modal.classList.add('open');
}

function closeLibCsvModal() {
  var modal = document.getElementById('lib-csv-modal');
  if (modal) modal.classList.remove('open');
  _libCsvData = null;
}

function handleLibCsvFile(file) {
  if (!file || !file.name.endsWith('.csv')) {
    document.getElementById('lib-csv-error').textContent = 'Please upload a .csv file.';
    document.getElementById('lib-csv-error').style.display = 'block';
    return;
  }
  if (typeof Papa === 'undefined') {
    alert('CSV parser not loaded');
    return;
  }
  document.getElementById('lib-csv-error').style.display = 'none';
  Papa.parse(file, {
    header: true, skipEmptyLines: true,
    complete: function (results) {
      if (results.errors.length) {
        document.getElementById('lib-csv-error').textContent = results.errors[0].message;
        document.getElementById('lib-csv-error').style.display = 'block';
        return;
      }
      if (!results.data.length) {
        document.getElementById('lib-csv-error').textContent = 'No data rows found.';
        document.getElementById('lib-csv-error').style.display = 'block';
        return;
      }
      _libCsvData = results.data.map(function (row) {
        return tcjLibCsvRowToPayload(LIB_CURRENT_TYPE, row);
      }).filter(function (p) { return p.name; });
      var prev = document.getElementById('lib-csv-preview-table');
      var cols = Object.keys(results.data[0] || {}).slice(0, 8);
      prev.innerHTML = '<thead><tr>' + cols.map(function (c) {
        return '<th style="padding:6px 10px;text-align:left;font-size:11px;border-bottom:1px solid var(--border)">' + esc(c) + '</th>';
      }).join('') + '</tr></thead><tbody>' +
        results.data.slice(0, 5).map(function (row) {
          return '<tr>' + cols.map(function (c) {
            return '<td style="padding:6px 10px;font-size:11px;border-bottom:1px solid rgba(255,255,255,.04)">' + esc(String(row[c] || '').slice(0, 40)) + '</td>';
          }).join('') + '</tr>';
        }).join('') + '</tbody>';
      document.getElementById('lib-csv-row-count').textContent = _libCsvData.length + ' profiles ready';
      document.getElementById('lib-csv-preview-section').style.display = 'block';
      document.getElementById('lib-csv-import-btn').disabled = !_libCsvData.length;
    }
  });
}

async function importLibCsv() {
  if (!_libCsvData || !_libCsvData.length) return;
  var btn = document.getElementById('lib-csv-import-btn');
  var status = document.getElementById('lib-csv-status');
  btn.disabled = true;
  btn.textContent = 'Importing…';
  try {
    var result = await rpc('admin_bulk_upsert_library_profiles', {
      p_type: LIB_CURRENT_TYPE,
      p_rows: _libCsvData
    });
    status.style.color = '#6dc86d';
    status.textContent = 'Done — ' + (result.inserted || 0) + ' inserted, ' + (result.updated || 0) + ' updated.';
    setTimeout(function () {
      closeLibCsvModal();
      loadLibProfiles(undefined, undefined, true);
    }, 1500);
  } catch (e) {
    status.style.color = '#dc5050';
    status.textContent = e.message || String(e);
    btn.disabled = false;
    btn.textContent = 'Import';
  }
}

async function loadLibCoverage() {
  var panel = document.getElementById('lm-panel');
  if (!panel) return;
  panel.innerHTML = '<div class="ap-loading">Loading coverage…</div>';
  try {
    var types = ['ingredient', 'spice', 'tool', 'cut', 'preservation'];
    var results = await Promise.all(types.map(function (t) {
      return rpc('admin_get_library_coverage', { p_type: t, p_limit: 30 }).then(function (d) {
        return { type: t, data: d };
      });
    }));
    buildLibCoveragePanel(panel, results);
  } catch (e) {
    panel.innerHTML = '<div class="ap-empty">Coverage unavailable: ' + esc(e.message || e) +
      '<div style="margin-top:8px;font-size:11px">Run <code>fix-library-unified.sql</code> in Supabase.</div></div>';
  }
}

function buildLibCoveragePanel(panel, results) {
  var typeLabels = { ingredient: '🌿 Ingredients', spice: '🌶 Spices', tool: '🔪 Tools', cut: '🥩 Cuts', preservation: '🫙 Preservation' };
  var html = '<div style="font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);margin-bottom:16px;line-height:1.55">' +
    'Prioritised worklist: published profiles matching <strong>zero</strong> approved recipes, and governed ingredients used in recipes with no library link.</div>';
  results.forEach(function (r) {
    var s = r.data.summary || {};
    var zero = r.data.zero_recipe_profiles || [];
    var gaps = r.data.ingredient_gaps || [];
    html += '<div style="background:var(--surface);border:1px solid var(--border);border-radius:12px;padding:16px 20px;margin-bottom:16px">' +
      '<div style="font-family:Cormorant Garamond,serif;font-size:1.15rem;font-weight:700;color:var(--text-high);margin-bottom:10px">' + (typeLabels[r.type] || r.type) + '</div>' +
      '<div style="display:flex;gap:16px;flex-wrap:wrap;font-size:11px;color:var(--text-mid);margin-bottom:12px">' +
      '<span>Published: <strong style="color:var(--text-high)">' + (s.published || 0) + '</strong></span>' +
      '<span>With recipes: <strong style="color:#6dc86d">' + (s.with_recipes || 0) + '</strong></span>' +
      '<span>Zero matches: <strong style="color:#c4973b">' + (s.zero_recipes || 0) + '</strong></span>';
    if (r.type === 'ingredient') {
      html += '<span>Ingredient gaps: <strong style="color:#dc5050">' + (s.ingredient_gaps || 0) + '</strong></span>';
    }
    html += '</div>';
    if (zero.length) {
      html += '<div style="font-size:10px;font-weight:700;text-transform:uppercase;color:#c4973b;margin-bottom:6px">Dead published profiles (no recipe matches)</div>' +
        '<ul style="margin:0 0 12px;padding-left:18px;font-size:12px;color:var(--text-high)">' +
        zero.map(function (p) {
          return '<li style="margin-bottom:4px">' + esc(p.name) +
            ' <button data-action="lib-cov-edit" data-lid="' + esc(p.id) + '" data-ltype="' + esc(r.type) + '" ' +
            'style="font-size:10px;padding:2px 8px;border:1px solid var(--accent);background:none;color:var(--accent);border-radius:5px;cursor:pointer;margin-left:6px">Edit</button></li>';
        }).join('') + '</ul>';
    }
    if (r.type === 'ingredient' && gaps.length) {
      html += '<div style="font-size:10px;font-weight:700;text-transform:uppercase;color:#dc5050;margin-bottom:6px">Recipe ingredients missing a library profile</div>' +
        '<ul style="margin:0;padding-left:18px;font-size:12px;color:var(--text-high)">' +
        gaps.map(function (g) {
          return '<li style="margin-bottom:4px">' + esc(g.ingredient_name) + ' <span style="color:var(--text-muted);font-size:10px">#' + g.ingredient_id + ' · ' + g.recipe_count + ' recipes</span>' +
            ' <button data-action="lib-cov-new" data-prefill="' + esc(g.ingredient_name) + '" data-ingid="' + g.ingredient_id + '" ' +
            'style="font-size:10px;padding:2px 8px;border:1px solid var(--border);background:none;color:var(--text-mid);border-radius:5px;cursor:pointer;margin-left:6px">+ Draft</button></li>';
        }).join('') + '</ul>';
    }
    if (!zero.length && !(r.type === 'ingredient' && gaps.length)) {
      html += '<div style="font-size:11px;color:var(--text-muted)">No gaps in this slice.</div>';
    }
    html += '</div>';
  });
  panel.innerHTML = html;
  panel.onclick = function (e) {
    var btn = e.target.closest('[data-action]');
    if (!btn) return;
    if (btn.dataset.action === 'lib-cov-edit') {
      LIB_CURRENT_TYPE = btn.dataset.ltype;
      switchLibTab(Object.keys(LIB_TYPE_MAP).find(function (k) { return LIB_TYPE_MAP[k].type === LIB_CURRENT_TYPE; }) || 'lm-ingredients');
      openLibEditor(btn.dataset.lid);
    }
    if (btn.dataset.action === 'lib-cov-new') {
      LIB_CURRENT_TYPE = 'ingredient';
      switchLibTab('lm-ingredients');
      openLibEditor(null);
      setTimeout(function () {
        libEdSet('lib-ed-name', btn.dataset.prefill || '');
        libEdSet('lib-ed-governed-id', btn.dataset.ingid || '');
      }, 300);
    }
  };
}
