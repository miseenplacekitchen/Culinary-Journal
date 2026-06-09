/**
 * Recipe hero ring labels — owner spec (diagram 07f7d99b)
 * • One shared concentric arc: same centre as frame, radius = frame − padding.
 * • Brand centre-anchored at 10 o'clock (150°).
 * • Username start-anchored at 4 o'clock (330°), 180° opposite; grows along arc.
 * • SVG textPath on measured circular arcs (no per-glyph canvas rotation).
 */
(function (global) {
  'use strict';

  var NS = 'http://www.w3.org/2000/svg';
  var XLINK = 'http://www.w3.org/1999/xlink';
  var BRAND_TEXT = 'The Culinary Journal';
  var BRAND_CENTER_DEG = 150;
  var HANDLE_START_DEG = 330;
  var BRAND_HALF_SPAN_DEG = 46;
  var HANDLE_ARC_SPAN_DEG = 62;
  var PADDING_MM = 2;
  var RING_VB = 420;
  var RING_R = 168;
  var uid = 0;

  function mmPx(mm) { return mm * (96 / 25.4); }
  function deg2rad(d) { return d * Math.PI / 180; }

  /** Geometry from ring SVG viewBox — single source of truth with the frame. */
  function getGeometry(wrapEl) {
    var wrapRect = wrapEl.getBoundingClientRect();
    if (!wrapRect.width || !wrapRect.height) return null;
    var ringSvg = wrapEl.querySelector('.sr-img-hero-ring, .rp-hero-ring');
    var stroke = 3;
    if (ringSvg) {
      var circle = ringSvg.querySelector('circle');
      if (circle) stroke = parseFloat(circle.getAttribute('stroke-width')) || 3;
    }
    var half = Math.min(wrapRect.width, wrapRect.height) / 2;
    var frameR = half * (RING_R / (RING_VB / 2));
    return {
      cx: wrapRect.width / 2,
      cy: wrapRect.height / 2,
      r: frameR - stroke / 2 - mmPx(PADDING_MM),
      w: wrapRect.width,
      h: wrapRect.height
    };
  }

  function polar(g, deg) {
    var rad = deg2rad(deg);
    return {
      x: g.cx + g.r * Math.cos(rad),
      y: g.cy - g.r * Math.sin(rad)
    };
  }

  function arcPath(g, fromDeg, toDeg) {
    var a = polar(g, fromDeg);
    var b = polar(g, toDeg);
    var span = Math.abs(fromDeg - toDeg);
    var large = span > 180 ? 1 : 0;
    var sweep = toDeg < fromDeg ? 0 : 1;
    return 'M ' + a.x.toFixed(2) + ' ' + a.y.toFixed(2) +
      ' A ' + g.r.toFixed(2) + ' ' + g.r.toFixed(2) + ' 0 ' + large + ' ' + sweep +
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
    var hi = Math.max(l1, l2) + 0.05;
    var lo = Math.min(l1, l2) + 0.05;
    return hi / lo;
  }

  function sampleLuminance(wrapEl, g, deg) {
    var img = wrapEl.querySelector('.sr-img-hero-img, .rp-hero-img');
    var circle = wrapEl.querySelector('.sr-img-hero-circle, .rp-hero-circle');
    if (!img || !img.naturalWidth || !circle) return 0.5;
    var pt = polar(g, deg);
    var cw = circle.clientWidth;
    var ch = circle.clientHeight;
    var cRect = circle.getBoundingClientRect();
    var wRect = wrapEl.getBoundingClientRect();
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
    var lx = Math.round(pt.x - (cRect.left - wRect.left));
    var ly = Math.round(pt.y - (cRect.top - wRect.top));
    lx = Math.max(0, Math.min(cw - 1, lx));
    ly = Math.max(0, Math.min(ch - 1, ly));
    var d = ctx.getImageData(lx, ly, 1, 1).data;
    return lum({ r: d[0], g: d[1], b: d[2] });
  }

  /** Theme colour by default; contrast override only when illegible. */
  function pickColor(bgL, themeStr) {
    var themeL = lum(parseRgb(themeStr));
    if (contrastRatio(bgL, themeL) >= 3) return themeStr;
    return bgL < 0.45 ? '#f5f0e8' : '#2a1e14';
  }

  function ensureSvg(wrapEl, g) {
    if (!wrapEl._rhUid) wrapEl._rhUid = 'rh' + (++uid);
    var id = wrapEl._rhUid;
    var svg = wrapEl.querySelector('.rh-label-svg');
    if (!svg) {
      svg = document.createElementNS(NS, 'svg');
      svg.setAttribute('class', 'rh-label-svg');
      svg.setAttribute('aria-hidden', 'true');
      var defs = document.createElementNS(NS, 'defs');
      var brandP = document.createElementNS(NS, 'path');
      brandP.setAttribute('id', id + '-arc-brand');
      var handleP = document.createElementNS(NS, 'path');
      handleP.setAttribute('id', id + '-arc-handle');
      defs.appendChild(brandP);
      defs.appendChild(handleP);
      svg.appendChild(defs);

      var brandT = document.createElementNS(NS, 'text');
      brandT.setAttribute('class', 'rh-ring-text');
      brandT.setAttribute('text-anchor', 'middle');
      var brandTp = document.createElementNS(NS, 'textPath');
      brandTp.setAttribute('href', '#' + id + '-arc-brand');
      brandTp.setAttributeNS(XLINK, 'href', '#' + id + '-arc-brand');
      brandTp.setAttribute('startOffset', '50%');
      brandT.appendChild(brandTp);
      svg.appendChild(brandT);

      var handleT = document.createElementNS(NS, 'text');
      handleT.setAttribute('class', 'rh-ring-text rh-ring-handle');
      handleT.setAttribute('text-anchor', 'start');
      handleT.style.display = 'none';
      var handleTp = document.createElementNS(NS, 'textPath');
      handleTp.setAttribute('href', '#' + id + '-arc-handle');
      handleTp.setAttributeNS(XLINK, 'href', '#' + id + '-arc-handle');
      handleTp.setAttribute('startOffset', '0%');
      handleT.appendChild(handleTp);
      svg.appendChild(handleT);
      wrapEl.appendChild(svg);
    }
    svg.setAttribute('viewBox', '0 0 ' + g.w + ' ' + g.h);
    svg.style.setProperty('--rh-font', Math.max(15, Math.round(g.w * 0.042)) + 'px');
    svg._rhId = id;
    return svg;
  }

  function paint(wrapEl, opts) {
    opts = opts || {};
    var g = getGeometry(wrapEl);
    if (!g || g.r <= 0) return;

    var oldCanvas = wrapEl.querySelector('.rh-label-canvas');
    if (oldCanvas) oldCanvas.remove();

    var brandFrom = BRAND_CENTER_DEG + BRAND_HALF_SPAN_DEG;
    var brandTo = BRAND_CENTER_DEG - BRAND_HALF_SPAN_DEG;
    var handleTo = HANDLE_START_DEG - HANDLE_ARC_SPAN_DEG;

    var svg = ensureSvg(wrapEl, g);
    var id = svg._rhId;
    svg.querySelector('#' + id + '-arc-brand').setAttribute('d', arcPath(g, brandFrom, brandTo));
    svg.querySelector('#' + id + '-arc-handle').setAttribute('d', arcPath(g, HANDLE_START_DEG, handleTo));

    var theme = themeAccent();
    var brandT = svg.querySelector('.rh-ring-text:not(.rh-ring-handle)');
    var brandTp = brandT.querySelector('textPath');
    brandTp.textContent = opts.brand != null ? opts.brand : BRAND_TEXT;
    brandT.setAttribute('fill', pickColor(sampleLuminance(wrapEl, g, BRAND_CENTER_DEG), theme));

    var handleT = svg.querySelector('.rh-ring-handle');
    var handle = opts.handle || '';
    if (handle) {
      handleT.style.display = '';
      handleT.querySelector('textPath').textContent = handle;
      handleT.setAttribute('fill', pickColor(sampleLuminance(wrapEl, g, HANDLE_START_DEG), theme));
    } else {
      handleT.style.display = 'none';
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
    BRAND_CENTER_DEG: BRAND_CENTER_DEG,
    HANDLE_START_DEG: HANDLE_START_DEG,
    render: render,
    _debugGeometry: getGeometry
  };
})(typeof window !== 'undefined' ? window : global);
