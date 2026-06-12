// garden-ui.js — public presentation for Garden pages (names only; no slugs/UUIDs on screen)
(function (global) {
  var CARE_LABELS = {
    sunlight: 'Sunlight', water: 'Water', frost: 'Frost tolerance', soil: 'Soil',
    pest_mgmt: 'Pests & disease', feeding: 'Feeding', spacing: 'Spacing', mulch: 'Mulch',
    support: 'Support / staking', pruning: 'Pruning', humidity: 'Humidity'
  };

  var ACTIVITY_EMOJI = { sow: '🌱', transplant: '🪴', plant: '🌿', harvest: '🧺', prune: '✂️' };
  var ACTIVITY_LABEL = { sow: 'Sow', transplant: 'Transplant', plant: 'Plant out', harvest: 'Harvest', prune: 'Prune' };

  function esc(s) {
    return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function careLabel(key) {
    return CARE_LABELS[key] || String(key || '').replace(/_/g, ' ');
  }

  function monthNames() {
    return ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  }

  function monthLabel(m) {
    return monthNames()[m] || '';
  }

  function uniqueClimates(care, calendar) {
    var set = {};
    (care || []).forEach(function (c) { if (c.climate_zone) set[c.climate_zone] = 1; });
    (calendar || []).forEach(function (c) { if (c.climate_zone) set[c.climate_zone] = 1; });
    return Object.keys(set);
  }

  function filterByClimate(items, climate) {
    if (!climate) return items || [];
    return (items || []).filter(function (x) {
      return !x.climate_zone || x.climate_zone === climate;
    });
  }

  function renderCareCards(climateCare, preferredClimate) {
    var climates = uniqueClimates(climateCare, []);
    if (!climates.length && !(climateCare || []).length) return '';
    var html = '';
    var groups = climates.length ? climates : [preferredClimate || 'All climates'];
    groups.forEach(function (cl) {
      var rows = filterByClimate(climateCare, cl === 'All climates' ? null : cl);
      if (!rows.length) return;
      html += '<div class="gj-care-climate">' + esc(cl) + '</div><div class="gj-care-grid">';
      rows.forEach(function (c) {
        html += '<div class="gj-care-card"><div class="gj-care-label">' + esc(careLabel(c.field_key)) + '</div>' +
          '<div class="gj-care-core">' + esc(c.core) + '</div>' +
          (c.risk ? '<div class="gj-care-risk">⚠ ' + esc(c.risk) + '</div>' : '') +
          (c.fix ? '<div class="gj-care-fix">✓ ' + esc(c.fix) + '</div>' : '') +
          '</div>';
      });
      html += '</div>';
    });
    return html;
  }

  function renderCalendar(calendar, preferredClimate) {
    var items = filterByClimate(calendar, preferredClimate);
    if (!items.length) return '<p class="gj-section-lead">Seasonal calendar for your climate will appear once you set your growing climate in My Garden.</p>';

    var activeMonths = {};
    items.forEach(function (c) {
      var s = c.month_start, e = c.month_end || c.month_start;
      if (!s) return;
      if (s <= e) {
        for (var m = s; m <= e; m++) activeMonths[m] = (activeMonths[m] || 0) + 1;
      } else {
        for (var m2 = s; m2 <= 12; m2++) activeMonths[m2] = (activeMonths[m2] || 0) + 1;
        for (var m3 = 1; m3 <= e; m3++) activeMonths[m3] = (activeMonths[m3] || 0) + 1;
      }
    });

    var bar = '<div class="gj-cal-bar">';
    for (var i = 1; i <= 12; i++) {
      bar += '<div class="gj-cal-month' + (activeMonths[i] ? ' on' : '') + '">' + monthLabel(i) + '</div>';
    }
    bar += '</div><div class="gj-cal-legend">';
    items.forEach(function (c) {
      var range = monthLabel(c.month_start) + (c.month_end && c.month_end !== c.month_start ? '–' + monthLabel(c.month_end) : '');
      var act = ACTIVITY_LABEL[c.activity] || c.activity;
      bar += '<div class="gj-cal-item"><strong>' + esc(act) + '</strong> · ' + esc(range) +
        (c.notes ? '<br><span style="font-size:12px;color:var(--text-muted)">' + esc(c.notes) + '</span>' : '') + '</div>';
    });
    bar += '</div>';
    return bar;
  }

  function renderKitchenBridge(ingredients) {
    var ings = ingredients || [];
    if (!ings.length) {
      return '<div class="gj-kitchen"><h3>From garden to kitchen</h3>' +
        '<p class="gj-kitchen-note">Kitchen link coming soon — this species will bridge to your governed ingredient library.</p></div>';
    }
    var links = ings.map(function (i) {
      var libSlug = i.library_slug || '';
      var href = libSlug ? 'library-profile.html?type=ingredient&slug=' + encodeURIComponent(libSlug) : '#';
      return '<li>' + (libSlug ? '<a href="' + href + '">' + esc(i.ingredient_name) + '</a>' : esc(i.ingredient_name)) +
        (i.part ? ' <span style="color:var(--text-muted);font-size:12px">(' + esc(i.part) + ')</span>' : '') +
        (i.is_primary ? ' <span class="gj-tag gj-tag-accent" style="font-size:10px;padding:2px 8px">Primary</span>' : '') +
        '</li>';
    }).join('');
    return '<div class="gj-kitchen"><h3>From garden to kitchen</h3>' +
      '<p style="font-family:DM Sans,sans-serif;font-size:14px;color:var(--text-mid);margin:0;line-height:1.6">' +
      'This species links to your governed ingredient library. Recipes, meal plans, and grocery lists use the same names.</p>' +
      '<ul class="gj-kitchen-links">' + links + '</ul>' +
      '<p class="gj-kitchen-note">Each <strong>cultivar</strong> can link to its own governed kitchen ingredient where varieties differ (e.g. cherry vs paste tomato).</p></div>';
  }

  function renderVarietyKitchen(v) {
    if (!v.ingredient_name) return '';
    var href = v.library_slug ? 'library-profile.html?type=ingredient&slug=' + encodeURIComponent(v.library_slug) : '#';
    return v.library_slug
      ? '<a href="' + href + '" style="font-size:12px;color:var(--accent)">Kitchen: ' + esc(v.ingredient_name) + ' →</a>'
      : '<span style="font-size:12px;color:var(--text-muted)">Kitchen: ' + esc(v.ingredient_name) + '</span>';
  }

  function renderVarietiesSection(varieties, opts) {
    opts = opts || {};
    var selected = opts.selectedSlug || '';
    var climateName = opts.climateName || '';
    var list = varieties || [];
    if (!list.length) {
      return '<div class="gj-varieties"><p class="gj-varieties-soon" style="margin:0">No published cultivars for' +
        (climateName ? ' <strong>' + esc(climateName) + '</strong>' : ' this climate') +
        ' yet — more assessments are being imported.</p></div>';
    }
    return '<div class="gj-var-grid">' + list.map(function (v) {
      var active = selected && v.slug === selected ? ' gj-var-card-active' : '';
      var qs = '?slug=' + encodeURIComponent(opts.plantSlug || '') + '&variety=' + encodeURIComponent(v.slug || '');
      return '<a class="gj-var-card' + active + '" href="garden-plant.html' + qs + '" data-variety-slug="' + esc(v.slug) + '">' +
        '<div class="gj-var-name">' + esc(v.name) + '</div>' +
        (v.lineage_label ? '<span class="gj-tag gj-tag-accent" style="font-size:10px;margin-top:6px;display:inline-block">' + esc(v.lineage_label) + '</span>' : '') +
        (v.traits ? '<div class="gj-var-traits">' + esc(v.traits) + '</div>' : '') +
        (v.growing_notes ? '<div class="gj-var-notes">' + esc(v.growing_notes) + '</div>' : '') +
        '<div style="margin-top:8px">' + renderVarietyKitchen(v) + '</div></a>';
    }).join('') + '</div>';
  }

  function renderDirectoryCard(p) {
    var href = 'garden-plant.html?slug=' + encodeURIComponent(p.slug || '');
    var pills = [];
    if (p.ease_rating) pills.push('Ease: ' + esc(p.ease_rating));
    if (p.lifecycle) pills.push(esc(p.lifecycle));
    if (p.harvest_season) pills.push(esc(p.harvest_season));
    if (p.plant_family) pills.push(esc(p.plant_family));
    if (p.variety_count) pills.push(p.variety_count + ' cultivars');
    return '<a class="lib-card lib-card-mise gj-card-rich" href="' + href + '">' +
      '<div class="lib-card-body">' +
      '<div class="lib-card-name">' + esc(p.common_name) + '</div>' +
      (p.botanical_name ? '<div class="lib-card-aka">' + esc(p.botanical_name) + '</div>' : '') +
      '<div class="lib-card-desc">' + esc(p.care_summary || 'Growing profile') + '</div>' +
      (pills.length ? '<div class="gj-card-meta">' + pills.map(function (x) {
        return '<span class="gj-card-pill">' + x + '</span>';
      }).join('') + '</div>' : '') +
      '</div></a>';
  }

  function renderPlantProfile(data, opts) {
    opts = opts || {};
    if (!data || !data.plant) {
      return '<div class="gj-wrap gj-error">Plant not found or not published.</div>';
    }
    var p = data.plant;
    var preferredClimate = opts.climateName || null;
    var selectedVariety = opts.selectedVarietySlug || '';
    var varieties = data.varieties || [];
    var activeVariety = null;
    for (var vi = 0; vi < varieties.length; vi++) {
      if (varieties[vi].slug === selectedVariety) { activeVariety = varieties[vi]; break; }
    }

    var tags = [];
    if (p.lifecycle) tags.push(p.lifecycle);
    if (p.growth_habit) tags.push(p.growth_habit);
    if (p.ease_rating) tags.push('Ease: ' + p.ease_rating);
    if (p.garden_layer) tags.push(p.garden_layer);
    if (p.plant_type) tags.push(p.plant_type);

    var flags = (data.safety_flags || []).map(function (f) {
      return '<span class="gj-flag" title="' + esc(f.message) + '">' + esc(f.flag) + '</span>';
    }).join('');

    var parts = (data.parts || []).map(function (pt) {
      return '<li>' + esc(pt.part) + ' — <em>' + esc(pt.role) + '</em>' +
        (pt.notes ? ' · ' + esc(pt.notes) : '') + '</li>';
    }).join('');

    var companions = (data.companions || []);
    var compHtml = '';
    if (companions.length) {
      var good = companions.filter(function (c) { return c.relationship === 'companion'; });
      var bad = companions.filter(function (c) { return c.relationship === 'incompatible'; });
      if (good.length) {
        compHtml += '<p style="font-size:12px;color:var(--text-muted);margin:0 0 6px">Good companions</p><ul class="gj-list">' +
          good.map(function (c) {
            var link = c.other_slug ? '<a href="garden-plant.html?slug=' + encodeURIComponent(c.other_slug) + '" style="color:var(--accent)">' + esc(c.other_name) + '</a>' : esc(c.other_name);
            return '<li>' + link + (c.reason ? ' — ' + esc(c.reason) : '') + '</li>';
          }).join('') + '</ul>';
      }
      if (bad.length) {
        compHtml += '<p style="font-size:12px;color:var(--text-muted);margin:12px 0 6px">Avoid planting with</p><ul class="gj-list">' +
          bad.map(function (c) {
            return '<li>' + esc(c.other_name) + (c.reason ? ' — ' + esc(c.reason) : '') + '</li>';
          }).join('') + '</ul>';
      }
    }

    var pests = (data.organisms || []).map(function (o) {
      return '<li>' + esc(o.name) +
        (o.scientific_name ? ' <em>(' + esc(o.scientific_name) + ')</em>' : '') +
        ' — ' + esc(o.relationship) + (o.notes ? ' · ' + esc(o.notes) : '') + '</li>';
    }).join('');

    var lessons = (data.lessons || []).map(function (l) {
      return '<div class="gj-side-card"><div class="gj-side-label">' + esc(l.difficulty || 'Lesson') + '</div>' +
        '<div class="gj-side-value" style="font-weight:600;margin-bottom:6px">' + esc(l.title) + '</div>' +
        '<div style="font-size:13px;color:var(--text-mid);line-height:1.6">' + esc(l.body) + '</div></div>';
    }).join('');

    function sideCard(label, val) {
      if (!val) return '';
      return '<div class="gj-side-card"><div class="gj-side-label">' + esc(label) + '</div><div class="gj-side-value">' + esc(val) + '</div></div>';
    }

    var sidebar = [
      sideCard('Family', p.plant_family),
      sideCard('Origin', p.origin),
      sideCard('Size', [p.size_height, p.size_spread].filter(Boolean).join(' · ')),
      sideCard('Pollination', p.pollination_type),
      sideCard('Flowering', p.flowering_season),
      sideCard('Harvest season', p.harvest_season),
      sideCard('Time to harvest', p.time_to_harvest),
      sideCard('Yield', p.yield_per_plant),
      sideCard('Storage', p.storage_methods)
    ].join('');

    var propagation = [p.propagation_methods, p.germination_time, p.planting_windows].filter(Boolean).join(' · ');
    var culinary = [p.edible_parts, p.culinary_applications].filter(Boolean);

    var main =
      (p.care_summary ? '<div class="gj-summary">' + esc(p.care_summary) + '</div>' : '') +
      '<div class="gj-section"><h2>Care for your climate</h2>' +
      '<p class="gj-section-lead">Core, risk, and fix — the same structure as printable care cards.</p>' +
      renderCareCards(data.climate_care, preferredClimate) + '</div>' +
      '<div class="gj-section"><h2>Growing calendar</h2>' + renderCalendar(data.calendar, preferredClimate) + '</div>' +
      '<div class="gj-section"><h2>Varieties for your climate</h2>' +
      (preferredClimate ? '<p class="gj-section-lead">Showing cultivars suited to <strong>' + esc(preferredClimate) + '</strong>. Select a variety to add to My Garden with that cultivar.</p>' : '<p class="gj-section-lead">Choose your growing climate above to filter cultivars.</p>') +
      renderVarietiesSection(varieties, { selectedSlug: selectedVariety, climateName: preferredClimate, plantSlug: p.slug }) +
      (activeVariety ? '<div class="gj-var-detail" style="margin-top:16px;padding:16px;border:1px solid var(--border);border-radius:12px;background:var(--surface)">' +
        '<div style="font-family:Cormorant Garamond,serif;font-size:1.2rem;font-weight:600">' + esc(activeVariety.name) + '</div>' +
        (activeVariety.origin ? '<p style="font-size:13px;color:var(--text-mid);margin:8px 0 0">Origin: ' + esc(activeVariety.origin) + '</p>' : '') +
        (activeVariety.flesh_fruit ? '<p style="font-size:13px;color:var(--text-mid);margin:6px 0 0">' + esc(activeVariety.flesh_fruit) + '</p>' : '') +
        (activeVariety.availability ? '<p style="font-size:12px;color:var(--text-muted);margin:8px 0 0">Where to find: ' + esc(activeVariety.availability) + '</p>' : '') +
        '</div>' : '') + '</div>' +
      (propagation ? '<div class="gj-section"><h2>Propagation</h2><p style="font-family:DM Sans,sans-serif;font-size:14px;color:var(--text-mid);line-height:1.75;margin:0">' + esc(propagation) + '</p></div>' : '') +
      (culinary.length ? '<div class="gj-section"><h2>Edible uses</h2><p style="font-family:DM Sans,sans-serif;font-size:14px;color:var(--text-mid);line-height:1.75;margin:0;white-space:pre-line">' + esc(culinary.join('\n\n')) + '</p></div>' : '') +
      (p.toxic_parts ? '<div class="gj-section"><h2>Safety</h2><p style="font-family:DM Sans,sans-serif;font-size:14px;color:#e8a080;line-height:1.65;margin:0">' + esc(p.toxic_parts) + '</p></div>' : '') +
      (parts ? '<div class="gj-section"><h2>Plant parts</h2><ul class="gj-list">' + parts + '</ul></div>' : '') +
      (compHtml ? '<div class="gj-section"><h2>Companions</h2>' + compHtml + '</div>' : '') +
      (pests ? '<div class="gj-section"><h2>Pests &amp; ecology</h2><ul class="gj-list">' + pests + '</ul></div>' : '') +
      '<div class="gj-section">' + renderKitchenBridge(data.ingredients) + '</div>' +
      (lessons ? '<div class="gj-section"><h2>Learn</h2>' + lessons + '</div>' : '');

    return '<div class="gj-wrap">' +
      '<a class="gj-back" href="garden-directory.html">← Plant Directory</a>' +
      '<div class="gj-hero-plant">' +
      '<h1 class="gj-plant-name">' + esc(p.common_name) + '</h1>' +
      (p.botanical_name ? '<div class="gj-botanical">' + esc(p.botanical_name) + '</div>' : '') +
      (tags.length ? '<div class="gj-tag-row">' + tags.map(function (t) {
        return '<span class="gj-tag">' + esc(t) + '</span>';
      }).join('') + '</div>' : '') +
      (flags ? '<div>' + flags + '</div>' : '') +
      '</div>' +
      '<div class="gj-layout"><div>' + main + '</div><div>' + sidebar +
      '<button type="button" class="gj-btn gj-btn-filled" id="gp-add" data-variety-slug="' + esc(selectedVariety) + '">' +
      (activeVariety ? 'Add ' + esc(activeVariety.name) + ' to My Garden' : 'Add to My Garden') + '</button>' +
      '<a href="my-garden.html" class="gj-btn" style="text-align:center;text-decoration:none;box-sizing:border-box">My Garden</a>' +
      '</div></div></div>';
  }

  function renderTaskCard(task) {
    var emoji = ACTIVITY_EMOJI[task.activity] || '📅';
    var act = ACTIVITY_LABEL[task.activity] || task.activity;
    var range = monthLabel(task.month_start) + (task.month_end && task.month_end !== task.month_start ? '–' + monthLabel(task.month_end) : '');
    var title = task.plant_name + (task.variety_name ? ' · ' + task.variety_name : '');
    return '<div class="gj-task"><div class="gj-task-icon">' + emoji + '</div><div class="gj-task-body">' +
      '<div class="gj-task-title">' + esc(title) + '</div>' +
      '<div class="gj-task-sub"><strong>' + esc(act) + '</strong> · ' + esc(range) +
      (task.bed_label ? ' · ' + esc(task.bed_label) : '') +
      (task.notes ? '<br>' + esc(task.notes) : '') + '</div></div></div>';
  }

  function renderMyPlantCard(p) {
    var href = 'garden-plant.html?slug=' + encodeURIComponent(p.plant_slug || '');
    if (p.variety_slug) href += '&variety=' + encodeURIComponent(p.variety_slug);
    return '<div class="gj-side-card" style="margin-bottom:12px">' +
      '<a href="' + href + '" style="font-family:Cormorant Garamond,serif;font-size:1.2rem;font-weight:600;color:var(--text-high);text-decoration:none">' +
      esc(p.plant_name) + (p.variety_name ? ' · ' + esc(p.variety_name) : '') + '</a>' +
      (p.lineage_label ? '<span class="gj-tag" style="font-size:10px;margin-top:6px;display:inline-block">' + esc(p.lineage_label) + '</span>' : '') +
      '<div style="font-family:DM Sans,sans-serif;font-size:12px;color:var(--text-muted);margin-top:6px">' +
      'Status: ' + esc(p.status) + (p.bed_label ? ' · Bed: ' + esc(p.bed_label) : '') + '</div>' +
      (p.care_summary ? '<div style="font-size:13px;color:var(--text-mid);margin-top:8px;line-height:1.5">' + esc(p.care_summary) + '</div>' : '') +
      '</div>';
  }

  global.GardenUI = {
    esc: esc,
    monthLabel: monthLabel,
    renderDirectoryCard: renderDirectoryCard,
    renderPlantProfile: renderPlantProfile,
    renderTaskCard: renderTaskCard,
    renderMyPlantCard: renderMyPlantCard,
    renderKitchenBridge: renderKitchenBridge,
    uniqueClimates: uniqueClimates
  };
})(window);
