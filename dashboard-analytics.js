// The Culinary Journal — Dashboard Module
// This file is loaded by dashboard.html
// Requires: supabase-config.js to be loaded first

async function loadUMAnalytics(container) {
  container.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)">Loading\u2026</div>';
  try {
    var raw  = await rpc('admin_get_user_analytics', {});
    var data = Array.isArray(raw) ? raw[0] : (raw || {});
    var inactive = await rpc('admin_get_inactive_users', {p_days:90}) || [];
    container.innerHTML = '';
    function mk(tag,s,t){var e=document.createElement(tag);if(s)e.style.cssText=s;if(t!==undefined)e.textContent=t;return e;}
    var css = {
      card:  'background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:12px;padding:20px',
      num:   "font-family:'Cormorant Garamond',serif;font-size:2.2rem;font-weight:700;color:var(--accent);line-height:1",
      label: "font-family:'DM Sans',sans-serif;font-size:10px;font-weight:600;letter-spacing:0.1em;text-transform:uppercase;color:var(--text-mid);margin-top:4px",
      title: "font-family:'Cormorant Garamond',serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:14px"
    };
    // Summary cards
    var row1 = mk('div','display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin-bottom:20px');
    [{num:data.total||0,label:'Total Members'},{num:data.active||0,label:'Active'},{num:data.new_this_month||0,label:'New This Month'},{num:data.deactivated||0,label:'Deactivated'}].forEach(function(c){
      var card=mk('div',css.card); card.appendChild(mk('div',css.num,String(c.num))); card.appendChild(mk('div',css.label,c.label)); row1.appendChild(card);
    });
    container.appendChild(row1);
    var row2 = mk('div','display:grid;grid-template-columns:repeat(4,1fr);gap:14px;margin-bottom:20px');
    [{num:data.flagged||0,label:'Flagged'},{num:data.admins||0,label:'Admins'},{num:data.new_this_week||0,label:'New This Week'},{num:data.inactive_90d||0,label:'Inactive 90d'}].forEach(function(c){
      var card=mk('div',css.card); card.appendChild(mk('div',css.num,String(c.num))); card.appendChild(mk('div',css.label,c.label)); row2.appendChild(card);
    });
    container.appendChild(row2);
    // Plan breakdown + Growth side by side
    var r3 = mk('div','display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-bottom:20px');
    // Plan breakdown
    var planCard = mk('div',css.card); planCard.appendChild(mk('div',css.title,'Plan Breakdown'));
    var planTotal = (data.plan_free||0) + (data.plan_premium||0) || 1;
    [{label:'Free',count:data.plan_free||0,color:'var(--text-mid)'},{label:'Premium',count:data.plan_premium||0,color:'var(--accent)'}].forEach(function(d){
      var pct=Math.round(d.count/planTotal*100);
      var row=mk('div','display:flex;align-items:center;gap:10px;margin-bottom:10px');
      row.appendChild(mk('div','width:10px;height:10px;border-radius:50%;flex-shrink:0;background:'+d.color,''));
      row.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-high);flex:1",d.label));
      var bw=mk('div','flex:2;background:rgba(255,255,255,0.06);border-radius:4px;height:8px;overflow:hidden');
      bw.appendChild(mk('div','height:100%;border-radius:4px;background:'+d.color+';width:'+pct+'%',''));
      row.appendChild(bw);
      row.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-mid);width:80px;text-align:right",d.count+' ('+pct+'%)'));
      planCard.appendChild(row);
    });
    r3.appendChild(planCard);
    // Growth chart
    var gc = mk('div',css.card); gc.appendChild(mk('div',css.title,'Member Growth (Last 6 Months)'));
    var growth = data.growth||[];
    if(growth.length){
      var maxG=Math.max.apply(null,growth.map(function(g){return g.count||0;}))||1;
      growth.forEach(function(g){
        var pct=Math.round((g.count||0)/maxG*100);
        var row=mk('div','display:grid;grid-template-columns:70px 1fr 32px;align-items:center;gap:8px;margin-bottom:8px');
        row.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-high);text-align:right",g.month||''));
        var bw=mk('div','background:rgba(255,255,255,0.06);border-radius:4px;height:14px;overflow:hidden');
        bw.appendChild(mk('div','height:100%;border-radius:4px;background:var(--accent);width:'+pct+'%',''));
        row.appendChild(bw);
        row.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-mid)",String(g.count||0)));
        gc.appendChild(row);
      });
    } else { gc.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-mid)",'No data yet.')); }
    r3.appendChild(gc);
    container.appendChild(r3);
    // Top contributors + deactivation reasons
    var r4 = mk('div','display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-bottom:20px');
    var tc = mk('div',css.card); tc.appendChild(mk('div',css.title,'Top Contributors'));
    var contribs = data.top_contributors||[];
    if(contribs.length){
      contribs.forEach(function(c,i){
        var row=mk('div','display:grid;grid-template-columns:24px 1fr 80px;align-items:center;gap:10px;margin-bottom:8px');
        row.appendChild(mk('div',"font-family:'Cormorant Garamond',serif;font-size:1.1rem;color:var(--accent);text-align:center",String(i+1)));
        row.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-high)",esc(c.full_name||c.username||'\u2014')));
        row.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-mid);text-align:right",(c.recipe_count||0)+' recipes'));
        tc.appendChild(row);
      });
    } else { tc.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-mid)",'No contributions yet.')); }
    r4.appendChild(tc);
    // Deactivation reasons
    var dr = mk('div',css.card); dr.appendChild(mk('div',css.title,'Deactivation Reasons'));
    var reasons = data.deactivation_reasons||[];
    if(reasons.length){
      var maxR=reasons[0].count||1;
      reasons.forEach(function(r){
        var pct=Math.round(r.count/maxR*100);
        var row=mk('div','display:grid;grid-template-columns:1fr 1fr 32px;align-items:center;gap:8px;margin-bottom:8px');
        row.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-high);overflow:hidden;text-overflow:ellipsis;white-space:nowrap",esc(r.reason||'Unknown')));
        var bw=mk('div','background:rgba(255,255,255,0.06);border-radius:4px;height:12px;overflow:hidden');
        bw.appendChild(mk('div','height:100%;border-radius:4px;background:#dc5050;width:'+pct+'%',''));
        row.appendChild(bw);
        row.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-mid)",String(r.count)));
        dr.appendChild(row);
      });
    } else { dr.appendChild(mk('div',"font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-mid)",'No deactivation data yet.')); }
    r4.appendChild(dr);
    container.appendChild(r4);
    // Inactive users
    if(inactive && Array.isArray(inactive) && inactive.length){
      var inactCard=mk('div',css.card+';margin-bottom:20px');
      inactCard.appendChild(mk('div',css.title,'\uD83D\uDCA4 Inactive Members (90+ days) \u2014 '+inactive.length));
      var tblWrap=mk('div','overflow-x:auto');var tbl=mk('table','width:100%;border-collapse:collapse');
      tbl.innerHTML='<thead><tr style="border-bottom:1px solid var(--border)"><th class="ap-th">Member</th><th class="ap-th">Email</th><th class="ap-th">Last Active</th><th class="ap-th">Actions</th></tr></thead>';
      var tbody=document.createElement('tbody');
      inactive.slice(0,20).forEach(function(u){
        var tr=mk('tr','border-bottom:1px solid rgba(255,255,255,0.04)');
        var la=u.last_active_at?new Date(u.last_active_at).toLocaleDateString('en-GB',{day:'numeric',month:'short',year:'numeric'}):'Never';
        tr.innerHTML='<td class="ap-td"><span style="font-size:12px;color:var(--text-high)">@'+esc(u.username||'')+'</span></td>'+
          '<td class="ap-td" style="font-size:12px">'+esc(u.email||'')+'</td>'+
          '<td class="ap-td" style="font-size:12px;color:var(--text-mid)">'+la+'</td>'+
          '<td class="ap-td"></td>';
        var vBtn=mk('button','padding:4px 10px;background:none;border:1px solid var(--border);border-radius:6px;color:var(--text-mid);font-family:DM Sans,sans-serif;font-size:11px;cursor:pointer','View');
        vBtn.addEventListener('click',(function(id){return function(){openUserDetail(id);};})(u.id));
        tr.lastElementChild.appendChild(vBtn);tbody.appendChild(tr);
      });
      tbl.appendChild(tbody);tblWrap.appendChild(tbl);inactCard.appendChild(tblWrap);container.appendChild(inactCard);
    }
  }catch (e) { TcjErr.warn('dashboard-analytics.js:117', e); }
}

// UM Audit Trail

function switchFinanceTab(tab) {
  try {
    localStorage.setItem('tcj_active_finance_tab', tab);
    document.querySelectorAll('#v-finance .ap-inner-tab').forEach(function(t){
      t.classList.toggle('active', t.dataset.tab === tab);
    });
    ['fi-overview','fi-members','fi-pricing','fi-history','fi-interface'].forEach(function(p){
      var el = document.getElementById('upanel-' + p);
      if (el) el.style.display = p === tab ? 'block' : 'none';
    });
    var container = document.getElementById('upanel-' + tab);
    if (!container || container.dataset.built === '1') return;
    container.dataset.built = 'loading';
    if (tab === 'fi-overview') buildFiOverview(container);
    else if (tab === 'fi-members')  buildFiMembers(container);
    else if (tab === 'fi-pricing')  buildFiPricing(container);
    else if (tab === 'fi-history')    buildFiHistory(container);
    else if (tab === 'fi-interface') buildFiInterface(container);
  } catch (e) { TcjErr.warn('dashboard-analytics.js:140', e); }
}

function renderBarChart(containerId, data, colorVar) {
  const el = document.getElementById(containerId);
  if (!el || !data || !data.length) { if(el) el.innerHTML='<div style="padding:20px;text-align:center;font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)">No data yet</div>'; return; }
  const max = Math.max(...data.map(function(d){ return d.value; }));
  el.innerHTML = data.slice(0,10).map(function(d) {
    const pct = max > 0 ? Math.round((d.value/max)*100) : 0;
    const color = colorVar || 'var(--accent)';
    return '<div style="display:flex;align-items:center;gap:10px;margin-bottom:8px">' +
      '<div style="font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);width:120px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;flex-shrink:0">' + escT(d.label) + '</div>' +
      '<div style="flex:1;background:rgba(255,255,255,.05);border-radius:4px;height:18px;overflow:hidden">' +
        '<div style="width:' + pct + '%;height:100%;background:' + color + ';border-radius:4px;transition:width .4s"></div>' +
      '</div>' +
      '<div style="font-family:DM Sans,sans-serif;font-size:12px;font-weight:600;color:var(--text-high);width:30px;text-align:right;flex-shrink:0">' + d.value + '</div>' +
      '</div>';
  }).join('');
}

async function loadIngAnalytics(container) {
  var el = container || document.getElementById('ia-panel');
  if (!el) return;
  el.innerHTML = '<div style="padding:40px;text-align:center;font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)">Loading analytics...</div>';

  var data;
  try {
    var raw = await rpc('admin_get_ingredient_analytics', {});
    data = Array.isArray(raw) ? raw[0] : (raw || {});
    if (!data || !data.total) throw new Error('No data returned. Make sure you have run the analytics SQL in Supabase.');
  } catch(e) {
    el.innerHTML = '<div style="padding:24px;color:#dc5050;font-family:DM Sans,sans-serif;font-size:13px;border:1px solid #dc5050;border-radius:8px;margin:16px"><strong>Analytics Error:</strong> ' + escT(e.message) + '</div>';
    return;
  }

  el.innerHTML = '';
  var total = parseInt(data.total) || 0;

  var css = {
    card:  'background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:12px;padding:20px 24px',
    title: "font-family:'Cormorant Garamond',serif;font-size:1.05rem;font-weight:700;color:var(--text-high);margin-bottom:16px",
    num:   "font-family:'Cormorant Garamond',serif;font-size:2.2rem;font-weight:700;color:var(--accent);line-height:1",
    label: "font-family:'DM Sans',sans-serif;font-size:10px;font-weight:600;letter-spacing:0.1em;text-transform:uppercase;color:var(--text-mid);margin-bottom:4px",
    sub:   "font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-mid);margin-top:4px"
  };

  function mk(tag, style, text) {
    var e = document.createElement(tag);
    if (style) e.style.cssText = style;
    if (text !== undefined) e.textContent = text;
    return e;
  }

  // Summary cards
  var comp = data.completeness || {};
  var compKeys = Object.keys(comp);
  var compSum  = compKeys.reduce(function(s,k){ return s + (parseInt(comp[k])||0); }, 0);
  var compMax  = compKeys.length * total;
  var compPct  = compMax > 0 ? Math.round(compSum / compMax * 100) : 0;
  var withBrand = parseInt(data.with_brand) || 0;
  var vegan = parseInt(data.vegan) || 0;

  var cardRow = mk('div', 'display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin-bottom:24px');
  [
    { icon: '\u{1F9C2}', num: total,     label: 'Total Ingredients' },
    { icon: '\u{1F3F7}', num: withBrand, label: 'Brands Mapped',       sub: total > 0 ? Math.round(withBrand/total*100)+'% coverage' : '' },
    { icon: '\u{1F49A}', num: vegan,     label: 'Vegan Ingredients',    sub: total > 0 ? Math.round(vegan/total*100)+'% of total' : '' },
    { icon: '\u2705',    num: compPct+'%', label: 'Data Completion',    sub: compSum + ' of ' + compMax + ' fields filled' }
  ].forEach(function(c) {
    var card = mk('div', css.card);
    card.appendChild(mk('div', 'font-size:1.6rem;margin-bottom:8px', c.icon));
    card.appendChild(mk('div', css.num, String(c.num)));
    card.appendChild(mk('div', css.label, c.label));
    if (c.sub) card.appendChild(mk('div', css.sub, c.sub));
    cardRow.appendChild(card);
  });
  el.appendChild(cardRow);

  // Category distribution - full width
  var catCard = mk('div', css.card + ';margin-bottom:24px');
  catCard.appendChild(mk('div', css.title, 'Ingredients by Category'));
  var cats = data.by_category || [];
  if (cats.length) {
    var maxC = cats[0].count || 1;
    var cg = mk('div', 'display:grid;grid-template-columns:170px 1fr 44px;gap:6px 10px;align-items:center');
    cats.forEach(function(c) {
      var pct = Math.round(c.count / maxC * 100);
      cg.appendChild(mk('div', "font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-high);text-align:right;overflow:hidden;text-overflow:ellipsis;white-space:nowrap", c.name || 'Uncategorised'));
      var bw = mk('div', 'background:rgba(255,255,255,0.06);border-radius:4px;height:16px;overflow:hidden');
      var bar = mk('div', 'height:100%;border-radius:4px;background:var(--accent);width:' + pct + '%', '');
      bw.appendChild(bar); cg.appendChild(bw);
      cg.appendChild(mk('div', "font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-mid)", String(c.count)));
    });
    catCard.appendChild(cg);
  } else {
    catCard.appendChild(mk('div', css.sub, 'No category data yet.'));
  }
  el.appendChild(catCard);

  // Dietary + Units row
  var r1 = mk('div', 'display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-bottom:24px');

  var dietCard = mk('div', css.card);
  dietCard.appendChild(mk('div', css.title, 'Dietary Profile'));
  var veg = parseInt(data.vegetarian) || 0;
  var liq = parseInt(data.liquid) || 0;
  var nonveg = Math.max(0, total - Math.max(vegan, veg) - liq);
  [
    { label: 'Vegan',      count: vegan,  color: '#4caf76' },
    { label: 'Vegetarian', count: veg,    color: '#81c784' },
    { label: 'Liquid',     count: liq,    color: '#5B8FD4' },
    { label: 'Non-Veg',    count: nonveg, color: '#C4973B' }
  ].forEach(function(d) {
    var pct = total > 0 ? Math.round(d.count / total * 100) : 0;
    var row = mk('div', 'display:flex;align-items:center;gap:10px;margin-bottom:10px');
    row.appendChild(mk('div', 'width:10px;height:10px;border-radius:50%;flex-shrink:0;background:' + d.color, ''));
    row.appendChild(mk('div', "font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-high);flex:1", d.label));
    var bw = mk('div', 'flex:2;background:rgba(255,255,255,0.06);border-radius:4px;height:8px;overflow:hidden');
    bw.appendChild(mk('div', 'height:100%;border-radius:4px;background:' + d.color + ';width:' + pct + '%', ''));
    row.appendChild(bw);
    row.appendChild(mk('div', "font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-mid);width:70px;text-align:right", d.count + ' (' + pct + '%)'));
    dietCard.appendChild(row);
  });
  r1.appendChild(dietCard);

  var unitCard = mk('div', css.card);
  unitCard.appendChild(mk('div', css.title, 'Top Units Used'));
  var units = data.by_unit || [];
  var uColors = ['#C4973B','#5B8FD4','#4caf76','#E86D4A','#9B59B6','#1ABC9C','#E74C3C','#F39C12','#3498DB','#2ECC71','#E67E22','#9C27B0','#00BCD4','#FF5722','#607D8B'];
  if (units.length) {
    var maxU = units[0].count || 1;
    units.forEach(function(u, i) {
      var pct = Math.round(u.count / maxU * 100);
      var row = mk('div', 'display:grid;grid-template-columns:80px 1fr 36px;align-items:center;gap:8px;margin-bottom:6px');
      row.appendChild(mk('div', "font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-high);text-align:right", u.name || ''));
      var bw = mk('div', 'background:rgba(255,255,255,0.06);border-radius:4px;height:14px;overflow:hidden');
      bw.appendChild(mk('div', 'height:100%;border-radius:4px;background:' + uColors[i % uColors.length] + ';width:' + pct + '%', ''));
      row.appendChild(bw);
      row.appendChild(mk('div', "font-family:'DM Sans',sans-serif;font-size:10px;color:var(--text-mid)", String(u.count)));
      unitCard.appendChild(row);
    });
  } else { unitCard.appendChild(mk('div', css.sub, 'No unit data yet.')); }
  r1.appendChild(unitCard);
  el.appendChild(r1);

  // Allergen + Completeness row
  var r2 = mk('div', 'display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-bottom:24px');

  var algCard = mk('div', css.card);
  algCard.appendChild(mk('div', css.title, 'Allergen Distribution'));
  var algs = data.by_allergen || [];
  if (algs.length) {
    var maxA = algs[0].count || 1;
    algs.forEach(function(a) {
      var pct = Math.round(a.count / maxA * 100);
      var row = mk('div', 'display:grid;grid-template-columns:120px 1fr 36px;align-items:center;gap:8px;margin-bottom:6px');
      row.appendChild(mk('div', "font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-high);text-align:right", a.name || ''));
      var bw = mk('div', 'background:rgba(255,255,255,0.06);border-radius:4px;height:14px;overflow:hidden');
      bw.appendChild(mk('div', 'height:100%;border-radius:4px;background:#E86D4A;width:' + pct + '%', ''));
      row.appendChild(bw);
      row.appendChild(mk('div', "font-family:'DM Sans',sans-serif;font-size:10px;color:var(--text-mid)", String(a.count)));
      algCard.appendChild(row);
    });
  } else { algCard.appendChild(mk('div', css.sub, 'No allergen data yet.')); }
  r2.appendChild(algCard);

  var cmpCard = mk('div', css.card);
  cmpCard.appendChild(mk('div', css.title, 'Data Completeness'));
  compKeys.forEach(function(field) {
    var filled = parseInt(comp[field]) || 0;
    var pct    = total > 0 ? Math.round(filled / total * 100) : 0;
    var color  = pct >= 90 ? '#4caf76' : pct >= 60 ? '#C4973B' : '#dc5050';
    var row = mk('div', 'display:grid;grid-template-columns:140px 1fr 40px;align-items:center;gap:8px;margin-bottom:8px');
    row.appendChild(mk('div', "font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-high)", field));
    var bw = mk('div', 'background:rgba(255,255,255,0.06);border-radius:4px;height:8px;overflow:hidden');
    bw.appendChild(mk('div', 'height:100%;border-radius:4px;background:' + color + ';width:' + pct + '%', ''));
    row.appendChild(bw);
    row.appendChild(mk('div', "font-family:'DM Sans',sans-serif;font-size:10px;font-weight:600;color:" + color, pct + '%'));
    cmpCard.appendChild(row);
  });
  r2.appendChild(cmpCard);
  el.appendChild(r2);

  // Needs Attention
  var att = data.needs_attention || [];
  if (att.length) {
    var attCard = mk('div', css.card);
    attCard.appendChild(mk('div', css.title, '\u26a0 Needs Attention \u2014 ' + att.length + ' ingredient' + (att.length === 1 ? '' : 's') + ' missing Category or Unit'));
    var tbl = mk('div', 'display:grid;grid-template-columns:50px 1fr 130px 130px;gap:0 8px');
    ['ID', 'Ingredient Name', 'Category', 'Unit'].forEach(function(h) {
      tbl.appendChild(mk('div', "font-family:'DM Sans',sans-serif;font-size:10px;font-weight:700;color:var(--text-mid);text-transform:uppercase;letter-spacing:0.08em;padding-bottom:8px;border-bottom:1px solid var(--border)", h));
    });
    att.forEach(function(r) {
      var rs = "font-family:'DM Sans',sans-serif;font-size:12px;padding:7px 0;border-bottom:1px solid rgba(255,255,255,0.04)";
      tbl.appendChild(mk('div', rs + ';color:var(--text-mid)', String(r.ID || r.id || '')));
      tbl.appendChild(mk('div', rs + ';color:var(--text-high)', r['Ingredient Name'] || r.ingredient_name || ''));
      tbl.appendChild(mk('div', rs + (r.missing_cat ? ';color:#dc5050;font-weight:600' : ';color:var(--text-mid)'), r.missing_cat ? '\u2715 Missing' : 'OK'));
      tbl.appendChild(mk('div', rs + (r.missing_unit ? ';color:#dc5050;font-weight:600' : ';color:var(--text-mid)'), r.missing_unit ? '\u2715 Missing' : 'OK'));
    });
    attCard.appendChild(tbl);
    if (att.length === 20) attCard.appendChild(mk('div', "font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-mid);margin-top:10px", 'Showing first 20. Fix these and reload to see more.'));
    el.appendChild(attCard);
  } else {
    var ok = mk('div', css.card + ';text-align:center;padding:32px');
    ok.appendChild(mk('div', 'font-size:2rem;margin-bottom:8px', '\u2705'));
    ok.appendChild(mk('div', "font-family:'DM Sans',sans-serif;font-size:13px;color:#4caf76", 'All ingredients have a Category and Unit assigned.'));
    el.appendChild(ok);
  }
}



// ── INGREDIENTS TABS ─────────────────────────────────────────────
var currentIngTab = 'all';


// ── RECYCLE BIN ───────────────────────────────────────────────────