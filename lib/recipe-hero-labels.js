/**
 * Recipe hero ring labels — owner spec (diagram 07f7d99b)
 * Labels live IN the ring SVG (viewBox 0 0 420 420) so textPath always binds.
 * Brand centre-anchored 150° (10 o'clock); username start-anchored 330° (4 o'clock).
 */
(function (global) {
  'use strict';

  var BRAND_TEXT = 'The Culinary Journal';
  var BRAND_CENTER_DEG = 150;
  var HANDLE_START_DEG = 330;
  var BRAND_HALF_SPAN_DEG = 46;
  var HANDLE_ARC_SPAN_DEG = 62;
  var VB = 420;
  var CX = 210;
  var CY = 210;
  var RING_R = 168;
  var STROKE = 3;
  var PADDING_MM = 2;

  function mmPx(mm) { return mm * (96 / 25.4); }
  function deg2rad(d) { return d * Math.PI / 180; }

  function labelRadius() {
    return RING_R - STROKE / 2 - mmPx(PADDING_MM);
  }

  function polar(deg, r) {
    var rad = deg2rad(deg);
    return {
      x: CX + r * Math.cos(rad),
      y: CY - r * Math.sin(rad)
    };
  }

  function arcD(fromDeg, toDeg, r) {
    var a = polar(fromDeg, r);
    var b = polar(toDeg, r);
    var span = Math.abs(fromDeg - toDeg);
    var large = span > 180 ? 1 : 0;
    var sweep = toDeg > fromDeg ? 1 : 0;
    return 'M ' + a.x.toFixed(2) + ' ' + a.y.toFixed(2) +
      ' A ' + r.toFixed(2) + ' ' + r.toFixed(2) + ' 0 ' + large + ' ' + sweep +
      ' ' + b.x.toFixed(2) + ' ' + b.y.toFixed(2);
  }

  function themeAccent() {
    return (getComputedStyle(document.body).getPropertyValue('--accent') || '#C4973B').trim();
  }

  function parseRgb(str) {
    var m = String(str || '').match(/rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/i);
    if (m) return { r: +m[1], g: +m[2], b: +m[3] };
    if (str && str[0] === '#') {
      var h = str.slice(1);
      if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
      return { r: parseInt(h.slice(0, 2), 16), g: parseInt(h.slice(2, 4), 16), b: parseInt(h.slice(4, 6), 16) };
    }
    return { r: 196, g: 151, b: 59 };
  }

  function lum(rgb) {
    function ch(c) {
      c /= 255;
      return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
    }
    return 0.2126 * ch(rgb.r) + 0.7152 * ch(rgb.g) + 0.0722 * ch(rgb.b);
  }

  function contrastRatio(l1, l2) {
    return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
  }

  function sampleLuminance(wrapEl, deg) {
    var img = wrapEl.querySelector('.sr-img-hero-img, .rp-hero-img');
    var circle = wrapEl.querySelector('.sr-img-hero-circle, .rp-hero-circle');
    if (!img || !img.naturalWidth || !circle) return 0.5;
    var r = labelRadius();
    var pt = polar(deg, r);
    var cw = circle.clientWidth;
    var ch = circle.clientHeight;
    var ring = wrapEl.querySelector('.sr-img-hero-ring, .rp-hero-ring');
    var ringRect = ring ? ring.getBoundingClientRect() : null;
    var circleRect = circle.getBoundingClientRect();
    if (!ringRect || !ringRect.width) return 0.5;
    var scale = cw / (RING_R * 2 * (ringRect.width / VB));
    var lx = Math.round((pt.x - CX) * scale + cw / 2);
    var ly = Math.round((pt.y - CY) * scale + ch / 2);
    var c = document.createElement('canvas');
    c.width = Math.max(1, cw);
    c.height = Math.max(1, ch);
    var ctx = c.getContext('2d');
    ctx.save();
    ctx.beginPath();
    ctx.arc(cw / 2, ch / 2, cw / 2, 0, Math.PI * 2);
    ctx.clip();
    if (img.classList.contains('rp-hero-img')) {
      ctx.drawImage(img, 0, 0, cw, ch);
    } else {
      var crop = global._imgCrop || {};
      var zoom = Math.min(3, Math.max(1, crop.zoom || 1));
      var base = Math.max(cw / img.naturalWidth, ch / img.naturalHeight);
      var sc = base * zoom;
      var w = img.naturalWidth * sc;
      var h = img.naturalHeight * sc;
      ctx.drawImage(img, (cw / 2) + (crop.panX || 0) - w / 2, (ch / 2) + (crop.panY || 0) - h / 2, w, h);
    }
    ctx.restore();
    lx = Math.max(0, Math.min(cw - 1, lx));
    ly = Math.max(0, Math.min(ch - 1, ly));
    var d = ctx.getImageData(lx, ly, 1, 1).data;
    return lum({ r: d[0], g: d[1], b: d[2] });
  }

  function pickColor(bgL, themeStr) {
    if (contrastRatio(bgL, lum(parseRgb(themeStr))) >= 3) return themeStr;
    return bgL < 0.5 ? '#f5f0e8' : '#2a1e14';
  }

  function applyLegibility(textEl, fill) {
    var light = lum(parseRgb(fill)) > 0.55;
    textEl.setAttribute('fill', fill);
    textEl.setAttribute('stroke', light ? 'rgba(42,30,20,0.88)' : 'rgba(255,255,255,0.92)');
    textEl.setAttribute('stroke-width', '2');
    textEl.setAttribute('paint-order', 'stroke fill');
  }

  function ringParts(wrapEl) {
    var ring = wrapEl.querySelector('.sr-img-hero-ring, .rp-hero-ring');
    if (!ring) return null;
    var isSubmit = ring.classList.contains('sr-img-hero-ring');
    var pfx = isSubmit ? 'sr-ring' : 'rp-ring';
    return {
      ring: ring,
      brandArc: ring.querySelector('#' + pfx + '-arc-brand'),
      handleArc: ring.querySelector('#' + pfx + '-arc-handle'),
      brandText: ring.querySelector('.rh-ring-brand'),
      handleText: ring.querySelector('.rh-ring-handle')
    };
  }

  function paint(wrapEl, opts) {
    opts = opts || {};
    var parts = ringParts(wrapEl);
    if (!parts || !parts.brandArc || !parts.brandText) return;

    var legacy = wrapEl.querySelector('.rh-label-svg, .rh-label-canvas');
    if (legacy) legacy.remove();

    var r = labelRadius();
    var brandLo = BRAND_CENTER_DEG - BRAND_HALF_SPAN_DEG;
    var brandHi = BRAND_CENTER_DEG + BRAND_HALF_SPAN_DEG;
    var handleLo = HANDLE_START_DEG - HANDLE_ARC_SPAN_DEG;

    parts.brandArc.setAttribute('d', arcD(brandLo, brandHi, r));
    var brandTp = parts.brandText.querySelector('textPath');
    if (brandTp) {
      brandTp.setAttribute('startOffset', '50%');
      brandTp.textContent = opts.brand != null ? opts.brand : BRAND_TEXT;
    }
    applyLegibility(parts.brandText, pickColor(sampleLuminance(wrapEl, BRAND_CENTER_DEG), themeAccent()));

    var handle = opts.handle || '';
    if (handle && parts.handleArc && parts.handleText) {
      parts.handleArc.setAttribute('d', arcD(handleLo, HANDLE_START_DEG, r));
      parts.handleText.style.display = '';
      var handleTp = parts.handleText.querySelector('textPath');
      if (handleTp) {
        handleTp.setAttribute('startOffset', '100%');
        handleTp.textContent = handle;
      }
      applyLegibility(parts.handleText, pickColor(sampleLuminance(wrapEl, HANDLE_START_DEG), themeAccent()));
    } else if (parts.handleText) {
      parts.handleText.style.display = 'none';
    }
  }

  function render(wrapEl, opts) {
    if (!wrapEl) return;
    wrapEl._rhOpts = opts || wrapEl._rhOpts || {};
    var run = function() { paint(wrapEl, wrapEl._rhOpts); };
    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(run);
    } else {
      run();
    }
    if (!wrapEl._rhRO && typeof ResizeObserver !== 'undefined') {
      wrapEl._rhRO = new ResizeObserver(run);
      wrapEl._rhRO.observe(wrapEl);
    }
  }

  global.RecipeHeroLabels = {
    BRAND_TEXT: BRAND_TEXT,
    render: render
  };
})(typeof window !== 'undefined' ? window : global);
