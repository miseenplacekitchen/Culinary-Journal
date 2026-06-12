/**
 * lib/theme-catalog.js — single source of truth for theme metadata.
 * Used by profile.html (picker) and dashboard Site Management (Themes tab).
 */
(function () {
  var GROUPS = [
    {
      id: 'dark', label: 'Dark',
      themes: [
        { key: 'midnight-slate',  name: 'Midnight Slate',  sub: 'Default',          swatches: ['#0f1011', '#C4973B', '#ffffff'] },
        { key: 'midnight-black',  name: 'Midnight Black',  sub: 'Pure dark',        swatches: ['#000000', '#C4973B', '#ffffff'] },
        { key: 'dark-forest',     name: 'Dark Forest',     sub: 'Deep green',       swatches: ['#0b1410', '#6b8e5a', '#ffffff'] },
        { key: 'dark-bordeaux',   name: 'Dark Bordeaux',   sub: 'Wine red',         swatches: ['#1a0a0e', '#a04050', '#ffffff'] },
        { key: 'dark-navy',       name: 'Dark Navy',       sub: 'Deep blue',        swatches: ['#08111e', '#5080b8', '#ffffff'] },
        { key: 'dark-chocolate',  name: 'Dark Chocolate',  sub: 'Cocoa brown',      swatches: ['#180e08', '#a07050', '#ffffff'] },
        { key: 'dark-obsidian',   name: 'Dark Obsidian',   sub: 'Volcanic glass',   swatches: ['#0a0a14', '#7868a0', '#ffffff'] }
      ]
    },
    {
      id: 'light', label: 'Light',
      themes: [
        { key: 'cream-gold',      name: 'Cream & Gold',    sub: 'Warm paper',       swatches: ['#fdf6e3', '#b8860b', '#281e12'] },
        { key: 'pure-white',      name: 'Pure White',      sub: 'Minimal',          swatches: ['#ffffff', '#9b7028', '#141414'] },
        { key: 'soft-linen',      name: 'Soft Linen',      sub: 'Natural texture',  swatches: ['#f5f0e8', '#a08868', '#2a2418'] },
        { key: 'sage-cream',      name: 'Sage & Cream',    sub: 'Herb garden',      swatches: ['#f4f1e8', '#8a9d7a', '#2a2e22'] },
        { key: 'blush-rose',      name: 'Blush & Rose',    sub: 'Soft romance',     swatches: ['#fbeae5', '#c47b8f', '#3a2028'] },
        { key: 'silver-morning',  name: 'Silver Morning',  sub: 'Cool grey',        swatches: ['#f0f2f5', '#7a8898', '#1a2028'] },
        { key: 'lemon-fresh',     name: 'Lemon Fresh',     sub: 'Citrus light',     swatches: ['#fdfbe8', '#c8a838', '#2e2818'] }
      ]
    },
    {
      id: 'seasonal', label: 'Seasonal',
      themes: [
        { key: 'spring-blossom',  name: 'Spring Blossom',  sub: 'Soft pinks',       swatches: ['#fdeef2', '#c47b8f', '#3c1e28'] },
        { key: 'summer-citrus',   name: 'Summer Citrus',   sub: 'Bright zest',      swatches: ['#fff8e0', '#e08820', '#3a2a10'] },
        { key: 'autumn-harvest',  name: 'Autumn Harvest',  sub: 'Burnt orange',     swatches: ['#1a0e08', '#d97c3c', '#ffffff'] },
        { key: 'winter-frost',    name: 'Winter Frost',    sub: 'Icy blue',         swatches: ['#e8f0f5', '#6890b0', '#1a2830'] }
      ]
    },
    {
      id: 'festive', label: 'Festive',
      themes: [
        { key: 'christmas',       name: 'Christmas',       sub: 'Red & green',      swatches: ['#1a0a0a', '#c83838', '#3a8050'] },
        { key: 'diwali',          name: 'Diwali',          sub: 'Golden glow',      swatches: ['#1f0a05', '#e8a020', '#c84040'] },
        { key: 'ramadan',         name: 'Ramadan',         sub: 'Crescent moon',    swatches: ['#0a1418', '#80a8c0', '#d8b860'] },
        { key: 'new-year',        name: 'New Year',        sub: 'Midnight sparkle', swatches: ['#000814', '#d4af37', '#ffffff'] },
        { key: 'onam',            name: 'Onam',            sub: 'Floral feast',     swatches: ['#fff5e0', '#e08020', '#7a9050'] },
        { key: 'easter',          name: 'Easter',          sub: 'Pastel spring',    swatches: ['#fbf2e8', '#c8a0c0', '#a0c890'] }
      ]
    },
    {
      id: 'special', label: 'Special',
      themes: [
        { key: 'wedding-white',   name: 'Wedding White',   sub: 'Pure & elegant',   swatches: ['#ffffff', '#c0a060', '#1a1a1a'] },
        { key: 'birthday-cake',   name: 'Birthday Cake',   sub: 'Confetti joy',     swatches: ['#fff0f8', '#e878a8', '#5a3050'] },
        { key: 'baby-shower',     name: 'Baby Shower',     sub: 'Soft pastels',     swatches: ['#eef5f8', '#a0c8d8', '#3a4a58'] },
        { key: 'fine-dining',     name: 'Fine Dining',     sub: 'Black & gold',     swatches: ['#0a0a0a', '#d4af37', '#ffffff'] },
        { key: 'old-cookbook',    name: 'Old Cookbook',    sub: 'Vintage paper',    swatches: ['#f2e8d0', '#7a4828', '#2a1810'] },
        { key: 'world-kitchen',   name: 'World Kitchen',   sub: 'Global mosaic',    swatches: ['#1a1208', '#e08838', '#80a060'] }
      ]
    },
    {
      id: 'inspired', label: 'Inspired',
      themes: [
        { key: 'silk-whisper',     name: 'Silk & Whisper',     sub: 'Soft luxury',       swatches: ['#1a1418', '#c8a8b0', '#ffffff'] },
        { key: 'midnight-garden',  name: 'Midnight Garden',    sub: 'Botanical dark',    swatches: ['#0a1410', '#7a9070', '#e0c890'] },
        { key: 'crystal-pearl',    name: 'Crystal & Pearl',    sub: 'Iridescent',        swatches: ['#f8f4f8', '#b8a8c8', '#3a304a'] },
        { key: 'secret-garden',    name: 'The Secret Garden',  sub: 'Hidden bloom',      swatches: ['#0e1a14', '#90b870', '#e8d8b0'] },
        { key: 'bridal-blush',     name: 'Bridal Blush',       sub: 'Veil & rose',       swatches: ['#fbf0ee', '#d8a8a0', '#4a302e'] },
        { key: 'pure-petals',      name: 'Pure Petals',        sub: 'White florals',     swatches: ['#fdfafa', '#e8c8c8', '#3a2828'] },
        { key: 'violet-storm',     name: 'Violet Storm',       sub: 'Electric purple',   swatches: ['#0a0814', '#9070d0', '#ffffff'] },
        { key: 'golden-hour',      name: 'Golden Hour',        sub: 'Sunset glow',       swatches: ['#1a1008', '#e8a040', '#ffd890'] },
        { key: 'forest-rain',      name: 'Forest Rain',        sub: 'Petrichor mist',    swatches: ['#0e1614', '#7a9088', '#d8d0c0'] },
        { key: 'enchanted-winter', name: 'Enchanted Winter',   sub: 'Snow & silver',     swatches: ['#e8eef2', '#7088a0', '#1a2a3a'] },
        { key: 'emerald-night',    name: 'Emerald Night',      sub: 'Jewel green',       swatches: ['#040e0a', '#10a070', '#ffffff'] },
        { key: 'still-waters',     name: 'Still Waters',       sub: 'Calm lake',         swatches: ['#0a1418', '#5090a0', '#d0e0e8'] },
        { key: 'heavens-gate',     name: "Heaven's Gate",      sub: 'Celestial light',   swatches: ['#f0f0fa', '#a890d0', '#2a2848'] },
        { key: 'ocean-breeze',     name: 'Ocean Breeze',       sub: 'Salt & spray',      swatches: ['#e8f4f8', '#4090b0', '#1a3a48'] },
        { key: 'wildfire',         name: 'Wildfire',           sub: 'Untamed flame',     swatches: ['#1a0808', '#e04020', '#f8c060'] },
        { key: 'full-bloom',       name: 'Full Bloom',         sub: 'Garden in summer',  swatches: ['#fbf4e8', '#d870a0', '#3a2030'] },
        { key: 'lunar-gold',       name: 'Lunar Gold',         sub: 'Moonlight metal',   swatches: ['#0a0a14', '#d4c068', '#ffffff'] }
      ]
    }
  ];

  function flatThemes() {
    var out = [];
    GROUPS.forEach(function (g) {
      g.themes.forEach(function (t) {
        out.push({
          key: t.key,
          name: t.name,
          sub: t.sub,
          swatches: t.swatches.slice(),
          category: g.id,
          categoryLabel: g.label
        });
      });
    });
    return out;
  }

  function defaultThemeEntry(theme) {
    return {
      enabled: true,
      pricing: 'free',
      price: 0,
      min_tier: 'free',
      featured: theme.key === 'midnight-slate',
      description: theme.sub || '',
      colors: {
        bg: theme.swatches[0] || '#0f1011',
        accent: theme.swatches[1] || '#C4973B',
        text: theme.swatches[2] || '#ffffff',
        border: '',
        surface: '',
        nav_bg: ''
      }
    };
  }

  function buildDefaultCatalog() {
    var themes = {};
    flatThemes().forEach(function (t) {
      themes[t.key] = defaultThemeEntry(t);
    });
    return {
      version: 1,
      default_theme: 'midnight-slate',
      seasonal_default: '',
      themes: themes,
      custom: [],
      custom_categories: []
    };
  }

  function slugify(str) {
    return String(str || '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
  }

  function getAllCategories(catalog) {
    catalog = catalog || {};
    var list = GROUPS.map(function (g) {
      return { id: g.id, label: g.label, builtin: true };
    });
    (catalog.custom_categories || []).forEach(function (c) {
      if (!c || !c.id) return;
      if (!list.some(function (x) { return x.id === c.id; })) {
        list.push({ id: c.id, label: c.label || c.id, builtin: false });
      }
    });
    return list;
  }

  function getCategoryLabel(catalog, categoryId) {
    var hit = getAllCategories(catalog).filter(function (c) { return c.id === categoryId; })[0];
    return hit ? hit.label : categoryId;
  }

  function customEntryFromStored(c) {
    return {
      enabled: c.enabled !== false,
      pricing: c.pricing || 'paid',
      price: Number(c.price || 0),
      min_tier: c.min_tier || 'free',
      featured: !!c.featured,
      description: c.description || c.sub || 'Custom theme',
      category: c.category || 'inspired',
      colors: Object.assign({
        bg: '#0f1011', accent: '#C4973B', text: '#ffffff', border: '', surface: '', nav_bg: ''
      }, c.colors || {})
    };
  }

  function parseJson(raw, fallback) {
    if (!raw) return fallback;
    try {
      var v = typeof raw === 'string' ? JSON.parse(raw) : raw;
      return v && typeof v === 'object' ? v : fallback;
    } catch (_) { return fallback; }
  }

  function nameOrKeyToThemeKey(nameOrKey) {
    if (!nameOrKey) return '';
    var flat = flatThemes();
    var hit = flat.filter(function (t) {
      return t.key === nameOrKey || t.name === nameOrKey;
    })[0];
    return hit ? hit.key : String(nameOrKey);
  }

  function syncDefaultThemeFlags(catalog) {
    if (!catalog || !catalog.themes) return catalog;
    var def = catalog.default_theme || 'midnight-slate';
    var effective = catalog.seasonal_default || def;
    Object.keys(catalog.themes).forEach(function (key) {
      catalog.themes[key].featured = key === effective;
    });
    return catalog;
  }

  function mergeThemeCatalog(stored, disabledLegacy, seasonalDefault, defaultThemeOverride) {
    var base = buildDefaultCatalog();
    stored = parseJson(stored, {});
    if (stored.default_theme) base.default_theme = nameOrKeyToThemeKey(stored.default_theme);
    if (defaultThemeOverride) base.default_theme = nameOrKeyToThemeKey(defaultThemeOverride);
    if (stored.seasonal_default) base.seasonal_default = nameOrKeyToThemeKey(stored.seasonal_default);
    if (seasonalDefault) base.seasonal_default = nameOrKeyToThemeKey(seasonalDefault);

    function applyThemeConfig(dst, src) {
      if (!dst || !src) return;
      ['enabled', 'pricing', 'price', 'min_tier', 'featured', 'description', 'category'].forEach(function (f) {
        if (src[f] !== undefined && src[f] !== null) dst[f] = src[f];
      });
      if (src.colors) dst.colors = Object.assign({}, dst.colors, src.colors);
    }

    Object.keys(stored.themes || {}).forEach(function (key) {
      if (!base.themes[key]) return;
      applyThemeConfig(base.themes[key], stored.themes[key]);
    });

    base.custom_categories = Array.isArray(stored.custom_categories) ? stored.custom_categories.slice() : [];
    base.custom = Array.isArray(stored.custom) ? stored.custom.slice() : [];

    base.custom.forEach(function (c) {
      if (!c || !c.key) return;
      if (!base.themes[c.key]) base.themes[c.key] = customEntryFromStored(c);
      applyThemeConfig(base.themes[c.key], stored.themes && stored.themes[c.key] ? stored.themes[c.key] : c);
      if (!base.themes[c.key].category) base.themes[c.key].category = c.category || 'inspired';
    });

    var disabled = Array.isArray(disabledLegacy) ? disabledLegacy : [];
    flatThemes().forEach(function (t) {
      if (disabled.indexOf(t.name) !== -1) base.themes[t.key].enabled = false;
    });

    return syncDefaultThemeFlags(base);
  }

  function effectiveSiteThemeKey(catalog) {
    if (!catalog) return 'midnight-slate';
    return catalog.seasonal_default || catalog.default_theme || 'midnight-slate';
  }

  function disabledNamesFromCatalog(catalog) {
    var names = [];
    var byKey = {};
    flatThemes().forEach(function (t) { byKey[t.key] = t.name; });
    Object.keys(catalog.themes || {}).forEach(function (key) {
      if (catalog.themes[key].enabled === false && byKey[key]) names.push(byKey[key]);
    });
    (catalog.custom || []).forEach(function (c) {
      if (c.enabled === false && c.name) names.push(c.name);
    });
    return names;
  }

  function themeMetaForProfile(catalog, key) {
    var flat = flatThemes();
    var base = flat.filter(function (t) { return t.key === key; })[0];
    var custom = (catalog.custom || []).filter(function (c) { return c.key === key; })[0];
    var cfg = (catalog.themes && catalog.themes[key]) || (custom || null);
    if (!base && !custom) return null;
    var name = base ? base.name : custom.name;
    var sub = (cfg && cfg.description) || (base ? base.sub : custom.sub) || '';
    var swatches = (cfg && cfg.colors && cfg.colors.bg)
      ? [cfg.colors.bg, cfg.colors.accent, cfg.colors.text]
      : (base ? base.swatches : (custom.swatches || ['#0f1011', '#C4973B', '#ffffff']));
    var enabled = cfg ? cfg.enabled !== false : true;
    var pricing = cfg ? (cfg.pricing || 'free') : 'free';
    var price = cfg ? Number(cfg.price || 0) : 0;
    var minTier = cfg ? (cfg.min_tier || 'free') : 'free';
    var defKey = catalog.default_theme || 'midnight-slate';
    var effectiveKey = effectiveSiteThemeKey(catalog);
    var featured = key === effectiveKey;
    if (key === defKey) {
      sub = 'Default';
    } else if (base && base.sub === 'Default') {
      sub = (cfg && cfg.description) || 'Classic dark';
    }
    var live = enabled && pricing === 'free';
    return {
      key: key,
      name: name,
      sub: sub,
      swatches: swatches,
      live: live,
      enabled: enabled,
      pricing: pricing,
      price: price,
      min_tier: minTier,
      featured: featured
    };
  }

  function profileThemeGroups(catalog) {
    var out = {};
    getAllCategories(catalog).forEach(function (g) { out[g.id] = []; });

    GROUPS.forEach(function (g) {
      g.themes.forEach(function (t) {
        var meta = themeMetaForProfile(catalog, t.key);
        if (meta && meta.enabled) out[g.id].push(meta);
      });
    });

    (catalog.custom || []).forEach(function (c) {
      if (!c || !c.key) return;
      var cfg = catalog.themes && catalog.themes[c.key];
      if (cfg && cfg.enabled === false) return;
      var cat = (cfg && cfg.category) || c.category || 'inspired';
      if (!out[cat]) out[cat] = [];
      var meta = themeMetaForProfile(catalog, c.key);
      if (meta && meta.enabled) out[cat].push(meta);
    });

    return out;
  }

  function themesForAdminCategory(catalog, categoryId) {
    var builtins = [];
    var group = GROUPS.filter(function (g) { return g.id === categoryId; })[0];
    if (group) {
      group.themes.forEach(function (t) {
        builtins.push({
          key: t.key,
          name: t.name,
          category: categoryId,
          categoryLabel: group.label,
          swatches: t.swatches,
          builtin: true
        });
      });
    }
    var customs = (catalog.custom || []).filter(function (c) {
      var cfg = catalog.themes && catalog.themes[c.key];
      var cat = (cfg && cfg.category) || c.category || 'inspired';
      return cat === categoryId;
    }).map(function (c) {
      return {
        key: c.key,
        name: c.name,
        category: categoryId,
        categoryLabel: getCategoryLabel(catalog, categoryId),
        swatches: c.swatches || ['#0f1011', '#C4973B', '#ffffff'],
        builtin: false
      };
    });
    return builtins.concat(customs);
  }

  window.TCJ_THEME_GROUPS = GROUPS;
  window.TCJ_flatThemes = flatThemes;
  window.TCJ_slugify = slugify;
  window.TCJ_getAllCategories = getAllCategories;
  window.TCJ_getCategoryLabel = getCategoryLabel;
  window.TCJ_themesForAdminCategory = themesForAdminCategory;
  window.TCJ_buildDefaultCatalog = buildDefaultCatalog;
  window.TCJ_mergeThemeCatalog = mergeThemeCatalog;
  window.TCJ_syncDefaultThemeFlags = syncDefaultThemeFlags;
  window.TCJ_effectiveSiteThemeKey = effectiveSiteThemeKey;
  window.TCJ_nameOrKeyToThemeKey = nameOrKeyToThemeKey;
  window.TCJ_disabledNamesFromCatalog = disabledNamesFromCatalog;
  window.TCJ_profileThemeGroups = profileThemeGroups;
  window.TCJ_themeMetaForProfile = themeMetaForProfile;
})();
