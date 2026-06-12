// Dashboard User Management ops tabs (reports, requests, feedback, invites, audit)
// Requires: dashboard-shared.js (rpc, esc, auditLog, openUserDetail, loadUMTab)

// ── UM Reports ────────────────────────────────────────────────────

async function loadUMReports(container) {
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)">Loading\u2026</div>';
  try {
    var reports = [];
    if (typeof TcjAdminReports !== 'undefined') {
      reports = await TcjAdminReports.fetchAll({ p_status: null });
    } else {
      var rawReports = await rpc('admin_get_reports', { p_status: null, p_limit: 200, p_offset: 0 });
      reports = Array.isArray(rawReports) ? rawReports : [];
    }
    var appeals = await rpc('admin_get_appeals', {}) || [];
    appeals = Array.isArray(appeals) ? appeals : [];
    container.innerHTML = '';
    function mk(tag,s,t){var e=document.createElement(tag);if(s)e.style.cssText=s;if(t!==undefined)e.textContent=t;return e;}

    // Appeals section
    var appCard=mk('div','background:rgba(91,143,212,0.06);border:1px solid rgba(91,143,212,0.3);border-radius:12px;padding:20px;margin-bottom:20px');
    appCard.appendChild(mk('div',"font-family:'Cormorant Garamond',serif;font-size:1rem;font-weight:700;color:#5B8FD4;margin-bottom:12px",'\uD83D\uDCE8 Deactivation Appeals ('+appeals.filter(function(a){return a.status==='pending';}).length+' pending)'));
    if(!appeals.length){
      appCard.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-mid)",'No appeals submitted yet.'));
    } else {
      appeals.forEach(function(a){
        var sc={'pending':'#d4a017','approved':'#4caf76','rejected':'#dc5050'}[a.status]||'var(--text-mid)';
        var row=mk('div','background:rgba(255,255,255,0.04);border-radius:9px;padding:12px 16px;margin-bottom:8px');
        var hdr=mk('div','display:flex;align-items:center;justify-content:space-between;margin-bottom:6px');
        hdr.appendChild(mk('span',"font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-high)",'@'+esc(a.username||'')+(a.full_name?' ('+esc(a.full_name)+')':'')));
        hdr.appendChild(mk('span','font-size:11px;font-weight:600;color:'+sc,a.status));
        row.appendChild(hdr);
        row.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-mid);margin-bottom:8px",esc(a.appeal_text)));
        if(a.status==='pending'){
          var btns=mk('div','display:flex;gap:6px');
          var apBtn=mk('button','padding:4px 12px;background:none;border:1px solid #4caf76;border-radius:6px;color:#4caf76;font-family:DM Sans,sans-serif;font-size:11px;cursor:pointer','Approve & Reactivate');
          apBtn.addEventListener('click',(function(id,b){return async function(){b.disabled=true;try{await rpc('admin_review_appeal',{p_id:id,p_status:'approved',p_notes:null});auditLog('User Management > Reports','Appeal Approved',null,String(id),'approved',null);loadUMReports(container);}catch(e){b.disabled=false;alert('Error: '+e.message);}};})(a.id,apBtn));
          var rjBtn=mk('button','padding:4px 12px;background:none;border:1px solid #dc5050;border-radius:6px;color:#dc5050;font-family:DM Sans,sans-serif;font-size:11px;cursor:pointer','Reject Appeal');
          rjBtn.addEventListener('click',(function(id,b){return async function(){var notes=prompt('Reason for rejecting this appeal (shown to user):');if(notes===null)return;b.disabled=true;try{await rpc('admin_review_appeal',{p_id:id,p_status:'rejected',p_notes:notes||null});auditLog('User Management > Reports','Appeal Rejected',null,String(id),'rejected',notes||null);loadUMReports(container);}catch(e){b.disabled=false;alert('Error: '+e.message);}};})(a.id,rjBtn));
          btns.appendChild(apBtn);btns.appendChild(rjBtn);row.appendChild(btns);
        }
        appCard.appendChild(row);
      });
    }
    container.appendChild(appCard);

    // Reports section
    var rptTitle=mk('div',"font-family:'Cormorant Garamond',serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:12px",'User Reports ('+reports.length+')');
    container.appendChild(rptTitle);
    if(!reports.length){container.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:13px;color:var(--text-mid)",'No reports filed yet.'));return;}
    var tblWrap=mk('div','overflow-x:auto;border:1px solid var(--border);border-radius:12px');
    var tbl=mk('table','width:100%;border-collapse:collapse');
    tbl.innerHTML='<thead><tr style="border-bottom:1px solid var(--border)"><th class="ap-th">Reporter</th><th class="ap-th">Reported User</th><th class="ap-th">Reason</th><th class="ap-th">Status</th><th class="ap-th">Date</th><th class="ap-th">Actions</th></tr></thead>';
    var tbody=document.createElement('tbody');
    reports.forEach(function(r){
      var sc={pending:'#d4a017',reviewed:'#5B8FD4',actioned:'#4caf76',dismissed:'#dc5050'}[r.status]||'var(--text-mid)';
      var dt=r.created_at?new Date(r.created_at).toLocaleDateString('en-GB',{day:'numeric',month:'short',year:'numeric'}):'\u2014';
      var tr=mk('tr','border-bottom:1px solid rgba(255,255,255,0.04)');
      function td(h,s){var t=mk('td','padding:8px 10px'+(s?';'+s:''));t.innerHTML=h;return t;}
      tr.appendChild(td('<span style="font-size:12px;color:var(--text-high)">@'+esc(r.reporter_username||'anon')+'</span>'));
      tr.appendChild(td('<span style="font-size:12px;color:var(--text-high)">@'+esc(r.reported_username||'\u2014')+'</span>'));
      tr.appendChild(td('<span style="font-size:12px;color:var(--text-mid)">'+esc(r.reason||'')+'</span>'));
      tr.appendChild(td('<span style="font-size:11px;font-weight:600;color:'+sc+'">'+esc(r.status)+'</span>'));
      tr.appendChild(td('<span style="font-size:11px;color:var(--text-mid)">'+dt+'</span>'));
      var actTd=mk('td','padding:8px 10px');var btns=mk('div','display:flex;gap:4px');
      if(r.status==='pending'){
        var aBtn=mk('button','padding:4px 10px;background:none;border:1px solid #4caf76;border-radius:6px;color:#4caf76;font-family:DM Sans,sans-serif;font-size:11px;cursor:pointer','Action');
        aBtn.addEventListener('click',(function(id,b){return function(){doUpdateReport(id,'actioned',b);};})(r.id,aBtn));
        var dBtn=mk('button','padding:4px 10px;background:none;border:1px solid #dc5050;border-radius:6px;color:#dc5050;font-family:DM Sans,sans-serif;font-size:11px;cursor:pointer','Dismiss');
        dBtn.addEventListener('click',(function(id,b){return function(){doUpdateReport(id,'dismissed',b);};})(r.id,dBtn));
        btns.appendChild(aBtn);btns.appendChild(dBtn);
      }
      if(r.reported_user_id){
        var vBtn=mk('button','padding:4px 10px;background:none;border:1px solid var(--border);border-radius:6px;color:var(--text-mid);font-family:DM Sans,sans-serif;font-size:11px;cursor:pointer','View User');
        vBtn.addEventListener('click',(function(uid){return function(){openUserDetail(uid);};})(r.reported_user_id));btns.appendChild(vBtn);
      }
      actTd.appendChild(btns);tr.appendChild(actTd);tbody.appendChild(tr);
    });
    tbl.appendChild(tbody);tblWrap.appendChild(tbl);container.appendChild(tblWrap);
  }catch(e){container.innerHTML='<div style="color:#dc5050;font-family:DM Sans,sans-serif;font-size:13px">Error: '+esc(e.message)+'</div>';}
}

async function doUpdateReport(id, status, btn) {
  btn.disabled=true;
  try{await rpc('admin_update_report',{p_id:id,p_status:status});auditLog('User Management > Reports','Report '+status,null,String(id),status,null);
    var panel=document.getElementById('upanel-umsettings');if(panel)loadUMTab('reports',panel.querySelector('[style*="block"]')||panel);}
  catch(e){btn.disabled=false;alert('Error: '+e.message);}
}

// ── UM Recipe Requests ────────────────────────────────────────────

async function loadUMRequests(container) {
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)">Loading…</div>';
  try {
    var rows = await rpc('admin_get_recipe_requests', {p_status:null}) || [];
    container.innerHTML = '';
    function mk(tag,style,text){var e=document.createElement(tag);if(style)e.style.cssText=style;if(text!==undefined)e.textContent=text;return e;}
    var countLbl = mk('div',"font-family:Cormorant Garamond,serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:16px",rows.length+' recipe request'+(rows.length===1?'':'s'));
    container.appendChild(countLbl);
    if(!rows.length){container.appendChild(mk('div',"font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)","No recipe requests yet. When users submit requests they will appear here."));return;}
    var tblWrap = mk('div','overflow-x:auto;border:1px solid var(--border);border-radius:12px');
    var tbl = mk('table','width:100%;border-collapse:collapse');
    tbl.innerHTML = '<thead><tr style="border-bottom:1px solid var(--border)"><th class="ap-th">Request</th><th class="ap-th">From</th><th class="ap-th">Status</th><th class="ap-th">Notes</th><th class="ap-th">Date</th><th class="ap-th">Actions</th></tr></thead>';
    var tbody = mk('tbody','');
    rows.forEach(function(r) {
      var sc = {pending:'#d4a017',in_progress:'#5B8FD4',fulfilled:'#4caf76',declined:'#dc5050'}[r.status]||'var(--text-mid)';
      var dt = r.created_at ? new Date(r.created_at).toLocaleDateString('en-GB',{day:'numeric',month:'short',year:'numeric'}) : '—';
      var tr = mk('tr','border-bottom:1px solid rgba(255,255,255,0.04)');
      tr.innerHTML = '<td class="ap-td" style="max-width:240px"><span style="font-size:12px;color:var(--text-high)">'+esc(r.request_text||'')+'</span></td>'+
        '<td class="ap-td"><span style="font-size:12px;color:var(--text-mid)">@'+esc(r.username||'anonymous')+'</span></td>'+
        '<td class="ap-td"><span style="font-size:11px;font-weight:600;color:'+sc+'">'+esc((r.status||'').replace('_',' '))+'</span></td>'+
        '<td class="ap-td" style="font-size:11px;color:var(--text-mid);max-width:160px">'+esc(r.notes||'—')+'</td>'+
        '<td class="ap-td" style="font-size:11px;color:var(--text-mid)">'+dt+'</td>'+
        '<td class="ap-td"><select onchange="doUpdateRequest('+r.id+',this.value)" style="padding:4px 8px;background:var(--bg);border:1px solid var(--border);border-radius:6px;font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-high)">'+
          ['pending','in_progress','fulfilled','declined'].map(function(s){return '<option value="'+s+'"'+(r.status===s?' selected':'')+'>'+s.replace('_',' ')+'</option>';}).join('')+
        '</select></td>';
      tbody.appendChild(tr);
    });
    tbl.appendChild(tbody);tblWrap.appendChild(tbl);container.appendChild(tblWrap);
  } catch(e){container.innerHTML='<div style="color:#dc5050;font-family:DM Sans,sans-serif;font-size:13px">Error: '+esc(e.message)+'</div>';}
}

async function doUpdateRequest(id, status) {
  try{await rpc('admin_update_recipe_request',{p_id:id,p_status:status,p_notes:null});auditLog('User Management > Recipe Requests','Request Updated',null,String(id),status,null);}
  catch(e){alert('Error: '+e.message);}
}

// ── UM Feedback ───────────────────────────────────────────────────

async function loadUMFeedback(container) {
  if (typeof loadVocInbox === 'function') { loadVocInbox(container); return; }
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)">Loading…</div>';
  try {
    var rows = await rpc('admin_get_feedback', {p_status:null}) || [];
    container.innerHTML = '';
    function mk(tag,style,text){var e=document.createElement(tag);if(style)e.style.cssText=style;if(text!==undefined)e.textContent=text;return e;}
    var countLbl = mk('div',"font-family:Cormorant Garamond,serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:16px",rows.length+' feedback item'+(rows.length===1?'':'s'));
    container.appendChild(countLbl);
    if(!rows.length){container.appendChild(mk('div',"font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)","No feedback yet. User feedback on recipes will appear here for review."));return;}
    rows.forEach(function(r){
      var sc = {new:'#d4a017',reviewed:'#5B8FD4',actioned:'#4caf76',dismissed:'#dc5050'}[r.status]||'var(--text-mid)';
      var dt = r.created_at ? new Date(r.created_at).toLocaleDateString('en-GB',{day:'numeric',month:'short',year:'numeric'}) : '—';
      var typeBadge = {general:'#5B8FD4',recipe:'#4caf76',bug:'#dc5050',suggestion:'#C4973B'}[r.type]||'var(--text-mid)';
      var card = mk('div','background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:10px;padding:14px 18px;margin-bottom:10px');
      var header = mk('div','display:flex;align-items:center;gap:10px;margin-bottom:8px');
      header.appendChild(mk('span','font-size:11px;font-weight:600;padding:2px 8px;border-radius:10px;background:rgba(0,0,0,0.2);color:'+typeBadge,r.type));
      header.appendChild(mk('span',"font-family:DM Sans,sans-serif;font-size:11px;color:var(--text-mid)",'@'+esc(r.username||'anonymous')+' — '+dt));
      header.appendChild(mk('span','margin-left:auto;font-size:11px;font-weight:600;color:'+sc,r.status));
      card.appendChild(header);
      card.appendChild(mk('div',"font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-high);margin-bottom:12px",r.feedback||''));
      var btns = mk('div','display:flex;gap:6px');
      [{s:'actioned',l:'Mark Actioned',c:'#4caf76'},{s:'dismissed',l:'Dismiss',c:'#dc5050'},{s:'new',l:'Reset to New',c:'var(--text-mid)'}].forEach(function(b){
        if(r.status!==b.s){
          var btn=mk('button','padding:4px 10px;background:none;border:1px solid '+b.c+';border-radius:6px;color:'+b.c+";font-family:DM Sans,sans-serif;font-size:11px;cursor:pointer",b.l);
          btn.addEventListener('click',async function(){this.disabled=true;try{await rpc('admin_update_feedback',{p_id:r.id,p_status:b.s});auditLog('User Management > Feedback','Feedback '+b.s,null,String(r.id),b.s,null);loadUMFeedback(container);}catch(e){this.disabled=false;alert('Error: '+e.message);}});
          btns.appendChild(btn);
        }
      });
      card.appendChild(btns);
      container.appendChild(card);
    });
  } catch(e){container.innerHTML='<div style="color:#dc5050;font-family:DM Sans,sans-serif;font-size:13px">Error: '+esc(e.message)+'</div>';}
}

function buildUMStub(container, title, description) {
  container.innerHTML =
    '<div style="padding:40px;text-align:center;background:rgba(255,255,255,0.02);border:1px solid var(--border);border-radius:12px">' +
      '<div style="font-size:2rem;margin-bottom:12px">\uD83D\uDD27</div>' +
      '<div style="font-family:\'Cormorant Garamond\',serif;font-size:1.1rem;font-weight:700;color:var(--text-high);margin-bottom:8px">'+esc(title)+'</div>' +
      '<div style="font-family:\'DM Sans\',sans-serif;font-size:13px;color:var(--text-mid);max-width:400px;margin:0 auto">'+esc(description)+'</div>' +
      '<div style="margin-top:16px;display:inline-block;padding:6px 16px;border:1px solid var(--border);border-radius:8px;font-family:\'DM Sans\',sans-serif;font-size:11px;color:var(--text-mid)">Coming Soon</div>' +
    '</div>';
}

// Deactivated Accounts

async function loadUMInvites(container) {
  container.innerHTML = '<div style="font-family:\'DM Sans\',sans-serif;font-size:13px;color:var(--text-mid)">Loading\u2026</div>';
  try {
    var invites = await rpc('admin_get_invites',{}) || [];
    container.innerHTML = '';
    // Create invite form
    var form = document.createElement('div');
    form.style.cssText = 'background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:12px;padding:20px;margin-bottom:20px';
    form.innerHTML =
      '<div style="font-family:\'Cormorant Garamond\',serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:16px">Send Invite</div>' +
      '<div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-bottom:12px">' +
        '<div><label style="display:block;font-family:\'DM Sans\',sans-serif;font-size:11px;color:var(--text-mid);margin-bottom:4px">Email</label>' +
          '<input id="invite-email" type="email" placeholder="chef@example.com" style="width:100%;box-sizing:border-box;padding:8px 12px;background:var(--bg);border:1px solid var(--border);border-radius:8px;font-family:\'DM Sans\',sans-serif;font-size:13px;color:var(--text-high)"></div>' +
        '<div><label style="display:block;font-family:\'DM Sans\',sans-serif;font-size:11px;color:var(--text-mid);margin-bottom:4px">Role</label>' +
          '<select id="invite-role" style="width:100%;padding:8px 12px;background:var(--bg);border:1px solid var(--border);border-radius:8px;font-family:\'DM Sans\',sans-serif;font-size:13px;color:var(--text-high)">' +
            '<option value="contributor">Contributor</option>' +
            '<option value="guest_chef">Guest Chef</option>' +
          '</select></div>' +
      '</div>' +
      '<div style="margin-bottom:12px"><label style="display:block;font-family:\'DM Sans\',sans-serif;font-size:11px;color:var(--text-mid);margin-bottom:4px">Personal Message (optional)</label>' +
        '<input id="invite-msg" placeholder="We\'d love to have you contribute..." style="width:100%;box-sizing:border-box;padding:8px 12px;background:var(--bg);border:1px solid var(--border);border-radius:8px;font-family:\'DM Sans\',sans-serif;font-size:13px;color:var(--text-high)"></div>' +
      '<button onclick="sendInvite()" style="padding:9px 20px;background:var(--accent);border:none;border-radius:8px;color:#fff;font-family:\'DM Sans\',sans-serif;font-size:13px;font-weight:600;cursor:pointer">Send Invite</button>' +
      '<div id="invite-status" style="margin-top:10px;font-family:\'DM Sans\',sans-serif;font-size:12px;color:#4caf76"></div>';
    container.appendChild(form);
    // Invite list
    var listTitle = document.createElement('div');
    listTitle.style.cssText = "font-family:'Cormorant Garamond',serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:12px";
    listTitle.textContent = invites.length + ' invite' + (invites.length===1?'':'s') + ' sent';
    container.appendChild(listTitle);
    if (invites.length) {
      var tbl = document.createElement('div');
      tbl.style.cssText = 'overflow-x:auto;border:1px solid var(--border);border-radius:12px';
      tbl.innerHTML = '<table style="width:100%;border-collapse:collapse">' +
        '<thead><tr style="border-bottom:1px solid var(--border)"><th class="ap-th">Email</th><th class="ap-th">Role</th><th class="ap-th">Status</th><th class="ap-th">Sent</th><th class="ap-th">Expires</th><th class="ap-th">Invite Link</th></tr></thead>' +
        '<tbody>' + invites.map(function(inv){
          var sc={'pending':'#d4a017','accepted':'#4caf76','expired':'#dc5050'}[inv.status]||'var(--text-mid)';
          var sd = new Date(inv.created_at).toLocaleDateString('en-GB',{day:'numeric',month:'short',year:'numeric'});
          var ed = new Date(inv.expires_at).toLocaleDateString('en-GB',{day:'numeric',month:'short',year:'numeric'});
          var link = window.location.origin + '/login.html?invite=' + esc(inv.token);
          return '<tr style="border-bottom:1px solid rgba(255,255,255,0.04)">' +
            '<td class="ap-td" style="font-size:12px">'+esc(inv.email)+'</td>' +
            '<td class="ap-td" style="font-size:12px;color:var(--text-mid)">'+esc(inv.role)+'</td>' +
            '<td class="ap-td"><span style="font-size:11px;font-weight:600;color:'+sc+'">'+esc(inv.status)+'</span></td>' +
            '<td class="ap-td" style="font-size:12px;color:var(--text-mid)">'+sd+'</td>' +
            '<td class="ap-td" style="font-size:12px;color:var(--text-mid)">'+ed+'</td>' +
            '<td class="ap-td"><button onclick="copyToClipboard(\''+link+'\')" style="padding:4px 10px;background:none;border:1px solid var(--border);border-radius:6px;color:var(--text-mid);font-family:\'DM Sans\',sans-serif;font-size:11px;cursor:pointer">Copy Link</button></td>' +
          '</tr>';
        }).join('') + '</tbody></table>';
      container.appendChild(tbl);
    } else {
      var empty = document.createElement('div');
      empty.style.cssText = "font-family:'DM Sans',sans-serif;font-size:13px;color:var(--text-mid)";
      empty.textContent = 'No invites sent yet.';
      container.appendChild(empty);
    }
  } catch(e) { container.innerHTML = '<div style="color:#dc5050;font-family:\'DM Sans\',sans-serif;font-size:13px">Error: '+esc(e.message)+'</div>'; }
}

async function sendInvite() {
  var email = (document.getElementById('invite-email').value||'').trim();
  var role  = document.getElementById('invite-role').value;
  var msg   = (document.getElementById('invite-msg').value||'').trim();
  if (!email) { alert('Email is required.'); return; }
  try {
    var token = await rpc('admin_create_invite',{p_email:email,p_role:role,p_message:msg||null});
    document.getElementById('invite-status').textContent = '\u2713 Invite sent to ' + email + '. Link: ' + window.location.origin + '/login.html?invite=' + token;
    auditLog('User Management','Invite Sent',email,null,role,null);
    loadUMInvites(document.getElementById('invite-email').closest('[data-panel="umsettings"]') || document.getElementById('upanel-umsettings'));
  } catch(e) { alert('Error: '+e.message); }
}

function copyToClipboard(text) {
  navigator.clipboard.writeText(text).then(function(){ alert('Link copied!'); }).catch(function(){ alert(text); });
}

// UM Analytics

async function loadUMAudit(container) {
  container.innerHTML = '<div style="font-family:\'DM Sans\',sans-serif;font-size:13px;color:var(--text-mid)">Loading\u2026</div>';
  try {
    var rows = [];
    if (typeof TcjAdminAudit !== 'undefined') {
      rows = await TcjAdminAudit.fetchAll({});
    } else {
      rows = await rpc('admin_get_audit_log',{p_limit:200,p_offset:0}) || [];
    }
    var umRows = rows.filter(function(r){ return (r.tab||'').includes('User Management'); });
    container.innerHTML = '';
    if (!umRows.length) { container.innerHTML = '<div style="font-family:\'DM Sans\',sans-serif;font-size:13px;color:var(--text-mid)">No user management actions logged yet.</div>'; return; }
    var tblWrap = document.createElement('div');
    tblWrap.style.cssText = 'overflow-x:auto';
    var COLS = [{l:'Timestamp',w:'160px'},{l:'Admin',w:'140px'},{l:'Action',w:'180px'},{l:'Target',w:'140px'},{l:'Old',w:'minmax(100px,1fr)'},{l:'New',w:'minmax(100px,1fr)'}];
    var tpl = COLS.map(function(c){return c.w;}).join(' ');
    var inner = document.createElement('div'); inner.style.cssText='min-width:900px';
    var hdr = document.createElement('div');
    hdr.style.cssText='display:grid;grid-template-columns:'+tpl+';gap:0 8px;padding-bottom:8px;border-bottom:1px solid var(--border)';
    COLS.forEach(function(c){var h=document.createElement('div');h.style.cssText="font-family:'DM Sans',sans-serif;font-size:10px;font-weight:700;color:var(--text-mid);text-transform:uppercase;letter-spacing:0.08em";h.textContent=c.l;hdr.appendChild(h);});
    inner.appendChild(hdr);
    var MONTHS=['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    umRows.forEach(function(r){
      var d=new Date(r.created_at);
      var pad=function(n){return n<10?'0'+n:String(n);};
      var ts=d.getDate()+' '+MONTHS[d.getMonth()]+' '+d.getFullYear()+' '+pad(d.getHours())+':'+pad(d.getMinutes());
      var row=document.createElement('div');
      row.style.cssText='display:grid;grid-template-columns:'+tpl+';gap:0 8px;padding:6px 0;border-bottom:1px solid rgba(255,255,255,0.04)';
      var cs="font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-mid)";
      var ch="font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-high)";
      function cell(t,s){var el=document.createElement('div');el.style.cssText=s||cs;el.textContent=t||'\u2014';return el;}
      row.appendChild(cell(ts,cs)); row.appendChild(cell(r.admin_name,ch)); row.appendChild(cell(r.action,ch));
      row.appendChild(cell(r.target,cs)); row.appendChild(cell(r.old_value,cs)); row.appendChild(cell(r.new_value,cs));
      inner.appendChild(row);
    });
    tblWrap.appendChild(inner); container.appendChild(tblWrap);
  } catch(e){ container.innerHTML='<div style="color:#dc5050;font-family:\'DM Sans\',sans-serif;font-size:13px">Error: '+esc(e.message)+'</div>'; }
}
