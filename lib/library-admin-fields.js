/* Shared library profile field schema for admin editor + library-submit */
(function (global) {
  var TCJ_LIB_TYPE_FIELDS = {
    ingredient: [
      { id: 'f-category', label: 'Category', type: 'input', ph: 'e.g. Oils & Fats' },
      { id: 'f-subcategory', label: 'Subcategory', type: 'input', ph: 'e.g. Animal Fats' },
      { id: 'f-allergen', label: 'Allergen Info', type: 'input', ph: 'e.g. Dairy' },
      { id: 'f-vegan', label: 'Vegan', type: 'checkbox' },
      { id: 'f-vegetarian', label: 'Vegetarian', type: 'checkbox' },
      { id: 'f-origin', label: 'The Story — Origin & Heritage', type: 'textarea' },
      { id: 'f-history', label: 'History', type: 'textarea' },
      { id: 'f-cultural', label: 'Across Cultures', type: 'textarea' },
      { id: 'f-flavour', label: 'Flavour Profile', type: 'textarea' },
      { id: 'f-buy', label: 'How to Buy', type: 'textarea' },
      { id: 'f-store', label: 'How to Store', type: 'textarea' },
      { id: 'f-prep', label: 'How to Prep', type: 'textarea' },
      { id: 'f-when', label: 'When to Add It', type: 'textarea' },
      { id: 'f-mistakes', label: 'Common Mistakes', type: 'textarea' },
      { id: 'f-science', label: 'The Science', type: 'textarea' },
      { id: 'f-pairings', label: 'Flavour Pairings', type: 'textarea' },
      { id: 'f-preserv', label: 'Preservation Notes', type: 'textarea' },
      { id: 'f-baby', label: 'For Babies & Toddlers', type: 'textarea' },
      { id: 'f-subs', label: 'Substitutes', type: 'textarea' },
      { id: 'f-nutrition', label: 'Nutrition & Health Notes', type: 'textarea' },
      { id: 'f-season', label: 'Seasonality', type: 'input', ph: 'e.g. Best in autumn months' }
    ],
    spice: [
      { id: 'f-origin', label: 'Origin Story', type: 'textarea' },
      { id: 'f-history', label: 'History', type: 'textarea' },
      { id: 'f-cultural', label: 'Across Cultures', type: 'textarea' },
      { id: 'f-flavour', label: 'Flavour Wheel', type: 'textarea' },
      { id: 'f-heat', label: 'Heat Level (0–5)', type: 'input', ph: '0' },
      { id: 'f-wvg', label: 'Whole vs Ground', type: 'textarea' },
      { id: 'f-toast', label: 'How to Toast & Bloom', type: 'textarea' },
      { id: 'f-blends', label: 'Blends It Belongs To', type: 'textarea' },
      { id: 'f-when', label: 'When to Add It', type: 'textarea' },
      { id: 'f-science', label: 'The Science', type: 'textarea' },
      { id: 'f-pairings', label: 'Flavour Pairings', type: 'textarea' },
      { id: 'f-subs', label: 'Substitutes', type: 'textarea' }
    ],
    tool: [
      { id: 'f-toolcat', label: 'Category', type: 'input', ph: 'e.g. Knife / Pan / Appliance' },
      { id: 'f-whatfor', label: 'What It Is For', type: 'textarea' },
      { id: 'f-howtouse', label: 'How to Use It', type: 'textarea' },
      { id: 'f-care', label: 'How to Care for It', type: 'textarea' },
      { id: 'f-lookfor', label: 'What to Look For When Buying', type: 'textarea' },
      { id: 'f-mistakes', label: 'Common Mistakes', type: 'textarea' },
      { id: 'f-price', label: 'Price Range', type: 'input', ph: 'e.g. £20–£60' }
    ],
    cut: [
      { id: 'f-protein', label: 'Protein Type', type: 'select', opts: ['beef', 'lamb', 'pork', 'chicken', 'duck', 'fish', 'seafood', 'other'] },
      { id: 'f-intlnames', label: 'International Names', type: 'input', ph: 'comma separated' },
      { id: 'f-location', label: 'Location on Animal', type: 'textarea' },
      { id: 'f-chars', label: 'Characteristics', type: 'textarea' },
      { id: 'f-clean', label: 'How to Clean It', type: 'textarea' },
      { id: 'f-prep', label: 'How to Prep It', type: 'textarea' },
      { id: 'f-methods', label: 'Best Cooking Methods', type: 'textarea' }
    ],
    preservation: [
      { id: 'f-techtype', label: 'Technique Type', type: 'select', opts: ['canning', 'fermenting', 'pickling', 'drying', 'smoking', 'freezing', 'curing', 'other'] },
      { id: 'f-whatitis', label: 'What It Is', type: 'textarea' },
      { id: 'f-history', label: 'History', type: 'textarea' },
      { id: 'f-bestfor', label: 'Best For', type: 'textarea' },
      { id: 'f-equipment', label: 'Equipment Needed', type: 'textarea' },
      { id: 'f-steps', label: 'Step by Step (one per line)', type: 'textarea' },
      { id: 'f-safety', label: 'Safety Notes', type: 'textarea' },
      { id: 'f-shelf', label: 'Shelf Life', type: 'input', ph: 'e.g. 12 months sealed' }
    ]
  };

  var TCJ_LIB_FIELD_MAP = {
    'f-category': 'category', 'f-subcategory': 'subcategory', 'f-allergen': 'allergen',
    'f-vegan': 'vegan', 'f-vegetarian': 'vegetarian', 'f-origin': 'origin_story',
    'f-history': 'history', 'f-cultural': 'cultural_use', 'f-flavour': 'flavour_profile',
    'f-buy': 'how_to_buy', 'f-store': 'how_to_store', 'f-prep': 'how_to_prep',
    'f-when': 'when_to_add', 'f-mistakes': 'common_mistakes', 'f-science': 'science_notes',
    'f-pairings': 'pairings', 'f-preserv': 'preservation_notes', 'f-baby': 'baby_notes',
    'f-subs': 'substitutes', 'f-nutrition': 'nutrition_notes', 'f-season': 'seasonality',
    'f-heat': 'heat_level', 'f-wvg': 'whole_vs_ground', 'f-toast': 'how_to_toast',
    'f-blends': 'blends', 'f-toolcat': 'tool_category', 'f-whatfor': 'what_its_for',
    'f-howtouse': 'how_to_use', 'f-care': 'how_to_care', 'f-lookfor': 'what_to_look_for',
    'f-price': 'price_range', 'f-protein': 'protein_type', 'f-intlnames': 'international_names',
    'f-location': 'location_on_animal', 'f-chars': 'characteristics', 'f-clean': 'how_to_clean',
    'f-methods': 'best_cooking_methods', 'f-techtype': 'technique_type', 'f-whatitis': 'what_it_is',
    'f-bestfor': 'best_for', 'f-equipment': 'equipment_needed', 'f-steps': 'step_by_step',
    'f-safety': 'safety_notes', 'f-shelf': 'shelf_life'
  };

  var TCJ_LIB_DB_TO_FORM = {};
  Object.keys(TCJ_LIB_FIELD_MAP).forEach(function (fid) {
    TCJ_LIB_DB_TO_FORM[TCJ_LIB_FIELD_MAP[fid]] = fid;
  });

  function tcjLibSlugify(str) {
    return String(str || '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
  }

  function tcjLibBuildPayload(type, getVal, opts) {
    opts = opts || {};
    var name = getVal('f-name');
    var slug = opts.slug || (tcjLibSlugify(name) + '-' + Date.now());
    var localRaw = getVal('f-local') || '';
    var localNames = localRaw.split(',').map(function (s) { return s.trim(); }).filter(Boolean);

    var payload = {
      slug: slug,
      name: name,
      also_known_as: getVal('f-aka') || null,
      local_names: localNames,
      image_url: getVal('f-img-url') || null,
      mise_image_url: getVal('f-mise-url') || null,
      image_status: getVal('f-image-status') || 'missing',
      chefs_notes: getVal('f-chefs') || null,
      recommended_brand: getVal('f-brand') || null,
      did_you_know: getVal('f-dyk') || null,
      status: getVal('f-status') || 'draft',
      visibility: getVal('f-visibility') || 'public'
    };

    if (type === 'ingredient' && getVal('f-governed-id')) {
      payload.governed_ingredient_id = parseInt(getVal('f-governed-id'), 10) || null;
    }

    var fields = TCJ_LIB_TYPE_FIELDS[type] || [];
    fields.forEach(function (f) {
      var dbKey = TCJ_LIB_FIELD_MAP[f.id];
      if (type === 'spice' && f.id === 'f-flavour') dbKey = 'flavour_wheel';
      if (!dbKey) return;
      var v = getVal(f.id);
      if (f.id === 'f-steps' && v) {
        v = v.split('\n').map(function (s) { return s.trim(); }).filter(Boolean);
      } else if (f.id === 'f-intlnames' && v) {
        v = v.split(',').map(function (s) { return s.trim(); }).filter(Boolean);
      } else if (f.id === 'f-heat') {
        v = parseInt(v, 10);
        if (isNaN(v)) v = 0;
      } else if (f.type === 'checkbox') {
        v = !!v;
      }
      payload[dbKey] = (v === '' || v === null || v === undefined) ? null : v;
    });

    return payload;
  }

  function tcjLibFillForm(profile, setVal, type) {
    if (!profile) return;
    setVal('f-name', profile.name);
    setVal('f-aka', profile.also_known_as);
    setVal('f-local', Array.isArray(profile.local_names) ? profile.local_names.join(', ') : '');
    setVal('f-img-url', profile.image_url);
    setVal('f-mise-url', profile.mise_image_url);
    setVal('f-image-status', profile.image_status || (profile.mise_image_url ? 'draft' : 'missing'));
    setVal('f-chefs', profile.chefs_notes);
    setVal('f-brand', profile.recommended_brand);
    setVal('f-dyk', profile.did_you_know);
    setVal('f-status', profile.status);
    setVal('f-visibility', profile.visibility);
    if (type === 'ingredient') setVal('f-governed-id', profile.governed_ingredient_id || '');

    var fields = TCJ_LIB_TYPE_FIELDS[type] || [];
    fields.forEach(function (f) {
      var dbKey = TCJ_LIB_FIELD_MAP[f.id];
      if (!dbKey) return;
      var v = profile[dbKey];
      if (f.id === 'f-flavour' && type === 'spice' && !v) v = profile.flavour_wheel;
      if (f.id === 'f-steps' && Array.isArray(v)) v = v.join('\n');
      if (f.id === 'f-intlnames' && Array.isArray(v)) v = v.join(', ');
      if (f.type === 'checkbox') setVal(f.id, !!v);
      else setVal(f.id, v != null ? v : '');
    });
  }

  var TCJ_LIB_SHARED_CSV = [
    'name', 'slug', 'also_known_as', 'local_names', 'image_url', 'mise_image_url', 'image_status',
    'chefs_notes', 'recommended_brand', 'did_you_know', 'status', 'visibility',
    'governed_ingredient_id', 'internal_notes'
  ];

  var TCJ_LIB_CSV_COLUMNS = {
    ingredient: TCJ_LIB_SHARED_CSV.concat([
      'category', 'subcategory', 'allergen', 'vegan', 'vegetarian', 'origin_story', 'history',
      'cultural_use', 'flavour_profile', 'how_to_buy', 'how_to_store', 'how_to_prep', 'when_to_add',
      'common_mistakes', 'science_notes', 'pairings', 'preservation_notes', 'baby_notes',
      'substitutes', 'nutrition_notes', 'seasonality'
    ]),
    spice: TCJ_LIB_SHARED_CSV.concat([
      'origin_story', 'history', 'cultural_use', 'flavour_wheel', 'heat_level', 'whole_vs_ground',
      'how_to_toast', 'blends', 'when_to_add', 'science_notes', 'pairings', 'substitutes'
    ]),
    tool: TCJ_LIB_SHARED_CSV.concat([
      'tool_category', 'what_its_for', 'how_to_use', 'how_to_care', 'common_mistakes',
      'what_to_look_for', 'price_range'
    ]),
    cut: TCJ_LIB_SHARED_CSV.concat([
      'international_names', 'protein_type', 'location_on_animal', 'characteristics',
      'how_to_clean', 'how_to_prep', 'best_cooking_methods'
    ]),
    preservation: TCJ_LIB_SHARED_CSV.concat([
      'technique_type', 'what_it_is', 'history', 'best_for', 'equipment_needed', 'step_by_step',
      'safety_notes', 'shelf_life'
    ])
  };

  function tcjLibParseCsvValue(key, raw) {
    if (raw === undefined || raw === null) return null;
    var s = String(raw).trim();
    if (s === '') return null;
    if (key === 'local_names' || key === 'international_names' || key === 'step_by_step') {
      return s.split('|').map(function (x) { return x.trim(); }).filter(Boolean);
    }
    if (key === 'vegan' || key === 'vegetarian') return /^(1|yes|true)$/i.test(s);
    if (key === 'heat_level' || key === 'governed_ingredient_id') {
      var n = parseInt(s, 10);
      return isNaN(n) ? null : n;
    }
    return s;
  }

  function tcjLibCsvRowToPayload(type, row) {
    var cols = TCJ_LIB_CSV_COLUMNS[type] || TCJ_LIB_SHARED_CSV;
    var payload = {};
    cols.forEach(function (key) {
      if (row[key] === undefined && row[key] !== 0) return;
      var v = tcjLibParseCsvValue(key, row[key]);
      if (v !== null && v !== undefined && v !== '') payload[key] = v;
    });
    if (!payload.name && row.Name) payload.name = String(row.Name).trim();
    return payload;
  }

  var TCJ_LIB_TYPE_META = {
    ingredient: {
      emoji: '🌿', short: 'Ingredient', directory: 'Ingredients',
      tagline: 'A full ingredient guide — origin, buying, storing, prep, science, pairings, and substitutes.',
      ex: { name: 'Sebago Potato', aka: 'White potato, Waxy potato', local: 'Kipfler, Dutch Cream, Nicola', img: 'Whole potatoes on a board — natural light, no packaging' },
      chefs: 'Reach for waxy potatoes in salads and floury ones for mash — the starch type matters more than the brand.',
      brand: 'e.g. your trusted local greengrocer pick',
      dyk: 'Roughly 80% of a potato is water — variety changes everything in the pan.'
    },
    spice: {
      emoji: '🌶', short: 'Spice', directory: 'Spices',
      tagline: 'Flavour wheel, heat, toasting technique, blends, and when to add it in cooking.',
      ex: { name: 'Cumin', aka: 'Jeera, Comino', local: 'Safed Jeera, Shah Jeera', img: 'Whole cumin seeds in a small bowl or on a spice spoon' },
      chefs: 'Toast whole cumin until fragrant — about 30 seconds — before grinding. Ground cumin fades fast.',
      brand: 'e.g. whole seeds from a spice merchant you trust',
      dyk: 'Cumin is one of the most ancient traded spices — it appears in Egyptian tomb records.'
    },
    tool: {
      emoji: '🔪', short: 'Tool / Appliance', directory: 'Tools',
      tagline: 'What it is for, how to use it safely, care, buying advice, and common mistakes.',
      ex: { name: 'Dutch Oven', aka: 'French oven, Cocotte', local: 'Cast-iron casserole', img: 'Clean tool on neutral background — lid off, showing interior' },
      chefs: 'A heavy lid and thick walls matter more than the badge on the box — feel the weight before you buy.',
      brand: 'e.g. Le Creuset, Lodge, or solid cast-iron equivalent',
      dyk: 'Dutch ovens were designed for coals on top and underneath — that is why the lid is domed.'
    },
    cut: {
      emoji: '🥩', short: 'Cut / Prep', directory: 'Cuts & Prep',
      tagline: 'Where it sits on the animal, characteristics, cleaning, prep, and best cooking methods.',
      ex: { name: 'Beef Brisket', aka: 'Chest, Pectoral', local: 'Point, Flat, Deckle', img: 'Raw cut on butcher paper — show grain and fat cap clearly' },
      chefs: 'Brisket wants low heat and time — rushing it is the most common mistake at home.',
      brand: 'n/a — ask your butcher for grass-fed or grain-fed as you prefer',
      dyk: 'Brisket is two muscles separated by fat — the point is fattier and more forgiving.'
    },
    preservation: {
      emoji: '🫙', short: 'Preservation', directory: 'Preservation',
      tagline: 'Technique overview, equipment, step-by-step process, safety, and shelf life.',
      ex: { name: 'Water-bath Canning', aka: 'Boiling-water canning', local: 'Hot pack, Raw pack', img: 'Jars in canner or finished sealed jars — labels visible' },
      chefs: 'Acidity and processing time are not negotiable — treat published processing times as fixed, not approximate.',
      brand: 'n/a',
      dyk: 'Water-bath canning is only safe for high-acid foods — low-acid needs pressure canning.'
    }
  };

  var TCJ_LIB_FIELD_PANELS = {
    ingredient: [
      { title: 'Classification', desc: 'Category, subcategory, allergens, dietary flags', fields: ['f-category', 'f-subcategory', 'f-allergen', 'f-vegan', 'f-vegetarian'], open: true },
      { title: 'Story & heritage', desc: 'Origin, history, and cultural context', fields: ['f-origin', 'f-history', 'f-cultural'] },
      { title: 'In the kitchen', desc: 'Flavour, buying, storing, prep, timing, mistakes', fields: ['f-flavour', 'f-buy', 'f-store', 'f-prep', 'f-when', 'f-mistakes'] },
      { title: 'Science & pairings', desc: 'Food science, pairings, substitutes, nutrition', fields: ['f-science', 'f-pairings', 'f-subs', 'f-nutrition', 'f-season'] },
      { title: 'Special notes', desc: 'Preservation, babies & toddlers', fields: ['f-preserv', 'f-baby'] }
    ],
    spice: [
      { title: 'Story & culture', desc: 'Origin, history, and use across cuisines', fields: ['f-origin', 'f-history', 'f-cultural'], open: true },
      { title: 'Flavour & heat', desc: 'Flavour wheel, heat level, whole vs ground', fields: ['f-flavour', 'f-heat', 'f-wvg'] },
      { title: 'Technique', desc: 'Toasting, blooming, blends, when to add', fields: ['f-toast', 'f-blends', 'f-when', 'f-science'] },
      { title: 'Pairings & substitutes', desc: 'What it loves and what can replace it', fields: ['f-pairings', 'f-subs'] }
    ],
    tool: [
      { title: 'Overview', desc: 'Category and what this tool is for', fields: ['f-toolcat', 'f-whatfor'], open: true },
      { title: 'Usage & care', desc: 'How to use it and keep it in good condition', fields: ['f-howtouse', 'f-care', 'f-mistakes'] },
      { title: 'Buying advice', desc: 'What to look for and typical price range', fields: ['f-lookfor', 'f-price'] }
    ],
    cut: [
      { title: 'Anatomy', desc: 'Protein type, names, and location on the animal', fields: ['f-protein', 'f-intlnames', 'f-location'], open: true },
      { title: 'Characteristics & prep', desc: 'Texture, fat, cleaning, and butchery prep', fields: ['f-chars', 'f-clean', 'f-prep'] },
      { title: 'Cooking methods', desc: 'Best ways to cook this cut', fields: ['f-methods'] }
    ],
    preservation: [
      { title: 'Technique overview', desc: 'Type, definition, history, best uses', fields: ['f-techtype', 'f-whatitis', 'f-history', 'f-bestfor'], open: true },
      { title: 'Process', desc: 'Equipment and step-by-step method', fields: ['f-equipment', 'f-steps'] },
      { title: 'Safety & shelf life', desc: 'Critical safety notes and storage duration', fields: ['f-safety', 'f-shelf'] }
    ]
  };

  var TCJ_LIB_FIELD_HINTS = {
    ingredient: {
      'f-origin': 'Where it comes from and why that matters on the plate…',
      'f-flavour': 'Earthy, nutty, sweet notes — how it behaves when cooked…',
      'f-buy': 'What to look for at the shop — colour, firmness, smell…',
      'f-prep': 'Wash, peel, cut — the steps before it hits the pan…'
    },
    spice: {
      'f-origin': 'Native region and how it entered world cuisines…',
      'f-flavour': 'Warm, earthy, citrus back-note — map the flavour wheel…',
      'f-toast': 'Dry pan, medium heat, until fragrant — usually under a minute…',
      'f-when': 'Bloomed in oil at the start, or finished at the end…'
    },
    tool: {
      'f-whatfor': 'Braising, baking, stovetop sear — the jobs it does best…',
      'f-howtouse': 'Preheat, handle safety, typical workflow in a recipe…',
      'f-care': 'Cleaning, seasoning, storage — keep it usable for decades…'
    },
    cut: {
      'f-location': 'Chest, hindquarter, belly — where the butcher takes it from…',
      'f-chars': 'Fat marbling, grain direction, typical thickness…',
      'f-methods': 'Low-and-slow smoke, braise, pressure cook — what works…'
    },
    preservation: {
      'f-whatitis': 'Plain-language definition a home cook understands…',
      'f-steps': 'One step per line — pack, process, cool, store…',
      'f-safety': 'Botulism risk, acidity requirements, altitude adjustments…'
    }
  };

  function tcjLibFieldHint(type, fieldId) {
    var t = TCJ_LIB_FIELD_HINTS[type] || {};
    return t[fieldId] || '';
  }

  function tcjLibGetField(type, fieldId) {
    var list = TCJ_LIB_TYPE_FIELDS[type] || [];
    for (var i = 0; i < list.length; i++) {
      if (list[i].id === fieldId) return list[i];
    }
    return null;
  }

  global.TCJ_LIB_TYPE_META = TCJ_LIB_TYPE_META;
  global.TCJ_LIB_FIELD_PANELS = TCJ_LIB_FIELD_PANELS;
  global.tcjLibFieldHint = tcjLibFieldHint;
  global.tcjLibGetField = tcjLibGetField;
  global.TCJ_LIB_TYPE_FIELDS = TCJ_LIB_TYPE_FIELDS;
  global.TCJ_LIB_FIELD_MAP = TCJ_LIB_FIELD_MAP;
  global.TCJ_LIB_DB_TO_FORM = TCJ_LIB_DB_TO_FORM;
  global.TCJ_LIB_CSV_COLUMNS = TCJ_LIB_CSV_COLUMNS;
  global.tcjLibSlugify = tcjLibSlugify;
  global.tcjLibBuildPayload = tcjLibBuildPayload;
  global.tcjLibFillForm = tcjLibFillForm;
  global.tcjLibCsvRowToPayload = tcjLibCsvRowToPayload;
})(typeof window !== 'undefined' ? window : globalThis);
