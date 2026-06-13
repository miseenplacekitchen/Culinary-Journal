// garden-export.js — Garden admin/public export helpers (CSV cultivars, care-card JSON)
(function (global) {
  function escCsv(val) {
    var s = String(val == null ? '' : val);
    if (/[",\n\r]/.test(s)) return '"' + s.replace(/"/g, '""') + '"';
    return s;
  }

  function downloadBlob(filename, mime, text) {
    var blob = new Blob([text], { type: mime });
    var a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = filename;
    a.click();
    setTimeout(function () { URL.revokeObjectURL(a.href); }, 4000);
  }

  function cultivarsToCsv(varieties, plantMap) {
    var head = ['species', 'species_slug', 'cultivar_name', 'cultivar_slug', 'lineage', 'climate_slug', 'origin', 'traits', 'published'];
    var rows = (varieties || []).map(function (v) {
      var sp = plantMap[v.plant_id] || {};
      return [
        sp.common_name || '',
        sp.slug || '',
        v.name || '',
        v.slug || '',
        v.lineage_type || '',
        '',
        v.origin || '',
        v.traits || '',
        v.is_published ? 'yes' : 'no'
      ].map(escCsv).join(',');
    });
    return head.join(',') + '\n' + rows.join('\n');
  }

  function careCardPayload(detail, core, climateSlug) {
    var p = detail.plant || {};
    var climate = (core.climates || []).find(function (c) { return c.slug === climateSlug; })
      || (core.climates || [])[0];
    var care = (detail.care || []).filter(function (c) {
      return !climate || c.climate_zone_id === climate.id;
    });
    var calendar = (detail.calendar || []).filter(function (c) {
      return !climate || c.climate_zone_id === climate.id;
    });
    return {
      format: 'tcj-care-card-v1',
      species: p.common_name,
      botanical: p.botanical_name,
      climate: climate ? climate.name : null,
      care_summary: p.care_summary,
      care_fields: care.map(function (c) {
        return { field: c.field_key, core: c.core, risk: c.risk, fix: c.fix };
      }),
      calendar: calendar.map(function (c) {
        return {
          activity: c.activity,
          month_start: c.month_start,
          month_end: c.month_end,
          notes: c.notes
        };
      }),
      ppt_note: 'Map to Artichoke care-card template when PPT export ships.'
    };
  }

  global.GardenExport = {
    downloadBlob: downloadBlob,
    cultivarsToCsv: cultivarsToCsv,
    careCardPayload: careCardPayload,
    exportCultivarsCsv: function (varieties, plants) {
      var map = {};
      (plants || []).forEach(function (p) { map[p.id] = p; });
      downloadBlob('tcj-cultivars-' + new Date().toISOString().slice(0, 10) + '.csv', 'text/csv;charset=utf-8', cultivarsToCsv(varieties, map));
    },
    exportCareCardJson: function (detail, core, climateSlug, slug) {
      var payload = careCardPayload(detail, core, climateSlug);
      downloadBlob('tcj-care-card-' + (slug || 'species') + '.json', 'application/json', JSON.stringify(payload, null, 2));
    }
  };
})(window);
