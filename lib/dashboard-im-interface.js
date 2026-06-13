// The Culinary Journal — Dashboard IM Interface module
// Loaded by dashboard.html after dashboard-ingredients.js (_imGet/_imSet)
// Requires: dashboard-shared.js (rpc, session), dashboard-ingredients.js

// ── IM INTERFACE — complete rebuild ──────────────────────────────
let _imSettings = {};

function getUnits(){ return _imGet('tcj_units',['cup','tbsp','tsp','ml','l','g','kg','oz','lb','piece','bunch','clove','leaf','sprig','pinch','slice','sheet','can','bottle','packet','whole']); }

function getCats(){ return _imGet('tcj_cats',['Baking','Grains, Pasta & Noodles','Breads & Flatbreads','Packaged & Convenience','Meat','Poultry','Seafood','Dairy & Eggs','Plant-Based','Vegetables','Fruits','Herbs','Spices','Oils & Fats','Legumes & Pulses','Nuts & Seeds','Condiments & Sauces','Vinegars','Sweeteners','Canned & Preserved','Alcohol & Cooking Wine','Stocks & Broths']); }

function getSubCats(){
  var _defaults={"Baking": ["Flour", "Sugar", "Leavening Agents", "Binding Agents", "Chocolate & Cocoa", "Starches", "Food Colouring", "Mixes & Pre-mixes"], "Grains, Pasta & Noodles": ["Rice", "Pasta", "Noodles", "Quinoa", "Oats", "Barley & Rye", "Couscous & Bulgur"], "Breads & Flatbreads": ["White Bread", "Wholegrain & Sourdough", "Flatbreads", "Wraps & Tortillas", "Crackers & Crispbreads", "Rolls & Buns"], "Packaged & Convenience": ["Canned Meals", "Instant Noodles", "Breakfast Cereals", "Frozen Meals", "Snack Foods", "Packet Mixes"], "Meat": ["Beef", "Pork", "Lamb", "Veal", "Game Meat", "Offal", "Processed & Cured Meat", "Mince & Ground"], "Poultry": ["Chicken", "Turkey", "Duck", "Quail & Goose", "Processed Poultry"], "Seafood": ["Fish \u2014 White", "Fish \u2014 Oily", "Prawns & Shrimp", "Crab & Lobster", "Squid & Octopus", "Mussels & Clams", "Oysters", "Smoked & Preserved Seafood"], "Dairy & Eggs": ["Milk", "Cream", "Butter", "Cheese \u2014 Hard", "Cheese \u2014 Soft", "Yoghurt", "Eggs", "Ice Cream & Frozen"], "Plant-Based": ["Tofu", "Tempeh", "Plant Milk", "Meat Alternatives", "Vegan Cheese", "Vegan Cream & Butter"], "Vegetables": ["Root Vegetables", "Leafy Greens", "Brassicas", "Alliums", "Nightshades", "Squash & Gourds", "Fungi", "Stems & Shoots", "Pods & Corn"], "Fruits": ["Citrus", "Stone Fruits", "Berries", "Tropical Fruits", "Melons", "Apples & Pears", "Dried Fruits", "Fruit Preserves"], "Herbs": ["Fresh Herbs", "Dried Herbs"], "Spices": ["Whole Spices", "Ground Spices", "Spice Blends", "Chilli & Pepper", "Salt & Pepper"], "Oils & Fats": ["Neutral Cooking Oils", "Olive Oil", "Specialty Oils", "Butter & Ghee", "Margarine & Shortening", "Animal Fats"], "Legumes & Pulses": ["Lentils", "Chickpeas", "Beans", "Peas", "Dried Legumes", "Canned Legumes"], "Nuts & Seeds": ["Tree Nuts", "Nut Butters & Pastes", "Seeds", "Seed Butters", "Mixed Nuts & Trail Mix"], "Condiments & Sauces": ["Tomato Based", "Soy & Asian Sauces", "Mustard & Mayonnaise", "Hot Sauces", "Dressings & Vinaigrettes", "Pestos & Relishes"], "Vinegars": ["White & Red Wine Vinegar", "Apple Cider Vinegar", "Rice Vinegar", "Balsamic Vinegar", "Malt Vinegar", "Specialty Vinegars"], "Sweeteners": ["White & Raw Sugar", "Brown & Muscovado Sugar", "Honey", "Maple & Agave Syrup", "Artificial Sweeteners", "Molasses & Treacle"], "Canned & Preserved": ["Canned Tomatoes", "Canned Vegetables", "Canned Fish", "Preserved Meats", "Pickles & Fermented", "Jams & Spreads"], "Alcohol & Cooking Wine": ["White Wine", "Red Wine", "Fortified Wine", "Beer", "Spirits & Liqueurs", "Non-Alcoholic Substitutes"], "Stocks & Broths": ["Chicken Stock", "Beef Stock", "Vegetable Stock", "Fish Stock", "Bone Broth", "Concentrated Stock Pastes"]};
  var stored=_imGet('tcj_subcats',null);
  if(stored===null){
    // First load — seed defaults
    _imSet('tcj_subcats',_defaults);
    return _defaults;
  }
  return stored;
}

function getCurrencies(){ return _imGet('tcj_currencies',['AED', 'AFN', 'ALL', 'AMD', 'ANG', 'AOA', 'ARS', 'AUD', 'AWG', 'AZN', 'BAM', 'BBD', 'BDT', 'BGN', 'BHD', 'BIF', 'BMD', 'BND', 'BOB', 'BRL', 'BSD', 'BTN', 'BWP', 'BYN', 'BZD', 'CAD', 'CDF', 'CHF', 'CLP', 'CNY', 'COP', 'CRC', 'CUP', 'CVE', 'CZK', 'DJF', 'DKK', 'DOP', 'DZD', 'EGP', 'ERN', 'ETB', 'EUR', 'FJD', 'FKP', 'GBP', 'GEL', 'GHS', 'GIP', 'GMD', 'GNF', 'GTQ', 'GYD', 'HKD', 'HNL', 'HRK', 'HTG', 'HUF', 'IDR', 'ILS', 'INR', 'IQD', 'IRR', 'ISK', 'JMD', 'JOD', 'JPY', 'KES', 'KGS', 'KHR', 'KMF', 'KPW', 'KRW', 'KWD', 'KYD', 'KZT', 'LAK', 'LBP', 'LKR', 'LRD', 'LSL', 'LYD', 'MAD', 'MDL', 'MGA', 'MKD', 'MMK', 'MNT', 'MOP', 'MRU', 'MUR', 'MVR', 'MWK', 'MXN', 'MYR', 'MZN', 'NAD', 'NGN', 'NIO', 'NOK', 'NPR', 'NZD', 'OMR', 'PAB', 'PEN', 'PGK', 'PHP', 'PKR', 'PLN', 'PYG', 'QAR', 'RON', 'RSD', 'RUB', 'RWF', 'SAR', 'SBD', 'SCR', 'SDG', 'SEK', 'SGD', 'SHP', 'SLL', 'SOS', 'SRD', 'STN', 'SVC', 'SYP', 'SZL', 'THB', 'TJS', 'TMT', 'TND', 'TOP', 'TRY', 'TTD', 'TWD', 'TZS', 'UAH', 'UGX', 'USD', 'UYU', 'UZS', 'VES', 'VND', 'VUV', 'WST', 'XAF', 'XCD', 'XOF', 'XPF', 'YER', 'ZAR', 'ZMW', 'ZWL']); }

function getUnitMeta(){ return _imGet('tcj_unit_meta',{}); }

function getCatMeta(){ return _imGet('tcj_cat_meta',{}); }

function getSubMeta(){ return _imGet('tcj_sub_meta',{}); }

function getAdminName(){
  try{
    var _p=JSON.parse(localStorage.getItem('tcj_profile')||'null');
    if(_p&&_p.username) return _p.username;
    if(_p&&_p.full_name) return _p.full_name;
    if(_p&&_p.email) return _p.email;
    var _s=JSON.parse(localStorage.getItem('tcj_session')||'null');
    if(_s&&_s.user&&_s.user.email) return _s.user.email;
    return 'Admin';
  }catch(e){return 'Admin';}
}


// ── Column resize helper ─────────────────────────────────────────

function auditLog(tab,action,target,oldVal,newVal,details){
  try{
    rpc('admin_log_action',{
      p_admin_name: getAdminName(),
      p_tab: tab, p_action: action,
      p_target: target||null,
      p_old_value: oldVal!=null?String(oldVal):null,
      p_new_value: newVal!=null?String(newVal):null,
      p_details: details||null
    }).catch(function(err){ console.warn('audit log', err); });
  }catch(e){ console.warn('auditLog', e); }
}

function _tipOn(el, text){
  if(!text)return;
  el.style.cursor='help';
  el.style.borderBottom='1px dotted var(--text-mid)';
  el.addEventListener('mouseenter',function(ev){
    var tip=document.createElement('div');tip.className='tcj-tip';
    tip.textContent=text;tip.id='_tcj_tip';document.body.appendChild(tip);
    function moveTip(e){
      var t=document.getElementById('_tcj_tip');
      if(!t)return;
      var x=e.clientX+14, y=e.clientY+14;
      if(x+290>window.innerWidth)x=e.clientX-300;
      t.style.left=x+'px'; t.style.top=y+'px';
    }
    document.addEventListener('mousemove',moveTip);
    el._moveTip=moveTip;
  });
  el.addEventListener('mouseleave',function(){
    var t=document.getElementById('_tcj_tip');if(t)t.remove();
    if(el._moveTip)document.removeEventListener('mousemove',el._moveTip);
  });
}

var _imS = {
  label: "font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-mid)",
  hdr:   "font-family:'DM Sans',sans-serif;font-size:9px;font-weight:600;letter-spacing:0.1em;text-transform:uppercase;color:var(--text-mid);padding:2px 4px",
  inp:   "font-family:'DM Sans',sans-serif;font-size:12px;padding:5px 8px;border:1px solid var(--border);border-radius:6px;background:var(--bg);color:var(--text-high);outline:none;width:100%;box-sizing:border-box",
  sel:   "font-family:'DM Sans',sans-serif;font-size:11px;padding:5px 8px;border:1px solid var(--border);border-radius:6px;background:var(--bg);color:var(--text-high);outline:none;cursor:pointer;width:100%;box-sizing:border-box",
  btn:   "padding:5px 14px;border:none;border-radius:6px;font-family:'DM Sans',sans-serif;font-size:12px;font-weight:600;cursor:pointer",
  delBtn:"padding:4px 8px;background:none;border:1px solid #dc5050;border-radius:5px;color:#dc5050;cursor:pointer;font-size:12px;flex-shrink:0"
};

// ── Accordion helper ─────────────────────────────────────────────

function makeAccordion(title, contentFn, startOpen, container){
  var wrap=document.createElement('div');
  wrap.style.cssText='margin-bottom:12px;border:1px solid var(--border);border-radius:10px;overflow:hidden';
  wrap.dataset.accordion='1';

  var hdr=document.createElement('div');
  hdr.style.cssText='display:flex;align-items:center;justify-content:space-between;padding:10px 14px;background:rgba(255,255,255,0.03);cursor:pointer;user-select:none';

  var t=document.createElement('div');
  t.style.cssText="font-family:'Cormorant Garamond',serif;font-size:1rem;font-weight:700;color:var(--text-high)";
  t.textContent=title;

  var arr=document.createElement('span');
  arr.style.cssText='font-size:14px;color:var(--text-mid);transition:transform 0.2s';
  arr.textContent='▲';
  if(startOpen===false){arr.textContent='▼';}

  var body=document.createElement('div');
  body.style.cssText='padding:14px';
  if(startOpen===false) body.style.display='none';

  hdr.addEventListener('click',function(){
    var open=body.style.display!=='none';
    body.style.display=open?'none':'block';
    arr.textContent=open?'▼':'▲';
  });

  hdr.appendChild(t); hdr.appendChild(arr);
  wrap.appendChild(hdr); wrap.appendChild(body);
  if(container) container.appendChild(wrap);
  contentFn(body);
  return wrap;
}

// ── Expand All / Collapse All bar ────────────────────────────────

function makeExpandCollapseBar(container){
  var bar=document.createElement('div');
  bar.style.cssText='display:flex;gap:8px;margin-bottom:14px;align-items:center';
  function makeBtn(label, open){
    var b=document.createElement('button');
    b.textContent=label;
    b.style.cssText='padding:4px 12px;background:none;border:1px solid var(--border);border-radius:6px;'+_imS.label+';cursor:pointer';
    b.addEventListener('click',function(){
      container.querySelectorAll('[data-accordion]').forEach(function(acc){
        var body=acc.querySelector('div:last-child');
        var arr=acc.querySelector('span');
        if(body){ body.style.display=open?'block':'none'; }
        if(arr){ arr.textContent=open?'▲':'▼'; }
      });
    });
    return b;
  }
  bar.appendChild(makeBtn('Expand All',true));
  bar.appendChild(makeBtn('Collapse All',false));
  return bar;
}

// ── IM Interface main loader ─────────────────────────────────────

function loadIMInterface(){
  var el=document.getElementById('im-interface-content');
  if(!el) return;
  el.innerHTML='';

  // ── Top-level tab bar ────────────────────────────────────────
  var TAB_DEFS=[
    {key:'refdata',    label:'Ingredient Data Management'},
    {key:'duplicates', label:'🔍 Find Duplicates'},
    {key:'analytics',  label:'📊 Analytics'},
    {key:'audit',      label:'Audit Trail'},
    {key:'recycle',    label:'Recycle Bin'}
  ];

  var topBar=document.createElement('div');
  topBar.style.cssText='display:flex;gap:0;border-bottom:1px solid var(--border);margin-bottom:20px';
  var topPanels={};
  var activeTop=localStorage.getItem('tcj_active_im_tab')||'refdata';
  if(activeTop==='health'){
    activeTop='refdata';
    localStorage.setItem('tcj_active_im_tab','refdata');
  }

  TAB_DEFS.forEach(function(td){
    var btn=document.createElement('button');
    btn.style.cssText="padding:9px 18px;font-family:'DM Sans',sans-serif;font-size:12px;font-weight:500;background:none;border:none;border-bottom:2px solid transparent;cursor:pointer;color:var(--text-mid);margin-bottom:-1px;white-space:nowrap";
    btn.textContent=td.label; btn.dataset.imtab=td.key;
    btn.addEventListener('click',function(){
      topBar.querySelectorAll('button').forEach(function(b){ b.style.borderBottomColor='transparent'; b.style.color='var(--text-mid)'; });
      btn.style.borderBottomColor='var(--accent)'; btn.style.color='var(--accent)';
      localStorage.setItem('tcj_active_im_tab', td.key);
      Object.keys(topPanels).forEach(function(k){ topPanels[k].style.display=k===td.key?'block':'none'; });
      if(td.key==='recycle')    loadIngRecycleBinInto(topPanels['recycle']);
      if(td.key==='duplicates') loadIngDuplicates(topPanels['duplicates']);
      if(td.key==='audit')   loadAuditTrail(topPanels['audit']);
      if(td.key==='analytics') loadIngAnalytics(topPanels['analytics']);
    });
    if(td.key===activeTop){ btn.style.borderBottomColor='var(--accent)'; btn.style.color='var(--accent)'; }
    topBar.appendChild(btn);

    var panel=document.createElement('div');
    panel.style.display=td.key===activeTop?'block':'none';
    topPanels[td.key]=panel;
  });

  el.appendChild(topBar);
  Object.values(topPanels).forEach(function(p){ el.appendChild(p); });

  // ── TAB: Reference Data ──────────────────────────────────────
  buildRefDataTab(topPanels['refdata']);

  // ── TAB: Column Settings ─────────────────────────────────────
  // Column Settings now inside IDM sub-tabs

  // ── TAB: Recycle Bin ─────────────────────────────────────────
  topPanels['recycle'].innerHTML='<div style="'+_imS.label+';padding:8px 0">Loading\u2026</div>';
  if(activeTop==='recycle')    loadIngRecycleBinInto(topPanels['recycle']);
  if(activeTop==='duplicates') loadIngDuplicates(topPanels['duplicates']);
  // ── Trigger load for restored active tab ─────────────────────
  if(activeTop==='audit')    loadAuditTrail(topPanels['audit']);
  if(activeTop==='analytics') loadIngAnalytics(topPanels['analytics']);

  // ── TAB: Audit Trail ─────────────────────────────────────────
  var _atWrap=document.createElement('div');
  var _atBar=makeExpandCollapseBar(_atWrap);
  var _atContent=document.createElement('div');
  _atContent.dataset.accordion='1';
  _atContent.innerHTML='<div style="'+_imS.label+';padding:8px 0">Click the Audit Trail tab to load.</div>';
  _atWrap.appendChild(_atBar); _atWrap.appendChild(_atContent);
  topPanels['audit'].appendChild(_atWrap);
  // override loadAuditTrail to target _atContent
  topPanels['audit']._content = _atContent;
}

// ── Reference Data Tab ───────────────────────────────────────────
// ── REFERENCE DATA TAB - Complete rebuild ────────────────────────
// Sub-tabs: Categories | Sub Categories | Units | Currencies | Brand Mapping
// Each has: ID, alphabetical order, strategic columns, Save button
// Save All per tab (not global)

// ── Reference Data Import / Export ──────────────────────────────

// ── CSV helpers ──────────────────────────────────────────────────

function makeImportExportBar(exportFn, importFn, label){
  var bar=document.createElement('div');
  bar.style.cssText='display:flex;gap:8px;margin-bottom:14px;align-items:center';

  var expBtn=document.createElement('button');
  expBtn.textContent='⬇ Export '+label;
  expBtn.style.cssText="padding:6px 14px;background:none;border:1px solid var(--border);border-radius:6px;font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-mid);cursor:pointer";
  expBtn.addEventListener('click',exportFn);

  var impBtn=document.createElement('button');
  impBtn.textContent='⬆ Import '+label;
  impBtn.style.cssText="padding:6px 14px;background:none;border:1px solid var(--accent);border-radius:6px;font-family:'DM Sans',sans-serif;font-size:11px;color:var(--accent);cursor:pointer";

  var fileIn=document.createElement('input');
  fileIn.type='file';fileIn.accept='.csv';fileIn.style.display='none';
  fileIn.addEventListener('change',function(){
    if(!this.files[0])return;
    Papa.parse(this.files[0],{header:true,skipEmptyLines:true,complete:function(results){
      importFn(results.data, results.meta.fields||[]);
    }});
    this.value='';
  });
  impBtn.addEventListener('click',function(){fileIn.click();});

  bar.appendChild(expBtn);bar.appendChild(impBtn);bar.appendChild(fileIn);
  return bar;
}

// ── Import preview modal ─────────────────────────────────────────

function importCategoriesCSV(data, fields){
  if(!data||!data.length){alert('No data found in CSV.');return;}
  // Detect columns (case-insensitive)
  var fMap={};
  (fields||[]).forEach(function(f){ fMap[f.toLowerCase().replace(/\s/g,'')]=f; });
  var catCol=fMap['category']||fMap['cat']||fields[1];
  var reqCol=fMap['categoryrequired']||fMap['required']||fields[2];
  var actCol=fMap['categoryactive']||fMap['active']||fields[3];
  var subCol=fMap['subcategory']||fMap['sub-category']||fMap['subcategories']||fields[4];
  var noteCol=fMap['notes']||fMap['note']||fields[5];

  var newCats={}; var newMeta={};
  data.forEach(function(row){
    var cat=(row[catCol]||'').trim();
    var sub=(row[subCol]||'').trim();
    var req=(row[reqCol]||'').trim()||null;
    var act=(row[actCol]||'').trim()||null;
    if(!cat)return;
    if(!newCats[cat]){
      newCats[cat]=[];
      newMeta[cat]={required:req||'No',active:act||'Yes'};
    }
    if(sub&&!newCats[cat].includes(sub))newCats[cat].push(sub);
  });

  var catList=Object.keys(newCats).sort();
  var totalSubs=catList.reduce(function(n,c){return n+newCats[c].length;},0);
  var summary=catList.length+' categories\n'+totalSubs+' sub-categories\n\nMerge adds new items to your existing list.\nReplace clears everything and loads only this file.';

  showImportPreview('Import Categories & Sub Categories', summary,
    function(){
      // Merge
      var existing=getCats();var existingSubs=getSubCats();var existingMeta=getCatMeta();
      catList.forEach(function(cat){
        if(!existing.includes(cat))existing.push(cat);
        if(!existingSubs[cat])existingSubs[cat]=[];
        newCats[cat].forEach(function(s){ if(!existingSubs[cat].includes(s))existingSubs[cat].push(s); });
        if(newMeta[cat])existingMeta[cat]=newMeta[cat];
      });
      _imSet('tcj_cats',existing.sort());_imSet('tcj_subcats',existingSubs);_imSet('tcj_cat_meta',existingMeta);
      CATS_LIST.length=0;existing.sort().forEach(function(c){CATS_LIST.push(c);});
      auditLog('IM Interface','Import Merge','Categories & Sub Categories',null,null,catList.length+' cats merged');
      loadIMInterface();
    },
    function(){
      // Replace
      var newSubsStore={};catList.forEach(function(c){newSubsStore[c]=newCats[c].sort();});
      _imSet('tcj_cats',catList);_imSet('tcj_subcats',newSubsStore);_imSet('tcj_cat_meta',newMeta);
      CATS_LIST.length=0;catList.forEach(function(c){CATS_LIST.push(c);});
      auditLog('IM Interface','Import Replace','Categories & Sub Categories',null,null,catList.length+' cats replaced');
      loadIMInterface();
    }
  );
}

// ── Units Export ─────────────────────────────────────────────────

function exportUnitsCSV(){
  var units=getUnits().slice().sort();var meta=getUnitMeta();
  var rows=[['ID','Unit','Measurement Type','Min','Max','Decimal Places','Required','Active','Description','Notes']];
  units.forEach(function(u,i){
    var m=meta[u]||{};
    rows.push([i+1,u,m.mtype||'Other',m.min!=null?m.min:'',m.max!=null?m.max:'',m.decimals!=null?m.decimals:'',m.required||'No',m.active||'Yes',m.description||'','']);
  });
  _downloadCSV('units.csv',rows);
  auditLog('IM Interface > Reference Data','Export','Units',null,null,units.length+' units exported');
}

// ── Units Import ─────────────────────────────────────────────────

function importUnitsCSV(data, fields){
  if(!data||!data.length){alert('No data found in CSV.');return;}
  var fMap={};(fields||[]).forEach(function(f){fMap[f.toLowerCase().replace(/[\s\/\(\)]/g,'')]=f;});
  var unitCol=fMap['unit']||fields[1];
  var typeCol=fMap['measurementtype']||fMap['type']||fields[2];
  var minCol=fMap['min']||fields[3];
  var maxCol=fMap['max']||fields[4];
  var decCol=fMap['decimalplaces']||fMap['decimals']||fields[5];
  var reqCol=fMap['required']||fields[6];
  var actCol=fMap['active']||fields[7];
  var descCol=fMap['description']||fields[8];

  var newUnits=[];var newMeta={};
  data.forEach(function(row){
    var u=(row[unitCol]||'').trim();if(!u)return;
    if(!newUnits.includes(u))newUnits.push(u);
    newMeta[u]={
      mtype:(row[typeCol]||'Other').trim(),
      min:row[minCol]!==undefined&&row[minCol]!==''?parseFloat(row[minCol]):null,
      max:row[maxCol]!==undefined&&row[maxCol]!==''?parseFloat(row[maxCol]):null,
      decimals:row[decCol]!==undefined&&row[decCol]!==''?parseInt(row[decCol]):null,
      required:(row[reqCol]||'No').trim(),
      active:(row[actCol]||'Yes').trim(),
      description:descCol&&row[descCol]?(row[descCol]||'').trim():''
    };
  });
  newUnits.sort();
  showImportPreview('Import Units',newUnits.length+' units found in CSV.\n\nMerge adds new units to your existing list.\nReplace clears everything and loads only this file.',
    function(){
      var ex=getUnits();var exM=getUnitMeta();
      newUnits.forEach(function(u){if(!ex.includes(u))ex.push(u);exM[u]=newMeta[u];});
      _imSet('tcj_units',ex.sort());_imSet('tcj_unit_meta',exM);
      auditLog('IM Interface','Import Merge','Units',null,null,newUnits.length+' units merged');
      loadIMInterface();
    },
    function(){
      _imSet('tcj_units',newUnits);_imSet('tcj_unit_meta',newMeta);
      auditLog('IM Interface','Import Replace','Units',null,null,newUnits.length+' units replaced');
      loadIMInterface();
    }
  );
}

// ── Currencies Export ─────────────────────────────────────────────

function exportCurrenciesCSV(){
  var currencies=getCurrencies().slice().sort();var meta=_imGet('tcj_curr_meta',{});
  var rows=[['ID','Code','Full Name','Active']];
  currencies.forEach(function(c,i){ var m=meta[c]||{}; rows.push([i+1,c,m.name||'',m.active||'Yes']); });
  _downloadCSV('currencies.csv',rows);
  auditLog('IM Interface > Reference Data','Export','Currencies',null,null,currencies.length+' currencies exported');
}

// ── Currencies Import ─────────────────────────────────────────────

function importCurrenciesCSV(data, fields){
  if(!data||!data.length){alert('No data found in CSV.');return;}
  var fMap={};(fields||[]).forEach(function(f){fMap[f.toLowerCase()]=f;});
  var codeCol=fMap['code']||fields[1];var nameCol=fMap['full name']||fMap['name']||fields[2];var actCol=fMap['active']||fields[3];
  var newCurrs=[];var newMeta={};
  data.forEach(function(row){
    var c=(row[codeCol]||'').trim().toUpperCase();if(!c)return;
    if(!newCurrs.includes(c))newCurrs.push(c);
    newMeta[c]={name:(row[nameCol]||'').trim(),active:(row[actCol]||'Yes').trim()};
  });
  newCurrs.sort();
  showImportPreview('Import Currencies',newCurrs.length+' currencies found in CSV.\n\nMerge adds new currencies to your existing list.\nReplace clears everything and loads only this file.',
    function(){var ex=getCurrencies();var exM=_imGet('tcj_curr_meta',{});newCurrs.forEach(function(c){if(!ex.includes(c))ex.push(c);exM[c]=newMeta[c];});_imSet('tcj_currencies',ex.sort());_imSet('tcj_curr_meta',exM);loadIMInterface();},
    function(){_imSet('tcj_currencies',newCurrs);_imSet('tcj_curr_meta',newMeta);loadIMInterface();}
  );
}

function buildRefDataTab(container){
  // Track unsaved state per sub-tab
  var _dirty = {categories:false, subcategories:false, units:false, currencies:false, brands:false};

  // Sub-tab bar
  var SUB=[
    {key:'brands',        label:'Brand Mapping'},
    {key:'colsettings',   label:'Column Settings'},
    {key:'categories',    label:'Categories'},
    {key:'subcategories', label:'Sub Categories'},
    {key:'units',         label:'Units'},
    {key:'currencies',    label:'Currencies'}
  ];
  var subBar=document.createElement('div');
  subBar.style.cssText='display:flex;gap:0;border-bottom:1px solid var(--border);margin-bottom:16px;flex-wrap:wrap';
  var subPanels={};
  var activeSub=localStorage.getItem('tcj_active_sub_tab')||'brands';

  SUB.forEach(function(s){
    var btn=document.createElement('button');
    btn.style.cssText="padding:8px 16px;font-family:'DM Sans',sans-serif;font-size:11px;font-weight:500;background:none;border:none;border-bottom:2px solid transparent;cursor:pointer;color:var(--text-mid);margin-bottom:-1px;white-space:nowrap";
    btn.textContent=s.label; btn.dataset.subtab=s.key;
    btn.addEventListener('click',function(){
      // Prompt if dirty
      if(_dirty[activeSub]){
        if(!confirm('You have unsaved changes in '+activeSub+'. Leave without saving?')) return;
        _dirty[activeSub]=false;
      }
      activeSub=s.key;
      localStorage.setItem('tcj_active_sub_tab', s.key);
      subBar.querySelectorAll('button').forEach(function(b){ b.style.borderBottomColor='transparent'; b.style.color='var(--text-mid)'; });
      btn.style.borderBottomColor='var(--accent)'; btn.style.color='var(--accent)';
      Object.keys(subPanels).forEach(function(k){ subPanels[k].style.display=k===s.key?'block':'none'; });
    });
    if(s.key===activeSub){ btn.style.borderBottomColor='var(--accent)'; btn.style.color='var(--accent)'; }
    subBar.appendChild(btn);
    var panel=document.createElement('div');
    panel.style.display=s.key===activeSub?'block':'none';
    subPanels[s.key]=panel;
  });
  container.appendChild(subBar);
  Object.values(subPanels).forEach(function(p){ container.appendChild(p); });

  // ── Save All Reference Data button ────────────────────────────
  var saveAllWrap=document.createElement('div');
  saveAllWrap.style.cssText='display:flex;justify-content:flex-end;margin-bottom:12px';
  var saveAllBtn=document.createElement('button');
  saveAllBtn.textContent='💾 Save All Reference Data';
  saveAllBtn.title='Saves Categories, Sub Categories, Units, Currencies and Brand Mapping';
  saveAllBtn.style.cssText="padding:7px 18px;background:var(--accent);border:none;border-radius:7px;color:#fff;font-family:'DM Sans',sans-serif;font-size:12px;font-weight:600;cursor:pointer";
  saveAllBtn.addEventListener('click',function(){
    _imSet('tcj_cats',    getCats());
    _imSet('tcj_subcats', getSubCats());
    _imSet('tcj_units',   getUnits());
    _imSet('tcj_currencies', getCurrencies());
    _imSet('tcj_brands',  getBrands());
    CATS_LIST.length=0; getCats().forEach(function(c){CATS_LIST.push(c);});
    Object.keys(_dirty).forEach(function(k){_dirty[k]=false;});
    buildTableHeader(); buildColVisPanel(); renderIngFiltered();
    auditLog('IM Interface > Reference Data','Save All Reference Data',null,null,null,'All reference data saved');
    saveAllBtn.textContent='✓ All Saved'; saveAllBtn.style.background='#2d5a2d'; saveAllBtn.disabled=true;
    setTimeout(function(){saveAllBtn.textContent='💾 Save All Reference Data';saveAllBtn.style.background='var(--accent)';saveAllBtn.disabled=false;},2500);
  });
  saveAllWrap.appendChild(saveAllBtn);
  container.insertBefore(saveAllWrap, subBar);

  buildCategoriesTab(subPanels['categories'], _dirty);
  buildSubCategoriesTab(subPanels['subcategories'], _dirty);
  buildUnitsTab(subPanels['units'], _dirty);
  buildCurrenciesTab(subPanels['currencies'], _dirty);
  buildBrandsTab(subPanels['brands'], _dirty);
  buildColumnSettingsTab(subPanels['colsettings']);
}

// ── CATEGORIES TAB ───────────────────────────────────────────────

function buildCategoriesTab(container, _dirty){
  var _catSyncBar=document.createElement('div');_catSyncBar.style.cssText='display:flex;align-items:center;gap:10px;margin-bottom:10px';
  var _catSyncBtn=document.createElement('button');_catSyncBtn.textContent='⧳ Sync from All Ingredients';_catSyncBtn.style.cssText=_imS.btn+';background:none;border:1px solid var(--accent);color:var(--accent);padding:6px 14px';
  var _catSyncMsg=document.createElement('span');_catSyncMsg.style.cssText='font-family:DM Sans,sans-serif;font-size:11px;color:#4caf76';
  _catSyncBtn.addEventListener('click',function(){_catSyncBtn.disabled=true;_catSyncBtn.textContent='Syncing…';syncRefDataFromIngredients(['categories','subcategories'],function(msg){_catSyncMsg.textContent=msg;_catSyncBtn.textContent='⧳ Sync from All Ingredients';_catSyncBtn.disabled=false;setTimeout(function(){_catSyncMsg.textContent='';},4000);});});
  _catSyncBar.appendChild(_catSyncBtn);_catSyncBar.appendChild(_catSyncMsg);container.appendChild(_catSyncBar);
  container.appendChild(makeImportExportBar(exportCategoriesCSV,importCategoriesCSV,'Categories \u0026 Sub Categories'));
  var cats = getCats().slice().sort();
  var meta = getCatMeta();


  // Grid header
  var COLS=['ID','CATEGORY NAME','REQUIRED','ACTIVE','DELETE'];
  var _catHdrTips={
    'REQUIRED':'Required = Yes means any ingredient in this category must also select a Sub Category. Auto-set to Yes when sub-categories exist.',
    'ACTIVE':'Active = No hides this category from all dropdowns without deleting it. Use to retire a category safely.'
  };
  var grid=document.createElement('div');
  grid.style.cssText='display:grid;grid-template-columns:40px 1fr 90px 70px 36px;gap:4px 10px;align-items:center';

  COLS.forEach(function(h){
    var d=document.createElement('div');d.style.cssText=_imS.hdr;d.textContent=h;
    if(_catHdrTips[h]){_tipOn(d,_catHdrTips[h]);}
    grid.appendChild(d);
  });

  function renderRows(){
    while(grid.children.length>5) grid.removeChild(grid.lastChild);
    cats.sort().forEach(function(cat,i){
      var _hasSubs=(getSubCats()[cat]||[]).length>0;
      var m=meta[cat]||{required:_hasSubs?'Yes':'No',active:'Yes'};
      // ID
      var idDiv=document.createElement('div');idDiv.style.cssText=_imS.hdr+';color:var(--text-mid);text-align:center';idDiv.textContent=i+1;
      // Name
      var ni=document.createElement('input');ni.type='text';ni.value=cat;ni.style.cssText=_imS.inp;
      ni.addEventListener('change',function(){
        var oldName=cats[i]; var newName=this.value.trim();
        if(!newName||newName===oldName)return;
        // Propagate rename across ingredients in DB
        rpc('admin_rename_reference_value',{p_table:'ingredients',p_column:'Category',p_old:oldName,p_new:newName}).then(function(n){
          auditLog('IM Interface > Reference Data','Category Renamed',oldName,oldName,newName,'Updated '+n+' ingredients');
        }).catch(function(e){ console.warn('dash stats badge', e); });
        if(meta[oldName]){meta[newName]=meta[oldName];delete meta[oldName];}
        cats[i]=newName;
        _dirty.categories=true;
      });
      // Required
      var reqSel=document.createElement('select');reqSel.style.cssText=_imS.sel;
      ['No','Yes'].forEach(function(v){var o=document.createElement('option');o.value=v;o.textContent=v;o.selected=(m.required||'No')===v;reqSel.appendChild(o);});
      reqSel.addEventListener('change',function(){if(!meta[cat])meta[cat]={};meta[cat].required=this.value;_dirty.categories=true;});
      // Active
      var actSel=document.createElement('select');actSel.style.cssText=_imS.sel;
      ['Yes','No'].forEach(function(v){var o=document.createElement('option');o.value=v;o.textContent=v;o.selected=(m.active||'Yes')===v;actSel.appendChild(o);});
      actSel.addEventListener('change',function(){if(!meta[cat])meta[cat]={};meta[cat].active=this.value;_dirty.categories=true;});
      // Delete
      var del=document.createElement('button');del.textContent='×';del.style.cssText=_imS.delBtn;
      del.addEventListener('click',function(){
        if(!confirm('Delete category "'+cat+'"? This cannot be undone.'))return;
        cats.splice(i,1);delete meta[cat];
        _imSet('tcj_cats',cats);_imSet('tcj_cat_meta',meta);
        CATS_LIST.length=0;cats.forEach(function(c){CATS_LIST.push(c);});
        renderRows();_dirty.categories=false;
        rpc('admin_clear_ingredient_category',{p_category:cat}).then(function(n){
          if(n>0) alert('ℹ '+n+' ingredient'+(n===1?' has':' have')+' had their Category cleared from "'+cat+'". Please update them in All Ingredients.');
          auditLog('IM Interface > Reference Data','Category Deleted',cat,cat,null,'Cleared from '+n+' ingredients');
        }).catch(function(e){console.error('Category cascade failed:',e);});
      });
      grid.appendChild(idDiv);grid.appendChild(ni);grid.appendChild(reqSel);grid.appendChild(actSel);grid.appendChild(del);
    });
  }
  renderRows();
  container.appendChild(grid);
  

  // Add new
  var addRow=document.createElement('div');addRow.style.cssText='display:flex;gap:8px;margin-top:10px';
  var ni=document.createElement('input');ni.type='text';ni.placeholder='Add new category…';ni.style.cssText=_imS.inp;
  var ab=document.createElement('button');ab.textContent='+ Add';ab.style.cssText=_imS.btn+';background:var(--accent);color:#fff';
  ab.addEventListener('click',function(){var v=ni.value.trim();if(!v||cats.includes(v))return;cats.push(v);cats.sort();renderRows();ni.value='';_dirty.categories=true;});
  ni.addEventListener('keydown',function(ev){if(ev.key==='Enter')ab.click();});
  addRow.appendChild(ni);addRow.appendChild(ab);container.appendChild(addRow);

  // Save button
  var sb=makeSaveBtn('Save Categories',function(){
    _imSet('tcj_cats',cats);_imSet('tcj_cat_meta',meta);
    CATS_LIST.length=0;cats.sort().forEach(function(c){CATS_LIST.push(c);});
    buildTableHeader();renderIngFiltered();
    auditLog('IM Interface > Reference Data','Categories Saved',null,null,null,cats.length+' categories');
    _dirty.categories=false;
  });
  container.appendChild(sb);
}

// ── SUB CATEGORIES TAB ───────────────────────────────────────────

function buildSubCategoriesTab(container, _dirty){
  container.appendChild(makeImportExportBar(exportCategoriesCSV,importCategoriesCSV,'Categories \u0026 Sub Categories'));
  var cats=getCats().slice().sort();
  var subs=getSubCats();

  var selRow=document.createElement('div');selRow.style.cssText='display:flex;align-items:center;gap:10px;margin-bottom:12px';
  var lbl=document.createElement('div');lbl.style.cssText=_imS.label;lbl.textContent='Category:';
  var catSel=document.createElement('select');catSel.style.cssText=_imS.sel.replace('width:100%;','')+';width:auto;min-width:180px';
  cats.forEach(function(c){var o=document.createElement('option');o.value=c;o.textContent=c;catSel.appendChild(o);});
  selRow.appendChild(lbl);selRow.appendChild(catSel);container.appendChild(selRow);
  

  var subPanel=document.createElement('div');container.appendChild(subPanel);

  function renderSubs(cat){
    subPanel.innerHTML='';
    if(!subs[cat])subs[cat]=[];
    var arr=subs[cat].slice().sort();
    subs[cat]=arr;

    var COLS2=['ID','SUB-CATEGORY NAME','REQUIRED','ACTIVE','DELETE'];
    var _subHdrTips={'REQUIRED':'Required = Yes means this sub-category must be selected when an ingredient uses its parent category.','ACTIVE':'Active = No hides this sub-category from dropdowns without deleting it.'};
    var grid2=document.createElement('div');
    grid2.style.cssText='display:grid;grid-template-columns:40px 1fr 90px 70px 36px;gap:4px 10px;align-items:center;margin-bottom:8px';
    COLS2.forEach(function(h){var d=document.createElement('div');d.style.cssText=_imS.hdr;d.textContent=h;if(_subHdrTips[h]){_tipOn(d,_subHdrTips[h]);}grid2.appendChild(d);});

    arr.forEach(function(sub,i){
      var idDiv=document.createElement('div');idDiv.style.cssText=_imS.hdr+';text-align:center';idDiv.textContent=i+1;
      var ni=document.createElement('input');ni.type='text';ni.value=sub;ni.style.cssText=_imS.inp;
      ni.addEventListener('change',function(){
        var oldSub=arr[i];arr[i]=this.value.trim()||sub;
        subs[cat]=arr;_dirty.subcategories=true;
        auditLog('IM Interface > Reference Data','Sub-Category Renamed',cat+' > '+oldSub,oldSub,arr[i]);
      });
      var reqSel=document.createElement('select');reqSel.style.cssText=_imS.sel;
      ['No','Yes'].forEach(function(v){var o=document.createElement('option');o.value=v;o.textContent=v;reqSel.appendChild(o);});
      reqSel.addEventListener('change',function(){_dirty.subcategories=true;});
      var actSel=document.createElement('select');actSel.style.cssText=_imS.sel;
      ['Yes','No'].forEach(function(v){var o=document.createElement('option');o.value=v;o.textContent=v;actSel.appendChild(o);});
      actSel.addEventListener('change',function(){_dirty.subcategories=true;});
      var del=document.createElement('button');del.textContent='×';del.style.cssText=_imS.delBtn;
      del.addEventListener('click',function(){arr.splice(i,1);subs[cat]=arr;_imSet('tcj_subcats',subs);renderSubs(cat);_dirty.subcategories=false;});
      grid2.appendChild(idDiv);grid2.appendChild(ni);grid2.appendChild(reqSel);grid2.appendChild(actSel);grid2.appendChild(del);
    });
    subPanel.appendChild(grid2);

    var addRow=document.createElement('div');addRow.style.cssText='display:flex;gap:8px;margin-bottom:10px';
    var ni2=document.createElement('input');ni2.type='text';ni2.placeholder='Add sub-category…';ni2.style.cssText=_imS.inp;
    var ab2=document.createElement('button');ab2.textContent='+ Add';ab2.style.cssText=_imS.btn+';background:var(--accent);color:#fff';
    ab2.addEventListener('click',function(){var v=ni2.value.trim();if(!v)return;arr.push(v);arr.sort();subs[cat]=arr;renderSubs(cat);ni2.value='';_dirty.subcategories=true;});
    ni2.addEventListener('keydown',function(ev){if(ev.key==='Enter')ab2.click();});
    addRow.appendChild(ni2);addRow.appendChild(ab2);subPanel.appendChild(addRow);

    var sb2=makeSaveBtn('Save Sub Categories',function(){
      _imSet('tcj_subcats',subs);
      auditLog('IM Interface > Reference Data','Sub-Categories Saved',cat,null,null,arr.length+' sub-categories');
      _dirty.subcategories=false;
    });
    subPanel.appendChild(sb2);
  }
  catSel.addEventListener('change',function(){renderSubs(this.value);});
  renderSubs(cats[0]||'');
}

// ── UNITS TAB ────────────────────────────────────────────────────

function buildUnitsTab(container, _dirty){
  var _unitSyncBar=document.createElement('div');_unitSyncBar.style.cssText='display:flex;align-items:center;gap:10px;margin-bottom:10px';
  var _unitSyncBtn=document.createElement('button');_unitSyncBtn.textContent='⧳ Sync from All Ingredients';_unitSyncBtn.style.cssText=_imS.btn+';background:none;border:1px solid var(--accent);color:var(--accent);padding:6px 14px';
  var _unitSyncMsg=document.createElement('span');_unitSyncMsg.style.cssText='font-family:DM Sans,sans-serif;font-size:11px;color:#4caf76';
  _unitSyncBtn.addEventListener('click',function(){_unitSyncBtn.disabled=true;_unitSyncBtn.textContent='Syncing…';syncRefDataFromIngredients(['units'],function(msg){_unitSyncMsg.textContent=msg;_unitSyncBtn.textContent='⧳ Sync from All Ingredients';_unitSyncBtn.disabled=false;setTimeout(function(){_unitSyncMsg.textContent='';},4000);});});
  _unitSyncBar.appendChild(_unitSyncBtn);_unitSyncBar.appendChild(_unitSyncMsg);container.appendChild(_unitSyncBar);
  container.appendChild(makeImportExportBar(exportUnitsCSV,importUnitsCSV,'Units'));
  var units=getUnits().slice().sort();
  var meta=getUnitMeta();
  var MTYPE=['Weight','Volume','Count','Other'];

  var grid=document.createElement('div');
  grid.style.cssText='display:grid;grid-template-columns:40px 100px 100px 70px 70px 70px 70px 70px 1fr 36px;gap:4px 8px;align-items:center';
  var _unitHdrTips={
    'TYPE':'Measurement type: Weight (g/kg/oz/lb), Volume (ml/l/cup), Count (piece/clove), or Other.',
    'MIN':'Minimum valid value for this unit. Leave blank for no minimum.',
    'MAX':'Maximum valid value for this unit. Leave blank for no maximum.',
    'DECIMALS':'Number of decimal places allowed. 0 = whole numbers only.',
    'REQUIRED':'Required = Yes means the Unit field becomes a strict dropdown — the admin must select from this list.',
    'ACTIVE':'Active = No hides this unit from all dropdowns without deleting it.'
  };
  _unitHdrTips['DESCRIPTION']='A short description of what this unit is and how it is used.';
  ['ID','UNIT','TYPE','MIN','MAX','DECIMALS','REQUIRED','ACTIVE','DESCRIPTION',''].forEach(function(h){
    var d=document.createElement('div');d.style.cssText=_imS.hdr;d.textContent=h;
    if(_unitHdrTips[h]){_tipOn(d,_unitHdrTips[h]);}
    grid.appendChild(d);
  });

  function renderUnits(){
    while(grid.children.length>10) grid.removeChild(grid.lastChild);
    units.sort().forEach(function(unit,i){
      var m=meta[unit]||{mtype:'Other',required:'No',active:'Yes',description:''};
      var idDiv=document.createElement('div');idDiv.style.cssText=_imS.hdr+';text-align:center';idDiv.textContent=i+1;
      var ni=document.createElement('input');ni.type='text';ni.value=unit;ni.style.cssText=_imS.inp;
      ni.addEventListener('change',function(){
        var oldU=units[i];units[i]=this.value.trim()||unit;
        var oldM=meta[oldU];if(oldM){meta[units[i]]=oldM;delete meta[oldU];}
        // Propagate rename
        rpc('admin_rename_reference_value',{p_table:'ingredients',p_column:'Unit',p_old:oldU,p_new:units[i]}).then(function(n){
          auditLog('IM Interface > Reference Data','Unit Renamed',oldU,oldU,units[i],'Updated '+n+' ingredients');
        }).catch(function(e){ console.warn('dash stats badge', e); });
        _dirty.units=true;
      });
      var mSel=document.createElement('select');mSel.style.cssText=_imS.sel;
      MTYPE.forEach(function(t){var o=document.createElement('option');o.value=t;o.textContent=t;o.selected=(m.mtype||'Other')===t;mSel.appendChild(o);});
      mSel.addEventListener('change',function(){if(!meta[unit])meta[unit]={};meta[unit].mtype=this.value;_dirty.units=true;});
      function numF(val,ph){
        var f=document.createElement('input');f.type='text';f.inputMode='decimal';f.value=val!=null?val:'';f.placeholder=ph;f.style.cssText=_imS.inp;
        f.addEventListener('keydown',function(ev){var ok=['Backspace','Delete','ArrowLeft','ArrowRight','Tab','.','Enter','Escape'];if(ok.includes(ev.key)||ev.key>='0'&&ev.key<='9'||ev.ctrlKey||ev.metaKey)return;ev.preventDefault();});
        return f;
      }
      var minF=numF(m.min,'—');minF.addEventListener('change',function(){if(!meta[unit])meta[unit]={};meta[unit].min=this.value===''?null:parseFloat(this.value);_dirty.units=true;});
      var maxF=numF(m.max,'—');maxF.addEventListener('change',function(){if(!meta[unit])meta[unit]={};meta[unit].max=this.value===''?null:parseFloat(this.value);_dirty.units=true;});
      var decF=numF(m.decimals,'0');decF.addEventListener('change',function(){if(!meta[unit])meta[unit]={};meta[unit].decimals=this.value===''?null:parseInt(this.value);_dirty.units=true;});
      var reqSel=document.createElement('select');reqSel.style.cssText=_imS.sel;
      ['No','Yes'].forEach(function(v){var o=document.createElement('option');o.value=v;o.textContent=v;o.selected=(m.required||'No')===v;reqSel.appendChild(o);});
      reqSel.addEventListener('change',function(){if(!meta[unit])meta[unit]={};meta[unit].required=this.value;_dirty.units=true;});
      var actSel=document.createElement('select');actSel.style.cssText=_imS.sel;
      ['Yes','No'].forEach(function(v){var o=document.createElement('option');o.value=v;o.textContent=v;o.selected=(m.active||'Yes')===v;actSel.appendChild(o);});
      actSel.addEventListener('change',function(){if(!meta[unit])meta[unit]={};meta[unit].active=this.value;_dirty.units=true;});
      var del=document.createElement('button');del.textContent='×';del.style.cssText=_imS.delBtn;
      del.addEventListener('click',function(){if(!confirm('Delete unit "'+unit+'"?'))return;units.splice(i,1);delete meta[unit];
        _imSet('tcj_units',units);_imSet('tcj_unit_meta',meta);
        renderUnits();_dirty.units=false;
        rpc('admin_rename_reference_value',{p_table:'ingredients',p_column:'Unit',p_old:unit,p_new:''}).then(function(n){
          if(n>0) alert('ℹ '+n+' ingredient'+(n===1?' has':' have')+' had their Unit cleared from "'+unit+'". Please update them in All Ingredients.');
          auditLog('IM Interface > Reference Data','Unit Deleted',unit,unit,null,'Cleared from '+n+' ingredients');
        }).catch(function(e){console.error('Unit cascade failed:',e);});});
      var descF=document.createElement('input');descF.type='text';descF.value=m.description||'';descF.placeholder='e.g. Metric cup (250ml)';descF.style.cssText=_imS.inp;
      descF.addEventListener('change',function(){if(!meta[unit])meta[unit]={};meta[unit].description=this.value.trim();_dirty.units=true;});
      grid.appendChild(idDiv);grid.appendChild(ni);grid.appendChild(mSel);grid.appendChild(minF);grid.appendChild(maxF);grid.appendChild(decF);grid.appendChild(reqSel);grid.appendChild(actSel);grid.appendChild(descF);grid.appendChild(del);
    });
  }
  renderUnits();container.appendChild(grid);
  

  var addRow=document.createElement('div');addRow.style.cssText='display:flex;gap:8px;margin-top:10px';
  var ni2=document.createElement('input');ni2.type='text';ni2.placeholder='Add unit…';ni2.style.cssText=_imS.inp;
  var ab2=document.createElement('button');ab2.textContent='+ Add';ab2.style.cssText=_imS.btn+';background:var(--accent);color:#fff';
  ab2.addEventListener('click',function(){var v=ni2.value.trim();if(!v)return;units.push(v);units.sort();renderUnits();ni2.value='';_dirty.units=true;});
  ni2.addEventListener('keydown',function(ev){if(ev.key==='Enter')ab2.click();});
  addRow.appendChild(ni2);addRow.appendChild(ab2);container.appendChild(addRow);

  var sb=makeSaveBtn('Save Units',function(){
    _imSet('tcj_units',units);_imSet('tcj_unit_meta',meta);
    auditLog('IM Interface > Reference Data','Units Saved',null,null,null,units.length+' units');
    _dirty.units=false;
  });
  container.appendChild(sb);
}

// ── CURRENCIES TAB ───────────────────────────────────────────────

function buildCurrenciesTab(container, _dirty){
  container.appendChild(makeImportExportBar(exportCurrenciesCSV,importCurrenciesCSV,'Currencies'));
  var currencies=getCurrencies().slice().sort();

  var grid=document.createElement('div');
  grid.style.cssText='display:grid;grid-template-columns:40px 80px 1fr 70px 36px;gap:4px 8px;align-items:center';
  ['ID','CODE','FULL NAME','ACTIVE',''].forEach(function(h){var d=document.createElement('div');d.style.cssText=_imS.hdr;d.textContent=h;grid.appendChild(d);});

  var currMeta=_imGet('tcj_curr_meta',{});

  function renderCurrs(){
    while(grid.children.length>5) grid.removeChild(grid.lastChild);
    currencies.sort().forEach(function(c,i){
      var m=currMeta[c]||{name:'',active:'Yes'};
      var idD=document.createElement('div');idD.style.cssText=_imS.hdr+';text-align:center';idD.textContent=i+1;
      var codeI=document.createElement('input');codeI.type='text';codeI.value=c;codeI.style.cssText=_imS.inp+';font-weight:600;text-transform:uppercase';
      codeI.addEventListener('change',function(){var old=currencies[i];currencies[i]=this.value.trim().toUpperCase();var oldM=currMeta[old];if(oldM){currMeta[currencies[i]]=oldM;delete currMeta[old];}});
      var nameI=document.createElement('input');nameI.type='text';nameI.value=m.name||'';nameI.placeholder='e.g. Australian Dollar';nameI.style.cssText=_imS.inp;
      nameI.addEventListener('change',function(){if(!currMeta[c])currMeta[c]={};currMeta[c].name=this.value;_dirty.currencies=true;});
      var actSel=document.createElement('select');actSel.style.cssText=_imS.sel;
      ['Yes','No'].forEach(function(v){var o=document.createElement('option');o.value=v;o.textContent=v;o.selected=(m.active||'Yes')===v;actSel.appendChild(o);});
      actSel.addEventListener('change',function(){if(!currMeta[c])currMeta[c]={};currMeta[c].active=this.value;_dirty.currencies=true;});
      var del=document.createElement('button');del.textContent='×';del.style.cssText=_imS.delBtn;
      del.addEventListener('click',function(){currencies.splice(i,1);delete currMeta[c];_imSet('tcj_currencies',currencies);_imSet('tcj_curr_meta',currMeta);renderCurrs();_dirty.currencies=false;});
      grid.appendChild(idD);grid.appendChild(codeI);grid.appendChild(nameI);grid.appendChild(actSel);grid.appendChild(del);
    });
  }
  renderCurrs();container.appendChild(grid);
  

  var addRow=document.createElement('div');addRow.style.cssText='display:flex;gap:8px;margin-top:10px';
  var ni=document.createElement('input');ni.type='text';ni.placeholder='Code e.g. AUD';ni.style.cssText=_imS.inp.replace('width:100%;','')+';width:80px;text-transform:uppercase';
  var nameI=document.createElement('input');nameI.type='text';nameI.placeholder='Full name e.g. Australian Dollar';nameI.style.cssText=_imS.inp;
  var ab=document.createElement('button');ab.textContent='+ Add';ab.style.cssText=_imS.btn+';background:var(--accent);color:#fff';
  ab.addEventListener('click',function(){var v=ni.value.trim().toUpperCase();if(!v||currencies.includes(v))return;currencies.push(v);if(nameI.value.trim())currMeta[v]={name:nameI.value.trim(),active:'Yes'};renderCurrs();ni.value='';nameI.value='';_dirty.currencies=true;});
  ni.addEventListener('keydown',function(ev){if(ev.key==='Enter')ab.click();});
  addRow.appendChild(ni);addRow.appendChild(nameI);addRow.appendChild(ab);container.appendChild(addRow);

  var sb=makeSaveBtn('Save Currencies',function(){
    _imSet('tcj_currencies',currencies);_imSet('tcj_curr_meta',currMeta);
    auditLog('IM Interface > Reference Data','Currencies Saved',null,null,null,currencies.length+' currencies');
    _dirty.currencies=false;
  });
  container.appendChild(sb);
}



// ── Save button helper ────────────────────────────────────────────

function makeSaveBtn(label, fn){
  var wrap=document.createElement('div');
  wrap.style.cssText='margin-top:14px;border-top:1px solid var(--border);padding-top:12px';
  var btn=document.createElement('button');
  btn.textContent=label;
  btn.style.cssText="padding:8px 20px;background:var(--accent);border:none;border-radius:7px;color:#fff;font-family:'DM Sans',sans-serif;font-size:12px;font-weight:600;cursor:pointer";
  btn.addEventListener('click',function(){
    try{
      fn();
      btn.textContent='✓ Saved'; btn.style.background='#2d5a2d'; btn.disabled=true;
      setTimeout(function(){btn.textContent=label;btn.style.background='var(--accent)';btn.disabled=false;},2500);
    }catch(e){alert('Save failed: '+e.message);}
  });
  wrap.appendChild(btn);
  return wrap;
}

function loadIngRecycleBinInto(container){
  container.innerHTML='<div style="'+_imS.label+';padding:8px 0">Loading\u2026</div>';
  rpc('admin_get_deleted_extra_fields',{}).then(function(rows){
    if(!rows||!rows.length){container.innerHTML='<div style="'+_imS.label+';padding:8px 0">Recycle Bin is empty.</div>';return;}
    var groups={};
    rows.forEach(function(r){ var m=r.field_name.match(/^Deleted(\d+)(.+)$/);if(!m)return;var base=m[2],n=parseInt(m[1]);if(!groups[base])groups[base]=[];groups[base].push({key:r.field_name,n:n,count:parseInt(r.ingredient_count)||0}); });
    container.innerHTML='';
    var COLS=[{l:'Original Name',w:'1fr'},{l:'Stored As',w:'1.2fr'},{l:'Type',w:'70px'},{l:'Source',w:'110px'},{l:'Deleted On',w:'140px'},{l:'Rows',w:'50px'},{l:'Actions',w:'170px'}];
    var tpl=COLS.map(function(c){return c.w;}).join(' ');
    var tableWrap=document.createElement('div');tableWrap.style.cssText='overflow-x:auto;min-width:0';
    var hdr=document.createElement('div');hdr.style.cssText='display:grid;grid-template-columns:'+tpl+';gap:0 8px;align-items:center;padding-bottom:6px;border-bottom:1px solid var(--border);margin-bottom:4px;min-width:1100px';
    COLS.forEach(function(c){ var h=document.createElement('div');h.style.cssText=_imS.hdr;h.textContent=c.l;hdr.appendChild(h); });
    tableWrap.appendChild(hdr);
    var MONTHS=['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    Object.keys(groups).sort().forEach(function(base){
      groups[base].sort(function(a,b){return b.n-a.n;}).forEach(function(item){
        var dm=(JSON.parse(localStorage.getItem('tcj_deleted_meta')||'{}')||{})[item.key]||{};
        var _d=dm.deletedAt?new Date(dm.deletedAt):null;
        var _pad=function(n){return n<10?'0'+n:String(n);};
        var dDate=_d?(_d.getDate()+' '+MONTHS[_d.getMonth()]+' '+_d.getFullYear()+' '+_pad(_d.getHours())+':'+_pad(_d.getMinutes())+':'+_pad(_d.getSeconds())):'—';
        var row=document.createElement('div');row.style.cssText='display:grid;grid-template-columns:'+tpl+';gap:0 8px;align-items:center;padding:8px 0;border-bottom:1px solid rgba(255,255,255,0.04)';
        function cell(t,s){var d=document.createElement('div');d.style.cssText=(s||"font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-high)");d.textContent=t;return d;}
        row.appendChild(cell(base,"font-family:'DM Sans',sans-serif;font-size:13px;font-weight:600;color:var(--text-high)"));
        row.appendChild(cell(item.key,"font-family:'DM Sans',sans-serif;font-size:10px;color:var(--accent);font-style:italic;word-break:break-all"));
        row.appendChild(cell(dm.colType==='yesno'?'Yes/No':dm.colType==='number'?'Num':'Text',"font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-mid)"));
        row.appendChild(cell(dm.source||'All Ingredients',"font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-mid)"));
        row.appendChild(cell(dDate,"font-family:'DM Sans',sans-serif;font-size:10px;color:var(--text-mid)"));
        row.appendChild(cell(item.count+' row'+(item.count===1?'':'s'),"font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-mid)"));
        var acts=document.createElement('div');acts.style.cssText='display:flex;gap:4px';
        var rb=document.createElement('button');rb.textContent='\u21ba Restore';rb.style.cssText="padding:4px 10px;background:none;border:1px solid var(--accent);border-radius:6px;color:var(--accent);font-family:'DM Sans',sans-serif;font-size:10px;font-weight:600;cursor:pointer;white-space:nowrap";
        rb.addEventListener('click',(function(k,b){return function(){restoreDeletedColumn(k,b);};})(item.key,base));
        var db=document.createElement('button');db.textContent='Delete';db.style.cssText="padding:4px 10px;background:none;border:1px solid #dc5050;border-radius:6px;color:#dc5050;font-family:'DM Sans',sans-serif;font-size:10px;font-weight:600;cursor:pointer";
        db.addEventListener('click',(function(k,b,c){return function(){permanentlyDeleteColumn(k,b,c);setTimeout(function(){loadIngRecycleBinInto(container);},1000);};})(item.key,base,item.count));
        acts.appendChild(rb);acts.appendChild(db);row.appendChild(acts);tableWrap.appendChild(row);
      });
    });
    container.appendChild(tableWrap);
  }).catch(function(e){container.innerHTML='<div style="color:#dc5050;font-family:DM Sans,sans-serif;font-size:12px">Error: '+esc(e.message)+'</div>';});
}

// ── Audit Trail Tab ──────────────────────────────────────────────

function loadAuditTrail(container){
  container.innerHTML='<div style="'+_imS.label+';padding:8px 0">Loading…</div>';
  var auditFetch = (typeof TcjAdminAudit !== 'undefined')
    ? TcjAdminAudit.fetchAll({})
    : rpc('admin_get_audit_log',{p_limit:500,p_offset:0});
  auditFetch.then(function(rows){
    container.innerHTML='';

    var exportBar=document.createElement('div');exportBar.style.cssText='display:flex;gap:8px;margin-bottom:14px';
    var csvBtn=document.createElement('button');csvBtn.textContent='⬇ Export CSV';csvBtn.style.cssText=_imS.btn+';background:none;border:1px solid var(--border);color:var(--text-mid);padding:6px 14px';
    var pdfBtn=document.createElement('button');pdfBtn.textContent='⬇ Export PDF';pdfBtn.style.cssText=csvBtn.style.cssText;
    csvBtn.addEventListener('click',function(){exportAuditCSV(rows);});
    pdfBtn.addEventListener('click',function(){exportAuditPDF(rows);});
    exportBar.appendChild(csvBtn);exportBar.appendChild(pdfBtn);container.appendChild(exportBar);

    if(!rows||!rows.length){
      var empty=document.createElement('div');empty.style.cssText=_imS.label+';padding:8px 0';empty.textContent='No audit entries yet.';container.appendChild(empty);return;
    }

    var COLS=[
      {l:'Timestamp', w:'160px'},
      {l:'Admin',     w:'160px'},
      {l:'Section',   w:'200px'},
      {l:'Action',    w:'160px'},
      {l:'Target',    w:'160px'},
      {l:'Old Value', w:'minmax(120px,1fr)'},
      {l:'New Value', w:'minmax(120px,1fr)'}
    ];
    var tpl=COLS.map(function(c){return c.w;}).join(' ');
    var MONTHS=['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

    var tableWrap=document.createElement('div');
    tableWrap.style.cssText='overflow-x:auto';

    var inner=document.createElement('div');
    inner.style.cssText='min-width:1100px';

    var hdr=document.createElement('div');
    hdr.style.cssText='display:grid;grid-template-columns:'+tpl+';gap:0 8px;align-items:center;padding-bottom:6px;border-bottom:1px solid var(--border);margin-bottom:4px';
    COLS.forEach(function(c){var h=document.createElement('div');h.style.cssText=_imS.hdr;h.textContent=c.l;hdr.appendChild(h);});
    inner.appendChild(hdr);

    rows.forEach(function(r){
      var d=new Date(r.created_at);
      var _pad=function(n){return n<10?'0'+n:String(n);};
      var ts=d.getDate()+' '+MONTHS[d.getMonth()]+' '+d.getFullYear()+' '+_pad(d.getHours())+':'+_pad(d.getMinutes())+':'+_pad(d.getSeconds());
      var row=document.createElement('div');
      row.style.cssText='display:grid;grid-template-columns:'+tpl+';gap:0 8px;align-items:start;padding:6px 0;border-bottom:1px solid rgba(255,255,255,0.04)';
      var cs="font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-mid);word-break:break-word";
      var cs2="font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-high);word-break:break-word";
      function cell(t,s){var el=document.createElement('div');el.style.cssText=s||cs;el.textContent=t||'—';return el;}
      row.appendChild(cell(ts,cs));
      row.appendChild(cell(r.admin_name,cs2));
      row.appendChild(cell(r.tab,cs));
      row.appendChild(cell(r.action,cs2));
      row.appendChild(cell(r.target,cs));
      row.appendChild(cell(r.old_value,cs));
      row.appendChild(cell(r.new_value,cs));
      inner.appendChild(row);
    });

    tableWrap.appendChild(inner);
    container.appendChild(tableWrap);
  }).catch(function(e){
    container.innerHTML='<div style="color:#dc5050;font-family:DM Sans,sans-serif;font-size:12px;padding:8px 0">Error loading audit trail: '+escT(e.message)+'</div>';
  });
}

function exportAuditCSV(rows){
  var headers=['Timestamp','Admin','Tab','Action','Target','Old Value','New Value','Details'];
  var MONTHS=['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  var lines=[headers.map(function(h){return '"'+h+'"';}).join(',')];
  rows.forEach(function(r){
    var d=new Date(r.created_at);
    var _pad=function(n){return n<10?'0'+n:String(n);};
    var ts=d.getDate()+' '+MONTHS[d.getMonth()]+' '+d.getFullYear()+' '+_pad(d.getHours())+':'+_pad(d.getMinutes())+':'+_pad(d.getSeconds());
    lines.push([ts,r.admin_name,r.tab,r.action,r.target||'',r.old_value||'',r.new_value||'',r.details||''].map(function(v){return '"'+(String(v)).replace(/"/g,'""')+'"';}).join(','));
  });
  var blob=new Blob([lines.join('\n')],{type:'text/csv'});
  var a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='audit-log-'+new Date().toISOString().slice(0,10)+'.csv';a.click();
  URL.revokeObjectURL(a.href);
}

function exportAuditPDF(rows){
  var MONTHS=['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  var win=window.open('','_blank');
  var html='<!DOCTYPE html><html><head><title>Audit Log</title><style>body{font-family:sans-serif;font-size:11px;margin:20px}h1{font-size:16px;margin-bottom:12px}table{width:100%;border-collapse:collapse}th{background:#333;color:#fff;padding:4px 8px;text-align:left;font-size:10px}td{padding:4px 8px;border-bottom:1px solid #eee;vertical-align:top}tr:nth-child(even)td{background:#f9f9f9}@media print{button{display:none}}</style></head><body>';
  html+='<h1>The Culinary Journal — Audit Log</h1>';
  html+='<p style="font-size:10px;color:#666">Exported '+new Date().toLocaleString()+'</p>';
  html+='<button onclick="window.print()" style="margin-bottom:12px;padding:6px 14px;cursor:pointer">Print / Save as PDF</button>';
  html+='<table><thead><tr><th>Timestamp</th><th>Admin</th><th>Tab</th><th>Action</th><th>Target</th><th>Old Value</th><th>New Value</th></tr></thead><tbody>';
  rows.forEach(function(r){
    var d=new Date(r.created_at);
    var _pad=function(n){return n<10?'0'+n:String(n);};
    var ts=d.getDate()+' '+MONTHS[d.getMonth()]+' '+d.getFullYear()+' '+_pad(d.getHours())+':'+_pad(d.getMinutes())+':'+_pad(d.getSeconds());
    function esc2(s){return String(s||'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');}
    html+='<tr><td>'+esc2(ts)+'</td><td>'+esc2(r.admin_name)+'</td><td>'+esc2(r.tab)+'</td><td>'+esc2(r.action)+'</td><td>'+esc2(r.target||'')+'</td><td>'+esc2(r.old_value||'')+'</td><td>'+esc2(r.new_value||'')+'</td></tr>';
  });
  html+='</tbody></table></body></html>';
  win.document.write(html); win.document.close();
}



// ── TAB SWITCHERS (clean, no class collisions) ────────────────────
var _currentRecipeTab = 'all';
var _currentUserTab   = 'pending';




// ── ANALYTICS RENDERERS ───────────────────────────────────────────

async function loadIngRecycleBin() {
  const list = document.getElementById('recycle-bin-list');
  if (!list) return;
  list.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);padding:12px 0">Loading…</div>';
  try {
    const rows = await rpc('admin_get_deleted_extra_fields', {});
    if (!rows || !rows.length) {
      list.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);padding:12px 0">Recycle Bin is empty. Delete a column to see it here.</div>';
      return;
    }

    const groups = {};
    rows.forEach(function(r) {
      var m = r.field_name.match(/^Deleted(\d+)(.+)$/);
      if (!m) return;
      var base = m[2], n = parseInt(m[1]);
      if (!groups[base]) groups[base] = [];
      groups[base].push({ key: r.field_name, n: n, count: parseInt(r.ingredient_count)||0 });
    });

    list.innerHTML = '';

    // Column definitions
    var COLS = [
      { label: 'Original Name',  width: '1fr'   },
      { label: 'Stored As',      width: '1.4fr' },
      { label: 'Type',           width: '80px'  },
      { label: 'Source',         width: '120px' },
      { label: 'Deleted On',     width: '140px' },
      { label: 'Rows',           width: '60px'  },
      { label: 'Actions',        width: '180px' }
    ];
    var tpl = COLS.map(function(c){return c.width;}).join(' ');
    var cellStyle = "font-family:'DM Sans',sans-serif;font-size:9px;font-weight:600;letter-spacing:0.1em;text-transform:uppercase;color:var(--text-mid);padding:2px 6px";

    // Header row
    var hdr = document.createElement('div');
    hdr.style.cssText = 'display:grid;grid-template-columns:'+tpl+';gap:0 10px;align-items:center;margin-bottom:4px;padding:0 4px;border-bottom:1px solid var(--border);padding-bottom:8px';
    COLS.forEach(function(c) {
      var h = document.createElement('div');
      h.style.cssText = cellStyle;
      h.textContent = c.label;
      hdr.appendChild(h);
    });
    list.appendChild(hdr);

    var typeLabel = function(t) {
      return t === 'yesno' ? 'Yes / No' : t === 'number' ? 'Number' : 'Text';
    };

    Object.keys(groups).sort().forEach(function(base) {
      groups[base].sort(function(a,b){return b.n-a.n;}).forEach(function(item) {
        var meta = JSON.parse(localStorage.getItem('tcj_deleted_meta') || '{}');
        var dm   = meta[item.key] || {};
        var _MONTHS=['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        var _d=dm.deletedAt?new Date(dm.deletedAt):null;
        var _pad=function(n){return n<10?'0'+n:String(n);};
        var dDate=_d?(_d.getDate()+' '+_MONTHS[_d.getMonth()]+' '+_d.getFullYear()+' '+_pad(_d.getHours())+':'+_pad(_d.getMinutes())+':'+_pad(_d.getSeconds())):'\u2014';
        var dSource = dm.source  || 'All Ingredients';
        var dType   = typeLabel(dm.colType || 'text');

        var row = document.createElement('div');
        row.style.cssText = 'display:grid;grid-template-columns:'+tpl+';gap:0 10px;align-items:center;padding:10px 4px;border-bottom:1px solid rgba(255,255,255,0.05)';

        function cell(text, style) {
          var d = document.createElement('div');
          d.style.cssText = (style || "font-family:'DM Sans',sans-serif;font-size:13px;color:var(--text-high)");
          d.textContent = text;
          return d;
        }

        // Original Name
        row.appendChild(cell(base, "font-family:'DM Sans',sans-serif;font-size:13px;font-weight:600;color:var(--text-high)"));

        // Stored As
        row.appendChild(cell(item.key, "font-family:'DM Sans',sans-serif;font-size:11px;color:var(--accent);font-style:italic;word-break:break-all"));

        // Type
        row.appendChild(cell(dType, "font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-mid)"));

        // Source
        row.appendChild(cell(dSource, "font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-mid)"));

        // Deleted On
        row.appendChild(cell(dDate, "font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-mid)"));

        // Rows
        row.appendChild(cell(item.count + ' row' + (item.count===1?'':'s'), "font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-mid);text-align:center"));

        // Actions
        var actDiv = document.createElement('div');
        actDiv.style.cssText = 'display:flex;gap:6px';

        var restoreBtn = document.createElement('button');
        restoreBtn.textContent = '↺ Restore';
        restoreBtn.style.cssText = "padding:5px 12px;background:none;border:1px solid var(--accent);border-radius:6px;color:var(--accent);font-family:'DM Sans',sans-serif;font-size:11px;font-weight:600;cursor:pointer;white-space:nowrap";
        restoreBtn.addEventListener('click', (function(k, b){ return function(){ restoreDeletedColumn(k, b); }; })(item.key, base));

        var permBtn = document.createElement('button');
        permBtn.textContent = 'Delete';
        permBtn.style.cssText = "padding:5px 12px;background:none;border:1px solid #dc5050;border-radius:6px;color:#dc5050;font-family:'DM Sans',sans-serif;font-size:11px;font-weight:600;cursor:pointer";
        permBtn.addEventListener('click', (function(k, b, c){ return function(){ permanentlyDeleteColumn(k, b, c); }; })(item.key, base, item.count));

        actDiv.appendChild(restoreBtn);
        actDiv.appendChild(permBtn);
        row.appendChild(actDiv);
        list.appendChild(row);
      });
    });

  } catch(e) {
    list.innerHTML = '<div style="font-family:DM Sans,sans-serif;font-size:13px;color:#dc5050;padding:12px 0">Error: ' + esc(e.message) + '</div>';
  }
}

function switchIngTab(tab) {
  currentIngTab = tab;
  localStorage.setItem('tcj_active_ing_tab', tab);
  document.querySelectorAll('.ap-inner-tab[id^="itab-"]').forEach(function(t) {
    t.classList.toggle('active', t.id === 'itab-' + tab);
  });
  document.querySelectorAll('[id^="ipanel-"]').forEach(function(el) {
    var p = el.id.replace('ipanel-', '');
    el.style.display = p === tab ? 'block' : 'none';
  });
  if (tab === 'all')       loadIngredients(1);
  if (tab === 'pending')   loadIngPending();
  if (tab === 'brands')    loadBrandMappings();
  if (tab === 'analytics') loadIngAnalytics();
  if (tab === 'recycle')   loadIngRecycleBin();
  if (tab === 'imsettings') loadIMInterface();
}

async function loadIngPending() {
  const tbody = document.getElementById('ing-pending-tbody');
  if (!tbody) return;
  tbody.innerHTML = '<tr><td colspan="5" class="ap-empty-row">Loading…</td></tr>';
  try {
    // Query ingredients table for pending items
    const rows = await rpc('admin_get_pending_ingredients', {});
    const pb = document.getElementById('itab-badge-pending');
    if (pb) pb.textContent = rows ? rows.length : 0;
    if (!rows || !rows.length) {
      tbody.innerHTML = '<tr><td colspan="5" class="ap-empty-row">No pending ingredients — all clear.</td></tr>';
      return;
    }
    tbody.innerHTML = rows.map(function(r) {
      const flagged = r.created_at ? new Date(r.created_at).toLocaleDateString('en-GB',{day:'numeric',month:'short',year:'numeric'}) : '—';
      const typeLabel = r.submission_type === 'unit' ? 'Unit' : 'Ingredient';
      const nameCell = r.submission_type === 'unit'
        ? escT(r.ingredient_name) + ' <span style="font-size:10px;color:var(--text-mid)">(unit)</span>'
        : escT(r.ingredient_name);
      return '<tr>' +
        '<td class="ap-td"><span style="color:#d4a017;margin-right:6px">⚠</span>' + nameCell + '</td>' +
        '<td class="ap-td" style="font-size:12px">' + escT(typeLabel) + (r.category ? ' · ' + escT(r.category) : '') + '</td>' +
        '<td class="ap-td" style="font-size:12px">@' + escT(r.submitted_by_username || '—') + '</td>' +
        '<td class="ap-td" style="font-size:12px;color:var(--text-mid)">' + flagged + '</td>' +
        '<td class="ap-td"><div style="display:flex;gap:6px">' +
        '<button data-id="' + r.id + '" onclick="approveIngredient(this.dataset.id,this)" style="padding:5px 12px;background:#2e7d4f;border:none;border-radius:7px;color:#fff;font-size:12px;cursor:pointer">Add</button>' +
        '<button data-id="' + r.id + '" onclick="dismissIngredient(this.dataset.id,this)" style="padding:5px 12px;background:none;border:1px solid var(--border);border-radius:7px;color:var(--text-mid);font-size:12px;cursor:pointer">Dismiss</button>' +
        '</div></td></tr>';
    }).join('');
  } catch(e) {
    tbody.innerHTML = '<tr><td colspan="5" class="ap-empty-row">No pending ingredients yet — they will appear here when recipes are submitted with unknown ingredients.</td></tr>';
  }
}

// ── Brand Mapping Tab ─────────────────────────────────────────────

function fixDropdownTheme() {
  // Apply CSS variable colours to select elements (browser quirk — CSS vars
  // don't cascade into <select> option backgrounds in some browsers)
  var bg     = getComputedStyle(document.body).getPropertyValue('--bg').trim()     || '#0f1011';
  var fg     = getComputedStyle(document.body).getPropertyValue('--text-high').trim() || '#ffffff';
  var border = getComputedStyle(document.body).getPropertyValue('--border').trim() || 'rgba(255,255,255,0.1)';
  document.querySelectorAll('.ing-modal-overlay select, .col-filter-panel select, #ing-modal select').forEach(function(sel) {
    sel.style.background    = bg;
    sel.style.color         = fg;
    sel.style.borderColor   = border;
  });
}

function applyThemeColors(container) {
  if (!container) return;
  var bg     = getComputedStyle(document.body).getPropertyValue('--bg').trim()     || '#0f1011';
  var fg     = getComputedStyle(document.body).getPropertyValue('--text-high').trim() || '#ffffff';
  var border = getComputedStyle(document.body).getPropertyValue('--border').trim() || 'rgba(255,255,255,0.1)';
  container.querySelectorAll('input, select, textarea').forEach(function(el) {
    el.style.background  = bg;
    el.style.color       = fg;
    el.style.borderColor = border;
  });
}

function fmtQty(val) {
  // Format quantity strings — return as-is, they're already human-readable
  // (values like "¼ cup", "1 tbsp", "2-3" etc.)
  if (val === null || val === undefined || val === '') return '';
  return String(val);
}

function getThemeColors() {
  var style  = getComputedStyle(document.body);
  return {
    accent:   style.getPropertyValue('--accent').trim()     || '#C4973B',
    textMid:  style.getPropertyValue('--text-mid').trim()   || 'rgba(255,255,255,0.5)',
    textHigh: style.getPropertyValue('--text-high').trim()  || '#ffffff',
    border:   style.getPropertyValue('--border').trim()     || 'rgba(255,255,255,0.1)',
    bg:       style.getPropertyValue('--bg').trim()         || '#0f1011'
  };
}

let STD_COLS = [
  {key:'Ingredient Name',           label:'Ingredient Name',    type:'text'},
  {key:'Also Known As',             label:'Also Known As',      type:'text'},
  {key:'Category',                  label:'Category',           type:'category', edit:'select'},
  {key:'Sub Category',              label:'Sub Category',       type:'text', edit:'select'},
  {key:'Standard Qty',              label:'Standard Qty',       type:'text'},
  {key:'Standard Weight (g or ml)', label:'Weight (g/ml)',      type:'number'},
  {key:'Unit',                      label:'Unit',               type:'text'},
  {key:'Liquid (Yes/No)',           label:'Liquid',             type:'yesno'},
  {key:'CJ Recommended Brand',      label:'CJ Brand',           type:'text'},
  {key:'Allergen',                  label:'Allergen',           type:'text'},
  {key:'Vegan (Yes/No)',            label:'Vegan',              type:'yesno'},
  {key:'Vegetarian (Yes/No)',       label:'Vegetarian',         type:'yesno'},
  {key:'Notes',                     label:'Notes',              type:'text'}
];
let CATS_LIST = [
  'Baking','Grains, Pasta & Noodles','Breads & Flatbreads','Packaged & Convenience',
  'Meat','Poultry','Seafood','Dairy & Eggs','Plant-Based','Vegetables','Fruits',
  'Herbs','Spices','Oils & Fats','Legumes & Pulses','Nuts & Seeds',
  'Condiments & Sauces','Vinegars','Sweeteners','Canned & Preserved',
  'Alcohol & Cooking Wine','Stocks & Broths'
];
const STANDARD = [
  'ID','Ingredient Name','Also Known As','Category','Sub Category',
  'Standard Qty','Standard Weight (g or ml)','Unit','Liquid (Yes/No)',
  'CJ Recommended Brand','Allergen','Vegan (Yes/No)','Vegetarian (Yes/No)','Notes'
];

let _ingAllData = [];
let _extraColKeys = [];
let _colVis = {};
let _ingColFilters = {};
let _ingSortCol = 'ID';
let _ingSortDir = 'asc';
let _pendingChanges = {};
let _ingRows = {};
let ingPage = 1;
let ING_PAGE_SIZE = 50;
let ingTotal      = 0;
let _ingSearch    = null;
let _ingCategoryFilter = null;
let selectedIds = new Set();

// ── PENDING CHANGES SYSTEM ───────────────────────────────────────

function recordChange(id, field, oldVal, newVal) {
  if (!_pendingChanges[id]) _pendingChanges[id] = {};
  _pendingChanges[id][field] = {old:oldVal, new:newVal};
  updateSaveBtn();
}

function hasPending() { return Object.keys(_pendingChanges).length > 0; }

function updateSaveBtn() {
  const btn = document.getElementById('ing-save-btn');
  if (!btn) return;
  if (hasPending()) {
    btn.style.setProperty('background', 'var(--accent)', 'important');
    btn.style.setProperty('color', '#fff', 'important');
    btn.style.opacity = '1';
    btn.textContent = '💾 Save Changes (' + Object.keys(_pendingChanges).length + ')';
  } else {
    btn.style.setProperty('background', 'none', 'important');
    btn.style.setProperty('color', 'var(--text-mid)', 'important');
    btn.style.opacity = '0.6';
    btn.textContent = '💾 Save Changes';
  }
}

async function saveAllChanges() {
  if (!hasPending()) return;
  const btn = document.getElementById('ing-save-btn');
  if (btn) { btn.disabled=true; btn.textContent='Saving...'; }
  let saved=0, errors=0;
  for (const id in _pendingChanges) {
    const changes = _pendingChanges[id];
    const ing = window._ingRows && window._ingRows[id];
    // Seed params with ALL current field values so nothing gets wiped
    const params = { p_id: parseInt(id) };
    Object.keys(PARAM_MAP).forEach(function(field) {
      params[PARAM_MAP[field]] = ing ? (ing[field] !== undefined ? ing[field] : '') : '';
    });
    const ef = Object.assign({}, (ing&&ing.extra_fields)||{});
    let hasExtra = false;
    for (const field in changes) {
      if (field.startsWith('extra:')) {
        ef[field.slice(6)] = changes[field].new;
        hasExtra = true;
      } else {
        const pm = PARAM_MAP[field];
        if (pm) params[pm] = changes[field].new; // override with new value
      }
    }
    try {
      await rpc('admin_upsert_ingredient', params);
    } catch(e) {
      console.error('Upsert error id '+id+':', e.message);
      errors++; continue;
    }
    if (hasExtra && Object.keys(ef).length) {
      try {
        await rpc('admin_save_extra_fields', { p_id: parseInt(id), p_extra_fields: ef });
        saved++;
      } catch(e) {
        // Show the exact Supabase error so we can see what's failing
        alert('Custom column save failed for row ' + id + ':\n\n' + e.message + '\n\nPlease screenshot this and report it.');
        errors++;
      }
    } else {
      saved++;
    }
  }
  _pendingChanges = {};
  if (btn) { btn.disabled=false; updateSaveBtn(); }
  // Remove pending highlights
  document.querySelectorAll('.cell-pending').forEach(function(td){td.classList.remove('cell-pending');});
  await loadIngredients(ingPage);
  // Reload Brand Mapping tab if it was open
  var _bmTbody=document.getElementById('brand-tbody');
  if(_bmTbody&&_bmTbody.closest('[style*="block"]')){
    await loadBrandsTable(_bmTbody);
  }
  if (errors) alert('Saved '+saved+' rows. '+errors+' errors — check console.');
}

function discardAllChanges() {
  if (!hasPending() && !confirm('Discard all unsaved changes?')) return;
  _pendingChanges = {};
  updateSaveBtn();
  loadIngredients(ingPage);
}

const PARAM_MAP = {
  'Ingredient Name':'p_ingredient_name','Also Known As':'p_also_known_as',
  'Category':'p_category','Sub Category':'p_sub_category',
  'Standard Qty':'p_standard_qty','Standard Weight (g or ml)':'p_standard_weight',
  'Unit':'p_unit','Liquid (Yes/No)':'p_liquid',
  'CJ Recommended Brand':'p_cj_recommended_brand','Allergen':'p_allergen',
  'Vegan (Yes/No)':'p_vegan','Vegetarian (Yes/No)':'p_vegetarian','Notes':'p_notes'
};

// ── LOAD ─────────────────────────────────────────────────────────
// ── Pagination controls ───────────────────────────────────────────

function buildPaginationControls(total){
  var wrap = document.getElementById('ing-pagination');
  if(!wrap) return;
  wrap.innerHTML = '';
  if(!total) return;

  var totalPages = Math.ceil(total / ING_PAGE_SIZE);
  if(totalPages <= 1){ wrap.style.display='none'; return; }
  wrap.style.display = 'flex';

  var style = "padding:6px 12px;background:none;border:1px solid var(--border);border-radius:6px;font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-mid);cursor:pointer;transition:all 0.15s";
  var activeStyle = style + ";background:var(--accent);border-color:var(--accent);color:#fff;cursor:default";

  function btn(label, page, disabled, active){
    var b = document.createElement('button');
    b.textContent = label;
    b.style.cssText = active ? activeStyle : style;
    b.disabled = disabled || active;
    if(!disabled && !active){
      b.addEventListener('click', function(){ loadIngredients(page); });
      b.addEventListener('mouseenter', function(){ if(!this.disabled) this.style.borderColor='var(--accent)'; this.style.color='var(--accent)'; });
      b.addEventListener('mouseleave', function(){ if(!this.disabled) this.style.borderColor='var(--border)'; this.style.color='var(--text-mid)'; });
    }
    return b;
  }

  // Previous
  wrap.appendChild(btn('← Prev', ingPage-1, ingPage<=1, false));

  // Page numbers with ellipsis
  var pages = [];
  if(totalPages <= 7){
    for(var i=1;i<=totalPages;i++) pages.push(i);
  } else {
    pages = [1,2];
    if(ingPage > 4) pages.push('...');
    for(var j=Math.max(3,ingPage-1); j<=Math.min(totalPages-2,ingPage+1); j++) pages.push(j);
    if(ingPage < totalPages-3) pages.push('...');
    pages.push(totalPages-1, totalPages);
    pages = pages.filter(function(v,i,a){ return a.indexOf(v)===i; });
  }

  pages.forEach(function(p){
    if(p === '...'){
      var dots = document.createElement('span');
      dots.textContent = '…';
      dots.style.cssText = "padding:6px 4px;font-family:'DM Sans',sans-serif;font-size:12px;color:var(--text-mid)";
      wrap.appendChild(dots);
    } else {
      wrap.appendChild(btn(String(p), p, false, p===ingPage));
    }
  });

  // Next
  wrap.appendChild(btn('Next →', ingPage+1, ingPage>=totalPages, false));

  // Page info
  var info = document.createElement('span');
  info.style.cssText = "font-family:'DM Sans',sans-serif;font-size:11px;color:var(--text-mid);margin-left:8px;align-self:center";
  info.textContent = 'Page '+ingPage+' of '+totalPages;
  wrap.appendChild(info);
}

// ── Sync Reference Data from All Ingredients ─────────────────────

function buildTableHeader() {
  const thead = document.querySelector('#ing-tbody')?.closest('table')?.querySelector('thead tr');
  if (!thead) return;
  while(thead.children.length>1)thead.removeChild(thead.lastChild);

  // ID column (not draggable, always first)
  const thId = document.createElement('th');
  thId.style.cssText='cursor:pointer;white-space:nowrap';
  thId.innerHTML='ID <span class="sort-icon" data-col="ID">⇅</span>';
  thId.addEventListener('click',function(){sortIngBy('ID');});
  thead.appendChild(thId);

  const colOrder = getColOrder();
  colOrder.forEach(function(colKey) {
    const stdCfg = STD_COLS.find(function(c){return c.key===colKey;});
    const label  = stdCfg ? stdCfg.label : colKey.replace('extra:','');
    const vis    = stdCfg ? _colVis[colKey]!==false : _colVis['extra:'+colKey.replace('extra:','')]!==false;

    const th = document.createElement('th');
    th.dataset.col = colKey;
    th.className = 'sortable-col';
    th.draggable = true;
    th.style.cssText = 'cursor:pointer;white-space:nowrap;user-select:none'+(vis?'':';display:none');

    th.innerHTML = '<span class="col-drag-handle" title="Drag to reorder">⠿</span> ' +
      label +
      ' <span class="sort-icon" data-col="'+colKey+'">⇅</span>' +
      ' <button class="col-filter-btn" title="Filter">▼</button>';

    th.addEventListener('click',function(e){if(!e.target.classList.contains('col-filter-btn')&&!e.target.classList.contains('col-drag-handle'))sortIngBy(colKey);});
    th.querySelector('.col-filter-btn').addEventListener('click',function(e){e.stopPropagation();openColFilter(e,colKey);});

    // Drag to reorder
    th.addEventListener('dragstart',function(e){e.dataTransfer.setData('text/plain',colKey);th.style.opacity='0.5';});
    th.addEventListener('dragend',function(){th.style.opacity='1';});
    th.addEventListener('dragover',function(e){e.preventDefault();th.style.background='rgba(var(--accent-rgb,196,151,59),0.15)';});
    th.addEventListener('dragleave',function(){th.style.background='';});
    th.addEventListener('drop',function(e){
      e.preventDefault();th.style.background='';
      const from=e.dataTransfer.getData('text/plain');
      if(from&&from!==colKey)moveColumn(from,colKey);
    });

    thead.appendChild(th);
  });

  // Edit column
  const thEdit = document.createElement('th');
  thead.appendChild(thEdit);
}

function getColOrder() {
  const stored = localStorage.getItem('tcj_col_order');
  if (stored) {
    try {
      const order = JSON.parse(stored);
      // Add any new keys not in stored order
      const allKeys = STD_COLS.map(function(c){return c.key;}).concat(_extraColKeys.map(function(k){return 'extra:'+k;}));
      allKeys.forEach(function(k){if(!order.includes(k))order.push(k);});
      return order.filter(function(k){return allKeys.includes(k)||STD_COLS.find(function(c){return c.key===k;})||_extraColKeys.includes(k.replace('extra:',''));});
    } catch(e){ console.warn('ingredient column order parse', e); }
  }
  return STD_COLS.map(function(c){return c.key;}).concat(_extraColKeys.map(function(k){return 'extra:'+k;}));
}

function sortIngValue(row, col) {
  if (!row) return '';
  if (col && col.indexOf('extra:') === 0) {
    var k = col.slice(6);
    return (row.extra_fields && row.extra_fields[k]) != null ? row.extra_fields[k] : '';
  }
  return row[col] != null ? row[col] : '';
}

function sortIngRows(rows, col, dir) {
  if (!rows || !rows.length || !col) return rows || [];
  var mul = dir === 'desc' ? -1 : 1;
  return rows.slice().sort(function(a, b) {
    var av = sortIngValue(a, col), bv = sortIngValue(b, col);
    if (col === 'ID') {
      return mul * ((parseInt(av, 10) || 0) - (parseInt(bv, 10) || 0));
    }
    if (col === 'Standard Weight (g or ml)') {
      return mul * ((parseFloat(av) || 0) - (parseFloat(bv) || 0));
    }
    return mul * String(av).localeCompare(String(bv), undefined, { numeric: true, sensitivity: 'base' });
  });
}

function sortIngBy(col) {
  _ingSortDir=(_ingSortCol===col&&_ingSortDir==='asc')?'desc':'asc';
  _ingSortCol=col;
  document.querySelectorAll('.sort-icon').forEach(function(el){el.className='sort-icon';});
  const icon=document.querySelector('.sort-icon[data-col="'+col+'"]');
  if(icon)icon.className='sort-icon '+_ingSortDir;
  if (col && col.indexOf('extra:') === 0) {
    _ingAllData = sortIngRows(_ingAllData, col, _ingSortDir);
    renderIngFiltered();
    return;
  }
  loadIngredients(1);
}

function renderIngFiltered() {
  let data=_ingAllData.slice();
  Object.keys(_ingColFilters).forEach(function(col){
    const vals=_ingColFilters[col];
    if(vals&&vals.length){
      data=data.filter(function(row){
        const v=col.startsWith('extra:')?((row.extra_fields&&row.extra_fields[col.slice(6)])||''):String(row[col]||'');
        return vals.includes(String(v));
      });
    }
  });
  data = sortIngRows(data, _ingSortCol, _ingSortDir);
  renderIngRows(data);
  const countEl=document.getElementById('ing-count');
  if(countEl){
    const activeFilters=Object.keys(_ingColFilters).length;
    if(activeFilters>0&&_ingAllData.length!==data.length){
      countEl.textContent=data.length+' shown (filtered from '+_ingAllData.length+')';
    } else {
      countEl.textContent=_ingAllData.length+' ingredient'+((_ingAllData.length===1)?'':'s');
    }
  }
}

// ── RENDER ROWS ──────────────────────────────────────────────────

function renderIngRows(rows) {
  const tbody=document.getElementById('ing-tbody');
  if(!tbody)return;
  window._ingRows={};
  rows.forEach(function(i){window._ingRows[i['ID']]=i;});
  if(!rows.length){tbody.innerHTML='<tr><td colspan="20" class="ap-empty-row">No ingredients found.</td></tr>';return;}

  tbody.innerHTML='';
  const colOrder=getColOrder();
  rows.forEach(function(i){
    const id=i['ID'];
    const tr=document.createElement('tr');
    tr.id='ing-row-'+id;
    tr.dataset.id=id;
    tr.style.cssText='height:44px;max-height:44px';

    // Checkbox
    const tdChk=document.createElement('td');
    tdChk.style.cssText='padding:0;width:36px';
    tdChk.addEventListener('click',function(e){e.stopPropagation();});
    const chk=document.createElement('input');
    chk.type='checkbox';chk.className='ing-check ing-row-check';chk.dataset.id=id;
    chk.addEventListener('click',updateBulkToolbar);
    const chkWrap=document.createElement('div');
    chkWrap.style.cssText='height:36px;display:flex;align-items:center;justify-content:center;overflow:hidden';
    chkWrap.appendChild(chk);
    tdChk.appendChild(chkWrap);tr.appendChild(tdChk);

    // ID
    const tdId=document.createElement('td');
    tdId.style.cssText='padding:0;width:36px';
    const idWrap=document.createElement('div');
    idWrap.style.cssText='height:36px;display:flex;align-items:center;padding:0 8px;font-size:11px;color:var(--text-mid);white-space:nowrap;overflow:hidden';
    idWrap.textContent=id;
    tdId.appendChild(idWrap);tr.appendChild(tdId);

    // Data columns in current order
    colOrder.forEach(function(colKey){
      const isExtra=colKey.startsWith('extra:');
      const extraKey=isExtra?colKey.slice(6):null;
      const stdCfg=STD_COLS.find(function(c){return c.key===colKey;});
      const visKey=isExtra?'extra:'+extraKey:colKey;
      const vis=_colVis[visKey]!==false;

      const td=document.createElement('td');
      td.dataset.col=colKey;
      td.style.cssText='padding:0;vertical-align:middle;'+((!vis)?'display:none':'');
      const tdWrap=document.createElement('div');
      // Set max-width per column type — Notes gets more space, others capped at 180px
      const _mw=colKey==='Notes'?'240px':colKey==='Ingredient Name'?'220px':colKey==='Also Known As'?'180px':'160px';
      tdWrap.style.cssText='height:36px;display:flex;align-items:center;overflow:hidden;padding:0 8px;box-sizing:border-box;white-space:nowrap;max-width:'+_mw;

      // Check for pending change
      const pending=_pendingChanges[id]&&_pendingChanges[id][isExtra?colKey:colKey];
      var _rawStr=isExtra?(i.extra_fields?String(i.extra_fields[extraKey]||''):''):String(i[colKey]||'');
      // Format values at source based on column type
      var rawVal=_rawStr;
      if(isExtra){
        var _xRawType=_extraColTypes[extraKey]||'text';
        if(/^[A-Z]{2,3}:[\d.]+$/.test(_rawStr)){
          // Currency: AUD:1234 → AUD 1234.00
          var _rp=_rawStr.split(':');
          rawVal=_rp[0]+' '+parseFloat(_rp[1]||0).toFixed(2);
        } else if(_xRawType==='percentage'&&_rawStr!==''){
          // Percentage: 5 → 5%
          rawVal=parseFloat(_rawStr.replace('%','')||0).toFixed(2)+'%';
        }
      }
      // Format pending new value too
      var _pendingNew=pending?pending.new:null;
      if(_pendingNew&&isExtra){
        var _xPendType=_extraColTypes[extraKey]||'text';
        if(/^[A-Z]{2,3}:[\d.]+$/.test(String(_pendingNew))){
          var _pp=String(_pendingNew).split(':');
          _pendingNew=_pp[0]+' '+parseFloat(_pp[1]||0).toFixed(2);
        } else if(_xPendType==='percentage'){
          _pendingNew=parseFloat(String(_pendingNew).replace('%','')||0).toFixed(2)+'%';
        }
      }
      const displayVal=pending?(_pendingNew||pending.new):rawVal;
      const fmtVal=(stdCfg&&stdCfg.fmt==='qty')?fmtQty(displayVal):displayVal;

      if(pending)td.classList.add('cell-pending');

      if(!stdCfg||stdCfg.edit==='modal'){
        td.addEventListener('click',function(){openIngModal(window._ingRows[id]);});
        td.style.cursor='pointer';
        const div=document.createElement('div');
        div.className=(colKey==='Ingredient Name')?'ap-recipe-name':'ap-submitter';
        div.textContent=fmtVal;
        td.title=fmtVal;
        tdWrap.appendChild(div);
        td.appendChild(tdWrap);
      } else if(stdCfg&&(stdCfg.type==='yesno'||stdCfg.edit==='yesno')){
        td.className='editable-cell'+(pending?' cell-pending':'');
        const span=document.createElement('span');
        span.className='ap-status-pill '+(displayVal==='Yes'?'approved':'rejected');
        span.textContent=displayVal;
        tdWrap.appendChild(span);
        td.appendChild(tdWrap);
        td.addEventListener('click',function(e){inlineCell(e,id,colKey,'yesno');});
      } else if(isExtra){
        td.className='editable-cell'+(pending?' cell-pending':'');
        const xType=_extraColTypes[extraKey]||'text';
        if(xType==='yesno'){
          const sp=document.createElement('span');
          sp.className='ap-status-pill '+(displayVal==='Yes'?'approved':displayVal==='No'?'rejected':'');
          sp.textContent=displayVal||'—';
          tdWrap.appendChild(sp);td.appendChild(tdWrap);
          td.addEventListener('click',function(e){inlineCell(e,id,colKey,'yesno');});
        } else {
          // Format display value based on column type
          var _dispVal=fmtVal;
          // Detect currency format (e.g. AUD:1234) by value pattern OR column type
          if(fmtVal&&/^[A-Z]{2,3}:[\d.]+$/.test(String(fmtVal))){
            var _cp=String(fmtVal).split(':');
            _dispVal=_cp[0]+' '+parseFloat(_cp[1]||0).toFixed(2);
          } else if((xType==='currency')&&fmtVal&&String(fmtVal).indexOf(':')>-1){
            var _cp2=String(fmtVal).split(':');
            _dispVal=_cp2[0]+' '+parseFloat(_cp2[1]||0).toFixed(2);
          } else if(xType==='percentage'&&fmtVal){
            _dispVal=String(fmtVal).replace('%','')+'%';
          }
          tdWrap.textContent=_dispVal;
          td.title=_dispVal||'Double-click to edit';
          td.appendChild(tdWrap);
          var _xEditType=xType==='number'?'number':xType==='currency'?'currency':xType==='percentage'?'percentage':xType==='fraction'?'fraction':xType==='yesno'?'yesno':'text';
          td.addEventListener('dblclick',(function(t){return function(e){inlineCell(e,id,colKey,t);};}(_xEditType)));
        }
      } else {
        td.className='editable-cell'+(pending?' cell-pending':'');
        tdWrap.textContent=fmtVal;
        td.title=fmtVal||'Click to edit';
        td.appendChild(tdWrap);
        const editType=stdCfg&&stdCfg.edit==='select'?'select':stdCfg&&stdCfg.type==='number'?'number':'text';
        if(editType==='select'){
          td.addEventListener('click',function(e){inlineCell(e,id,colKey,'select');});
        } else {
          // Unit and Sub Category get suggest type — single-line input with managed list suggestions
          var _iType='text';
          if(colKey==='Unit'){
            var _um=getUnitMeta(); var _unitRequired=Object.values(_um).some(function(m){return m&&m.required==='Yes';});
            _iType=_unitRequired?'select':'suggest';
          }
          td.addEventListener('dblclick',(function(t){return function(e){inlineCell(e,id,colKey,t);};}(_iType)));
        }
      }
      tr.appendChild(td);
    });

    // Edit button
    const tdEdit=document.createElement('td');
    tdEdit.style.cssText='padding:0';
    const editWrap=document.createElement('div');
    editWrap.style.cssText='height:36px;display:flex;align-items:center;padding:0 4px;overflow:hidden';
    const editBtn=document.createElement('button');
    editBtn.className='ap-filter-btn';editBtn.style.fontSize='11px';editBtn.textContent='Edit';
    editBtn.addEventListener('click',function(e){e.stopPropagation();openIngModal(window._ingRows[id]);});
    editWrap.appendChild(editBtn);tdEdit.appendChild(editWrap);tr.appendChild(tdEdit);
    tbody.appendChild(tr);
  });
  setTimeout(fixDropdownTheme,10);
}

// ── INLINE EDITING (stores as pending, does NOT save immediately) ─

function inlineCell(e,id,field,type){
  e.stopPropagation();
  const td=e.currentTarget;
  if(td.querySelector('input,select'))return;
  const ing=window._ingRows&&window._ingRows[id];
  const pending=_pendingChanges[id]&&_pendingChanges[id][field];
  const isExtra=field.startsWith('extra:');
  let currentVal;
  if(pending){currentVal=pending.new;}
  else if(isExtra){const k=field.slice(6);currentVal=ing&&ing.extra_fields?(ing.extra_fields[k]||''):'';}
  else{currentVal=ing?(ing[field]||''):td.textContent.trim();}
  const origHTML=td.innerHTML;

  function commitChange(newVal){
    const oldVal=ing?(isExtra?(ing.extra_fields?ing.extra_fields[field.slice(6)]||'':''):ing[field]||''):'';
    recordChange(id,field,oldVal,newVal);
    td.classList.add('cell-pending');
    // Update display
    if(field==='Vegan (Yes/No)'||field==='Vegetarian (Yes/No)'){
      const yw=document.createElement('div');yw.style.cssText='height:36px;display:flex;align-items:center;padding:0 8px';yw.innerHTML='<span class="ap-status-pill '+(newVal==='Yes'?'approved':'rejected')+'">'+newVal+'</span>';td.innerHTML='';td.style.padding='0';td.appendChild(yw);
    } else {
      const stdCfg=STD_COLS.find(function(c){return c.key===field;});
      const dv=document.createElement('div');
      dv.style.cssText='height:36px;display:flex;align-items:center;overflow:hidden;padding:0 8px;white-space:nowrap';
      dv.textContent=(stdCfg&&stdCfg.fmt==='qty')?fmtQty(newVal):newVal;
      td.innerHTML='';td.removeAttribute('style');td.style.padding='0';td.appendChild(dv);
    }
    td.className='editable-cell cell-pending';
  }

  if(type==='number'){
    const origStyle=td.getAttribute('style')||'';
    const ni=document.createElement('input');
    ni.type='text'; // use text so we control exactly what's accepted
    ni.inputMode='decimal';
    ni.className='inline-input';
    ni.style.cssText='width:100%;max-width:120px;font-family:DM Sans,sans-serif;font-size:12px;padding:4px 8px;border:1px solid var(--accent);border-radius:5px;background:var(--bg);color:var(--text-high);outline:none;box-sizing:border-box';
    ni.value=currentVal;
    // Block non-numeric keys before they reach the input
    ni.addEventListener('keydown',function(ev){
      var ok=['Backspace','Delete','ArrowLeft','ArrowRight','ArrowUp','ArrowDown','Tab','Home','End','Enter','Escape','.','-'];
      if(ok.includes(ev.key))return;
      if(ev.key>='0'&&ev.key<='9')return; // digits
      if(ev.key==='e'||ev.key==='E')ev.preventDefault(); // block scientific notation
      if(ev.ctrlKey||ev.metaKey)return;
      ev.preventDefault();
      ev.preventDefault();
    });
    // Secondary guard for paste — strips anything non-numeric
    ni.addEventListener('input',function(){
      var v=this.value;
      // Allow: digits, one decimal point, one leading minus
      var clean=v.replace(/[^0-9.\-]/g,'');
      // Only one decimal point
      var parts=clean.split('.');
      if(parts.length>2)clean=parts[0]+'.'+parts.slice(1).join('');
      if(clean!==v)this.value=clean;
    });
    function commitNum(val){
      var v=val.trim();
      if(v===''){commitChange('');return;}
      // Strict test — must be a clean number with optional leading minus and one decimal point
      // Rejects anything like '30g', '1a2', '12.3.4' entirely — no stripping
      if(!/^-?\d*\.?\d+$/.test(v)){
        td.setAttribute('style',origStyle);td.innerHTML=origHTML;
        td.className='editable-cell'+(td.classList.contains('cell-pending')?' cell-pending':'');
        return;
      }
      var formatted=parseFloat(parseFloat(v).toFixed(2)).toString();
      commitChange(formatted);
    }
    ni.addEventListener('keydown',function(ev){
      if(ev.key==='Enter'){ev.preventDefault();commitNum(this.value);return;}
      if(ev.key==='Escape'){td.setAttribute('style',origStyle);td.innerHTML=origHTML;td.className='editable-cell'+(td.classList.contains('cell-pending')?' cell-pending':'');}
    });
    ni.addEventListener('blur',function(){commitNum(this.value);});
    ni.addEventListener('click',function(ev){ev.stopPropagation();});
    td.innerHTML='';td.appendChild(ni);ni.focus();ni.select();
  } else if(type==='currency'){
    // Currency edit: [code dropdown] [amount input]
    const origStyle=td.getAttribute('style')||'';
    const wrap=document.createElement('div'); wrap.style.cssText='display:flex;gap:4px;align-items:center';
    var curParts=(currentVal&&currentVal.indexOf(':')>-1)?currentVal.split(':'):['AUD',''];
    var cSel=document.createElement('select');
    cSel.style.cssText='width:72px;flex-shrink:0;padding:4px 4px;border:1px solid var(--accent);border-radius:5px;background:var(--bg);color:var(--text-high);font-family:DM Sans,sans-serif;font-size:12px;outline:none';
    getCurrencies().forEach(function(c){var o=document.createElement('option');o.value=c;o.textContent=c;o.selected=curParts[0]===c;cSel.appendChild(o);});
    var cAmt=document.createElement('input'); cAmt.type='text'; cAmt.inputMode='decimal';
    cAmt.value=curParts[1]||''; cAmt.placeholder='0.00';
    cAmt.style.cssText='flex:1;min-width:90px;padding:4px 8px;border:1px solid var(--accent);border-radius:5px;background:var(--bg);color:var(--text-high);font-family:DM Sans,sans-serif;font-size:12px;outline:none';
    cAmt.addEventListener('keydown',function(ev){var ok=['Backspace','Delete','ArrowLeft','ArrowRight','Tab','.','Enter','Escape'];if(ok.includes(ev.key)||ev.key>='0'&&ev.key<='9'||ev.ctrlKey||ev.metaKey)return;ev.preventDefault();});
    function commitCurrency(){
      var amt=parseFloat(cAmt.value||0).toFixed(2);
      var val=cSel.value+':'+amt;
      td.setAttribute('style',origStyle); td.innerHTML=origHTML;
      td.className='editable-cell'+(td.classList.contains('cell-pending')?' cell-pending':'');
      recordChange(id,field,currentVal,val);
      td.classList.add('cell-pending');
    }
    cAmt.addEventListener('keydown',function(ev){if(ev.key==='Enter'){commitCurrency();}if(ev.key==='Escape'){td.setAttribute('style',origStyle);td.innerHTML=origHTML;}});
    cAmt.addEventListener('blur',commitCurrency);
    wrap.appendChild(cSel); wrap.appendChild(cAmt);
    td.innerHTML=''; td.appendChild(wrap); cAmt.focus();

  } else if(type==='percentage'){
    // Percentage: number 0-100
    const origStyle=td.getAttribute('style')||'';
    const pi=document.createElement('input'); pi.type='text'; pi.inputMode='decimal';
    pi.className='inline-input'; pi.style.cssText='width:70px;padding:5px 8px;border:1px solid var(--accent);border-radius:5px;background:var(--bg);color:var(--text-high);font-family:DM Sans,sans-serif;font-size:12px;outline:none';
    pi.value=(currentVal||'').toString().replace('%','');
    pi.addEventListener('keydown',function(ev){
      var ok=['Backspace','Delete','ArrowLeft','ArrowRight','Tab','.','Enter','Escape'];
      if(ok.includes(ev.key)||ev.key>='0'&&ev.key<='9'||ev.ctrlKey||ev.metaKey)return;
      ev.preventDefault();
    });
    function commitPct(){
      var v=parseFloat(pi.value||0);
      if(isNaN(v))v=0; if(v>100)v=100; if(v<0)v=0;
      td.setAttribute('style',origStyle); td.innerHTML=origHTML;
      td.className='editable-cell'+(td.classList.contains('cell-pending')?' cell-pending':'');
      recordChange(id,field,currentVal,String(v));
      td.classList.add('cell-pending');
    }
    pi.addEventListener('keydown',function(ev){if(ev.key==='Enter'){commitPct();}if(ev.key==='Escape'){td.setAttribute('style',origStyle);td.innerHTML=origHTML;}});
    pi.addEventListener('blur',commitPct);
    td.innerHTML=''; td.appendChild(pi); pi.focus(); pi.select();

  } else if(type==='fraction'){
    // Fraction: 1/4 | 1 1/2 | 3 | 0.5
    const origStyle=td.getAttribute('style')||'';
    const fi=document.createElement('input'); fi.type='text';
    fi.className='inline-input'; fi.style.cssText='width:90px;padding:5px 8px;border:1px solid var(--accent);border-radius:5px;background:var(--bg);color:var(--text-high);font-family:DM Sans,sans-serif;font-size:12px;outline:none';
    fi.value=currentVal||''; fi.placeholder='e.g. 1 1/4';
    // Only allow digits, space, / and decimal point
    fi.addEventListener('keydown',function(ev){
      var ok=['Backspace','Delete','ArrowLeft','ArrowRight','Tab','Enter','Escape','Home','End',' ','/','.',];
      if(ok.includes(ev.key)||ev.key>='0'&&ev.key<='9'||ev.ctrlKey||ev.metaKey)return;
      ev.preventDefault();
    });
    function commitFrac(){
      var v=fi.value.trim();
      td.setAttribute('style',origStyle); td.innerHTML=origHTML;
      td.className='editable-cell'+(td.classList.contains('cell-pending')?' cell-pending':'');
      if(!v){return;}
      // Validate: whole number, decimal, simple fraction, or mixed number
      var valid=/^\d+$/.test(v)||           // 3
                /^\d+\.\d+$/.test(v)||     // 0.5
                /^\d+\/\d+$/.test(v)||     // 1/4
                /^\d+ \d+\/\d+$/.test(v); // 1 1/2
      if(!valid){
        // Flash red and revert
        var _err=document.createElement('span');
        _err.textContent='Use: 1/4  1 1/2  3  0.5';
        _err.style.cssText='position:absolute;background:#8e2d2d;color:#fff;font-size:10px;padding:3px 8px;border-radius:5px;white-space:nowrap;z-index:9999;margin-top:2px;font-family:DM Sans,sans-serif';
        td.style.position='relative'; td.appendChild(_err);
        setTimeout(function(){if(_err.parentNode)_err.remove();},2000);
        return;
      }
      // Validate denominator not zero
      if(v.indexOf('/')>-1){
        var denom=parseInt(v.split('/')[1]);
        if(!denom){return;}
      }
      if(v!==currentVal){recordChange(id,field,currentVal,v);td.classList.add('cell-pending');}
    }
    fi.addEventListener('keydown',function(ev){if(ev.key==='Enter'){commitFrac();}if(ev.key==='Escape'){td.setAttribute('style',origStyle);td.innerHTML=origHTML;}});
    fi.addEventListener('blur',commitFrac);
    td.innerHTML=''; td.appendChild(fi); fi.focus(); fi.select();

  } else if(type==='suggest'){
    // Single-line input with datalist suggestions (Unit, Sub Category)
    const origStyle=td.getAttribute('style')||'';
    const inp=document.createElement('input');
    inp.type='text'; inp.className='inline-input';
    inp.style.cssText='width:100%;min-width:160px;font-family:DM Sans,sans-serif;font-size:12px;padding:5px 8px;border:1px solid var(--accent);border-radius:5px;background:var(--bg);color:var(--text-high);outline:none';
    inp.value=currentVal||'';
    // Attach datalist
    var dlId='_il_dl_'+field.replace(/[^a-z0-9]/gi,'_');
    var dl=document.getElementById(dlId);
    if(!dl){dl=document.createElement('datalist');dl.id=dlId;document.body.appendChild(dl);}
    dl.innerHTML='';
    var _sugg=(field==='Unit'?getUnits():(field==='Sub Category'?(getSubCats()[(ing&&ing['Category'])||'']||[]):[]));
    _sugg.forEach(function(s){var o=document.createElement('option');o.value=s;dl.appendChild(o);});
    inp.setAttribute('list',dlId);
    td.style.cssText='padding:2px;overflow:visible;position:relative;z-index:100';
    td.innerHTML='';
    td.appendChild(inp);
    inp.focus(); inp.select();
    function commitSuggest(v){
      var nv=v.trim();
      td.setAttribute('style',origStyle); td.innerHTML=origHTML;
      td.className='editable-cell'+(td.classList.contains('cell-pending')?' cell-pending':'');
      recordChange(id,field,currentVal,nv);
      if(nv!==currentVal)td.classList.add('cell-pending');
    }
    inp.addEventListener('keydown',function(ev){
      if(ev.key==='Enter'){ev.preventDefault();commitSuggest(this.value);}
      if(ev.key==='Escape'){td.setAttribute('style',origStyle);td.innerHTML=origHTML;}
    });
    inp.addEventListener('blur',function(){commitSuggest(this.value);});
  } else
if(type==='text'){
    // Expand cell into wrapping textarea — compact view restores on save/cancel
    const origStyle=td.getAttribute('style')||'';
    const ta=document.createElement('textarea');
    ta.className='inline-input';
    ta.style.cssText='width:100%;min-width:200px;min-height:72px;resize:vertical;white-space:pre-wrap;word-break:break-word;font-family:DM Sans,sans-serif;font-size:12px;padding:6px 8px;border:1px solid var(--accent);border-radius:5px;background:var(--bg);color:var(--text-high);outline:none;box-sizing:border-box;line-height:1.5';
    ta.value=currentVal;
    // Expand the td to fit the textarea
    td.style.cssText='padding:4px;vertical-align:top;min-width:220px;background:var(--bg)';
    ta.addEventListener('keydown',function(ev){
      if(ev.key==='Enter'&&!ev.shiftKey){ev.preventDefault();commitChange(this.value.trim());return;}
      if(ev.key==='Escape'){td.setAttribute('style',origStyle);td.innerHTML=origHTML;td.className='editable-cell'+(td.classList.contains('cell-pending')?' cell-pending':'');}
    });
    ta.addEventListener('blur',function(){commitChange(this.value.trim());});
    ta.addEventListener('click',function(ev){ev.stopPropagation();});
    ta.addEventListener('dblclick',function(ev){ev.stopPropagation();});
    td.innerHTML='';td.appendChild(ta);applyThemeColors(td);
    ta.focus();ta.setSelectionRange(ta.value.length,ta.value.length);
  } else {
    const sel=document.createElement('select');sel.className='inline-select';
    var opts;
    if(type==='yesno') opts=['Yes','No'];
    else if(field==='Unit'){
      opts=getUnits().filter(function(u){
        var m=getUnitMeta()[u]||{}; return m.active!=='No';
      }).sort();
    }
    else if(field==='Sub Category'){
      var _ingCat=(window._ingRows&&window._ingRows[id]&&window._ingRows[id]['Category'])||'';
      opts=(getSubCats()[_ingCat]||[]).slice().sort();
      if(!opts.length) opts=Object.values(getSubCats()).reduce(function(a,b){return a.concat(b);}).sort();
    }
    else opts=CATS_LIST.filter(function(c){
      var m=getCatMeta()[c]||{}; return m.active!=='No';
    });
    opts.forEach(function(o){const opt=document.createElement('option');opt.value=o;opt.textContent=o;if(o===currentVal)opt.selected=true;sel.appendChild(opt);});
    sel.addEventListener('change',function(){commitChange(this.value);});
    sel.addEventListener('blur',function(){if(!this._saved){td.innerHTML=origHTML;td.className='editable-cell'+(td.classList.contains('cell-pending')?' cell-pending':'');}});
    sel.addEventListener('click',function(ev){ev.stopPropagation();});
    td.innerHTML='';td.appendChild(sel);applyThemeColors(td);sel.focus();
  }
}

// ── ADD NEW COLUMN ───────────────────────────────────────────────

function toggleColVisPanel(){
  const panel=document.getElementById('col-vis-panel');if(!panel)return;
  const isOpen=panel.classList.toggle('open');
  if(isOpen){applyThemeColors(panel);setTimeout(function(){document.addEventListener('click',closeColVisPanelOutside);},10);}
  else document.removeEventListener('click',closeColVisPanelOutside);
}

function closeColVisPanelOutside(e){
  const panel=document.getElementById('col-vis-panel'),btn=document.getElementById('col-vis-btn');
  if(panel&&!panel.contains(e.target)&&btn&&!btn.contains(e.target)){panel.classList.remove('open');document.removeEventListener('click',closeColVisPanelOutside);}
}

function openColFilter(e,col){
  e.stopPropagation();closeColFilter();
  const vals={};
  _ingAllData.forEach(function(row){const v=col.startsWith('extra:')?((row.extra_fields&&row.extra_fields[col.slice(6)])||''):String(row[col]||'');vals[v]=true;});
  const unique=Object.keys(vals).sort();
  const active=_ingColFilters[col]||[];
  const panel=document.createElement('div');panel.className='col-filter-panel';panel.id='col-filter-panel';panel.dataset.col=col;
  const title=document.createElement('div');title.className='col-filter-panel-title';title.textContent='Filter: '+col.replace('extra:','');
  const search=document.createElement('input');search.className='col-filter-search';search.placeholder='Search...';
  search.addEventListener('input',function(){filterColOptions(this);});
  const opts=document.createElement('div');opts.className='col-filter-options';opts.id='col-filter-opts';
  unique.forEach(function(v){const lbl=document.createElement('label');lbl.className='col-filter-option';const cb=document.createElement('input');cb.type='checkbox';cb.value=v;if(active.includes(v))cb.checked=true;lbl.appendChild(cb);lbl.appendChild(document.createTextNode(' '+(v||'(blank)')));opts.appendChild(lbl);});
  const foot=document.createElement('div');foot.className='col-filter-foot';
  const ab=document.createElement('button');ab.className='col-filter-apply';ab.textContent='Apply';ab.addEventListener('click',function(){applyColFilter(col);});
  const cb2=document.createElement('button');cb2.className='col-filter-clear';cb2.textContent='Clear';cb2.addEventListener('click',function(){clearColFilter(col);});
  foot.appendChild(ab);foot.appendChild(cb2);
  panel.appendChild(title);panel.appendChild(search);panel.appendChild(opts);panel.appendChild(foot);
  document.body.appendChild(panel);_activeFilterPanel=panel;
  // Find the actual button element regardless of click target nesting
  const btn=e.target.closest('.col-filter-btn')||e.target;
  const rect=btn.getBoundingClientRect();
  panel.style.top=(rect.bottom+4)+'px';
  panel.style.left=Math.min(rect.left,window.innerWidth-260)+'px';
  setTimeout(function(){document.addEventListener('click',closeColFilterOnOutside);applyThemeColors(panel);},10);
}

function filterColOptions(input){const q=input.value.toLowerCase();document.querySelectorAll('#col-filter-opts .col-filter-option').forEach(function(el){el.style.display=el.textContent.toLowerCase().includes(q)?'':'none';});}

function applyColFilter(col){
  const checked=[];document.querySelectorAll('#col-filter-opts input:checked').forEach(function(cb){checked.push(cb.value);});
  if(checked.length)_ingColFilters[col]=checked;else delete _ingColFilters[col];
  document.querySelectorAll('[data-col="'+col+'"] .col-filter-btn').forEach(function(b){b.classList.toggle('active',checked.length>0);});
  closeColFilter();renderIngFiltered();
}

function clearColFilter(col){
  delete _ingColFilters[col];
  // Remove active highlight from the column header filter button
  document.querySelectorAll('[data-col="'+col+'"] .col-filter-btn')
    .forEach(function(b){ b.classList.remove('active'); });
  closeColFilter();
  renderIngFiltered();
}

function closeColFilter(){const p=document.getElementById('col-filter-panel');if(p)p.remove();_activeFilterPanel=null;document.removeEventListener('click',closeColFilterOnOutside);}

function closeColFilterOnOutside(e){const p=document.getElementById('col-filter-panel');if(p&&!p.contains(e.target))closeColFilter();}

// ── BULK EDIT ────────────────────────────────────────────────────

function toggleSelectAll(cb){document.querySelectorAll('.ing-row-check').forEach(function(c){c.checked=cb.checked;const id=parseInt(c.dataset.id);if(cb.checked)selectedIds.add(id);else selectedIds.delete(id);});updateBulkToolbar();}

function updateBulkToolbar(){
  const checks=document.querySelectorAll('.ing-row-check');selectedIds=new Set();
  checks.forEach(function(c){if(c.checked)selectedIds.add(parseInt(c.dataset.id));});
  const toolbar=document.getElementById('bulk-toolbar'),countEl=document.getElementById('bulk-count');
  if(selectedIds.size>0){toolbar.classList.add('visible');countEl.textContent=selectedIds.size+' selected';}else toolbar.classList.remove('visible');
  const all=document.getElementById('ing-select-all');if(all)all.checked=checks.length>0&&selectedIds.size===checks.length;
}

function clearSelection(){document.querySelectorAll('.ing-row-check').forEach(function(c){c.checked=false;});const all=document.getElementById('ing-select-all');if(all)all.checked=false;selectedIds.clear();const t=document.getElementById('bulk-toolbar');if(t)t.classList.remove('visible');}

function updateBulkValueInput(){
  const field=document.getElementById('bulk-field').value,wrap=document.getElementById('bulk-val-wrap');
  const yesno=['Vegan (Yes/No)','Vegetarian (Yes/No)','Liquid (Yes/No)'];
  if(field==='Category')wrap.innerHTML='<select class="bulk-val-input" id="bulk-value-2"><option value="">— Select —</option>'+CATS_LIST.map(function(c){return '<option>'+c+'</option>';}).join('')+'</select>';
  else if(yesno.includes(field))wrap.innerHTML='<select class="bulk-val-input" id="bulk-value-3"><option>Yes</option><option>No</option></select>';
  else wrap.innerHTML='<input type="text" class="bulk-val-input" id="bulk-value" placeholder="New value...">';
  setTimeout(fixDropdownTheme,10);
}

async function applyBulkEdit(){
  const field=document.getElementById('bulk-field').value,value=document.getElementById('bulk-value').value.trim();
  if(!field){alert('Choose a field.');return;}if(!value&&field!=='Allergen'){alert('Enter a value.');return;}
  if(selectedIds.size===0){alert('No ingredients selected.');return;}
  if(!confirm('Update "'+field+'" to "'+value+'" for '+selectedIds.size+' ingredient(s)?'))return;
  try{const affected=await rpc('admin_bulk_update_field',{p_ids:Array.from(selectedIds),p_field:field,p_value:value});clearSelection();await loadIngredients(ingPage);alert('Updated '+affected+' ingredient(s).');}
  catch(e){alert('Error: '+e.message);}
}

async function deleteSelected(){
  if(selectedIds.size===0)return;if(!confirm('Delete '+selectedIds.size+' ingredient(s)?'))return;
  try{
    var toForce=[];
    for(var id of selectedIds){
      var res=await rpc('admin_delete_ingredient',{p_id:id,p_force:false});
      if(res&&res.blocked)toForce.push({id:id,name:res.ingredient_name,recipes:res.recipes_using});
    }
    if(toForce.length){
      var msg=toForce.map(function(b){return b.name+' ('+b.recipes+' recipes)';}).join('\n');
      if(!confirm(toForce.length+' ingredient(s) are in use:\n'+msg+'\n\nForce delete anyway?')){clearSelection();await loadIngredients(ingPage);return;}
      await Promise.all(toForce.map(function(b){return rpc('admin_delete_ingredient',{p_id:b.id,p_force:true});}));
    }
    if(typeof TcjIngredientLookup!=='undefined')TcjIngredientLookup.clearCache();
    clearSelection();await loadIngredients(ingPage);
  }
  catch(e){alert('Error: '+e.message);}
}

// ── INGREDIENT MODAL ─────────────────────────────────────────────
let _customFields={};

function openIngModal(ing){
  const msg=document.getElementById('ing-msg'),delBtn=document.getElementById('ing-del-btn');
  if(msg)msg.style.display='none';
  if(ing){
    document.getElementById('ing-modal-title').textContent='Edit Ingredient';
    document.getElementById('ing-id').value       =String(ing['ID']||'');
    document.getElementById('ing-name').value     =ing['Ingredient Name']||'';
    document.getElementById('ing-name').dataset.originalName=ing['Ingredient Name']||'';
    document.getElementById('ing-aka').value      =ing['Also Known As']||'';
    // Rebuild Category options from managed list
    var _catSel=document.getElementById('ing-category');
    var _catVal=ing['Category']||'';
    _catSel.innerHTML='<option value="">— Select —</option>';
    getCats().forEach(function(c){var o=document.createElement('option');o.value=c;o.textContent=c;_catSel.appendChild(o);});
    _catSel.value=_catVal;

    // Populate Unit datalist from managed units list
    var _uList=document.getElementById('ing-units-list');
    if(_uList){_uList.innerHTML='';getUnits().forEach(function(u){var o=document.createElement('option');o.value=u;_uList.appendChild(o);});}

    // Populate Sub Category datalist based on category
    function _rebuildSubcats(cat){
      var _sList=document.getElementById('ing-subcats-list');
      if(!_sList)return;
      _sList.innerHTML='';
      var subs=getSubCats()[cat]||[];
      subs.forEach(function(s){var o=document.createElement('option');o.value=s;_sList.appendChild(o);});
    }
    _rebuildSubcats(_catVal);
    _catSel.addEventListener('change',function(){_rebuildSubcats(this.value);},{ once:true });

    document.getElementById('ing-category').value =_catVal;
    document.getElementById('ing-subcat').value   =ing['Sub Category']||'';
    document.getElementById('ing-qty').value      =fmtQty(ing['Standard Qty'])||'';
    document.getElementById('ing-weight').value   =ing['Standard Weight (g or ml)']||'';
    document.getElementById('ing-unit').value     =ing['Unit']||'';
    document.getElementById('ing-liquid').value   =ing['Liquid (Yes/No)']||'No';
    document.getElementById('ing-brand').value    =ing['CJ Recommended Brand']||'';
    document.getElementById('ing-allergen').value =ing['Allergen']||'';
    document.getElementById('ing-vegan').value    =ing['Vegan (Yes/No)']||'Yes';
    document.getElementById('ing-veg').value      =ing['Vegetarian (Yes/No)']||'Yes';
    document.getElementById('ing-notes').value    =ing['Notes']||'';
    var rawEF=Object.assign({},ing.extra_fields||{});
    _customFieldTypes={};
    // Only keep keys that are:
    // 1. Active global columns (in _extraColKeys)
    // 2. Per-ingredient custom fields added this session (prefixed _cf_)
    // Everything else — old test data, deleted columns — is hidden
    var _activeGlobal=JSON.parse(localStorage.getItem('tcj_extra_cols')||'[]');
    Object.keys(rawEF).forEach(function(k){
      if(k.startsWith('_t_')){_customFieldTypes[k.slice(3)]=rawEF[k];delete rawEF[k];}
      else if(!_activeGlobal.includes(k)&&!k.startsWith('_cf_')){delete rawEF[k];}
    });
    _customFields=rawEF;
    // Ensure all global +Column columns appear in the modal
    _extraColKeys.forEach(function(k){
      if(!_customFields.hasOwnProperty(k)) _customFields[k]='';
      if(!_customFieldTypes[k]) _customFieldTypes[k]=_extraColTypes[k]||'text';
    });
    if(delBtn)delBtn.style.display='inline-block';
  }else{
    document.getElementById('ing-modal-title').textContent='Add Ingredient';
    ['ing-id','ing-name','ing-aka','ing-subcat','ing-qty','ing-weight','ing-unit','ing-brand','ing-allergen','ing-notes'].forEach(function(id){const el=document.getElementById(id);if(el)el.value='';});
    var nameEl=document.getElementById('ing-name');if(nameEl)delete nameEl.dataset.originalName;
    document.getElementById('ing-category').value='';document.getElementById('ing-liquid').value='No';
    document.getElementById('ing-vegan').value='Yes';document.getElementById('ing-veg').value='Yes';
    _customFields={};_customFieldTypes={};if(delBtn)delBtn.style.display='none';
  }
  const modal=document.getElementById('ing-modal');modal.classList.add('open');
  loadUnitsAutocomplete();renderCustomFieldsList();
  setTimeout(function(){applyThemeColors(modal);},20);
}

function closeIngModal(){document.getElementById('ing-modal').classList.remove('open');}

function showIngMsg(text,ok){const el=document.getElementById('ing-msg');if(!el)return;el.textContent=text;el.className='ing-msg '+(ok?'ok':'err');el.style.display='inline-block';}

// ── CUSTOM FIELDS ────────────────────────────────────────────────

async function loadUnitsAutocomplete(){
  try{const units=await rpc('admin_get_ingredient_units',{});const dl=document.getElementById('ing-units-list');if(dl&&units.length)dl.innerHTML=units.map(function(u){return '<option value="'+u.unit+'">';}).join('');}catch(e){ console.warn('ingredient units autocomplete', e); }
}

// ── CSV IMPORT ───────────────────────────────────────────────────
let csvData=null;

function openCsvModal(){
  csvData=null;
  document.getElementById('csv-preview-section').style.display='none';
  document.getElementById('csv-error').style.display='none';
  document.getElementById('csv-drop-zone').style.display='block';
  document.getElementById('csv-import-btn').disabled=true;
  document.getElementById('csv-status').textContent='';
  document.getElementById('csv-file-input').value='';
  const m=document.getElementById('csv-modal');m.classList.add('open');
  setTimeout(function(){applyThemeColors(m);},20);
}

function closeCsvModal(){document.getElementById('csv-modal').classList.remove('open');csvData=null;}

function handleCsvDrop(e){e.preventDefault();document.getElementById('csv-drop-zone').classList.remove('dragover');const f=e.dataTransfer.files[0];if(f)handleCsvFile(f);}

function handleCsvFile(file){
  if(!file||!file.name.endsWith('.csv')){showCsvError('Please upload a .csv file.');return;}
  document.getElementById('csv-error').style.display='none';
  const STANDARD=['ID','Ingredient Name','Also Known As','Category','Sub Category','Standard Qty','Standard Weight (g or ml)','Unit','Liquid (Yes/No)','CJ Recommended Brand','Allergen','Vegan (Yes/No)','Vegetarian (Yes/No)','Notes'];
  Papa.parse(file,{header:true,skipEmptyLines:true,
    complete:function(results){
      if(results.errors.length){showCsvError('CSV error: '+results.errors[0].message);return;}
      if(!results.data.length){showCsvError('No data rows found.');return;}
      const allCols=Object.keys(results.data[0]);
      const extraCols=allCols.filter(function(c){return!STANDARD.includes(c);});
      csvData=results.data.map(function(row){
        const mapped={};
        STANDARD.forEach(function(c){if(row[c]!==undefined)mapped[c]=row[c];});
        if(extraCols.length){
          mapped.extra_fields={};
          extraCols.forEach(function(c){if(row[c]!==undefined&&row[c]!=='')mapped.extra_fields[c]=row[c];});
        }
        return mapped;
      });
      showCsvPreview(results.data);
      if(extraCols.length){const rc=document.getElementById('csv-row-count');if(rc)rc.textContent+=' — '+extraCols.length+' extra column(s) will be stored as custom fields: '+extraCols.join(', ');}
    },
    error:function(e){showCsvError('Error: '+e.message);}
  });
}

function showCsvError(msg){const el=document.getElementById('csv-error');el.textContent=msg;el.style.display='block';document.getElementById('csv-import-btn').disabled=true;}

async function importCsv(){
  if(!csvData||!csvData.length) return;
  const btn    = document.getElementById('csv-import-btn');
  const status = document.getElementById('csv-status');
  btn.disabled = true;
  status.textContent = '';

  // ── Pre-flight: detect duplicate names inside the uploaded CSV ────────
  const nameCounts = {};
  csvData.forEach(function(row) {
    const n = (row['Ingredient Name']||'').trim().toLowerCase();
    if (n) nameCounts[n] = (nameCounts[n]||0) + 1;
  });
  const csvDupes = Object.keys(nameCounts).filter(function(n){ return nameCounts[n] > 1; });

  var resolvedData = csvData;  // default: send all rows as-is

  if (csvDupes.length > 0) {
    // Show modal — returns selections map or null if cancelled
    var selections = await showCsvDupeModal(csvDupes, nameCounts, csvData);
    if (selections === null) {
      btn.disabled = false;
      status.style.color = 'var(--text-mid)';
      status.textContent = 'Import cancelled — review your CSV and try again.';
      return;
    }

    // Build a deduplicated array using Betty's chosen rows
    var dupeNames = new Set(csvDupes);
    var seenDupes = new Set();
    var deduped   = [];

    csvData.forEach(function(row) {
      var n = (row['Ingredient Name']||'').trim().toLowerCase();
      if (dupeNames.has(n)) {
        if (!seenDupes.has(n)) {
          // Insert the chosen row (not the raw CSV row)
          var sel = selections[n];
          deduped.push(sel.rows[sel.keepIdx].r);
          seenDupes.add(n);
        }
        // Other copies of this name are dropped
      } else {
        deduped.push(row);
      }
    });

    resolvedData = deduped;
    status.style.color = '#d4a017';
    status.textContent = 'Selections confirmed. Importing…';
  }

  // ── Call the RPC ───────────────────────────────────────────────────────
  try {
    btn.textContent = 'Importing…';
    const result = await rpc('admin_bulk_upsert_ingredients', { p_rows: resolvedData });

    let inserted = 0, updated = 0;
    if (result && typeof result === 'object' && !Array.isArray(result)) {
      inserted = result.inserted || 0;
      updated  = result.updated  || 0;
    } else {
      inserted = parseInt(result) || csvData.length;
    }

    // ── Sync new Categories, Sub Categories and Units into IM Interface ──
    var _existingCats   = getCats();
    var _existingSubs   = getSubCats();
    var _existingUnits  = getUnits();
    var _newCats=[], _newSubs={}, _newUnits=[];
    resolvedData.forEach(function(row){
      var cat  = (row['Category']    ||'').trim();
      var sub  = (row['Sub Category']||'').trim();
      var unit = (row['Unit']        ||'').trim();
      if(cat){
        if(!_existingCats.includes(cat)&&!_newCats.includes(cat)) _newCats.push(cat);
        if(sub){
          if(!_existingSubs[cat]) _existingSubs[cat]=[];
          if(!_existingSubs[cat].includes(sub)){
            if(!_newSubs[cat]) _newSubs[cat]=[];
            _newSubs[cat].push(sub);
            _existingSubs[cat].push(sub);
          }
        }
      }
      if(unit&&!_existingUnits.includes(unit)&&!_newUnits.includes(unit)){
        _newUnits.push(unit);
        _existingUnits.push(unit);
      }
    });
    if(_newCats.length>0){
      _newCats.forEach(function(c){_existingCats.push(c);});
      _existingCats.sort();
      _imSet('tcj_cats',_existingCats);
      CATS_LIST.length=0;_existingCats.forEach(function(c){CATS_LIST.push(c);});
    }
    if(Object.keys(_newSubs).length>0){ _imSet('tcj_subcats',_existingSubs); }
    if(_newUnits.length>0){ _imSet('tcj_units',_existingUnits.sort()); }

    // ── Show result summary ────────────────────────────────────────────
    status.style.color = '#4caf76';
    var parts = [];
    if (inserted > 0) parts.push(inserted + ' new ingredient' + (inserted===1?'':'s') + ' added');
    if (updated  > 0) parts.push(updated  + ' existing ingredient' + (updated===1?'':'s') + ' updated');
    if (!parts.length) parts.push('No changes — all ingredients already up to date');
    status.textContent = '✓ ' + parts.join(', ') + '.';

    closeCsvModal();
    loadIngredients(1);
    buildTableHeader();
    renderIngFiltered();
    var iPanel = document.getElementById('ipanel-all');
    if(iPanel) { iPanel.dataset.built=''; }

  } catch(e) {
    status.style.color = '#dc5050';
    status.textContent = 'Import failed: ' + e.message;
    btn.disabled = false;
    btn.textContent = 'Import';
  }
}

// ── Duplicate review modal ────────────────────────────────────────────────────

function showCsvDupeModal(dupes, counts, allRows) {
  return new Promise(function(resolve) {

    var SCORE_FIELDS = ['Also Known As','Category','Sub Category','Unit',
      'Standard Qty','Standard Weight (g or ml)','CJ Recommended Brand',
      'Allergen','Vegan (Yes/No)','Vegetarian (Yes/No)','Notes'];

    function scoreRow(r) {
      return SCORE_FIELDS.reduce(function(n,f){
        return n + ((r[f]||'').trim() ? 1 : 0);
      }, 0);
    }

    // selections: name_lower → { rows: [...scored], keepIdx: 0 }
    var selections = {};
    var sorted = dupes.slice().sort(function(a,b){
      var diff = (counts[b]||0) - (counts[a]||0);
      return diff !== 0 ? diff : a.localeCompare(b);
    });

    sorted.forEach(function(name) {
      var matchingRows = (allRows||[]).filter(function(r){
        return (r['Ingredient Name']||'').trim().toLowerCase() === name;
      });
      var scored = matchingRows.map(function(r,i){ return {r:r, score:scoreRow(r), idx:i}; });
      scored.sort(function(a,b){ return b.score - a.score || b.idx - a.idx; });
      selections[name] = { rows: scored, keepIdx: 0 };
    });

    // Build overlay
    var overlay = document.createElement('div');
    overlay.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,0.7);z-index:99999;display:flex;align-items:center;justify-content:center;backdrop-filter:blur(3px)';

    var box = document.createElement('div');
    box.style.cssText = 'background:var(--bg);border:1px solid var(--border);border-radius:14px;padding:28px 32px;max-width:600px;width:92%;font-family:"DM Sans",sans-serif;max-height:86vh;display:flex;flex-direction:column;gap:0';

    var title = document.createElement('div');
    title.style.cssText = "font-family:'Cormorant Garamond',serif;font-size:1.3rem;font-weight:700;color:var(--text-high);margin-bottom:6px";
    title.textContent = '\u26a0\ufe0f Duplicate Names Found in CSV';
    box.appendChild(title);

    var sub = document.createElement('p');
    sub.style.cssText = 'font-size:13px;color:var(--text-mid);margin:0 0 16px;line-height:1.6';
    sub.innerHTML = dupes.length + ' name' + (dupes.length===1?' appears':' appear') + ' more than once. ' +
      'The most complete row is pre-selected (green). ' +
      'If the wrong one is highlighted, click <strong style="color:var(--text-high)">Use this one instead</strong> to switch. ' +
      'Cancel to fix the CSV yourself.';
    box.appendChild(sub);

    // Scrollable list
    var listWrap = document.createElement('div');
    listWrap.style.cssText = 'overflow-y:auto;flex:1;border:1px solid var(--border);border-radius:8px;margin-bottom:18px';

    // Render a single group
    function renderGroup(name, groupEl) {
      groupEl.innerHTML = '';
      var sel = selections[name];

      // Group header
      var grpHdr = document.createElement('div');
      grpHdr.style.cssText = 'padding:8px 14px;background:rgba(255,255,255,0.05);display:flex;align-items:center;gap:8px;border-bottom:1px solid var(--border)';
      var nameSpan = document.createElement('span');
      nameSpan.style.cssText = 'font-size:13px;font-weight:600;color:var(--text-high);text-transform:capitalize;flex:1';
      nameSpan.textContent = name;
      var cntSpan = document.createElement('span');
      cntSpan.style.cssText = 'font-size:11px;font-weight:600;color:#d4a017;padding:2px 8px;background:rgba(212,160,23,0.12);border-radius:10px';
      cntSpan.textContent = sel.rows.length + ' copies';
      grpHdr.appendChild(nameSpan);
      grpHdr.appendChild(cntSpan);
      groupEl.appendChild(grpHdr);

      sel.rows.forEach(function(item, si) {
        var isKeep = si === sel.keepIdx;
        var rowEl = document.createElement('div');
        rowEl.style.cssText = 'padding:9px 14px;border-bottom:1px solid rgba(255,255,255,0.03);background:' +
          (isKeep ? 'rgba(76,175,118,0.07)' : 'rgba(220,80,80,0.04)') +
          ';display:flex;align-items:flex-start;gap:10px';

        // Left: badge + detail
        var left = document.createElement('div');
        left.style.cssText = 'flex:1;min-width:0';

        var badge = document.createElement('div');
        badge.style.cssText = 'display:flex;align-items:center;gap:7px;margin-bottom:3px';
        var keepBadge = document.createElement('span');
        var keepStyle = isKeep
          ? 'background:rgba(76,175,118,0.2);color:#4caf76'
          : 'background:rgba(220,80,80,0.15);color:#dc5050';
        keepBadge.style.cssText = 'font-size:9px;font-weight:700;padding:2px 7px;border-radius:8px;flex-shrink:0;' + keepStyle;
        keepBadge.textContent = isKeep ? 'KEEP' : 'DISCARD';
        var scoreEl = document.createElement('span');
        scoreEl.style.cssText = 'font-size:10px;color:var(--text-mid)';
        scoreEl.textContent = item.score + '\u202f/\u202f' + SCORE_FIELDS.length + ' fields filled';
        badge.appendChild(keepBadge);
        badge.appendChild(scoreEl);
        left.appendChild(badge);

        var fields = ['Category','Also Known As','Unit','Standard Qty','Notes'];
        var parts = fields.map(function(f){ return (item.r[f]||'').trim(); }).filter(Boolean);
        if (parts.length) {
          var detail = document.createElement('div');
          detail.style.cssText = 'font-size:11px;color:var(--text-mid);overflow:hidden;text-overflow:ellipsis;white-space:nowrap';
          detail.textContent = parts.join(' \u00b7 ');
          left.appendChild(detail);
        }

        rowEl.appendChild(left);

        // Right: switch button (only on discard rows)
        if (!isKeep) {
          var switchBtn = document.createElement('button');
          switchBtn.textContent = 'Use this one instead';
          switchBtn.style.cssText = 'padding:4px 11px;background:none;border:1px solid var(--border);border-radius:6px;color:var(--text-mid);font-family:"DM Sans",sans-serif;font-size:11px;cursor:pointer;flex-shrink:0;white-space:nowrap;margin-top:2px;transition:all 0.15s';
          switchBtn.addEventListener('mouseenter', function(){ this.style.borderColor='var(--accent)';this.style.color='var(--accent)'; });
          switchBtn.addEventListener('mouseleave', function(){ this.style.borderColor='var(--border)';this.style.color='var(--text-mid)'; });
          switchBtn.addEventListener('click', (function(n, idx, el) {
            return function() {
              selections[n].keepIdx = idx;
              renderGroup(n, el);
            };
          })(name, si, groupEl));
          rowEl.appendChild(switchBtn);
        }

        groupEl.appendChild(rowEl);
      });
    }

    sorted.forEach(function(name) {
      var groupEl = document.createElement('div');
      renderGroup(name, groupEl);
      listWrap.appendChild(groupEl);
    });

    box.appendChild(listWrap);

    // Buttons
    var btns = document.createElement('div');
    btns.style.cssText = 'display:flex;gap:10px;flex-shrink:0';

    var cancelBtn = document.createElement('button');
    cancelBtn.textContent = 'Cancel \u2014 I\'ll fix the CSV first';
    cancelBtn.style.cssText = 'flex:1;padding:11px;background:none;border:1px solid var(--border);border-radius:8px;color:var(--text-mid);font-family:"DM Sans",sans-serif;font-size:13px;cursor:pointer';
    cancelBtn.addEventListener('click', function(){ overlay.remove(); resolve(null); });

    var proceedBtn = document.createElement('button');
    proceedBtn.textContent = 'Looks good \u2014 proceed';
    proceedBtn.style.cssText = 'flex:1;padding:11px;background:var(--accent);border:none;border-radius:8px;color:#fff;font-family:"DM Sans",sans-serif;font-size:13px;font-weight:600;cursor:pointer';
    proceedBtn.addEventListener('click', function(){
      overlay.remove();
      resolve(selections);
    });

    btns.appendChild(cancelBtn);
    btns.appendChild(proceedBtn);
    box.appendChild(btns);

    overlay.appendChild(box);
    document.body.appendChild(overlay);
  });
}

function downloadTemplate(){
  const cols=['ID','Ingredient Name','Also Known As','Category','Sub Category','Standard Qty','Standard Weight (g or ml)','Unit','Liquid (Yes/No)','CJ Recommended Brand','Allergen','Vegan (Yes/No)','Vegetarian (Yes/No)','Notes'];
  const csv=cols.join(',')+'\n,Plain Flour,,Baking,Wheat Flours,¼ cup,30,cup,No,,Gluten,Yes,Yes,Example ingredient';
  const blob=new Blob([csv],{type:'text/csv'}),url=URL.createObjectURL(blob),a=document.createElement('a');
  a.href=url;a.download='ingredients-template.csv';a.click();URL.revokeObjectURL(url);
}
// ── EXPORT CSV ───────────────────────────────────────────────────

async function exportCsv(){
  const btn=document.querySelector('[onclick="exportCsv()"]');if(btn){btn.textContent='⏳ Exporting...';btn.disabled=true;}
  try{
    const rows=await rpc('admin_export_ingredients',{p_search:null,p_category:null});
    if(!rows.length){alert('Nothing to export.');return;}
    // Only export active custom columns — exclude type metadata (_t_) and Recycle Bin (Deleted*)
    const _activeCols=JSON.parse(localStorage.getItem('tcj_extra_cols')||'[]');
    const extraKeys=[],seen={};
    rows.forEach(function(r){
      if(r.extra_fields&&typeof r.extra_fields==='object')
        Object.keys(r.extra_fields).forEach(function(k){
          if(!seen[k]&&_activeCols.includes(k)){seen[k]=true;extraKeys.push(k);}
        });
    });
    // Add any active columns not yet seen (columns with no values yet)
    _activeCols.forEach(function(k){if(!seen[k]){seen[k]=true;extraKeys.push(k);}});
    const stdCols=['ID','Ingredient Name','Also Known As','Category','Sub Category','Standard Qty','Standard Weight (g or ml)','Unit','Liquid (Yes/No)','CJ Recommended Brand','Allergen','Vegan (Yes/No)','Vegetarian (Yes/No)','Notes'];
    const allCols=stdCols.concat(extraKeys);
    const esc=function(v){const s=String(v==null?'':v);return(s.includes(',')||s.includes('"')||s.includes('\n'))?'"'+s.replace(/"/g,'""')+'"':s;};
    const csv=[allCols.join(',')].concat(rows.map(function(r){return allCols.map(function(c){return stdCols.includes(c)?esc(r[c]):esc(r.extra_fields?(r.extra_fields[c]||''):'');}).join(',');})).join('\n');
    const blob=new Blob([csv],{type:'text/csv'}),url=URL.createObjectURL(blob),a=document.createElement('a');
    a.href=url;a.download='ingredients-'+new Date().toISOString().slice(0,10)+'.csv';a.click();URL.revokeObjectURL(url);
  }catch(e){alert('Export failed: '+e.message);}
  finally{if(btn){btn.textContent='⬇ Export CSV';btn.disabled=false;}}
}


// ═══════════════════════════════════════════════════
// SITE MANAGEMENT + USER MANAGEMENT ADDITIONS
// ═══════════════════════════════════════════════════

async function smSaveAll() {
  var btn = document.getElementById('sm-save-all-btn');
  if (btn) { btn.disabled = true; btn.textContent = 'Saving\u2026'; }
  var errors = [];
  var saved  = 0;

  // ── Save Pages tab ──────────────────────────────────────────
  var pagesPanel = document.getElementById('upanel-sm-pages');
  if (pagesPanel && pagesPanel.dataset.built === '1') {
    var rows = pagesPanel.querySelectorAll('tbody tr.sm-page-row');
    for (var i = 0; i < rows.length; i++) {
      var tr = rows[i];
      var pathEl = tr.querySelector('td:nth-child(2)');
      if (!pathEl) continue;
      var path = pathEl.textContent.trim();
      var visEl  = document.getElementById('smv-' + path);
      var csEl   = document.getElementById('smcs-' + path);
      var tierEl = document.getElementById('smt-' + path);
      var mtEl   = document.getElementById('seo-t-' + path);
      var mdEl   = document.getElementById('seo-d-' + path);
      if (!visEl) continue;
      try {
        var r = await apiFetch(SUPABASE_URL + '/rest/v1/site_pages?path=eq.' + encodeURIComponent(path), {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json', 'Prefer': 'return=representation' },
          body: JSON.stringify({
            visibility: visEl.value,
            coming_soon: csEl ? csEl.checked : false,
            min_tier: tierEl ? tierEl.value : 'free',
            meta_title: mtEl ? (mtEl.value || null) : null,
            meta_desc: mdEl ? (mdEl.value || null) : null
          })
        });
        if (!r || !r.ok) throw new Error('Pages PATCH failed: ' + (r ? r.status : 'no response'));
        var updated = await r.json();
        if (!updated || !updated.length) throw new Error('Page not found: ' + path);
        saved++;
      } catch(e) { errors.push(e.message); }
    }
  }

  // ── Save Features tab ───────────────────────────────────────
  var featPanel = document.getElementById('upanel-sm-features');
  if (featPanel && featPanel.dataset.built === '1') {
    var cbs = featPanel.querySelectorAll('input[type="checkbox"]');
    for (var j = 0; j < cbs.length; j++) {
      var cb = cbs[j];
      // Get the key from the nearest parent row's feature key
      var row = cb.closest('div[style*="justify-content"]');
      if (!row) continue;
      var nameEl = row.querySelector('div[style*="font-weight:500"]');
      if (!nameEl) continue;
      // We store key on the cb via closure — get from onclick/change
      // Instead find it from the feature name by checking against loaded features
      // Skip — features are saved on toggle directly
    }
  }

  // ── Save Settings tab ───────────────────────────────────────
  var settPanel = (typeof smGetSettingsPanel === 'function') ? smGetSettingsPanel() : document.getElementById('upanel-sm-settings');
  if (settPanel && settPanel.dataset.built === '1') {
    var fields = {
      'maintenance_message': document.getElementById('ss-maintenance_message'),
      'watermark_font':      document.getElementById('ss-watermark_font'),
      'watermark_opacity':   document.getElementById('ss-watermark_opacity'),
      'footer_copyright':    document.getElementById('ss-footer_copyright')
    };
    for (var key in fields) {
      if (!fields[key]) continue;
      try {
        var r2 = await apiFetch(SUPABASE_URL + '/rest/v1/site_settings', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Prefer': 'resolution=merge-duplicates,return=representation' },
          body: JSON.stringify({ key: key, value: fields[key].value || '' })
        });
        if (!r2 || !r2.ok) throw new Error('Setting save failed: ' + key);
        saved++;
      } catch(e) { errors.push(e.message); }
    }
  }

  // ── Save Themes tab ───────────────────────────────────────
  var themesPanel = document.getElementById('upanel-sm-themes');
  if (themesPanel && themesPanel.dataset.built === '1' && window._tcjThemeCatalogState && window._tcjThemeCatalogState.persist) {
    try {
      await window._tcjThemeCatalogState.persist();
      saved++;
    } catch (e) { errors.push('Themes: ' + e.message); }
  }

  // ── Save Email Templates tab ────────────────────────────────
  var emailPanel = document.getElementById('upanel-sm-email');
  if (emailPanel && emailPanel.dataset.built === '1') {
    var subjects = emailPanel.querySelectorAll('input[id^="em-s-"]');
    for (var k = 0; k < subjects.length; k++) {
      var subj = subjects[k];
      var tkey = subj.id.replace('em-s-', '');
      var bodyEl = document.getElementById('em-b-' + tkey);
      if (!bodyEl) continue;
      try {
        var r3 = await apiFetch(SUPABASE_URL + '/rest/v1/email_templates', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'Prefer': 'resolution=merge-duplicates,return=representation' },
          body: JSON.stringify({ key: tkey, name: tkey.replace(/_/g,' ').replace(/\b\w/g,function(c){return c.toUpperCase();}), subject: subj.value, body: bodyEl.value })
        });
        if (!r3 || !r3.ok) throw new Error('Email template save failed: ' + tkey);
        saved++;
      } catch(e) { errors.push(e.message); }
    }
  }

  // ── Result ──────────────────────────────────────────────────
  if (btn) {
    if (errors.length === 0) {
      btn.textContent = '\u2713 All Saved (' + saved + ')';
      btn.style.background = '#4caf76';
      setTimeout(function() {
        btn.textContent = 'Save All';
        btn.style.background = '';
        btn.disabled = false;
        // Reload loaded panels to confirm
        ['sm-pages','sm-interface','sm-email','sm-themes'].forEach(function(tab) {
          var c = document.getElementById('upanel-' + tab);
          if (c && (c.dataset.built === '1' || c.dataset.shellBuilt === '1')) {
            c.dataset.built = '';
            c.dataset.shellBuilt = '';
            if (tab === 'sm-pages')    buildSMPages(c);
            if (tab === 'sm-interface') loadSMInterface(c);
            if (tab === 'sm-email')    buildSMEmail(c);
            if (tab === 'sm-themes')   buildSMThemes(c);
          }
        });
      }, 2000);
    } else {
      btn.textContent = 'Save All (' + errors.length + ' failed)';
      btn.style.background = '#dc5050';
      btn.disabled = false;
      alert('Save All completed with errors:\n\n' + errors.join('\n'));
    }
  }
}