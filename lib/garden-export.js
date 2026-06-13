// garden-export.js — Garden admin/public export helpers (CSV cultivars, care-card JSON/PPT)
(function (global) {
  var MONTHS = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

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
      species_slug: p.slug,
      botanical: p.botanical_name,
      climate: climate ? climate.name : null,
      climate_slug: climate ? climate.slug : null,
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
      })
    };
  }

  function monthRange(start, end) {
    if (!start) return '—';
    var a = MONTHS[start] || String(start);
    var b = end && end !== start ? ('–' + (MONTHS[end] || end)) : '';
    return a + b;
  }

  function careFieldLabel(key) {
    return String(key || '').replace(/_/g, ' ').replace(/\b\w/g, function (c) { return c.toUpperCase(); });
  }

  function exportCareCardPptx(payload, slug) {
    if (typeof global.PptxGenJS === 'undefined') {
      throw new Error('PptxGenJS not loaded — hard-refresh admin dashboard.');
    }
    var pptx = new global.PptxGenJS();
    pptx.author = 'The Culinary Journal';
    pptx.title = (payload.species || 'Plant') + ' care card';
    pptx.layout = 'LAYOUT_WIDE';

    var titleSlide = pptx.addSlide();
    titleSlide.addText(payload.species || 'Plant profile', {
      x: 0.5, y: 0.6, w: 12, h: 0.8,
      fontSize: 28, bold: true, color: '2D5016'
    });
    if (payload.botanical) {
      titleSlide.addText(payload.botanical, { x: 0.5, y: 1.4, w: 12, h: 0.4, fontSize: 14, italic: true, color: '555555' });
    }
    if (payload.climate) {
      titleSlide.addText('Climate: ' + payload.climate, { x: 0.5, y: 1.9, w: 12, h: 0.35, fontSize: 12, color: '666666' });
    }
    if (payload.care_summary) {
      titleSlide.addText(payload.care_summary, {
        x: 0.5, y: 2.5, w: 12, h: 2.5, fontSize: 11, valign: 'top', color: '333333'
      });
    }

    var fields = payload.care_fields || [];
    var chunk = 4;
    for (var i = 0; i < fields.length; i += chunk) {
      var slide = pptx.addSlide();
      slide.addText('Care — ' + payload.species, { x: 0.5, y: 0.3, w: 12, h: 0.5, fontSize: 16, bold: true, color: '2D5016' });
      var y = 0.95;
      for (var j = i; j < Math.min(i + chunk, fields.length); j++) {
        var f = fields[j];
        var body = 'Core: ' + (f.core || '—');
        if (f.risk) body += '\nRisk: ' + f.risk;
        if (f.fix) body += '\nFix: ' + f.fix;
        slide.addText(careFieldLabel(f.field), { x: 0.5, y: y, w: 12, h: 0.3, fontSize: 12, bold: true, color: '1a1a1a' });
        slide.addText(body, { x: 0.5, y: y + 0.32, w: 12, h: 1.05, fontSize: 10, valign: 'top', color: '444444' });
        y += 1.45;
      }
    }

    var cal = payload.calendar || [];
    if (cal.length) {
      var calSlide = pptx.addSlide();
      calSlide.addText('Growing calendar', { x: 0.5, y: 0.3, w: 12, h: 0.5, fontSize: 16, bold: true, color: '2D5016' });
      var rows = [['Activity', 'Months', 'Notes']];
      cal.forEach(function (c) {
        rows.push([
          c.activity || '',
          monthRange(c.month_start, c.month_end),
          (c.notes || '').slice(0, 120)
        ]);
      });
      calSlide.addTable(rows, {
        x: 0.5, y: 1.0, w: 12,
        fontSize: 10,
        border: { pt: 0.5, color: 'CCCCCC' },
        fill: { color: 'F8F8F8' }
      });
    }

    var fname = 'tcj-care-card-' + (slug || payload.species_slug || 'species') + '.pptx';
    return pptx.writeFile({ fileName: fname });
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
    },
    exportCareCardPptx: function (detail, core, climateSlug, slug) {
      var payload = careCardPayload(detail, core, climateSlug);
      return exportCareCardPptx(payload, slug);
    }
  };
})(window);
