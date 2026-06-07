// The Culinary Journal — Dashboard Module
// This file is loaded by dashboard.html
// Requires: supabase-config.js to be loaded first

var TCJ_REFUND_BANNER = 'No refunds on completed purchases. Core features stay free. Billing error or access fault? Email us within 7 days.';
var TCJ_REFUND_POLICY = 'Most of The Culinary Journal is free to use with a free account. If you choose a paid extra (such as a theme, optional plan, or subscription), that purchase is final once completed — we do not offer change-of-mind refunds.\n\nExceptions: If a payment was charged in error, duplicated, or you could not access what you paid for due to a technical fault on our side, contact us within 7 days at miseenplacekitchen.official@gmail.com and we will review it fairly.\n\nSubscriptions: You may cancel anytime; access continues until the end of the paid period. Cancelling does not refund the current period.\n\nBy completing a purchase you agree to this policy. See subscription-terms.html for full subscription terms.';
var TCJ_BILLING_EMAIL_KEYS = { purchase_confirmation: 1, subscription_confirmation: 1 };

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
      var tr = document.createElement('tr'); tr.style.borderBottom = '1px solid rgba(255,255,255,0.04)';
      var vis = '<select id="smv-'+esc(p.path||'')+'" style="padding:5px 8px;background:var(--bg);border:1px solid var(--border);border-radius:6px;font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-high)">'+
        [{v:'public',l:'Public — Everyone'},{v:'registered',l:'Registered Members'},{v:'paid',l:'Paid Members Only'},{v:'hidden',l:'Hidden'}].map(function(o){return '<option value="'+o.v+'"'+(p.visibility===o.v?' selected':'')+'>'+o.l+'</option>';}).join('')+'</select>';
      var minTier = p.min_tier || 'free';
      var tierSel = '<select id="smt-'+esc(p.path||'')+'" style="padding:5px 8px;background:var(--bg);border:1px solid var(--border);border-radius:6px;font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-high)">'+
        _SM_TIER_OPTS.map(function(o){return '<option value="'+o.v+'"'+(minTier===o.v?' selected':'')+'>'+o.l+'</option>';}).join('')+'</select>';
      tr.innerHTML = '<td class="ap-td" style="font-size:13px;font-weight:500;color:var(--text-high)">'+esc(p.name||'')+'</td>'+
        '<td class="ap-td" style="font-size:11px;color:var(--text-mid)">'+esc(p.path||'')+'</td>'+
        '<td class="ap-td">'+vis+'</td>'+
        '<td class="ap-td">'+tierSel+'</td>'+
        '<td class="ap-td" style="text-align:center"><input type="checkbox" id="smcs-'+esc(p.path||'')+'"'+(p.coming_soon?' checked':'')+' style="width:15px;height:15px;accent-color:var(--accent)"></td>'+
        '<td class="ap-td"></td>';
      var seoWrap = document.createElement('tr');
      seoWrap.style.cssText = 'border-bottom:1px solid rgba(255,255,255,0.04)';
      var seoCel = document.createElement('td');
      seoCel.setAttribute('colspan','6');
      seoCel.style.cssText = 'padding:0 8px 10px;display:none';
      seoCel.id = 'seo-row-' + esc(p.path||'');
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
      seoGrid.appendChild(seoMakeLabeledInput('Meta Title', 'seo-t-'+(p.path||''), S['seo_'+(p.path||'')+'_title']||''));
      seoGrid.appendChild(seoMakeLabeledInput('Meta Description', 'seo-d-'+(p.path||''), S['seo_'+(p.path||'')+'_desc']||''));
      seoCel.appendChild(seoGrid);
      seoWrap.appendChild(seoCel);
      tbody.appendChild(seoWrap);
      var btn = document.createElement('button'); btn.textContent = 'Save';
      btn.style.cssText = "padding:5px 12px;background:var(--accent);border:none;border-radius:6px;color:#fff;font-family:'DM Sans',sans-serif;font-size:11px;cursor:pointer";
      btn.addEventListener('click', (function(path, b) { return async function() {
        b.disabled=true; b.textContent='\u2026';
        try {
          var body = {
            visibility: document.getElementById('smv-'+path).value,
            coming_soon: document.getElementById('smcs-'+path).checked,
            min_tier: document.getElementById('smt-'+path).value
          };
          var r=await apiFetch(SUPABASE_URL+'/rest/v1/site_pages?path=eq.'+encodeURIComponent(path),{method:'PATCH',headers:{'Content-Type':'application/json','Prefer':'return=representation'},body:JSON.stringify(body)});
          var rBody = await r.json(); if(!Array.isArray(rBody)||!rBody.length) throw new Error('Row not found — no changes saved');
          b.textContent='\u2713 Saved'; setTimeout(function(){var c=document.getElementById('upanel-sm-pages');if(c){c.dataset.built='';buildSMPages(c);}},1500);
        } catch(e){b.textContent='Save';b.disabled=false;alert('Save failed: '+e.message);}
      };})(p.path,btn));
      tr.lastElementChild.appendChild(btn); tbody.appendChild(tr);
    });
    tbl.appendChild(tbody); wrap.appendChild(tbl); container.appendChild(wrap);
    container.dataset.built = '1';
  } catch(e) {
    container.dataset.built = '';
    container.innerHTML = '<div style="padding:16px;background:rgba(220,80,80,0.1);border:1px solid rgba(220,80,80,0.4);border-radius:10px;font-family:DM Sans,sans-serif;font-size:13px;color:#dc5050"><strong>Error:</strong> '+String(e.message).replace(/</g,'&lt;')+'</div>';
  }
}

async function buildSMAnnouncements(container) {
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);padding:8px 0">Loading\u2026</div>';
  try {
    var res = await apiFetch(SUPABASE_URL+'/rest/v1/site_announcements?order=created_at.desc');
    if (!res||!res.ok) throw new Error(res?res.status+': '+await res.text():'Session expired');
    var anns = await res.json(); if(!Array.isArray(anns)) anns=[];
    container.innerHTML='';
    var form=document.createElement('div');form.style.cssText='background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:12px;padding:16px 20px;margin-bottom:16px';
    form.innerHTML='<div style="font-family:Cormorant Garamond,serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:12px">New Announcement</div>'+
      '<div style="display:grid;grid-template-columns:1fr 100px;gap:10px;margin-bottom:10px">'+
      '<input id="sm-ann-new-text" placeholder="Announcement text\u2026" style="padding:7px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high)">'+
      '<select id="sm-ann-new-type" style="padding:7px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high)"><option value="info">Info</option><option value="success">Success</option><option value="warning">Warning</option><option value="error">Error</option></select></div>';
    var addBtn=document.createElement('button');addBtn.className='ing-add-btn';addBtn.textContent='Add Announcement';
    addBtn.addEventListener('click',async function(){
      var text=(document.getElementById('sm-ann-new-text').value||'').trim();if(!text)return;addBtn.disabled=true;
      try{var r=await apiFetch(SUPABASE_URL+'/rest/v1/site_announcements',{method:'POST',headers:{'Content-Type':'application/json','Prefer':'return=representation'},body:JSON.stringify({text:text,type:document.getElementById('sm-ann-new-type').value,active:true})});
      if(!r||!r.ok)throw new Error(r?r.status+': '+await r.text():'Session expired');
      var c=document.getElementById('upanel-sm-ann');if(c){c.dataset.built='';buildSMAnnouncements(c);}}
      catch(e){addBtn.disabled=false;alert('Add failed: '+e.message);}
    });
    form.appendChild(addBtn);container.appendChild(form);
    if(!anns.length){var p=document.createElement('p');p.style.cssText='font-size:13px;color:var(--text-mid)';p.textContent='No announcements yet.';container.appendChild(p);}
    else {
      var TC={info:'#5B8FD4',success:'#4caf76',warning:'#d4a017',error:'#dc5050'};
      anns.forEach(function(a){
        var card=document.createElement('div');card.style.cssText='background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:10px;padding:12px 16px;margin-bottom:8px;display:flex;gap:10px;justify-content:space-between';
        var left=document.createElement('div');left.style.flex='1';
        var annType = document.createElement('span'); annType.style.cssText = 'font-size:10px;font-weight:700;padding:2px 7px;border-radius:5px;background:rgba(0,0,0,0.3);color:'+(TC[a.type]||'var(--text-mid)'); annType.textContent = (a.type||'').toUpperCase(); var annText = document.createElement('div'); annText.style.cssText = 'font-size:13px;color:var(--text-high);margin-top:6px'; annText.textContent = a.text||''; left.appendChild(annType); left.appendChild(annText);
        var dBtn=document.createElement('button');dBtn.style.cssText="padding:4px 10px;background:none;border:1px solid #dc5050;border-radius:6px;color:#dc5050;font-size:11px;cursor:pointer;flex-shrink:0";dBtn.textContent='Delete';
        dBtn.addEventListener('click',async function(){if(!confirm('Delete?'))return;
          try{var r=await apiFetch(SUPABASE_URL+'/rest/v1/site_announcements?id=eq.'+a.id,{method:'DELETE'});
          if(!r||!r.ok)throw new Error(r?r.status:'Session expired');
          var c=document.getElementById('upanel-sm-ann');if(c){c.dataset.built='';buildSMAnnouncements(c);}}
          catch(e){alert('Delete failed: '+e.message);}});
        card.appendChild(left);card.appendChild(dBtn);container.appendChild(card);
      });
    }
    container.dataset.built='1';
  } catch(e){container.dataset.built='';container.innerHTML='<div style="padding:16px;background:rgba(220,80,80,0.1);border:1px solid rgba(220,80,80,0.4);border-radius:10px;font-family:DM Sans,sans-serif;font-size:13px;color:#dc5050"><strong>Error:</strong> '+String(e.message).replace(/</g,'&lt;')+'</div>';}
}

async function buildSMEmail(container) {
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);padding:8px 0">Loading\u2026</div>';
  try {
    var queueBox = document.createElement('div');
    queueBox.style.cssText = 'background:rgba(91,143,212,0.08);border:1px solid rgba(91,143,212,0.25);border-radius:12px;padding:16px 20px;margin-bottom:20px';
    try {
      var pending = await rpc('admin_get_email_queue', { p_status: 'pending', p_limit: 5 }) || [];
      var failed  = await rpc('admin_get_email_queue', { p_status: 'failed', p_limit: 5 }) || [];
      var sent    = await rpc('admin_get_email_queue', { p_status: 'sent', p_limit: 3 }) || [];
      queueBox.innerHTML = '<div style="font-family:Cormorant Garamond,serif;font-size:1.1rem;font-weight:700;color:#5B8FD4;margin-bottom:8px">Email Queue</div>' +
        '<div style="font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);line-height:1.6;margin-bottom:10px">' +
        '<strong>' + pending.length + '</strong> pending (showing up to 5) · <strong>' + failed.length + '</strong> failed · <strong>' + sent.length + '</strong> recent sent</div>' +
        '<div style="font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-mid);margin-bottom:12px">Sending uses the Supabase Edge Function <code>send-queued-emails</code> + Resend (see send-queued-emails.js). Schedule via pg_cron every 5 minutes.</div>';
      if (pending.length) {
        var ul = document.createElement('ul');
        ul.style.cssText = 'margin:0 0 12px;padding-left:18px;font-size:11px;color:var(--text-high)';
        pending.forEach(function(q) {
          var li = document.createElement('li');
          li.textContent = (q.template_key || '?') + ' → ' + (q.to_email || '');
          ul.appendChild(li);
        });
        queueBox.appendChild(ul);
      }
      var retryBtn = document.createElement('button');
      retryBtn.className = 'ing-add-btn';
      retryBtn.textContent = 'Retry failed emails';
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
      queueBox.innerHTML = '<div style="font-size:12px;color:var(--text-mid)">Email queue unavailable — run fix-phase6-batch.sql</div>';
    }

    var res = await apiFetch(SUPABASE_URL+'/rest/v1/email_templates?order=key');
    if (!res||!res.ok) throw new Error(res?res.status+': '+await res.text():'Session expired');
    var templates = await res.json();
    if(!Array.isArray(templates)||!templates.length){container.dataset.built='';container.innerHTML='<div style="padding:16px;font-size:13px;color:var(--text-mid)">No email templates. Run seed_settings.sql in Supabase.</div>';return;}
    container.innerHTML='';
    container.appendChild(queueBox);
    var tplNote = document.createElement('p');
    tplNote.style.cssText = 'font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);margin-bottom:16px;line-height:1.55';
    tplNote.innerHTML = 'Placeholders: <code>{{name}}</code>, <code>{{recipe_name}}</code>, <code>{{product_name}}</code>, <code>{{tier_label}}</code>, <code>{{amount_line}}</code>. Billing templates include refund wording — keep them aligned with <strong>Settings → Billing &amp; Refund Policy</strong>.';
    container.appendChild(tplNote);

    function appendEmailTemplateBlock(t) {
      var sec=document.createElement('div');sec.style.cssText='background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:12px;padding:16px 20px;margin-bottom:14px';
      var secTitle = document.createElement('div');
      secTitle.style.cssText = 'font-family:Cormorant Garamond,serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:12px';
      secTitle.textContent = t.name || t.key || '';
      sec.appendChild(secTitle);
      if (TCJ_BILLING_EMAIL_KEYS[t.key]) {
        var billHint = document.createElement('p');
        billHint.style.cssText = 'font-size:11px;color:var(--text-mid);margin:-6px 0 10px;line-height:1.5';
        billHint.textContent = 'Sent after a purchase or tier upgrade. Refund section should match Site Management → Settings.';
        sec.appendChild(billHint);
      }
      var subWrap = document.createElement('div'); subWrap.style.marginBottom = '8px';
      var subLbl = document.createElement('label'); subLbl.style.cssText = 'display:block;font-size:10px;color:var(--text-mid);margin-bottom:3px'; subLbl.textContent = 'Subject';
      var subInp = document.createElement('input'); subInp.id = 'em-s-'+t.key; subInp.value = t.subject||'';
      subInp.style.cssText = 'width:100%;box-sizing:border-box;padding:7px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-size:12px;color:var(--text-high)';
      subWrap.appendChild(subLbl); subWrap.appendChild(subInp); sec.appendChild(subWrap);
      var bodyWrap = document.createElement('div'); bodyWrap.style.marginBottom = '10px';
      var bodyLbl = document.createElement('label'); bodyLbl.style.cssText = 'display:block;font-size:10px;color:var(--text-mid);margin-bottom:3px'; bodyLbl.textContent = 'Body';
      var ta = document.createElement('textarea'); ta.id = 'em-b-'+t.key; ta.rows = TCJ_BILLING_EMAIL_KEYS[t.key] ? 8 : 4;
      ta.style.cssText = 'width:100%;box-sizing:border-box;padding:7px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-size:12px;color:var(--text-high);resize:vertical';
      ta.value = t.body || '';
      bodyWrap.appendChild(bodyLbl); bodyWrap.appendChild(ta); sec.appendChild(bodyWrap);
      var btn=document.createElement('button');btn.className='ing-add-btn';btn.textContent='Save';
      btn.addEventListener('click',(function(key,b){return async function(){b.disabled=true;b.textContent='Saving\u2026';
        try{var r=await apiFetch(SUPABASE_URL+'/rest/v1/email_templates',{method:'POST',headers:{'Content-Type':'application/json','Prefer':'resolution=merge-duplicates,return=minimal'},body:JSON.stringify({key:key,name:key.replace(/_/g,' ').replace(/\b\w/g,function(c){return c.toUpperCase();}),subject:document.getElementById('em-s-'+key).value,body:document.getElementById('em-b-'+key).value})});
        if(!r||!r.ok)throw new Error(r?r.status+': '+await r.text():'Session expired');
        b.textContent='\u2713 Saved';setTimeout(function(){var c=document.getElementById('upanel-sm-email');if(c){c.dataset.built='';buildSMEmail(c);}},1500);}
        catch(e){b.textContent='Save';b.disabled=false;alert('Save failed: '+e.message);}
      }})(t.key,btn));
      sec.appendChild(btn); container.appendChild(sec);
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
  if (tab === 'lm-submissions') { loadLibSubmissions(); return; }
  var info = LIB_TYPE_MAP[tab];
  if (info) { LIB_CURRENT_TYPE = info.type; loadLibProfiles(); }
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
    var actions = filter === 'pending'
      ? '<button data-action="lib-sub-approve" data-sid="' + esc(sub.id) + '" style="font-size:11px;padding:4px 10px;border-radius:6px;border:1px solid #6dc86d;background:rgba(100,200,100,.1);color:#6dc86d;cursor:pointer;margin-right:6px">Approve</button>' +
        '<button data-action="lib-sub-reject" data-sid="' + esc(sub.id) + '" style="font-size:11px;padding:4px 10px;border-radius:6px;border:1px solid var(--border);background:none;color:var(--text-mid);cursor:pointer">Reject</button>'
      : '<span style="font-size:11px;color:var(--text-mid)">' + esc(sub.status) + '</span>';
    html += '<tr style="border-bottom:1px solid rgba(255,255,255,.04)">' +
      '<td style="padding:8px 12px;font-size:12px;color:var(--text-mid)">' + esc(sub.profile_type || '') + '</td>' +
      '<td style="padding:8px 12px;font-size:13px;color:var(--text-high)">' + esc(name) + '</td>' +
      '<td style="padding:8px 12px;font-size:11px;color:var(--text-mid)">' + esc(when) + '</td>' +
      '<td style="padding:8px 12px;font-size:11px;color:var(--text-mid);max-width:240px">' + esc(preview) + '</td>' +
      '<td style="padding:8px 12px">' + actions + '</td></tr>';
  });
  html += '</tbody></table></div>';
  panel.innerHTML = html;
  panel.onclick = function (e) {
    var btn = e.target.closest('[data-action]');
    if (!btn) return;
    var sid = btn.dataset.sid;
    if (btn.dataset.action === 'lib-sub-approve') reviewLibSubmission(sid, 'approve');
    if (btn.dataset.action === 'lib-sub-reject') reviewLibSubmission(sid, 'reject');
  };
}

async function reviewLibSubmission(id, action) {
  var notes = action === 'reject' ? prompt('Rejection notes for submitter (optional):', '') : '';
  if (action === 'reject' && notes === null) return;
  if (action === 'approve' && !confirm('Approve and publish this profile to the library?')) return;
  try {
    await rpc('admin_review_library_submission', { p_id: id, p_action: action, p_notes: notes || null });
    alert(action === 'approve' ? 'Published to library.' : 'Submission rejected.');
    loadLibSubmissions('pending');
  } catch (e) { alert('Error: ' + (e.message || e)); }
}

async function loadLibProfiles(status, imageStatus) {
  if (status !== undefined) LIB_CURRENT_STATUS = status || null;
  if (imageStatus !== undefined) LIB_IMAGE_STATUS = imageStatus || null;
  var panel = document.getElementById('lm-panel');
  if (!panel) return;
  panel.innerHTML = '<div class="ap-loading">Loading…</div>';
  try {
    var stats = await rpc('admin_get_library_image_stats', { p_type: LIB_CURRENT_TYPE }).catch(function () { return null; });
    var data = await rpc('admin_get_library_profiles', {
      p_type: LIB_CURRENT_TYPE,
      p_status: LIB_CURRENT_STATUS,
      p_limit: 50,
      p_offset: 0,
      p_image_status: LIB_IMAGE_STATUS
    });
    buildLibPanel(panel, Array.isArray(data) ? data : [], stats);
  } catch(e) {
    panel.innerHTML = '<div class="ap-empty">Error loading profiles: ' + (e.message||e) + '</div>';
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
  var imgFilterBtns = ['All','missing','draft','approved'].map(function(s) {
    var active = (s === 'All' && !LIB_IMAGE_STATUS) || s === LIB_IMAGE_STATUS;
    return '<button onclick="loadLibProfiles(undefined,' + (s === 'All' ? 'null' : "'" + s + "'") + ')" ' +
      'style="font-family:DM Sans,sans-serif;font-size:11px;padding:4px 10px;border-radius:6px;border:1px solid var(--border);background:' +
      (active ? 'rgba(196,151,59,0.15)' : 'none') + ';color:' + (active ? 'var(--accent)' : 'var(--text-mid)') + ';cursor:pointer">' +
      (s === 'All' ? 'All images' : s) + '</button>';
  }).join('');
  var html = statsHtml +
    '<div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:12px;flex-wrap:wrap;gap:8px">' +
    '<div style="display:flex;gap:8px;flex-wrap:wrap">' +
    ['All','draft','published'].map(function(s){
      return '<button onclick="loadLibProfiles(' + (s==='All'?'null':"'"+s+"'")+ ', undefined)" ' +
        'style="font-family:DM Sans,sans-serif;font-size:12px;padding:5px 12px;border-radius:6px;border:1px solid var(--border);background:' +
        ((s==='All'&&!LIB_CURRENT_STATUS)||(s===LIB_CURRENT_STATUS)?'var(--accent)':'none') +
        ';color:' + ((s==='All'&&!LIB_CURRENT_STATUS)||(s===LIB_CURRENT_STATUS)?'#0C0702':'var(--text-mid)') +
        ';cursor:pointer">' + s + '</button>';
    }).join('') +
    '</div>' +
    '<a href="library-submit.html?type=' + LIB_CURRENT_TYPE + '" target="_blank" ' +
    'style="font-family:DM Sans,sans-serif;font-size:12px;font-weight:600;padding:8px 16px;border-radius:8px;background:var(--accent);color:#0C0702;text-decoration:none">+ New Profile</a>' +
    '</div>' +
    '<div style="display:flex;gap:6px;flex-wrap:wrap;margin-bottom:16px">' + imgFilterBtns + '</div>';

  if (!items.length) {
    html += '<div class="ap-empty">No ' + (info.label||'profiles') + ' found.</div>';
    panel.innerHTML = html;
    return;
  }

  var ingCol = LIB_CURRENT_TYPE === 'ingredient' ? '<th style="text-align:left;font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-muted);padding:8px 12px;border-bottom:1px solid var(--border)">Ing ID</th>' : '';
  html += '<div class="ap-table"><table style="width:100%;border-collapse:collapse">' +
    '<thead><tr>' +
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
    var ingCell = LIB_CURRENT_TYPE === 'ingredient'
      ? '<td style="padding:8px 12px"><input type="number" id="lib-ing-'+esc(p.id)+'" value="'+(p.governed_ingredient_id||'')+'" placeholder="ID" style="width:72px;padding:4px 8px;background:var(--bg);border:1px solid var(--border);border-radius:6px;font-size:11px;color:var(--text-high)"><button data-action="lib-link" data-lid="'+esc(p.id)+'" style="margin-left:4px;font-size:10px;padding:3px 8px;border:1px solid var(--accent);background:none;color:var(--accent);border-radius:5px;cursor:pointer">Link</button></td>'
      : '';
    html += '<tr style="border-bottom:1px solid rgba(255,255,255,.04)">' +
      '<td style="padding:8px 12px"><div style="width:44px;height:44px;border-radius:50%;background:var(--surface);overflow:hidden;display:flex;align-items:center;justify-content:center;border:1px solid var(--border)">' + miseThumb + '</div></td>' +
      '<td style="padding:8px 12px"><div style="width:40px;height:40px;border-radius:6px;background:var(--surface);overflow:hidden;display:flex;align-items:center;justify-content:center">' + heroThumb + '</div></td>' +
      '<td style="padding:8px 12px;font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-high)">' + esc(p.name) + '</td>' +
      '<td style="padding:8px 12px"><span style="font-size:10px;font-family:DM Sans,sans-serif;color:' + imgStColor + ';text-transform:uppercase;letter-spacing:.06em">' + esc(imgSt) + '</span>' + approveBtn + '</td>' +
      '<td style="padding:8px 12px"><span style="font-size:11px;font-family:DM Sans,sans-serif;color:' + statusColor + ';text-transform:uppercase;letter-spacing:.06em">' + esc(p.status) + '</span></td>' +
      '<td style="padding:8px 12px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-muted)">' + esc(p.visibility||'public') + '</td>' +
      '<td style="padding:8px 12px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-muted)">' + (p.updated_at ? new Date(p.updated_at).toLocaleDateString() : '—') + '</td>' +
      ingCell +
      '<td style="padding:8px 12px">' +
      '<a href="library-submit.html?type=' + LIB_CURRENT_TYPE + '&id=' + esc(p.id) + '" target="_blank" ' +
      'style="font-family:DM Sans,sans-serif;font-size:11px;color:var(--accent);margin-right:8px">Edit</a>' +
      '<button data-action="lib-toggle" data-lid="' + esc(p.id) + '" data-lstatus="' + esc(p.status) + '" ' +
      'style="font-family:DM Sans,sans-serif;font-size:11px;background:none;border:none;cursor:pointer;color:var(--text-mid)">' +
      (p.status==='published'?'Unpublish':'Publish') + '</button>' +
      '<button data-action="lib-delete" data-lid="' + esc(p.id) + '" data-lname="' + esc(p.name) + '" ' +
      'style="font-family:DM Sans,sans-serif;font-size:11px;background:none;border:none;cursor:pointer;color:var(--text-danger);margin-left:8px">Delete</button>' +
      '</td></tr>';
  });

  html += '</tbody></table></div>';
  panel.innerHTML = html;

  panel.addEventListener('click', function(e) {
    var btn = e.target.closest('[data-action]');
    if (!btn) return;
    var action  = btn.dataset.action;
    var lid     = btn.dataset.lid;
    var lstatus = btn.dataset.lstatus;
    var lname   = btn.dataset.lname;
    if (action === 'lib-toggle' && lid) libTogglePublish(lid, lstatus);
    if (action === 'lib-delete' && lid) libDelete(lid, lname);
    if (action === 'lib-link' && lid) {
      var inp = document.getElementById('lib-ing-' + lid);
      var ingId = inp ? parseInt(inp.value, 10) : 0;
      if (!ingId) { alert('Enter governed ingredient ID'); return; }
      rpc('admin_link_library_ingredient', { p_profile_id: lid, p_ingredient_id: ingId })
        .then(function() { alert('Linked'); loadLibProfiles(LIB_CURRENT_STATUS); })
        .catch(function(err) { alert(err.message); });
    }
    if (action === 'lib-mise-approve' && lid) {
      rpc('admin_set_library_image_status', { p_type: LIB_CURRENT_TYPE, p_id: lid, p_status: 'approved' })
        .then(function() { loadLibProfiles(LIB_CURRENT_STATUS); })
        .catch(function(err) { alert(err.message); });
    }
  }, { once: false });
}

async function libTogglePublish(id, currentStatus) {
  var newStatus = currentStatus === 'published' ? 'draft' : 'published';
  try {
    await rpc('admin_publish_library_profile', { p_type: LIB_CURRENT_TYPE, p_id: id, p_status: newStatus });
    loadLibProfiles(LIB_CURRENT_STATUS);
  } catch(e) { alert('Error: ' + (e.message||e)); }
}

async function libDelete(id, name) {
  if (!confirm('Delete "' + name + '"? This cannot be undone.')) return;
  try {
    await rpc('admin_delete_library_profile', { p_type: LIB_CURRENT_TYPE, p_id: id });
    loadLibProfiles(LIB_CURRENT_STATUS);
  } catch(e) { alert('Error: ' + (e.message||e)); }
}
