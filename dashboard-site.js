// The Culinary Journal — Dashboard Module
// This file is loaded by dashboard.html
// Requires: supabase-config.js to be loaded first

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

async function buildSMPages(container) {
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);padding:8px 0">Loading\u2026</div>';
  try {
    // Fetch pages and site_settings in parallel — S needed for SEO field values
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
    var wrap = document.createElement('div'); wrap.style.cssText = 'overflow-x:auto;border:1px solid var(--border);border-radius:12px';
    var tbl = document.createElement('table'); tbl.className = 'ap-table';
    tbl.innerHTML = '<thead><tr style="border-bottom:1px solid var(--border)"><th class="ap-th">Page</th><th class="ap-th">Path</th><th class="ap-th">Visibility</th><th class="ap-th" style="text-align:center">Coming Soon</th><th class="ap-th">Save</th></tr></thead>';
    var tbody = document.createElement('tbody');
    pages.forEach(function(p) {
      var tr = document.createElement('tr'); tr.style.borderBottom = '1px solid rgba(255,255,255,0.04)';
      var vis = '<select id="smv-'+(p.path||'')+'" style="padding:5px 8px;background:var(--bg);border:1px solid var(--border);border-radius:6px;font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-high)">'+
        [{v:'public',l:'Public — Everyone'},{v:'registered',l:'Registered Members'},{v:'paid',l:'Paid Members Only'},{v:'hidden',l:'Hidden'}].map(function(o){return '<option value="'+o.v+'"'+(p.visibility===o.v?' selected':'')+'>'+o.l+'</option>';}).join('')+'</select>';
      tr.innerHTML = '<td class="ap-td" style="font-size:13px;font-weight:500;color:var(--text-high)">'+(p.name||'')+'</td>'+
        '<td class="ap-td" style="font-size:11px;color:var(--text-mid)">'+(p.path||'')+'</td>'+
        '<td class="ap-td">'+vis+'</td>'+
        '<td class="ap-td" style="text-align:center"><input type="checkbox" id="smcs-'+(p.path||'')+'"'+(p.coming_soon?' checked':'')+' style="width:15px;height:15px;accent-color:var(--accent)"></td>'+
        '<td class="ap-td"></td>';
      var seoWrap = document.createElement('tr');
      seoWrap.style.cssText = 'border-bottom:1px solid rgba(255,255,255,0.04)';
      var seoCel = document.createElement('td');
      seoCel.setAttribute('colspan','5');
      seoCel.style.cssText = 'padding:0 8px 10px;display:none';
      seoCel.id = 'seo-row-' + (p.path||'');
      seoCel.innerHTML = '<div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;padding:8px 0">' +
        '<div><label style="display:block;font-size:10px;text-transform:uppercase;color:var(--text-mid);margin-bottom:3px">Meta Title</label>' +
        '<input id="seo-t-'+(p.path||'')+'" value="'+(S['seo_'+p.path+'_title']||'')+'" style="width:100%;box-sizing:border-box;padding:5px 8px;background:var(--bg);border:1px solid var(--border);border-radius:6px;font-size:11px;color:var(--text-high)"></div>' +
        '<div><label style="display:block;font-size:10px;text-transform:uppercase;color:var(--text-mid);margin-bottom:3px">Meta Description</label>' +
        '<input id="seo-d-'+(p.path||'')+'" value="'+(S['seo_'+p.path+'_desc']||'')+'" style="width:100%;box-sizing:border-box;padding:5px 8px;background:var(--bg);border:1px solid var(--border);border-radius:6px;font-size:11px;color:var(--text-high)"></div></div>';
      seoWrap.appendChild(seoCel);
      tbody.appendChild(seoWrap);
      var btn = document.createElement('button'); btn.textContent = 'Save';
      btn.style.cssText = "padding:5px 12px;background:var(--accent);border:none;border-radius:6px;color:#fff;font-family:'DM Sans',sans-serif;font-size:11px;cursor:pointer";
      btn.addEventListener('click', (function(path, b) { return async function() {
        b.disabled=true; b.textContent='\u2026';
        try {
          var r=await apiFetch(SUPABASE_URL+'/rest/v1/site_pages?path=eq.'+encodeURIComponent(path),{method:'PATCH',headers:{'Content-Type':'application/json','Prefer':'return=representation'},body:JSON.stringify({visibility:document.getElementById('smv-'+path).value,coming_soon:document.getElementById('smcs-'+path).checked})});
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
        left.innerHTML='<span style="font-size:10px;font-weight:700;padding:2px 7px;border-radius:5px;background:rgba(0,0,0,0.3);color:'+(TC[a.type]||'var(--text-mid)')+'">'+(a.type||'').toUpperCase()+'</span><div style="font-size:13px;color:var(--text-high);margin-top:6px">'+(a.text||'')+'</div>';
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
    var res = await apiFetch(SUPABASE_URL+'/rest/v1/email_templates?order=key');
    if (!res||!res.ok) throw new Error(res?res.status+': '+await res.text():'Session expired');
    var templates = await res.json();
    if(!Array.isArray(templates)||!templates.length){container.dataset.built='';container.innerHTML='<div style="padding:16px;font-size:13px;color:var(--text-mid)">No email templates. Run seed_settings.sql in Supabase.</div>';return;}
    container.innerHTML='<p style="font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);margin-bottom:16px">Use {{name}}, {{recipe_name}}, {{reset_link}} as placeholders.</p>';
    templates.forEach(function(t){
      var sec=document.createElement('div');sec.style.cssText='background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:12px;padding:16px 20px;margin-bottom:14px';
      sec.innerHTML='<div style="font-family:Cormorant Garamond,serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:12px">'+(t.name||t.key||'')+'</div>'+
        '<div style="margin-bottom:8px"><label style="display:block;font-size:10px;color:var(--text-mid);margin-bottom:3px">Subject</label><input id="em-s-'+t.key+'" value="'+(t.subject||'')+'" style="width:100%;box-sizing:border-box;padding:7px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-size:12px;color:var(--text-high)"></div>'+
        '<div style="margin-bottom:10px"><label style="display:block;font-size:10px;color:var(--text-mid);margin-bottom:3px">Body</label><textarea id="em-b-'+t.key+'" rows="4" style="width:100%;box-sizing:border-box;padding:7px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-size:12px;color:var(--text-high);resize:vertical">'+(t.body||'')+'</textarea></div>';
      var btn=document.createElement('button');btn.className='ing-add-btn';btn.textContent='Save';
      btn.addEventListener('click',(function(key,b){return async function(){b.disabled=true;b.textContent='Saving\u2026';
        try{var r=await apiFetch(SUPABASE_URL+'/rest/v1/email_templates',{method:'POST',headers:{'Content-Type':'application/json','Prefer':'resolution=merge-duplicates,return=minimal'},body:JSON.stringify({key:key,name:key.replace(/_/g,' ').replace(/\b\w/g,function(c){return c.toUpperCase();}),subject:document.getElementById('em-s-'+key).value,body:document.getElementById('em-b-'+key).value})});
        if(!r||!r.ok)throw new Error(r?r.status+': '+await r.text():'Session expired');
        b.textContent='\u2713 Saved';setTimeout(function(){var c=document.getElementById('upanel-sm-email');if(c){c.dataset.built='';buildSMEmail(c);}},1500);}
        catch(e){b.textContent='Save';b.disabled=false;alert('Save failed: '+e.message);}
      }})(t.key,btn));
      sec.appendChild(btn);container.appendChild(sec);
    });
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
    container.dataset.built='1';
  } catch(e){container.dataset.built='';container.innerHTML='<div style="padding:16px;background:rgba(220,80,80,0.1);border:1px solid rgba(220,80,80,0.4);border-radius:10px;font-family:DM Sans,sans-serif;font-size:13px;color:#dc5050"><strong>Error:</strong> '+String(e.message).replace(/</g,'&lt;')+'</div>';}
}


// ═══════════════════════════════════════════════════════════════
// FINANCE MANAGEMENT
// ═══════════════════════════════════════════════════════════════