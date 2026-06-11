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

// Library Management — see lib/lm-interface.js
