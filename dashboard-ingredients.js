// The Culinary Journal — Dashboard Module
// This file is loaded by dashboard.html
// Requires: supabase-config.js to be loaded first

function _imGet(key, def) {
  try { var v=localStorage.getItem(key); return v?JSON.parse(v):def; } catch(e){return def;}
}

function _imSet(key,val){
  try{ localStorage.setItem(key,JSON.stringify(val)); }
  catch(e){ console.error('Storage save failed for key '+key+':',e); }
}

function makeColumnsResizable(table){
  if(!table) return;
  table.querySelectorAll('th').forEach(function(th){
    if(th.querySelector('.col-resizer')) return; // already done
    var resizer = document.createElement('div');
    resizer.className = 'col-resizer';
    th.appendChild(resizer);
    var startX, startW;
    resizer.addEventListener('mousedown', function(e){
      startX = e.pageX;
      startW = th.offsetWidth;
      resizer.classList.add('resizing');
      document.body.style.cursor = 'col-resize';
      function onMove(e){
        var w = Math.max(60, startW + (e.pageX - startX));
        th.style.width = w+'px';
        th.style.minWidth = w+'px';
      }
      function onUp(){
        resizer.classList.remove('resizing');
        document.body.style.cursor = '';
        document.removeEventListener('mousemove', onMove);
        document.removeEventListener('mouseup', onUp);
      }
      document.addEventListener('mousemove', onMove);
      document.addEventListener('mouseup', onUp);
      e.preventDefault();
    });
  });
}

function loadImSettings(){
  try{ _imSettings=JSON.parse(localStorage.getItem('tcj_im_settings')||'{}'); }catch(e){_imSettings={};}
  STD_COLS.forEach(function(col){
    var s=_imSettings.cols&&_imSettings.cols[col.key];
    if(s){ if(s.label)col.label=s.label; if(s.type)col.type=s.type; if(typeof s.visible!=='undefined')_colVis[col.key]=s.visible; }
  });
  if(_imSettings.pageSize) ING_PAGE_SIZE=parseInt(_imSettings.pageSize)||50;
  if(_imSettings.sortCol)  _ingSortCol=_imSettings.sortCol;
  if(_imSettings.sortDir)  _ingSortDir=_imSettings.sortDir;
  CATS_LIST.length=0; getCats().forEach(function(c){CATS_LIST.push(c);});
}

function saveImSettings(settings){
  _imSettings=settings;
  localStorage.setItem('tcj_im_settings',JSON.stringify(settings));
  loadImSettings();
  // Reload custom column types from localStorage in case IM Interface changed them
  var _savedTypes=JSON.parse(localStorage.getItem('tcj_extra_col_types')||'{}');
  Object.keys(_savedTypes).forEach(function(k){_extraColTypes[k]=_savedTypes[k];});
  buildTableHeader();
  buildColVisPanel();
  renderIngFiltered();
  // Reload from DB so new page size and sort take effect immediately
  if(typeof loadIngredients==='function') loadIngredients(1);
  auditLog('IM Interface > Column Settings','Settings Saved',null,null,null,'Column labels/types/visibility updated');
}

// ── Style helpers ────────────────────────────────────────────────

// ── Custom tooltip helper ─────────────────────────────────────────

function _csvRow(arr){
  return arr.map(function(v){
    var s=String(v==null?'':v);
    return (s.includes(',')||s.includes('"')||s.includes('\n'))?'"'+s.replace(/"/g,'""')+'"':s;
  }).join(',')+'\n';
}

function _downloadCSV(filename, rows){
  var csv=rows.map(_csvRow).join('');
  var blob=new Blob([csv],{type:'text/csv'});
  var a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download=filename;a.click();URL.revokeObjectURL(a.href);
}

// ── Import toolbar (Export + Import buttons) ─────────────────────

function exportCategoriesCSV(){
  var cats=getCats(); var subs=getSubCats(); var meta=getCatMeta();
  var rows=[['ID','Category','Category Required','Category Active','Sub Category','Notes']];
  var id=1;
  cats.slice().sort().forEach(function(cat){
    var m=meta[cat]||{};
    var hasSubs=(subs[cat]||[]).length>0;
    var req=m.required||(hasSubs?'Yes':'No');
    var act=m.active||'Yes';
    var catSubs=(subs[cat]||[]).slice().sort();
    if(catSubs.length===0){
      rows.push([id++,cat,req,act,'','']);
    } else {
      catSubs.forEach(function(sub){ rows.push([id++,cat,req,act,sub,'']); });
    }
  });
  _downloadCSV('categories-subcategories.csv',rows);
  auditLog('IM Interface > Reference Data','Export','Categories & Sub Categories',null,null,(rows.length-1)+' rows exported');
}

// ── Categories + Sub Categories Import ───────────────────────────

function getBrands(){ return _imGet('tcj_brands',[]); }



// ── Column Settings Tab ──────────────────────────────────────────

function buildColumnSettingsTab(container){
  var settings=JSON.parse(localStorage.getItem('tcj_im_settings')||'{}');
  if(!settings.cols)settings.cols={};
  if(!settings.pageSize)settings.pageSize=ING_PAGE_SIZE||50;
  if(!settings.sortCol)settings.sortCol='ID';
  if(!settings.sortDir)settings.sortDir='asc';

  var LOCKED=['ID','Ingredient Name','Category'];
  var TYPE_OPTS=[{value:'text',label:'Text'},{value:'yesno',label:'Yes / No'},{value:'number',label:'Number'},{value:'currency',label:'Currency'},{value:'percentage',label:'Percentage'},{value:'fraction',label:'Fraction'},{value:'category',label:'Category'}];

  container.appendChild(makeExpandCollapseBar(container));

  // Standard Columns
  makeAccordion('Standard Column Settings', function(body){
    var grid=document.createElement('div');
    grid.style.cssText='display:grid;grid-template-columns:160px 1fr 110px 80px;gap:6px 12px;align-items:center';
    ['KEY','DISPLAY LABEL','TYPE','VISIBLE'].forEach(function(t){ var h=document.createElement('div');h.style.cssText=_imS.hdr;h.textContent=t;grid.appendChild(h); });

    var ALL=[{key:'ID',label:'ID',type:'number'}].concat(STD_COLS);
    ALL.forEach(function(col){
      var s=settings.cols[col.key]||{};
      var locked=LOCKED.includes(col.key)||col.key==='ID';

      var kd=document.createElement('div');kd.style.cssText=_imS.inp+';background:rgba(255,255,255,0.03);color:var(--text-mid);overflow:hidden;text-overflow:ellipsis;white-space:nowrap';kd.textContent=col.key;kd.title=col.key;

      var li=document.createElement('input');li.type='text';li.value=s.label||col.label;li.disabled=col.key==='ID';
      li.style.cssText=_imS.inp+(col.key==='ID'?';opacity:0.4':'');
      li.addEventListener('change',function(){ if(!settings.cols[col.key])settings.cols[col.key]={};settings.cols[col.key].label=this.value.trim()||col.label; });

      var ts=document.createElement('select');ts.disabled=locked;ts.style.cssText=_imS.sel+(locked?';opacity:0.4':'');
      TYPE_OPTS.forEach(function(opt){ var o=document.createElement('option');o.value=opt.value;o.textContent=opt.label;o.selected=(s.type||col.type)===opt.value;ts.appendChild(o); });
      ts.addEventListener('change',function(){ if(!settings.cols[col.key])settings.cols[col.key]={};settings.cols[col.key].type=this.value; });

      var vw=document.createElement('div');vw.style.cssText='display:flex;align-items:center;justify-content:center';
      if(col.key!=='ID'){
        var vc=document.createElement('input');vc.type='checkbox';vc.style.cssText='width:16px;height:16px;accent-color:var(--accent);cursor:pointer';
        vc.checked=typeof s.visible!=='undefined'?s.visible:(_colVis[col.key]!==false);
        vc.addEventListener('change',function(){ if(!settings.cols[col.key])settings.cols[col.key]={};settings.cols[col.key].visible=this.checked; });
        vw.appendChild(vc);
      } else { var lk=document.createElement('span');lk.textContent='🔒';lk.style.cssText='font-size:11px;opacity:0.4';vw.appendChild(lk); }
      grid.appendChild(kd);grid.appendChild(li);grid.appendChild(ts);grid.appendChild(vw);
    });
    body.appendChild(grid);
  }, true, container);

  // Custom Columns
  makeAccordion('Custom Columns', function(body){
    if(!_extraColKeys.length){
      var msg=document.createElement('div');msg.style.cssText=_imS.label;msg.textContent='No custom columns yet. Use + Column in the ingredient table.';body.appendChild(msg);return;
    }
    var cg=document.createElement('div');cg.style.cssText='display:grid;grid-template-columns:1fr 100px 1fr 70px;gap:6px 10px;align-items:center';
    ['NAME','TYPE','RENAME TO','ACTIONS'].forEach(function(t){ var h=document.createElement('div');h.style.cssText=_imS.hdr;h.textContent=t;cg.appendChild(h); });
    _extraColKeys.forEach(function(k){
      var nd=document.createElement('div');nd.style.cssText=_imS.inp+';background:rgba(255,255,255,0.03);color:var(--accent)';nd.textContent=k;
      var ts=document.createElement('select');ts.style.cssText=_imS.sel;
      [{value:'text',label:'Text'},{value:'yesno',label:'Yes/No'},{value:'number',label:'Number'},{value:'currency',label:'Currency'},{value:'percentage',label:'Percentage'},{value:'fraction',label:'Fraction'}].forEach(function(opt){ var o=document.createElement('option');o.value=opt.value;o.textContent=opt.label;o.selected=(_extraColTypes[k]||'text')===opt.value;ts.appendChild(o); });
      ts.addEventListener('change',function(){ _extraColTypes[k]=this.value;var types=JSON.parse(localStorage.getItem('tcj_extra_col_types')||'{}');types[k]=this.value;localStorage.setItem('tcj_extra_col_types',JSON.stringify(types));buildTableHeader();renderIngFiltered(); });
      var ri=document.createElement('input');ri.type='text';ri.placeholder='New name…';ri.style.cssText=_imS.inp;
      var acts=document.createElement('div');acts.style.cssText='display:flex;gap:4px';
      var rb=document.createElement('button');rb.textContent='↩';rb.title='Rename';rb.style.cssText='padding:4px 8px;background:none;border:1px solid var(--accent);border-radius:6px;color:var(--accent);font-size:11px;cursor:pointer';
      rb.addEventListener('click',(function(key,inp){return function(){ var nv=inp.value.trim();if(!nv||nv===key){inp.focus();return;} renameExtraColumn(key);loadIMInterface(); };})(k,ri));
      var db=document.createElement('button');db.textContent='🗑';db.title='Delete';db.style.cssText=_imS.delBtn;
      db.addEventListener('click',(function(key){return function(){ deleteExtraColumn(key);loadIMInterface(); };})(k));
      acts.appendChild(rb);acts.appendChild(db);
      cg.appendChild(nd);cg.appendChild(ts);cg.appendChild(ri);cg.appendChild(acts);
    });
    body.appendChild(cg);
  }, true, container);

  // Table Defaults
  makeAccordion('Table Defaults', function(body){
    var dg=document.createElement('div');dg.style.cssText='display:grid;grid-template-columns:160px 1fr;gap:10px 16px;align-items:center;max-width:420px';
    function addRow(label,input){ var l=document.createElement('div');l.style.cssText=_imS.label;l.textContent=label;dg.appendChild(l);dg.appendChild(input); }

    var ps=document.createElement('select');ps.style.cssText=_imS.sel.replace('width:100%;','')+';width:120px';
    [{v:25,l:'25'},{v:50,l:'50'},{v:100,l:'100'},{v:200,l:'200'},{v:500,l:'500'},{v:99999,l:'All'}].forEach(function(opt){
      var o=document.createElement('option');o.value=opt.v;o.textContent=opt.l;
      o.selected=(settings.pageSize||50)===opt.v;
      ps.appendChild(o);
    });
    ps.addEventListener('change',function(){settings.pageSize=parseInt(this.value)||50;});
    addRow('Rows per page',ps);

    var sc=document.createElement('select');sc.style.cssText=_imS.sel.replace('width:100%;','')+';width:auto';
    ['ID','Ingredient Name','Category','Sub Category'].forEach(function(c){ var o=document.createElement('option');o.value=c;o.textContent=c;o.selected=settings.sortCol===c;sc.appendChild(o); });
    sc.addEventListener('change',function(){settings.sortCol=this.value;});
    addRow('Default sort',sc);

    var sd=document.createElement('select');sd.style.cssText=sc.style.cssText;
    [{v:'asc',l:'A → Z'},{v:'desc',l:'Z → A'}].forEach(function(o){ var opt=document.createElement('option');opt.value=o.v;opt.textContent=o.l;opt.selected=settings.sortDir===o.v;sd.appendChild(opt); });
    sd.addEventListener('change',function(){settings.sortDir=this.value;});
    addRow('Direction',sd);
    body.appendChild(dg);
  }, false, container);

  // Save / Reset
  var sw=document.createElement('div');sw.style.cssText='margin-top:16px;display:flex;gap:10px;align-items:center';
  var sb=document.createElement('button');sb.textContent='Save Column Settings';sb.style.cssText=_imS.btn+';background:var(--accent);color:#fff;padding:10px 24px';
  var sm=document.createElement('span');sm.style.cssText='font-family:DM Sans,sans-serif;font-size:12px;color:#4caf76;display:none';sm.textContent='✓ Saved';
  sb.addEventListener('click',function(){
    sb.textContent='Saving...';
    sb.disabled=true;
    try{
      saveImSettings(settings);
      sb.textContent='✓ Saved';
      sb.style.background='#2d5a2d';
      setTimeout(function(){
        sb.textContent='Save Column Settings';
        sb.style.background='var(--accent)';
        sb.disabled=false;
      },2500);
    }catch(e){
      sb.textContent='Save Column Settings';
      sb.style.background='var(--accent)';
      sb.disabled=false;
      alert('Save failed: '+e.message);
    }
  });
  var rb=document.createElement('button');rb.textContent='Reset to Defaults';rb.style.cssText=_imS.btn+';background:none;border:1px solid var(--border);color:var(--text-mid);padding:10px 18px';
  rb.addEventListener('click',function(){if(!confirm('Reset all column settings to defaults?'))return;localStorage.removeItem('tcj_im_settings');location.reload();});
  sw.appendChild(sb);sw.appendChild(rb);sw.appendChild(sm);container.appendChild(sw);
}

// ── Recycle Bin (embedded) ───────────────────────────────────────

async function restoreDeletedColumn(deletedKey, originalName) {
  if (!confirm('Restore column "' + originalName + '"?\nAll ' + deletedKey + ' data will become visible again under "' + originalName + '".')) return;
  try {
    await rpc('admin_rename_extra_field', { p_old_key: deletedKey, p_new_key: originalName });
    var meta = JSON.parse(localStorage.getItem('tcj_deleted_meta') || '{}'); delete meta[deletedKey]; localStorage.setItem('tcj_deleted_meta', JSON.stringify(meta));
    auditLog('IM Interface > Recycle Bin','Column Restored',originalName,deletedKey,originalName);
    // Add back to _extraColKeys
    if (!_extraColKeys.includes(originalName)) {
      _extraColKeys.push(originalName);
      var stored = JSON.parse(localStorage.getItem('tcj_extra_cols') || '[]');
      if (!stored.includes(originalName)) { stored.push(originalName); localStorage.setItem('tcj_extra_cols', JSON.stringify(stored)); }
      _colVis['extra:' + originalName] = true;
    }
    await loadIngredients(ingPage);
    loadIngRecycleBin();
    buildColVisPanel();
  } catch(e) { alert('Error: ' + e.message); }
}

async function permanentlyDeleteColumn(deletedKey, originalName, count) {
  var meta = JSON.parse(localStorage.getItem('tcj_deleted_meta') || '{}'); delete meta[deletedKey]; localStorage.setItem('tcj_deleted_meta', JSON.stringify(meta));
  if (!confirm('PERMANENTLY delete all "' + originalName + '" data?\n' + count + ' ingredient row' + (count===1?'':'s') + ' will be affected.\nThis cannot be undone.')) return;
  try {
    await rpc('admin_delete_extra_field', { p_key: deletedKey });
    auditLog('IM Interface > Recycle Bin','Column Permanently Deleted',originalName,deletedKey,null,'Removed from '+count+' ingredient rows');
    loadIngRecycleBin();
  } catch(e) { alert('Error: ' + e.message); }
}

async function buildBrandsTab(container){
  container.innerHTML='';

  // Header bar: Import / Export / Add New
  var headerBar=document.createElement('div');
  headerBar.style.cssText='display:flex;gap:8px;align-items:center;margin-bottom:16px;flex-wrap:wrap';

  // Export
  var expBtn=document.createElement('button');
  expBtn.textContent='⬇ Export CSV';
  expBtn.style.cssText="padding:6px 14px;background:none;border:1px solid var(--border);border-radius:6px;font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-mid);cursor:pointer";
  expBtn.addEventListener('click',exportBrandsCSV);

  // Import
  var impBtn=document.createElement('button');
  impBtn.textContent='⬆ Import CSV';
  impBtn.style.cssText="padding:6px 14px;background:none;border:1px solid var(--accent);border-radius:6px;font-family:'DM Sans',sans-serif;font-size:11px;color:var(--accent);cursor:pointer";
  var brandFileIn=document.createElement('input');brandFileIn.type='file';brandFileIn.accept='.csv';brandFileIn.style.display='none';
  brandFileIn.addEventListener('change',function(){
    if(!this.files[0])return;
    Papa.parse(this.files[0],{header:true,skipEmptyLines:true,complete:function(r){importBrandsCSV(r.data,r.meta.fields||[],container);}});
    this.value='';
  });
  impBtn.addEventListener('click',function(){brandFileIn.click();});

  // Add New
  var addBtn=document.createElement('button');
  addBtn.textContent='+ Add Mapping';
  addBtn.style.cssText="padding:6px 16px;background:var(--accent);border:none;border-radius:6px;font-family:'DM Sans',sans-serif;font-size:11px;font-weight:600;color:#fff;cursor:pointer";
  addBtn.addEventListener('click',function(){openBrandForm(null,container);});

  // Sync from All Ingredients
  var syncBtn=document.createElement('button');
  syncBtn.textContent='⟳ Sync from All Ingredients';
  syncBtn.title='Pulls CJ Recommended Brand values from every ingredient and creates brand mappings automatically. Skips brands already mapped.';
  syncBtn.style.cssText="padding:6px 14px;background:none;border:1px solid var(--border);border-radius:6px;font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-mid);cursor:pointer";
  syncBtn.addEventListener('click',async function(){
    if(!confirm('This will sync all CJ Recommended Brand values from All Ingredients into Brand Mapping.\n\nNew brands will be added. Existing mappings will be updated with the latest ingredient data. Continue?'))return;
    syncBtn.disabled=true;syncBtn.textContent='Syncing…';
    try{
      var n=await rpc('admin_sync_brands_from_ingredients',{});
      var tbody=document.getElementById('brand-tbody');
      if(tbody)await loadBrandsTable(tbody);
      var status=document.getElementById('brand-status');
      if(status){status.textContent='✓ '+n+' brand'+(n===1?'':'s')+' imported from All Ingredients';setTimeout(function(){status.textContent='';},4000);}
      auditLog('IM Interface > Reference Data','Brand Sync',null,null,null,n+' brands synced from ingredients');
    }catch(e){alert('Sync failed: '+e.message);}
    finally{syncBtn.disabled=false;syncBtn.textContent='⟳ Sync from All Ingredients';}
  });

  headerBar.appendChild(expBtn);headerBar.appendChild(impBtn);headerBar.appendChild(brandFileIn);headerBar.appendChild(syncBtn);headerBar.appendChild(addBtn);
  container.appendChild(headerBar);

  // Form area (hidden by default)
  var formWrap=document.createElement('div');
  formWrap.id='brand-form-wrap';formWrap.style.display='none';
  container.appendChild(formWrap);

  // Status
  var statusEl=document.createElement('div');
  statusEl.id='brand-status';statusEl.style.cssText="font-family:'DM Sans',sans-serif;font-size:12px;color:#4caf76;min-height:20px;margin-bottom:8px";
  container.appendChild(statusEl);

  // Table
  var tableWrap=document.createElement('div');tableWrap.style.cssText='overflow-x:auto';
  var tbl=document.createElement('table');
  tbl.style.cssText='width:100%;border-collapse:collapse;font-family:DM Sans,sans-serif;font-size:12px';
  var thead=document.createElement('thead');
  var COLS=['ID','Brand Name','Ingredient Name','Category','Sub Category','Notes','Active','Actions'];
  var _bTips={
    'Active':'Active = Yes means this brand mapping is live and will be used in recipe parsing and grocery lists. Active = No hides it without deleting it.',
    'Actions':'Edit a mapping to correct it, or delete it permanently.'
  };
  thead.innerHTML='<tr>'+COLS.map(function(h){
    var tip=_bTips[h]?(' title="'+_bTips[h]+'" style="cursor:help;border-bottom:1px dotted var(--text-mid)"'):'';
    return '<th style="text-align:left;padding:8px 10px;border-bottom:1px solid var(--border);font-size:10px;font-weight:700;letter-spacing:0.08em;text-transform:uppercase;color:var(--text-mid);white-space:nowrap"><span'+tip+'>'+h+'</span></th>';
  }).join('')+'</tr>';
  var tbody=document.createElement('tbody');tbody.id='brand-tbody';
  tbl.appendChild(thead);tbl.appendChild(tbody);tableWrap.appendChild(tbl);
  container.appendChild(tableWrap);

  await loadBrandsTable(tbody);
}

async function loadBrandsTable(tbody){
  if(!tbody)tbody=document.getElementById('brand-tbody');
  tbody.innerHTML='<tr><td colspan="8" style="padding:20px;text-align:center;color:var(--text-mid)">Loading…</td></tr>';
  try{
    var rows=await rpc('admin_get_brand_mappings',{});
    if(!rows||!rows.length){
      tbody.innerHTML='<tr><td colspan="8" style="padding:20px;text-align:center;color:var(--text-mid)">No brand mappings yet. Use the ⧳ Sync button to import from All Ingredients.</td></tr>';
      return;
    }
    tbody.innerHTML='';
    rows.forEach(function(r,i){
      var tr=document.createElement('tr');
      tr.style.cssText='border-bottom:1px solid var(--border);transition:background 0.1s';
      tr.addEventListener('mouseenter',function(){this.style.background='rgba(255,255,255,0.03)';});
      tr.addEventListener('mouseleave',function(){this.style.background='';});
      function td(val,bold){
        var t=document.createElement('td');
        t.style.cssText='padding:8px 10px;color:var(--text-'+(bold?'high':'mid')+');white-space:nowrap;overflow:hidden;max-width:160px;text-overflow:ellipsis';
        t.textContent=val||'—';t.title=val||'';return t;
      }
      var activePill=document.createElement('span');
      activePill.style.cssText='padding:2px 8px;border-radius:10px;font-size:10px;font-weight:600;background:'+(r.active?'rgba(76,175,118,0.15)':'rgba(220,80,80,0.15)')+';color:'+(r.active?'#4caf76':'#dc5050');
      activePill.textContent=r.active?'Yes':'No';
      var actTd=document.createElement('td');actTd.style.cssText='padding:8px 10px';actTd.appendChild(activePill);

      var actionTd=document.createElement('td');actionTd.style.cssText='padding:8px 10px';
      var editBtn=document.createElement('button');
      editBtn.textContent='Edit';
      editBtn.style.cssText='padding:4px 10px;background:none;border:1px solid var(--border);border-radius:5px;color:var(--text-mid);font-size:11px;cursor:pointer;margin-right:4px';
      editBtn.addEventListener('click',function(){openBrandForm(r);});
      var delBtn=document.createElement('button');
      delBtn.textContent='Delete';
      delBtn.style.cssText='padding:4px 10px;background:none;border:1px solid #dc5050;border-radius:5px;color:#dc5050;font-size:11px;cursor:pointer';
      delBtn.addEventListener('click',function(){deleteBrandRow(r.id,tbody,null);});
      actionTd.appendChild(editBtn);actionTd.appendChild(delBtn);

      tr.appendChild(td(r.id));
      tr.appendChild(td(r.brand_name,true));
      tr.appendChild(td(r.generic_name,true));
      tr.appendChild(td(r.category));
      tr.appendChild(td(r.sub_category));
      tr.appendChild(td(r.notes));
      tr.appendChild(actTd);
      tr.appendChild(actionTd);
      tbody.appendChild(tr);
    });
  }catch(e){
    tbody.innerHTML='<tr><td colspan="8" style="padding:20px;text-align:center;color:#dc5050">'+escT(e.message||'Failed to load brand mappings.')+'</td></tr>';
  }
}

function openBrandForm(r){
  var wrap=document.getElementById('brand-form-wrap');
  if(!wrap)return;
  wrap.innerHTML='';wrap.style.display='block';
  wrap.scrollIntoView({behavior:'smooth',block:'start'});
  var isEdit=r&&r.id;
  var form=document.createElement('div');
  form.style.cssText='background:rgba(255,255,255,0.03);border:1px solid var(--border);border-radius:10px;padding:16px;margin-bottom:16px';

  var title=document.createElement('div');
  title.style.cssText="font-family:'Cormorant Garamond',serif;font-size:1rem;font-weight:700;color:var(--text-high);margin-bottom:12px";
  title.textContent=isEdit?'Edit Brand Mapping':'Add Brand Mapping';
  form.appendChild(title);

  var grid=document.createElement('div');
  grid.style.cssText='display:grid;grid-template-columns:1fr 1fr 1fr 1fr;gap:10px;margin-bottom:12px';

  function field(lbl,val,ph,required){
    var w=document.createElement('div');
    var l=document.createElement('div');l.style.cssText=_imS.label+';margin-bottom:4px';l.textContent=lbl+(required?' *':'');
    var inp=document.createElement('input');inp.type='text';inp.value=val||'';inp.placeholder=ph||'';
    inp.style.cssText=_imS.inp;
    w.appendChild(l);w.appendChild(inp);grid.appendChild(w);
    return inp;
  }
  function selectField(lbl,opts,val){
    var w=document.createElement('div');
    var l=document.createElement('div');l.style.cssText=_imS.label+';margin-bottom:4px';l.textContent=lbl;
    var sel=document.createElement('select');sel.style.cssText=_imS.sel;
    var blank=document.createElement('option');blank.value='';blank.textContent='— Select —';sel.appendChild(blank);
    opts.forEach(function(o){var opt=document.createElement('option');opt.value=o;opt.textContent=o;opt.selected=val===o;sel.appendChild(opt);});
    w.appendChild(l);w.appendChild(sel);grid.appendChild(w);
    return sel;
  }

  var fBrand   = field('Brand Name',      r&&r.brand_name,   'e.g. Dalda',         true);
  var fGeneric = field('Generic Name',    r&&r.generic_name, 'e.g. Ghee',          true);
  var fCat     = selectField('Category',  getCats(),         r&&r.category);
  var fSubCat  = selectField('Sub Category', [], r&&r.sub_category);

  // Populate sub-cats based on selected category
  function updateSubCats(){
    var cat=fCat.value;var subs=getSubCats()[cat]||[];
    fSubCat.innerHTML='';
    var blank=document.createElement('option');blank.value='';blank.textContent='— Select —';fSubCat.appendChild(blank);
    subs.forEach(function(s){var o=document.createElement('option');o.value=s;o.textContent=s;o.selected=(r&&r.sub_category)===s;fSubCat.appendChild(o);});
  }
  fCat.addEventListener('change',updateSubCats);
  updateSubCats();

  form.appendChild(grid);

  // Notes full width
  var notesRow=document.createElement('div');notesRow.style.cssText='display:grid;grid-template-columns:1fr 80px;gap:10px;margin-bottom:14px;align-items:start';
  var notesWrap=document.createElement('div');
  var notesLbl=document.createElement('div');notesLbl.style.cssText=_imS.label+';margin-bottom:4px';notesLbl.textContent='Notes';
  var fNotes=document.createElement('textarea');fNotes.value=r&&r.notes||'';fNotes.placeholder='Optional notes about this brand mapping…';
  fNotes.style.cssText=_imS.inp+';height:60px;resize:vertical';
  notesWrap.appendChild(notesLbl);notesWrap.appendChild(fNotes);

  var activeWrap=document.createElement('div');
  var activeLbl=document.createElement('div');activeLbl.style.cssText=_imS.label+';margin-bottom:4px';activeLbl.textContent='Active';
  var fActive=document.createElement('select');fActive.style.cssText=_imS.sel;
  ['Yes','No'].forEach(function(v){var o=document.createElement('option');o.value=v;o.textContent=v;var _av=(r?(r.active!==false):true); o.selected=(_av===(v==='Yes'));fActive.appendChild(o);});
  activeWrap.appendChild(activeLbl);activeWrap.appendChild(fActive);

  notesRow.appendChild(notesWrap);notesRow.appendChild(activeWrap);
  form.appendChild(notesRow);

  // Buttons
  var btnRow=document.createElement('div');btnRow.style.cssText='display:flex;gap:8px';
  var saveBtn=document.createElement('button');
  saveBtn.textContent=isEdit?'Save Changes':'Add Mapping';
  saveBtn.style.cssText="padding:8px 20px;background:var(--accent);border:none;border-radius:7px;color:#fff;font-family:'DM Sans',sans-serif;font-size:12px;font-weight:600;cursor:pointer";
  var cancelBtn=document.createElement('button');
  cancelBtn.textContent='Cancel';
  cancelBtn.style.cssText="padding:8px 16px;background:none;border:1px solid var(--border);border-radius:7px;color:var(--text-mid);font-family:'DM Sans',sans-serif;font-size:12px;cursor:pointer";
  cancelBtn.addEventListener('click',function(){wrap.innerHTML='';wrap.style.display='none';});

  saveBtn.addEventListener('click',async function(){
    var brand=fBrand.value.trim();var generic=fGeneric.value.trim();
    if(!brand||!generic){alert('Brand Name and Ingredient Name are required.');return;}
    saveBtn.disabled=true;saveBtn.textContent='Saving…';
    try{
      await rpc('admin_save_brand',{
        p_id:isEdit?r.id:0,
        p_brand_name:brand,
        p_generic_name:generic,
        p_old_brand:isEdit?(r.brand_name||null):null,
        p_category:fCat.value||null,
        p_sub_category:fSubCat.value||null,
        p_notes:fNotes.value.trim()||null,
        p_active:fActive.value==='Yes'
      });
      wrap.innerHTML='';wrap.style.display='none';
      var status=document.getElementById('brand-status');
      if(status){status.textContent='✓ '+(isEdit?'Updated':'Added')+': '+brand+' → '+generic;setTimeout(function(){status.textContent='';},3000);}
      var tbody=document.getElementById('brand-tbody');
      if(tbody)await loadBrandsTable(tbody);
      if(typeof loadIngredients==='function') await loadIngredients(ingPage||1);
      auditLog('IM Interface > Reference Data','Brand Mapping '+(isEdit?'Updated':'Added'),null,isEdit?r.brand_name:null,brand,generic);
    }catch(e){alert('Save failed: '+e.message);saveBtn.disabled=false;saveBtn.textContent=isEdit?'Save Changes':'Add Mapping';}
  });

  btnRow.appendChild(saveBtn);btnRow.appendChild(cancelBtn);
  form.appendChild(btnRow);
  wrap.appendChild(form);
  fBrand.focus();
}

async function deleteBrandRow(id,tbody,container){
  if(!confirm('Delete this brand mapping? The CJ Recommended Brand will also be cleared from any matching ingredients.'))return;
  try{
    var cleared=await rpc('admin_delete_brand_mapping',{p_id:parseInt(id)});
    if(tbody)await loadBrandsTable(tbody);
    var msg=cleared>0?' '+cleared+' ingredient'+(cleared===1?'':'s')+' updated.':'';
    var status=document.getElementById('brand-status');
    if(status){status.textContent='✓ Brand deleted.'+msg;setTimeout(function(){status.textContent='';},4000);}
    auditLog('IM Interface > Reference Data','Brand Mapping Deleted',null,String(id),null,'Cleared from '+cleared+' ingredients');
  }catch(e){alert('Delete failed: '+e.message);}
}

async function exportBrandsCSV(){
  try{
    var rows=await rpc('admin_get_brand_mappings',{});
    var out=[['ID','Brand Name','Generic Name','Category','Sub Category','Notes','Active']];
    (rows||[]).forEach(function(r){
      out.push([r.id,r.brand_name,r.generic_name,r.category||'',r.sub_category||'',r.notes||'',r.active?'Yes':'No']);
    });
    _downloadCSV('brand-mappings.csv',out);
    auditLog('IM Interface > Reference Data','Export','Brand Mappings',null,null,(out.length-1)+' rows');
  }catch(e){alert('Export failed: '+e.message);}
}

async function importBrandsCSV(data,fields,container){
  if(!data||!data.length){alert('No data found in CSV.');return;}
  var fMap={};(fields||[]).forEach(function(f){fMap[f.toLowerCase().replace(/[\s_]/g,'')]=f;});
  var brandCol=fMap['brandname']||fMap['brand']||fields[1];
  var genCol  =fMap['genericname']||fMap['generic']||fields[2];
  var catCol  =fMap['category']||fields[3];
  var subCol  =fMap['subcategory']||fields[4];
  var noteCol =fMap['notes']||fields[5];
  var actCol  =fMap['active']||fields[6];

  var rows=[];
  data.forEach(function(row){
    var brand=(row[brandCol]||'').trim();var gen=(row[genCol]||'').trim();
    if(!brand||!gen)return;
    rows.push({brand_name:brand,generic_name:gen,category:(row[catCol]||'').trim()||null,sub_category:(row[subCol]||'').trim()||null,notes:(row[noteCol]||'').trim()||null,active:(row[actCol]||'Yes').trim()!=='No'});
  });

  showImportPreview('Import Brand Mappings',
    rows.length+' brand mappings found in CSV.\n\nMerge adds new mappings and updates existing ones (matched by brand name).\nReplace clears all existing mappings and loads only this file.',
    async function(){
      try{
        var n=await rpc('admin_bulk_upsert_brand_mappings',{p_rows:rows});
        var tbody=document.getElementById('brand-tbody');
        if(tbody)await loadBrandsTable(tbody);
        auditLog('IM Interface','Import Brand Mappings',null,null,null,n+' mappings upserted');
      }catch(e){alert('Import failed: '+e.message);}
    },
    async function(){
      if(!confirm('This will DELETE all existing brand mappings and replace them. Are you sure?'))return;
      try{
        await rpc('admin_delete_all_brand_mappings',{});
        var n=await rpc('admin_bulk_upsert_brand_mappings',{p_rows:rows});
        var tbody=document.getElementById('brand-tbody');
        if(tbody)await loadBrandsTable(tbody);
        auditLog('IM Interface','Import Replace Brand Mappings',null,null,null,n+' mappings replaced');
      }catch(e){alert('Import failed: '+e.message);}
    }
  );
}


// loadBrandMappings replaced by buildBrandsTab

function openBrandModal(row) {
  const isEdit = row && row.id;
  const title  = isEdit ? 'Edit Brand Mapping' : 'Add Brand Mapping';
  const html   = '<div style="position:fixed;inset:0;background:rgba(0,0,0,.7);z-index:99999;display:flex;align-items:center;justify-content:center;padding:20px" id="brand-modal-overlay" onclick="if(event.target===this)this.remove()">' +
    '<div style="background:var(--surface-2,#1a1b1e);border:1px solid var(--border);border-radius:14px;padding:28px;width:100%;max-width:440px">' +
    '<h3 style="font-family:Cormorant Garamond,serif;font-size:1.2rem;color:var(--text-high);margin:0 0 20px">' + title + '</h3>' +
    '<div style="display:flex;flex-direction:column;gap:12px">' +
    '<div><label style="font-family:DM Sans,sans-serif;font-size:11px;font-weight:600;letter-spacing:.07em;text-transform:uppercase;color:var(--text-mid);display:block;margin-bottom:5px">Brand Name</label>' +
    '<input id="bm-brand" class="ap-search" placeholder="e.g. Dalda" value="' + (row ? escT(row.brand_name||'') : '') + '" style="width:100%"></div>' +
    '<div><label style="font-family:DM Sans,sans-serif;font-size:11px;font-weight:600;letter-spacing:.07em;text-transform:uppercase;color:var(--text-mid);display:block;margin-bottom:5px">Generic Name</label>' +
    '<input id="bm-generic" class="ap-search" placeholder="e.g. Ghee" value="' + (row ? escT(row.generic_name||'') : '') + '" style="width:100%"></div>' +
    '<div><label style="font-family:DM Sans,sans-serif;font-size:11px;font-weight:600;letter-spacing:.07em;text-transform:uppercase;color:var(--text-mid);display:block;margin-bottom:5px">Category</label>' +
    '<input id="bm-category" class="ap-search" placeholder="e.g. Oils & Fats" value="' + (row ? escT(row.category||'') : '') + '" style="width:100%"></div>' +
    '<div><label style="font-family:DM Sans,sans-serif;font-size:11px;font-weight:600;letter-spacing:.07em;text-transform:uppercase;color:var(--text-mid);display:block;margin-bottom:5px">Notes (optional)</label>' +
    '<input id="bm-notes" class="ap-search" placeholder="Any additional notes" value="' + (row ? escT(row.notes||'') : '') + '" style="width:100%"></div>' +
    '</div>' +
    '<div style="display:flex;gap:10px;margin-top:20px">' +
    '<button onclick="saveBrandMapping(' + (isEdit ? row.id : 'null') + ')" style="flex:1;padding:11px;background:var(--accent);border:none;border-radius:9px;color:#fff;font-family:DM Sans,sans-serif;font-size:14px;font-weight:600;cursor:pointer">Save</button>' +
    '<button onclick="closeBrandModal()" style="padding:11px 18px;background:none;border:1px solid var(--border);border-radius:9px;color:var(--text-mid);font-family:DM Sans,sans-serif;font-size:14px;cursor:pointer">Cancel</button>' +
    '</div></div></div>';
  document.body.insertAdjacentHTML('beforeend', html);
}

function closeBrandModal() { var o=document.getElementById("brand-modal-overlay"); if(o)o.remove(); }

async function saveBrandMapping(id) {
  const brand   = (document.getElementById('bm-brand')||{}).value||'';
  const generic = (document.getElementById('bm-generic')||{}).value||'';
  const cat     = (document.getElementById('bm-category')||{}).value||'';
  const notes   = (document.getElementById('bm-notes')||{}).value||'';
  if (!brand || !generic) { alert('Brand name and generic name are required.'); return; }
  try {
    await rpc('admin_upsert_brand_mapping', { p_id: id||null, p_brand_name:brand, p_generic_name:generic, p_category:cat, p_notes:notes });
    document.getElementById('brand-modal-overlay').remove();
    loadBrandMappings();
  } catch(e) { alert('Error: '+e.message); }
}

async function deleteBrandMapping(id, btn) {
  if (!confirm('Delete this brand mapping?')) return;
  btn.disabled = true;
  try { await rpc('admin_delete_brand_mapping', { p_id: id }); loadBrandMappings(); }
  catch(e) { btn.disabled=false; alert('Error: '+e.message); }
}

async function approveIngredient(id, btn) {
  btn.disabled=true; btn.textContent='Adding…';
  try {
    await rpc('admin_resolve_pending_ingredient', { p_id: parseInt(id), p_action: 'added' });
    btn.textContent='Added';
    setTimeout(loadIngPending, 600);
  } catch(e) { btn.disabled=false; btn.textContent='Add'; alert('Error: '+e.message); }
}

async function dismissIngredient(id, btn) {
  btn.disabled=true; btn.textContent='Dismissing…';
  try {
    await rpc('admin_resolve_pending_ingredient', { p_id: parseInt(id), p_action: 'dismissed' });
    btn.closest('tr').remove();
    const remaining = document.getElementById('ing-pending-tbody').querySelectorAll('tr[id]').length;
    const pb = document.getElementById('itab-badge-pending');
    if (pb) pb.textContent = Math.max(0, parseInt(pb.textContent||0) - 1);
  } catch(e) { btn.disabled=false; btn.textContent='Dismiss'; alert('Error: '+e.message); }
}


// ── INGREDIENT UTILITY FUNCTIONS ────────────────────────────────
// These apply theme colours to dynamically created dropdowns/inputs
// and format quantity values for display

async function syncRefDataFromIngredients(types, onDone){
  try{
    var data = await rpc('admin_get_ingredient_distinct_values',{});
    var added = {categories:0, subcategories:0, units:0};
    if(types.includes('categories') && data.categories){
      var cats=getCats();
      data.categories.forEach(function(c){if(c&&!cats.includes(c)){cats.push(c);added.categories++;}});
      if(added.categories>0){_imSet('tcj_cats',cats.sort());CATS_LIST.length=0;cats.forEach(function(c){CATS_LIST.push(c);});}
    }
    if(types.includes('subcategories') && data.subcategories){
      var subs=getSubCats();
      data.subcategories.forEach(function(s){
        if(!s) return;
        // Try to match to a category — add to "Uncategorised" if no match
        var placed=false;
        Object.keys(subs).forEach(function(cat){if(subs[cat]&&!subs[cat].includes(s)){/* can't auto-place without knowing category */}});
        if(!placed){ if(!subs['Uncategorised'])subs['Uncategorised']=[]; if(!subs['Uncategorised'].includes(s)){subs['Uncategorised'].push(s);added.subcategories++;} }
      });
      if(added.subcategories>0) _imSet('tcj_subcats',subs);
    }
    if(types.includes('units') && data.units){
      var units=getUnits();
      data.units.forEach(function(u){if(u&&!units.includes(u)){units.push(u);added.units++;}});
      if(added.units>0) _imSet('tcj_units',units.sort());
    }
    var msgs=[];
    if(added.categories>0) msgs.push(added.categories+' categor'+(added.categories===1?'y':'ies'));
    if(added.subcategories>0) msgs.push(added.subcategories+' sub categor'+(added.subcategories===1?'y':'ies'));
    if(added.units>0) msgs.push(added.units+' unit'+(added.units===1?'':'s'));
    var summary = msgs.length>0 ? '✓ Added: '+msgs.join(', ') : '✓ Already up to date — nothing new to add.';
    if(onDone) onDone(summary);
    loadIMInterface();
  }catch(e){ alert('Sync failed: '+e.message); }
}

async function loadIngredients(page) {
  ingPage = page||1;
  const tbody = document.getElementById('ing-tbody');
  if (!tbody) return;
  tbody.innerHTML = '<tr><td colspan="20" class="ap-empty-row">Loading...</td></tr>';
  try {
    var _ps = ING_PAGE_SIZE||50;
    var _off = (ingPage-1)*_ps;
    var _sc = _ingSortCol||'ID';
    var _sd = _ingSortDir||'asc';
    var _srch = _ingSearch||null;
    var _cat  = _ingCategoryFilter||null;
    const [rows, total] = await Promise.all([
      rpc('admin_get_ingredients',{p_search:_srch,p_category:_cat,p_limit:_ps,p_offset:_off,p_sort_col:_sc,p_sort_dir:_sd}),
      rpc('admin_count_ingredients',{p_search:_srch,p_category:_cat})
    ]);
    // localStorage is the source of truth for which columns exist.
    // Scanning extra_fields causes deleted columns to reappear and
    // leaks _t_ type metadata keys as visible columns.
    _extraColKeys = JSON.parse(localStorage.getItem('tcj_extra_cols') || '[]')
      .filter(function(k){ return k && !k.startsWith('_t_') && !k.startsWith('_'); });
    _extraColTypes = JSON.parse(localStorage.getItem('tcj_extra_col_types')||'{}');
    _extraColKeys.forEach(function(k){if(_colVis['extra:'+k]===undefined)_colVis['extra:'+k]=true;});
    ingTotal = parseInt(total)||0;
    _ingAllData = rows||[];
    const countEl = document.getElementById('ing-count');
    var _start=((ingPage-1)*ING_PAGE_SIZE)+1;
    var _end=Math.min(ingPage*ING_PAGE_SIZE, ingTotal);
    if(countEl)countEl.textContent = ingTotal+' ingredient'+(ingTotal===1?'':'s')+(ingTotal>0?' (showing '+_start+'–'+_end+')':'');
    const badge = document.getElementById('badge-ingredients');
    if(badge){badge.textContent=ingTotal;badge.style.display='inline-block';}
    buildTableHeader();
    buildColVisPanel();
    renderIngFiltered();
    buildPaginationControls(ingTotal);
    updateSaveBtn();
    setTimeout(fixDropdownTheme,50);
  } catch(e) {
    tbody.innerHTML='<tr><td colspan="20" class="ap-empty-row">Error: '+e.message+'</td></tr>';
  }
}

// ── BUILD HEADER ─────────────────────────────────────────────────

function moveColumn(fromKey, toKey) {
  const order = getColOrder();
  const fi = order.indexOf(fromKey), ti = order.indexOf(toKey);
  if(fi===-1||ti===-1)return;
  order.splice(fi,1); order.splice(ti,0,fromKey);
  localStorage.setItem('tcj_col_order',JSON.stringify(order));
  buildTableHeader(); renderIngFiltered();
}

// ── SORT & FILTER ────────────────────────────────────────────────

function addNewColumn(e){
  const panel=document.getElementById('add-col-panel');
  if(!panel)return;
  document.getElementById('new-col-name-input').value='';
  const radios=panel.querySelectorAll('input[name="nctype"]');
  radios.forEach(function(r){r.checked=r.value==='text';});
  const btn=e.currentTarget||e.target;
  const rect=btn.getBoundingClientRect();
  panel.style.top=(rect.bottom+6)+'px';
  panel.style.right=(window.innerWidth-rect.right)+'px';
  panel.style.left='auto';
  panel.style.display='block';
  applyThemeColors(panel);
  setTimeout(function(){
    document.getElementById('new-col-name-input').focus();
    document.addEventListener('click',closeAddColPanelOutside);
  },10);
}

function closeAddColPanel(){
  const p=document.getElementById('add-col-panel');
  if(p)p.style.display='none';
  document.removeEventListener('click',closeAddColPanelOutside);
}

function closeAddColPanelOutside(e){
  const p=document.getElementById('add-col-panel');
  if(p&&!p.contains(e.target)&&e.target.id!=='add-col-btn'){closeAddColPanel();}
}

function confirmAddColumn(){
  const name=(document.getElementById('new-col-name-input').value||'').trim();
  if(!name){document.getElementById('new-col-name-input').focus();return;}
  if(STD_COLS.find(function(c){return c.key===name;})||_extraColKeys.includes(name)){
    alert('A column with that name already exists.');return;
  }
  const checked=document.querySelector('input[name="nctype"]:checked');
  const colType=checked?checked.value:'text';
  _extraColKeys.push(name);
  _extraColTypes[name]=colType;
  _colVis['extra:'+name]=true;
  // Track in ever-created list so Edit modal can filter deleted columns
  var _ever=JSON.parse(localStorage.getItem('tcj_ever_global_cols')||'[]');
  if(!_ever.includes(name)){_ever.push(name);localStorage.setItem('tcj_ever_global_cols',JSON.stringify(_ever));}
  const stored=JSON.parse(localStorage.getItem('tcj_extra_cols')||'[]');
  if(!stored.includes(name)){stored.push(name);localStorage.setItem('tcj_extra_cols',JSON.stringify(stored));}
  const types=JSON.parse(localStorage.getItem('tcj_extra_col_types')||'{}');
  types[name]=colType;localStorage.setItem('tcj_extra_col_types',JSON.stringify(types));
  closeAddColPanel();
  buildTableHeader();buildColVisPanel();renderIngFiltered();
}

// ── RENAME CUSTOM COLUMN ─────────────────────────────────────────

function renameExtraColumn(oldName) {
  const newName = (prompt('Rename column "' + oldName + '" to:', oldName) || '').trim();
  if (!newName || newName === oldName) return;
  if (STD_COLS.find(function(c){ return c.key === newName; }) || _extraColKeys.includes(newName)) {
    alert('A column with that name already exists.'); return;
  }

  // 1. Update _extraColKeys
  var idx = _extraColKeys.indexOf(oldName);
  if (idx > -1) _extraColKeys[idx] = newName;

  // 2. Update _colVis
  var wasVisible = _colVis['extra:' + oldName] !== false;
  delete _colVis['extra:' + oldName];
  _colVis['extra:' + newName] = wasVisible;

  // 3. Update column order in localStorage
  var order = JSON.parse(localStorage.getItem('tcj_col_order') || '[]');
  var oi = order.indexOf('extra:' + oldName);
  if (oi > -1) order[oi] = 'extra:' + newName;
  localStorage.setItem('tcj_col_order', JSON.stringify(order));

  // 4. Update stored extra col names and types in localStorage
  var stored = JSON.parse(localStorage.getItem('tcj_extra_cols') || '[]');
  var si = stored.indexOf(oldName);
  if (si > -1) stored[si] = newName;
  localStorage.setItem('tcj_extra_cols', JSON.stringify(stored));
  var types = JSON.parse(localStorage.getItem('tcj_extra_col_types') || '{}');
  if (types[oldName]) { types[newName] = types[oldName]; delete types[oldName]; }
  localStorage.setItem('tcj_extra_col_types', JSON.stringify(types));
  if (_extraColTypes[oldName]) { _extraColTypes[newName] = _extraColTypes[oldName]; delete _extraColTypes[oldName]; }

  // 5. Rename the key in all loaded ingredient data
  _ingAllData.forEach(function(row) {
    if (row.extra_fields && row.extra_fields.hasOwnProperty(oldName)) {
      row.extra_fields[newName] = row.extra_fields[oldName];
      delete row.extra_fields[oldName];
    }
  });

  // 6. Update any pending changes
  Object.keys(_pendingChanges).forEach(function(id) {
    if (_pendingChanges[id] && _pendingChanges[id]['extra:' + oldName] !== undefined) {
      _pendingChanges[id]['extra:' + newName] = _pendingChanges[id]['extra:' + oldName];
      delete _pendingChanges[id]['extra:' + oldName];
    }
  });

  // 7. Rebuild
  buildTableHeader();
  buildColVisPanel();
  renderIngFiltered();
}


// ── DELETE CUSTOM COLUMN ─────────────────────────────────────────

async function deleteExtraColumn(name) {
  if (!confirm('Delete column "' + name + '"?\n\nThe column will be removed from the table. Its data will be renamed and moved to the Recycle Bin.')) return;

  // Find next available Deleted{n}Name slot
  var n = 1;
  var allKeys = [];
  _ingAllData.forEach(function(r) {
    if (r.extra_fields) Object.keys(r.extra_fields).forEach(function(k) { allKeys.push(k); });
  });
  while (allKeys.includes('Deleted' + n + name)) n++;
  var renamedTo = 'Deleted' + n + name;

  // Rename in Supabase — AWAIT so Recycle Bin is accurate immediately
  try {
    var count = await rpc('admin_rename_extra_field', { p_old_key: name, p_new_key: renamedTo });
    console.log('Renamed "' + name + '" to "' + renamedTo + '" in ' + (count||0) + ' rows');
    var _renameCount = count || 0;
    auditLog('All Ingredients > Columns','Column Deleted',name,name,renamedTo,'Renamed to '+renamedTo+' in '+_renameCount+' rows');
    // Store deletion metadata in localStorage
    var meta = JSON.parse(localStorage.getItem('tcj_deleted_meta') || '{}');
    meta[renamedTo] = {
      originalName: name,
      renamedTo:    renamedTo,
      deletedAt:    new Date().toISOString(),
      source:       'All Ingredients',
      colType:      _extraColTypes[name] || 'text'
    };
    localStorage.setItem('tcj_deleted_meta', JSON.stringify(meta));
  } catch(e) {
    alert('Could not rename column data: ' + e.message + '\nColumn removed from table but data may not be in Recycle Bin.');
  }

  // Update local data immediately
  _ingAllData.forEach(function(r) {
    if (r.extra_fields && r.extra_fields.hasOwnProperty(name)) {
      r.extra_fields[renamedTo] = r.extra_fields[name];
      delete r.extra_fields[name];
    }
  });

  // Remove from _extraColKeys, _colVis, _extraColTypes
  _extraColKeys = _extraColKeys.filter(function(k) { return k !== name; });
  delete _colVis['extra:' + name];
  delete _extraColTypes[name];

  // Update localStorage
  var order = JSON.parse(localStorage.getItem('tcj_col_order') || '[]');
  localStorage.setItem('tcj_col_order', JSON.stringify(order.filter(function(k) { return k !== 'extra:' + name; })));
  var stored = JSON.parse(localStorage.getItem('tcj_extra_cols') || '[]');
  localStorage.setItem('tcj_extra_cols', JSON.stringify(stored.filter(function(k) { return k !== name; })));
  var types = JSON.parse(localStorage.getItem('tcj_extra_col_types') || '{}');
  delete types[name];
  localStorage.setItem('tcj_extra_col_types', JSON.stringify(types));

  Object.keys(_pendingChanges).forEach(function(id) {
    if (_pendingChanges[id]) delete _pendingChanges[id]['extra:' + name];
  });
  delete _ingColFilters['extra:' + name];

  buildTableHeader(); buildColVisPanel(); renderIngFiltered(); updateSaveBtn();

  // Show result toast
  var _toast = document.getElementById('ing-delete-toast');
  if (!_toast) { _toast = document.createElement('div'); _toast.id='ing-delete-toast'; _toast.style.cssText='position:fixed;bottom:24px;right:24px;background:var(--card-bg);border:1px solid var(--border);border-radius:10px;padding:12px 20px;font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-high);z-index:99999;box-shadow:0 4px 24px rgba(0,0,0,0.4);max-width:320px'; document.body.appendChild(_toast); }
  _toast.textContent = _renameCount > 0 ? '✓ Column deleted. ' + _renameCount + ' ingredient value' + (_renameCount===1?'':'s') + ' moved to Recycle Bin.' : '⚠ Column deleted. No saved values found — nothing added to Recycle Bin.';
  _toast.style.display = 'block';
  setTimeout(function(){ _toast.style.display='none'; }, 4000);

  // If Recycle Bin tab is active, refresh it now
  if (currentIngTab === 'recycle') loadIngRecycleBin();
}


// ── COLUMN VISIBILITY PANEL ──────────────────────────────────────

function buildColVisPanel(){
  const panel=document.getElementById('col-vis-panel');
  if(!panel)return;
  panel.innerHTML='<div class="col-vis-title">Show / Hide Columns</div>';
  const addRow=function(key,label){
    const lbl=document.createElement('label');lbl.className='col-vis-row';
    const cb=document.createElement('input');cb.type='checkbox';cb.checked=_colVis[key]!==false;
    cb.addEventListener('change',function(){
      _colVis[key]=cb.checked;
      document.querySelectorAll('[data-col="'+key+'"]').forEach(function(el){el.style.display=cb.checked?'':'none';});
    });
    lbl.appendChild(cb);lbl.appendChild(document.createTextNode(' '+label));panel.appendChild(lbl);
  };
  STD_COLS.forEach(function(c){addRow(c.key,c.label);});
  _extraColKeys.forEach(function(k){
    // Build row manually so we can add a rename button
    const lbl=document.createElement('label');lbl.className='col-vis-row';lbl.style.justifyContent='space-between';
    const left=document.createElement('div');left.style.cssText='display:flex;align-items:center;gap:7px';
    const cb=document.createElement('input');cb.type='checkbox';cb.checked=_colVis['extra:'+k]!==false;
    cb.addEventListener('change',function(){
      _colVis['extra:'+k]=cb.checked;
      document.querySelectorAll('[data-col="extra:'+k+'"]').forEach(function(el){el.style.display=cb.checked?'':'none';});
    });
    left.appendChild(cb);left.appendChild(document.createTextNode(' '+k));
    const typeBadge=document.createElement('span');
    const colT=_extraColTypes[k]||'text';
    typeBadge.textContent=colT==='yesno'?'Y/N':colT==='number'?'#':'T';
    typeBadge.style.cssText='font-family:DM Sans,sans-serif;font-size:9px;padding:1px 5px;border-radius:4px;background:rgba(255,255,255,0.08);color:var(--text-mid);margin-left:4px;font-weight:600';
    left.appendChild(typeBadge);
    const renBtn=document.createElement('button');
    renBtn.textContent='Rename';
    renBtn.style.cssText='font-family:DM Sans,sans-serif;font-size:10px;padding:2px 8px;border-radius:5px;border:1px solid var(--border);background:none;color:var(--text-mid);cursor:pointer;margin-left:6px;flex-shrink:0';
    renBtn.addEventListener('click',function(e){e.preventDefault();e.stopPropagation();renameExtraColumn(k);});
    const delBtn2=document.createElement('button');
    delBtn2.textContent='Delete';
    delBtn2.style.cssText='font-family:DM Sans,sans-serif;font-size:10px;padding:2px 8px;border-radius:5px;border:1px solid #dc5050;background:none;color:#dc5050;cursor:pointer;margin-left:4px;flex-shrink:0';
    delBtn2.addEventListener('click',function(e){e.preventDefault();e.stopPropagation();deleteExtraColumn(k);});
    const btnGroup=document.createElement('div');btnGroup.style.cssText='display:flex;align-items:center;flex-shrink:0';
    btnGroup.appendChild(renBtn);btnGroup.appendChild(delBtn2);
    lbl.appendChild(left);lbl.appendChild(btnGroup);panel.appendChild(lbl);
  });
  applyThemeColors(panel);
}

function toggleColumn(){}// compat stub

// ── COLUMN FILTER PANEL ──────────────────────────────────────────
let _activeFilterPanel=null;

async function saveIngredient(){
  const saveBtn=document.querySelector('.ing-save-btn');
  const id=document.getElementById('ing-id').value,name=document.getElementById('ing-name').value.trim(),cat=document.getElementById('ing-category').value;
  if(!name){showIngMsg('Ingredient name is required.',false);return;}
  if(!cat){showIngMsg('Category is required.',false);return;}
  saveBtn.disabled=true;saveBtn.textContent='Saving...';
  try{
    var oldName=document.getElementById('ing-name').dataset.originalName||'';
    if(id&&oldName&&oldName.toLowerCase().trim()!==name.toLowerCase().trim()){
      var preview=await rpc('admin_preview_ingredient_amend',{p_id:parseInt(id),p_new_name:name});
      if(preview&&preview.name_will_change&&preview.recipes_affected>0){
        if(!confirm('Renaming "'+oldName+'" to "'+name+'" will update '+preview.recipes_affected+' recipe(s) and '+preview.library_profiles_linked+' library profile(s). Continue?')){saveBtn.disabled=false;saveBtn.textContent='Save Ingredient';return;}
      }
    }
    var result=await rpc('admin_upsert_ingredient',{
      p_id:id?parseInt(id):null,p_ingredient_name:name,
      p_also_known_as:document.getElementById('ing-aka').value.trim(),
      p_category:cat,p_sub_category:document.getElementById('ing-subcat').value.trim(),
      p_standard_qty:document.getElementById('ing-qty').value.trim(),
      p_standard_weight:parseFloat(document.getElementById('ing-weight').value)||null,
      p_unit:document.getElementById('ing-unit').value.trim(),
      p_liquid:document.getElementById('ing-liquid').value,
      p_cj_recommended_brand:document.getElementById('ing-brand').value.trim(),
      p_allergen:document.getElementById('ing-allergen').value.trim(),
      p_vegan:document.getElementById('ing-vegan').value,
      p_vegetarian:document.getElementById('ing-veg').value,
      p_notes:document.getElementById('ing-notes').value.trim(),
      p_extra_fields:(function(){
        var ef=Object.assign({},_customFields);
        Object.keys(_customFieldTypes).forEach(function(k){
          if(ef.hasOwnProperty(k)&&_customFieldTypes[k]!=='text')ef['_t_'+k]=_customFieldTypes[k];
        });
        return Object.keys(ef).length?ef:null;
      })()
    });
    if(typeof TcjIngredientLookup!=='undefined')TcjIngredientLookup.clearCache();
    var msg=id?'✓ Saved!':'✓ Added!';
    if(result&&result.recipes_updated>0)msg+=' '+result.recipes_updated+' recipe(s) updated.';
    showIngMsg(msg,true);
    setTimeout(function(){closeIngModal();loadIngredients(ingPage);},900);
  }catch(e){showIngMsg('Error: '+e.message,false);}
  finally{saveBtn.disabled=false;saveBtn.textContent='Save Ingredient';}
}

async function deleteIngredient(){
  const id=document.getElementById('ing-id').value,name=document.getElementById('ing-name').value;
  if(!id||!confirm('Delete "'+name+'"?'))return;
  try{
    var res=await rpc('admin_delete_ingredient',{p_id:parseInt(id),p_force:false});
    if(res&&res.blocked){
      if(!confirm(res.message+'\n\nRecipes using it: '+res.recipes_using+'. Library profiles: '+res.library_profiles_linked+'. Force delete?'))return;
      res=await rpc('admin_delete_ingredient',{p_id:parseInt(id),p_force:true});
    }
    if(typeof TcjIngredientLookup!=='undefined')TcjIngredientLookup.clearCache();
    closeIngModal();loadIngredients(ingPage);
  }
  catch(e){showIngMsg('Error: '+e.message,false);}
}

function renderCustomFieldsList(){
  const container=document.getElementById('ing-custom-fields-list');
  if(!container)return;
  container.innerHTML='';
  const keys=Object.keys(_customFields).filter(function(k){return !k.startsWith('_t_');});
  const globals=keys.filter(function(k){return _extraColKeys.includes(k);});
  const customs=keys.filter(function(k){return !_extraColKeys.includes(k);});

  if(!globals.length&&!customs.length){
    const msg=document.createElement('div');
    msg.style.cssText='font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);padding:4px 0';
    msg.textContent='No custom fields. Click + Add Field.';
    container.appendChild(msg);return;
  }

  // Header row
  const hdr=document.createElement('div');
  hdr.style.cssText='display:grid;grid-template-columns:minmax(80px,1fr) 88px minmax(80px,2fr) 28px;gap:0 8px;align-items:center;margin-bottom:4px';
  ['FIELD NAME','TYPE','VALUE',''].forEach(function(t){
    const h=document.createElement('div');
    h.style.cssText='font-family:DM Sans,sans-serif;font-size:9px;font-weight:600;letter-spacing:0.1em;text-transform:uppercase;color:var(--text-mid);padding:0 2px';
    h.textContent=t;container.appendChild(h);
  });
  // Oops — append header cells to a header row div instead
  container.innerHTML='';
  hdr.innerHTML='';
  ['FIELD NAME','TYPE','VALUE',''].forEach(function(t){
    const h=document.createElement('div');
    h.style.cssText='font-family:DM Sans,sans-serif;font-size:9px;font-weight:600;letter-spacing:0.1em;text-transform:uppercase;color:var(--text-mid);padding:2px 4px';
    h.textContent=t;hdr.appendChild(h);
  });
  container.appendChild(hdr);

  function makeRow(k,isGlobal){
    const row=document.createElement('div');
    row.className='cf-row';
    row.style.cssText='display:grid;grid-template-columns:minmax(80px,1fr) 88px minmax(80px,2fr) 28px;gap:4px 8px;align-items:center;margin-bottom:5px';

    // Column A: Name
    var nameEl;
    if(isGlobal){
      nameEl=document.createElement('div');
      nameEl.style.cssText='font-family:DM Sans,sans-serif;font-size:12px;padding:5px 8px;border:1px solid var(--border);border-radius:6px;background:rgba(255,255,255,0.04);color:var(--accent);overflow:hidden;text-overflow:ellipsis;white-space:nowrap;display:flex;align-items:center;gap:4px';
      nameEl.innerHTML='<span style="font-size:8px;opacity:0.55;font-weight:700;flex-shrink:0">COL</span><span style="overflow:hidden;text-overflow:ellipsis">'+k+'</span>';
    } else {
      nameEl=document.createElement('input');
      nameEl.dataset.role='name';
      nameEl.style.cssText='width:100%;font-family:DM Sans,sans-serif;font-size:12px;padding:5px 8px;border:1px solid var(--border);border-radius:6px;background:var(--bg);color:var(--text-high);outline:none;box-sizing:border-box';
      nameEl.value=k;nameEl.placeholder='Field name';
      nameEl.addEventListener('change',function(){renameCustomField(k,this.value);});
    }

    // Column B: Type
    var typeEl;
    if(isGlobal){
      const ct=_extraColTypes[k]||'text';
      typeEl=document.createElement('div');
      typeEl.style.cssText='font-family:DM Sans,sans-serif;font-size:11px;padding:5px 8px;border:1px solid var(--border);border-radius:6px;background:rgba(255,255,255,0.04);color:var(--text-mid);text-align:center';
      var _typeLabels={'text':'Text','yesno':'Yes / No','number':'Number','currency':'Currency','percentage':'Percentage','fraction':'Fraction'};
      typeEl.textContent=_typeLabels[ct]||ct||'Text';
    } else {
      typeEl=document.createElement('select');
      typeEl.style.cssText='width:100%;font-family:DM Sans,sans-serif;font-size:11px;padding:5px 6px;border:1px solid var(--border);border-radius:6px;background:var(--bg);color:var(--text-mid);outline:none;cursor:pointer;box-sizing:border-box';
      [{v:'text',l:'Text'},{v:'yesno',l:'Yes / No'},{v:'number',l:'Number'},{v:'currency',l:'Currency'},{v:'percentage',l:'Percentage'},{v:'fraction',l:'Fraction'}].forEach(function(t){
        const o=document.createElement('option');o.value=t.v;o.textContent=t.l;
        o.selected=(_customFieldTypes[k]||'text')===t.v;
        typeEl.appendChild(o);
      });
      typeEl.addEventListener('change',function(){_customFieldTypes[k]=this.value;renderCustomFieldsList();});
    }

    // Column C: Value
    const cft=isGlobal?(_extraColTypes[k]||'text'):(_customFieldTypes[k]||'text');
    var valEl;
    if(cft==='yesno'){
      valEl=document.createElement('select');
      valEl.style.cssText='width:100%;font-family:DM Sans,sans-serif;font-size:12px;padding:5px 8px;border:1px solid var(--border);border-radius:6px;background:var(--bg);color:var(--text-high);outline:none;box-sizing:border-box';
      ['','Yes','No'].forEach(function(o){var opt=document.createElement('option');opt.value=o;opt.textContent=o||'—';if((_customFields[k]||'')===o)opt.selected=true;valEl.appendChild(opt);});
      valEl.addEventListener('change',function(){_customFields[k]=this.value;});
    } else if(cft==='currency'){
      valEl=document.createElement('div'); valEl.style.cssText='display:flex;gap:4px;align-items:center;width:100%';
      var _cp=((_customFields[k]||'').indexOf(':')>-1)?(_customFields[k]||'').split(':'):['AUD',''];
      var _cSel=document.createElement('select');
      _cSel.style.cssText='width:72px;flex-shrink:0;padding:4px 4px;border:1px solid var(--border);border-radius:6px;background:var(--bg);color:var(--text-high);font-family:DM Sans,sans-serif;font-size:11px;outline:none';
      getCurrencies().forEach(function(c){var o=document.createElement('option');o.value=c;o.textContent=c;o.selected=_cp[0]===c;_cSel.appendChild(o);});
      var _cAmt=document.createElement('input'); _cAmt.type='text'; _cAmt.inputMode='decimal';
      _cAmt.value=_cp[1]||''; _cAmt.placeholder='Enter amount e.g. 12.00';
      _cAmt.style.cssText='flex:1;min-width:80px;font-family:DM Sans,sans-serif;font-size:12px;padding:5px 8px;border:1px solid var(--accent);border-radius:6px;background:var(--bg);color:var(--text-high);outline:none';
      _cAmt.addEventListener('keydown',function(ev){var ok=['Backspace','Delete','ArrowLeft','ArrowRight','Tab','.','Enter','Escape'];if(ok.includes(ev.key)||ev.key>='0'&&ev.key<='9'||ev.ctrlKey||ev.metaKey)return;ev.preventDefault();});
      var _saveCurr=function(){_customFields[k]=_cSel.value+':'+_cAmt.value;};
      _cSel.addEventListener('change',_saveCurr); _cAmt.addEventListener('change',_saveCurr);
      valEl.appendChild(_cSel); valEl.appendChild(_cAmt);
    } else if(cft==='percentage'){
      valEl=document.createElement('input'); valEl.type='text'; valEl.inputMode='decimal';
      valEl.style.cssText='width:100%;font-family:DM Sans,sans-serif;font-size:12px;padding:5px 8px;border:1px solid var(--border);border-radius:6px;background:var(--bg);color:var(--text-high);outline:none;box-sizing:border-box';
      valEl.value=(_customFields[k]||'').toString().replace('%',''); valEl.placeholder='0–100';
      valEl.addEventListener('keydown',function(ev){var ok=['Backspace','Delete','ArrowLeft','ArrowRight','Tab','.','Enter','Escape'];if(ok.includes(ev.key)||ev.key>='0'&&ev.key<='9'||ev.ctrlKey||ev.metaKey)return;ev.preventDefault();});
      valEl.addEventListener('change',function(){var v=parseFloat(this.value||0);if(v>100)v=100;if(v<0)v=0;this.value=v;_customFields[k]=String(v);});
    } else if(cft==='fraction'){
      valEl=document.createElement('input'); valEl.type='text';
      valEl.style.cssText='width:100%;font-family:DM Sans,sans-serif;font-size:12px;padding:5px 8px;border:1px solid var(--border);border-radius:6px;background:var(--bg);color:var(--text-high);outline:none;box-sizing:border-box';
      valEl.value=_customFields[k]||''; valEl.placeholder='e.g. 1/4  1 1/2  3  0.5';
      valEl.addEventListener('keydown',function(ev){
        var ok=['Backspace','Delete','ArrowLeft','ArrowRight','Tab','Enter','Escape','Home','End',' ','/','.',];
        if(ok.includes(ev.key)||ev.key>='0'&&ev.key<='9'||ev.ctrlKey||ev.metaKey)return;
        ev.preventDefault();
      });
      valEl.addEventListener('change',function(){
        var v=this.value.trim();
        var valid=/^\d+$/.test(v)||/^\d+\.\d+$/.test(v)||/^\d+\/\d+$/.test(v)||/^\d+ \d+\/\d+$/.test(v);
        if(v&&!valid){this.style.borderColor='#dc5050';this.title='Use formats: 1/4  1 1/2  3  0.5';return;}
        this.style.borderColor=''; this.title='';
        _customFields[k]=v;
      });
    } else {
      valEl=document.createElement('input');
      valEl.type='text'; // always text — number type allows 'e' natively
      if(cft==='number') valEl.inputMode='decimal';
      valEl.style.cssText='width:100%;font-family:DM Sans,sans-serif;font-size:12px;padding:5px 8px;border:1px solid var(--border);border-radius:6px;background:var(--bg);color:var(--text-high);outline:none;box-sizing:border-box';
      valEl.value=String(_customFields[k]||'');
      valEl.placeholder=isGlobal?'Value for '+k:'Value';
      valEl.addEventListener('change',function(){_customFields[k]=this.value;});
    }

    // Column D: Delete (custom only)
    var delEl=document.createElement('div'); // placeholder for globals
    if(!isGlobal){
      delEl=document.createElement('button');
      delEl.style.cssText='width:24px;height:24px;background:none;border:1px solid #dc5050;border-radius:5px;color:#dc5050;cursor:pointer;font-size:13px;display:flex;align-items:center;justify-content:center;padding:0;flex-shrink:0';
      delEl.textContent='×';
      delEl.addEventListener('click',function(){removeCustomField(k);});
    }

    row.appendChild(nameEl);row.appendChild(typeEl);row.appendChild(valEl);row.appendChild(delEl);
    container.appendChild(row);
  }

  // Render global columns first, then custom per-ingredient fields
  globals.forEach(function(k){makeRow(k,true);});
  if(globals.length&&customs.length){
    const sep=document.createElement('div');
    sep.style.cssText='border-top:1px solid var(--border);margin:6px 0;grid-column:1/-1';
    container.appendChild(sep);
  }
  customs.forEach(function(k){makeRow(k,false);});
}

function addCustomField(){
  // Generate a unique default name
  var n=1;
  while(_customFields.hasOwnProperty('Field '+n)||_customFields.hasOwnProperty('Field '+n)) n++;
  var key='Field '+n;
  _customFields[key]='';
  _customFieldTypes[key]='text'; // default type
  renderCustomFieldsList();
  // Focus the newly added name input
  var rows=document.querySelectorAll('#ing-custom-fields-list .cf-row');
  if(rows.length){var lastInput=rows[rows.length-1].querySelector('input[data-role="name"]');if(lastInput){lastInput.focus();lastInput.select();}}
}

function renameCustomField(oldKey,newKey){if(oldKey===newKey||!newKey.trim())return;const val=_customFields[oldKey];delete _customFields[oldKey];_customFields[newKey.trim()]=val;renderCustomFieldsList();}

function removeCustomField(key){delete _customFields[key];renderCustomFieldsList();}

// ── UNITS AUTOCOMPLETE ───────────────────────────────────────────

function _downloadFICSV(filename, csv){
  var blob=new Blob([csv],{type:'text/csv'});
  var a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download=filename;a.click();URL.revokeObjectURL(a.href);
}

async function buildFiInterface(container) {
  if (!container || typeof AdminTabNav === 'undefined') {
    if (container) container.textContent = 'Admin tab navigation failed to load.';
    return;
  }
  if (container.dataset.ifShell === '1' && container._ifShell) {
    var stored = localStorage.getItem('tcj_fmi_tab') || 'hub';
    container._ifShell.activate(stored);
    return;
  }

  container.innerHTML = '<div class="admin-if-loading">Loading…</div>';
  var fiCache = container._fiCache || (container._fiCache = { settings: null, members: null, tiers: null });

  async function fiSettings() {
    if (fiCache.settings) return fiCache.settings;
    var S = {};
    var settRes = await apiFetch(SUPABASE_URL + '/rest/v1/site_settings?select=key,value&key=in.(price_premium_monthly,price_premium_annual,price_event_monthly,price_event_annual,currency_symbol,currency_code)');
    if (settRes && settRes.ok) {
      var sr = await settRes.json();
      if (Array.isArray(sr)) sr.forEach(function (r) { S[r.key] = r.value; });
    }
    fiCache.settings = S;
    return S;
  }

  async function fiMembers() {
    if (fiCache.members) return fiCache.members;
    var memberList = [];
    if (typeof TcjAdminProfiles !== 'undefined') {
      memberList = await TcjAdminProfiles.fetchAllRest(apiFetch, SUPABASE_URL);
    } else {
      var mRes = await apiFetch(SUPABASE_URL + '/rest/v1/profiles?select=id,username,full_name,email,subscription_tier&order=full_name.asc&limit=500');
      if (mRes && mRes.ok) {
        var ml = await mRes.json();
        if (Array.isArray(ml)) memberList = ml;
      }
    }
    fiCache.members = memberList;
    return memberList;
  }

  async function fiTiers() {
    if (fiCache.tiers) return fiCache.tiers;
    fiCache.tiers = await rpc('admin_get_tier_stats', {}).catch(function () { return {}; }) || {};
    return fiCache.tiers;
  }

  function mk(tag, s, t) { var e = document.createElement(tag); if (s) e.style.cssText = s; if (t !== undefined) e.textContent = t; return e; }
  function card(title, desc, color) {
    var d = mk('div', 'background:rgba(255,255,255,0.04);border:1px solid var(--border);border-radius:12px;padding:20px;margin-bottom:16px');
    d.appendChild(mk('div', "font-family:'Cormorant Garamond',serif;font-size:1rem;font-weight:700;color:" + (color || 'var(--text-high)') + ';margin-bottom:' + (desc ? '4' : '14') + 'px', title));
    if (desc) d.appendChild(mk('p', 'font-size:12px;color:var(--text-mid);margin-bottom:14px', desc));
    return d;
  }
  function fi(id, lbl, ph, type) {
    var w = mk('div', ''); w.appendChild(mk('label', 'display:block;font-size:10px;text-transform:uppercase;letter-spacing:0.08em;color:var(--text-mid);margin-bottom:4px', lbl));
    var i = mk('input', 'width:100%;box-sizing:border-box;padding:8px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high)');
    i.id = 'fmi-' + id; i.type = type || 'text'; if (ph) i.placeholder = ph; w.appendChild(i); return w;
  }
  function fs(id, lbl, opts) {
    var w = mk('div', ''); w.appendChild(mk('label', 'display:block;font-size:10px;text-transform:uppercase;letter-spacing:0.08em;color:var(--text-mid);margin-bottom:4px', lbl));
    var s = mk('select', 'width:100%;padding:8px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high)');
    s.id = 'fmi-' + id; opts.forEach(function (o) { var el = document.createElement('option'); el.value = o.v; el.textContent = o.l; s.appendChild(el); }); w.appendChild(s); return w;
  }

  function renderFiManual(panel, S, memberList, cur) {
    panel.innerHTML = '';
    var c = card('Record Manual Payment', 'Record a payment received outside the system — cash, bank transfer, PayPal, etc. Sets member tier and logs the transaction.');
    var grid = mk('div', 'display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-bottom:14px');
    var mWrap = mk('div', 'grid-column:1/-1');
    mWrap.appendChild(mk('label', 'display:block;font-size:10px;text-transform:uppercase;letter-spacing:0.08em;color:var(--text-mid);margin-bottom:4px', 'Member *'));
    var mSel = mk('select', 'width:100%;padding:8px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high)');
    var bo = document.createElement('option'); bo.value = ''; bo.textContent = '-- Select member --'; mSel.appendChild(bo);
    memberList.forEach(function (m) {
      var o = document.createElement('option'); o.value = m.id;
      o.textContent = (m.full_name || m.username || '?') + ' (@' + (m.username || ')') + (m.subscription_tier !== 'free' ? ' [' + m.subscription_tier + ']' : '');
      mSel.appendChild(o);
    });
    mWrap.appendChild(mSel); grid.appendChild(mWrap);
    grid.appendChild(fs('tier', 'Upgrade to Tier', [{ v: 'premium', l: 'Premium -- ' + cur + (S.price_premium_monthly || '4.00') + '/mo' }, { v: 'event', l: 'Event / Wedding -- ' + cur + (S.price_event_monthly || '12.00') + '/mo' }]));
    grid.appendChild(fs('period', 'Billing Period', [{ v: 'monthly', l: 'Monthly' }, { v: 'annual', l: 'Annual' }]));
    grid.appendChild(fi('amount', 'Amount Received', '', 'text'));
    grid.appendChild(fs('method', 'Payment Method', [{ v: 'cash', l: 'Cash' }, { v: 'bank_transfer', l: 'Bank Transfer' }, { v: 'paypal', l: 'PayPal' }, { v: 'other', l: 'Other' }]));
    grid.appendChild(fi('ref', 'Reference / Receipt No.', 'e.g. TXN-12345', 'text'));
    grid.appendChild(fi('date', 'Payment Date', '', 'date'));
    setTimeout(function () { var d = document.getElementById('fmi-date'); if (d) d.value = new Date().toISOString().split('T')[0]; }, 0);
    var nw = mk('div', 'grid-column:1/-1'); nw.appendChild(mk('label', 'display:block;font-size:10px;text-transform:uppercase;letter-spacing:0.08em;color:var(--text-mid);margin-bottom:4px', 'Notes (optional)'));
    var na = mk('textarea', 'width:100%;box-sizing:border-box;padding:8px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high);resize:vertical;height:60px');
    na.id = 'fmi-notes'; nw.appendChild(na); grid.appendChild(nw); c.appendChild(grid);
    var sb = mk('button', 'padding:10px 24px;background:var(--accent);border:none;border-radius:8px;color:#fff;font-family:DM Sans,sans-serif;font-size:13px;font-weight:600;cursor:pointer', 'Record Payment');
    var sm = mk('span', 'margin-left:12px;font-family:DM Sans,sans-serif;font-size:12px;color:#4caf76', '');
    sb.addEventListener('click', async function () {
      var uid = mSel.value;
      if (!uid) { alert('Please select a member.'); return; }
      var tier = (document.getElementById('fmi-tier') || {}).value;
      var method = (document.getElementById('fmi-method') || {}).value || '';
      var ref = (document.getElementById('fmi-ref') || {}).value || '';
      var amount = (document.getElementById('fmi-amount') || {}).value || '';
      var notes = (document.getElementById('fmi-notes') || {}).value || '';
      var log = 'Manual ' + method + (ref ? ' ref:' + ref : '') + (amount ? ' ' + cur + amount : '') + (notes ? ' -- ' + notes : '');
      sb.disabled = true; sb.textContent = 'Saving\u2026'; sm.textContent = '';
      try {
        await rpc('admin_set_member_tier', { p_user_id: uid, p_tier: tier, p_notes: log });
        sm.textContent = '\u2713 Payment recorded, tier set to ' + tier;
        sb.textContent = 'Record Payment'; sb.disabled = false; mSel.value = '';
        fiCache.members = null;
        auditLog('Finance Management', 'Manual Payment Recorded', null, null, tier, log);
        var hist = document.getElementById('upanel-fi-history');
        if (hist && hist.dataset.built === '1') { hist.dataset.built = ''; buildFiHistory(hist); }
      } catch (e) { sb.textContent = 'Record Payment'; sb.disabled = false; sm.textContent = ''; alert('Error: ' + e.message); }
    });
    var br = mk('div', 'display:flex;align-items:center'); br.appendChild(sb); br.appendChild(sm); c.appendChild(br); panel.appendChild(c);
  }

  function renderFiInvoice(panel, S, memberList, cur) {
    panel.innerHTML = '';
    var c = card('Invoice Generator', 'Generate a simple receipt for any member. Useful for business accounts needing proof of subscription.');
    var mSel2 = mk('select', 'width:100%;padding:8px 10px;background:var(--bg);border:1px solid var(--border);border-radius:7px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-high);margin-bottom:14px');
    var b2 = document.createElement('option'); b2.value = ''; b2.textContent = '-- Select member --'; mSel2.appendChild(b2);
    memberList.forEach(function (m) {
      var o = document.createElement('option'); o.value = JSON.stringify({ name: m.full_name || m.username || '', email: m.email || '', tier: m.subscription_tier || 'free' });
      o.textContent = (m.full_name || m.username || '?') + ' (' + m.email + ')'; mSel2.appendChild(o);
    });
    c.appendChild(mSel2);
    var preview = mk('div', 'background:#fff;border-radius:10px;padding:28px;color:#222;font-family:DM Sans,sans-serif;margin-top:0;display:none'); preview.id = 'fmi-inv-preview';
    var genBtn = mk('button', 'padding:10px 24px;background:var(--accent);border:none;border-radius:8px;color:#fff;font-family:DM Sans,sans-serif;font-size:13px;font-weight:600;cursor:pointer', 'Generate Invoice');
    genBtn.addEventListener('click', function () {
      if (!mSel2.value) { alert('Select a member first.'); return; }
      var m = JSON.parse(mSel2.value);
      var price = m.tier === 'premium' ? (S.price_premium_monthly || '4.00') : m.tier === 'event' ? (S.price_event_monthly || '12.00') : '0.00';
      var tierLbl = m.tier === 'premium' ? 'Premium Plan' : m.tier === 'event' ? 'Event / Wedding Plan' : 'Free Plan';
      var today = new Date().toLocaleDateString('en-AU', { day: '2-digit', month: 'long', year: 'numeric' });
      var inv = 'INV-' + Date.now().toString().slice(-6);
      preview.style.display = 'block';
      preview.innerHTML = '<div style="display:flex;justify-content:space-between;border-bottom:2px solid #C4973B;padding-bottom:14px;margin-bottom:20px"><div><div style="font-family:Cormorant Garamond,serif;font-size:1.5rem;font-weight:700;color:#111">The Culinary Journal</div><div style="font-size:11px;color:#888">theculinaryjournal.site</div></div><div style="text-align:right"><div style="font-size:1rem;font-weight:700;color:#C4973B">INVOICE</div><div style="font-size:11px;color:#888">' + inv + '</div><div style="font-size:11px;color:#888">' + today + '</div></div></div>' +
        '<div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-bottom:20px"><div><div style="font-size:10px;font-weight:700;text-transform:uppercase;color:#888;margin-bottom:3px">Billed To</div><div style="font-size:13px;font-weight:600;color:#111">' + esc(m.name) + '</div><div style="font-size:12px;color:#666">' + esc(m.email) + '</div></div></div>' +
        '<table style="width:100%;border-collapse:collapse;margin-bottom:18px"><thead><tr style="background:#f5f5f0"><th style="padding:8px 12px;text-align:left;font-size:11px;font-weight:700;color:#555;text-transform:uppercase">Description</th><th style="padding:8px 12px;text-align:right;font-size:11px;font-weight:700;color:#555;text-transform:uppercase">Amount</th></tr></thead><tbody><tr style="border-bottom:1px solid #e0e0e0"><td style="padding:12px;font-size:13px;color:#222">' + tierLbl + ' \u2014 Monthly Subscription</td><td style="padding:12px;font-size:13px;font-weight:700;color:#111;text-align:right">' + cur + price + '</td></tr></tbody><tfoot><tr style="background:#f5f5f0"><td style="padding:10px 12px;font-size:13px;font-weight:700;color:#222">Total</td><td style="padding:10px 12px;font-size:14px;font-weight:700;color:#C4973B;text-align:right">' + cur + price + '</td></tr></tfoot></table>' +
        '<div style="font-size:11px;color:#999;border-top:1px solid #ddd;padding-top:10px">Thank you for your membership at The Culinary Journal.</div>';
    });
    var printBtn = mk('button', 'padding:10px 18px;background:rgba(255,255,255,0.08);border:1px solid var(--border);border-radius:8px;color:var(--text-mid);font-family:DM Sans,sans-serif;font-size:13px;cursor:pointer;margin-left:10px', 'Print / Save PDF');
    printBtn.addEventListener('click', function () { var pr = document.getElementById('fmi-inv-preview'); if (!pr || pr.style.display === 'none') { alert('Generate invoice first.'); return; } var w = window.open('', '_blank'); w.document.write('<html><head><title>Invoice</title></head><body>' + pr.innerHTML + '</body></html>'); w.document.close(); w.print(); });
    var br = mk('div', 'display:flex;align-items:center;margin-bottom:14px'); br.appendChild(genBtn); br.appendChild(printBtn); c.appendChild(br); c.appendChild(preview); panel.appendChild(c);
  }

  function renderFiExport(panel) {
    panel.innerHTML = '';
    var c = card('Export Financial Data', 'Download membership and revenue data as CSV for accounting, tax, or reporting.');
    var exports = [
      { label: 'All Members with Tier', icon: '&#128101;', desc: 'Full member list with name, email, tier, and join date.', fn: async function () {
        var r = await apiFetch(SUPABASE_URL + '/rest/v1/profiles?select=username,full_name,email,subscription_tier,created_at&order=created_at.desc');
        if (!r || !r.ok) throw new Error('Fetch failed');
        var rows = await r.json();
        _downloadFICSV('members-tiers.csv', 'Username,Full Name,Email,Tier,Joined\n' + rows.map(function (r) { return [r.username, r.full_name, r.email, r.subscription_tier, r.created_at ? new Date(r.created_at).toLocaleDateString('en-AU') : ''].map(function (v) { return '"' + String(v || '').replace(/"/g, '""') + '"'; }).join(','); }).join('\n'));
      }},
      { label: 'Subscription History', icon: '&#128196;', desc: 'Full log of all tier changes and subscription events.', fn: async function () {
        var rows = await rpc('admin_get_subscriptions', { p_limit: 9999, p_offset: 0 });
        if (!Array.isArray(rows)) throw new Error('No data');
        _downloadFICSV('subscription-history.csv', 'Username,Full Name,Email,Tier,Status,Source,Started,Notes\n' + rows.map(function (r) { return [r.username, r.full_name, r.email, r.tier, r.status, r.source, r.started_at ? new Date(r.started_at).toLocaleDateString('en-AU') : '', r.notes || ''].map(function (v) { return '"' + String(v || '').replace(/"/g, '""') + '"'; }).join(','); }).join('\n'));
      }},
      { label: 'Premium Members Only', icon: '&#11088;', desc: 'Filtered list of premium and event tier members only.', fn: async function () {
        var r = await apiFetch(SUPABASE_URL + '/rest/v1/profiles?select=username,full_name,email,subscription_tier,created_at&subscription_tier=neq.free&order=subscription_tier.asc,created_at.desc');
        if (!r || !r.ok) throw new Error('Fetch failed');
        var rows = await r.json();
        _downloadFICSV('premium-members.csv', 'Username,Full Name,Email,Tier,Joined\n' + rows.map(function (r) { return [r.username, r.full_name, r.email, r.subscription_tier, r.created_at ? new Date(r.created_at).toLocaleDateString('en-AU') : ''].map(function (v) { return '"' + String(v || '').replace(/"/g, '""') + '"'; }).join(','); }).join('\n'));
      }}
    ];
    exports.forEach(function (exp) {
      var row = mk('div', 'display:flex;align-items:center;justify-content:space-between;padding:12px 0;border-bottom:1px solid rgba(255,255,255,0.05)');
      var info = mk('div', '');
      info.appendChild(mk('div', 'font-size:13px;font-weight:600;color:var(--text-high)', exp.icon + ' ' + exp.label));
      info.appendChild(mk('div', 'font-size:11px;color:var(--text-mid);margin-top:2px', exp.desc));
      var btn = mk('button', 'padding:6px 14px;background:none;border:1px solid var(--border);border-radius:7px;color:var(--text-mid);font-family:DM Sans,sans-serif;font-size:11px;cursor:pointer;flex-shrink:0', '\u2b07 Export CSV');
      (function (fn, b) { b.addEventListener('click', async function () { b.disabled = true; b.textContent = 'Exporting\u2026'; try { await fn(); b.textContent = '\u2b07 Export CSV'; b.disabled = false; } catch (e) { b.textContent = '\u2b07 Export CSV'; b.disabled = false; alert('Export failed: ' + e.message); } }); })(exp.fn, btn);
      row.appendChild(info); row.appendChild(btn); c.appendChild(row);
    });
    panel.appendChild(c);
  }

  function renderFiPromo(panel, cur) {
    panel.innerHTML = '';
    var c = card('Promo & Discount Codes', 'Create discount codes for promotions, gifts, or partnerships. Codes are enforced at checkout once Stripe is connected.');
    c.appendChild(Object.assign(mk('div', 'padding:12px 14px;background:rgba(91,143,212,0.08);border:1px solid rgba(91,143,212,0.25);border-radius:9px;font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-mid);line-height:1.6;margin-bottom:16px'), { textContent: 'Promo code redemption activates when Stripe is connected. You can create and manage codes here now \u2014 they will be enforced at checkout automatically.' }));
    var form = mk('div', 'display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-bottom:14px');
    form.appendChild(fi('promo-code', 'Promo Code *', 'e.g. WELCOME20'));
    form.appendChild(fs('promo-type', 'Discount Type', [{ v: 'percent', l: 'Percentage off' }, { v: 'flat', l: 'Flat amount off' }, { v: 'free_month', l: 'One free month' }]));
    form.appendChild(fi('promo-value', 'Discount Value', 'e.g. 20 for 20%'));
    form.appendChild(fs('promo-tier', 'Applies to Tier', [{ v: 'premium', l: 'Premium' }, { v: 'event', l: 'Event / Wedding' }, { v: 'both', l: 'Both tiers' }]));
    form.appendChild(fi('promo-uses', 'Max Uses (blank = unlimited)', '', 'number'));
    form.appendChild(fi('promo-expires', 'Expiry Date', '', 'date'));
    c.appendChild(form);
    var _promos = [];
    var listDiv = mk('div', 'margin-top:8px');
    function promoTierLabel(t) { return t === 'event' ? 'Event' : t === 'both' ? 'Any tier' : (t || 'monthly'); }
    function renderPromos() {
      listDiv.innerHTML = '';
      if (!_promos.length) { listDiv.appendChild(mk('div', 'font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid)', 'No promo codes yet.')); return; }
      var tbl = document.createElement('table'); tbl.className = 'ap-table';
      tbl.innerHTML = '<thead><tr style="border-bottom:1px solid var(--border)"><th class="ap-th">Code</th><th class="ap-th">Type</th><th class="ap-th">Value</th><th class="ap-th">Tier grant</th><th class="ap-th">Uses</th><th class="ap-th">Expires</th><th class="ap-th">Delete</th></tr></thead>';
      var tbody = document.createElement('tbody');
      _promos.forEach(function (pp) {
        var tr = document.createElement('tr'); tr.style.borderBottom = '1px solid rgba(255,255,255,0.04)';
        var dtype = pp.discount_type || pp.type || 'percent';
        var dval = pp.discount_value != null ? pp.discount_value : pp.value;
        var usesTxt = (pp.uses_count || 0) + ' / ' + (pp.max_uses == null ? '\u221e' : pp.max_uses);
        var exp = pp.expires_at ? new Date(pp.expires_at).toLocaleDateString() : (pp.expires || 'Never');
        tr.innerHTML = '<td class="ap-td"><span style="font-family:monospace;font-size:12px;color:var(--accent);font-weight:700">' + esc(pp.code) + '</span></td>' +
          '<td class="ap-td" style="font-size:12px;color:var(--text-mid)">' + esc(dtype.replace('_', ' ')) + '</td>' +
          '<td class="ap-td" style="font-size:12px;color:var(--text-high)">' + esc(dtype === 'percent' ? dval + '%' : dtype === 'flat' ? cur + dval : 'Free month') + '</td>' +
          '<td class="ap-td" style="font-size:12px;color:var(--text-mid)">' + esc(promoTierLabel(pp.tier_grant || pp.tier)) + '</td>' +
          '<td class="ap-td" style="font-size:12px;color:var(--text-mid)">' + esc(usesTxt) + '</td>' +
          '<td class="ap-td" style="font-size:12px;color:var(--text-mid)">' + esc(exp) + '</td><td class="ap-td"></td>';
        var db = mk('button', 'padding:4px 10px;background:none;border:1px solid #dc5050;border-radius:6px;color:#dc5050;font-size:11px;cursor:pointer', 'Delete');
        db.addEventListener('click', function () {
          if (!confirm('Delete promo ' + pp.code + '?')) return;
          rpc('admin_delete_promo_code', { p_code: pp.code }).then(function () { loadPromos(); }).catch(function (e) { alert(e.message || e); });
        });
        tr.lastElementChild.appendChild(db); tbody.appendChild(tr);
      });
      tbl.appendChild(tbody); listDiv.appendChild(tbl);
    }
    function loadPromos() {
      rpc('admin_get_promo_codes', {}).then(function (rows) {
        _promos = Array.isArray(rows) ? rows : [];
        renderPromos();
      }).catch(function (e) {
        listDiv.innerHTML = '<div style="font-size:12px;color:#dc5050">' + esc(e.message || e) + '</div>';
      });
    }
    loadPromos();
    var addBtn = mk('button', 'padding:10px 24px;background:var(--accent);border:none;border-radius:8px;color:#fff;font-family:DM Sans,sans-serif;font-size:13px;font-weight:600;cursor:pointer', '+ Add Promo Code');
    addBtn.addEventListener('click', function () {
      var code = ((document.getElementById('fmi-promo-code') || {}).value || '').trim().toUpperCase();
      if (!code) { alert('Code is required.'); return; }
      var tierSel = (document.getElementById('fmi-promo-tier') || {}).value || 'premium';
      var tierGrant = tierSel === 'event' ? 'event' : tierSel === 'both' ? 'monthly' : 'monthly';
      var maxUses = ((document.getElementById('fmi-promo-uses') || {}).value || '').trim();
      var expDate = ((document.getElementById('fmi-promo-expires') || {}).value || '').trim();
      var val = parseFloat(((document.getElementById('fmi-promo-value') || {}).value || '0')) || 0;
      rpc('admin_upsert_promo_code', {
        p_code: code,
        p_discount_type: (document.getElementById('fmi-promo-type') || {}).value || 'percent',
        p_discount_value: val,
        p_tier_grant: tierGrant,
        p_max_uses: maxUses ? parseInt(maxUses, 10) : null,
        p_expires_at: expDate ? new Date(expDate + 'T23:59:59').toISOString() : null
      }).then(function () {
        loadPromos();
        document.getElementById('fmi-promo-code').value = ''; document.getElementById('fmi-promo-value').value = '';
        auditLog('Finance Management', 'Promo Code Created', code, null, null, code);
      }).catch(function (e) { alert(e.message || e); });
    });
    c.appendChild(addBtn); c.appendChild(listDiv); panel.appendChild(c);
  }

  try {
    container.innerHTML = '';
    container.dataset.built = '1';

    AdminTabNav.buildInterfaceShell(container, {
      storageKey: 'tcj_fmi_tab',
      defaultKey: 'hub',
      banner: 'Finance tools — overview and billing stay in the tabs above.',
      sections: [
        {
          key: 'hub',
          label: 'Hub',
          group: 'Overview',
          subtitle: 'Tier snapshot and one-click tools',
          refreshOnShow: true,
          render: function (panel, ctx, isRefresh) {
            if (!isRefresh) panel.innerHTML = '<div class="admin-if-loading">Loading stats…</div>';
            return Promise.all([
              fiTiers(),
              typeof TcjAdminCounts !== 'undefined'
                ? TcjAdminCounts.fetchInboxCounts(isRefresh).then(function (c) { return c.print_orders_pending || 0; })
                : rpc('admin_count_print_orders', { p_status: 'pending' }).catch(function () { return 0; })
            ]).then(function (res) {
              var tiers = res[0] || {};
              AdminTabNav.renderHub(panel, {
                intro: 'Record payments, generate invoices, export CSV, or manage promo codes — open a section in the sidebar or use a shortcut.',
                stats: [
                  { num: tiers.premium || 0, label: 'Premium' },
                  { num: tiers.event || 0, label: 'Event tier' },
                  { num: res[1] || 0, label: 'Print orders' }
                ],
                actions: [
                  { label: 'Manual payment', desc: 'Record off-system payment', onClick: function () { ctx.activate('manual'); } },
                  { label: 'Invoice generator', desc: 'Printable receipt', onClick: function () { ctx.activate('invoice'); } },
                  { label: 'Export CSV', desc: 'Members & subscriptions', onClick: function () { ctx.activate('export'); } },
                  { label: 'Promo codes', desc: 'Discount codes', onClick: function () { ctx.activate('promo'); } },
                  { label: 'Member tiers', desc: 'Grant or change tier', onClick: function () { switchFinanceTab('fi-members'); } },
                  { label: 'Pricing', desc: 'Monthly & annual rates', onClick: function () { switchFinanceTab('fi-pricing'); } }
                ]
              });
            });
          }
        },
        {
          key: 'manual',
          label: 'Manual payment',
          group: 'Tools',
          subtitle: 'Cash, transfer, PayPal, etc.',
          render: function (panel) {
            panel.innerHTML = '<div class="admin-if-loading">Loading members…</div>';
            return Promise.all([fiSettings(), fiMembers()]).then(function (res) {
              renderFiManual(panel, res[0], res[1], res[0].currency_symbol || '$');
            });
          }
        },
        {
          key: 'invoice',
          label: 'Invoice',
          group: 'Tools',
          subtitle: 'Generate printable receipt',
          render: function (panel) {
            panel.innerHTML = '<div class="admin-if-loading">Loading members…</div>';
            return Promise.all([fiSettings(), fiMembers()]).then(function (res) {
              renderFiInvoice(panel, res[0], res[1], res[0].currency_symbol || '$');
            });
          }
        },
        {
          key: 'export',
          label: 'Export data',
          group: 'Tools',
          subtitle: 'CSV downloads for accounting',
          render: function (panel) { renderFiExport(panel); }
        },
        {
          key: 'promo',
          label: 'Promo codes',
          group: 'Tools',
          subtitle: 'Discount codes for checkout',
          render: function (panel) {
            return fiSettings().then(function (S) { renderFiPromo(panel, S.currency_symbol || '$'); });
          }
        }
      ]
    });
  } catch (e) {
    container.dataset.built = '';
    container.innerHTML = '<div style="padding:16px;background:rgba(220,80,80,0.1);border:1px solid rgba(220,80,80,0.4);border-radius:10px;font-family:DM Sans,sans-serif;font-size:13px;color:#dc5050"><strong>Error:</strong> ' + String(e.message).replace(/</g, '&lt;') + '</div>';
  }
}

// ── Send Email to User ──────────────────────────────────────────────────────