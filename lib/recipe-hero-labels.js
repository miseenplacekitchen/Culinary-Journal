/**
 * Recipe hero ring labels — owner spec
 * ─────────────────────────────────────
 * • One shared concentric circle (same centre as photo frame, radius − padding).
 * • Brand centre-anchored at 10 o'clock (150°), fixed, never moves.
 * • Username start-anchored at 4 o'clock (330°), 180° opposite; grows along arc.
 * • Theme accent colour by default; contrast override when illegible + halo always.
 */
(function (global) {
  'use strict';

  var BRAND_TEXT = 'The Culinary Journal';
  var FONT_FAMILY = '"Cormorant Garamond", Georgia, "Times New Roman", serif';
  var BRAND_CENTER_DEG = 150;
  var HANDLE_START_DEG = 330;
  var PADDING_MM = 2;

  function mmPx(mm) { return mm * (96 / 25.4); }
  function deg2rad(d) { return d * Math.PI / 180; }

  function getGeometry(wrapEl) {
    var wrapRect = wrapEl.getBoundingClientRect();
    var circle = wrapEl.querySelector('.sr-img-hero-circle, .rp-hero-circle');
    if (!wrapRect.width || !circle) return null;
    var circleRect = circle.getBoundingClientRect();
    var border = parseFloat(getComputedStyle(circle).borderTopWidth) || 3;
    var photoR = circleRect.width / 2;
    return {
      cx: (circleRect.left - wrapRect.left) + circleRect.width / 2,
      cy: (circleRect.top - wrapRect.top) + circleRect.height / 2,
      labelR: photoR - border - mmPx(PADDING_MM),
      circleW: circleRect.width,
      circleH: circleRect.height,
      circleLeft: circleRect.left - wrapRect.left,
      circleTop: circleRect.top - wrapRect.top,
      w: wrapRect.width,
      h: wrapRect.height
    };
  }

  function themeAccent() {
    var v = getComputedStyle(document.body).getPropertyValue('--accent').trim();
    return v || '#C4973B';
  }

  function parseRgb(str) {
    if (!str) return { r: 196, g: 151, b: 59 };
    str = str.trim();
    var m = str.match(/rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/i);
    if (m) return { r: +m[1], g: +m[2], b: +m[3] };
    if (str[0] === '#') {
      var h = str.slice(1);
      if (h.length === 3) h = h[0] + h[0] + h[1] + h[1] + h[2] + h[2];
      return { r: parseInt(h.slice(0, 2), 16), g: parseInt(h.slice(2, 4), 16), b: parseInt(h.slice(4, 6), 16) };
    }
    return { r: 196, g: 151, b: 59 };
  }

  function luminance(rgb) {
    var r = rgb.r / 255, g = rgb.g / 255, b = rgb.b / 255;
    r = r <= 0.03928 ? r / 12.92 : Math.pow((r + 0.055) / 1.055, 2.4);
    g = g <= 0.03928 ? g / 12.92 : Math.pow((g + 0.055) / 1.055, 2.4);
    b = b <= 0.03928 ? b / 12.92 : Math.pow((b + 0.055) / 1.055, 2.4);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  function contrastRatio(l1, l2) {
    var a = Math.max(l1, l2) + 0.05;
    var b = Math.min(l1, l2) + 0.05;
    return a / b;
  }

  function pickFillColor(bgRgb, themeStr) {
    var theme = parseRgb(themeStr);
    var bgL = luminance(bgRgb);
    var themeL = luminance(theme);
    if (contrastRatio(bgL, themeL) >= 3) return themeStr;
    return bgL < 0.45 ? '#f5f0e8' : '#2a1e14';
  }

  function buildPhotoSample(wrapEl, geom) {
    var img = wrapEl.querySelector('.sr-img-hero-img, .rp-hero-img');
    var circle = wrapEl.querySelector('.sr-img-hero-circle, .rp-hero-circle');
    if (!img || !img.naturalWidth || !circle) return null;
    if (img.style.display === 'none' && !img.complete) return null;

    var cw = geom.circleW;
    var ch = geom.circleH;
    var canvas = document.createElement('canvas');
    canvas.width = Math.max(1, Math.round(cw));
    canvas.height = Math.max(1, Math.round(ch));
    var ctx = canvas.getContext('2d');
    ctx.save();
    ctx.beginPath();
    ctx.arc(cw / 2, ch / 2, cw / 2, 0, Math.PI * 2);
    ctx.clip();

    if (img.classList.contains('rp-hero-img')) {
      ctx.drawImage(img, 0, 0, cw, ch);
    } else {
      var crop = global._imgCrop || { panX: 0, panY: 0, zoom: 1 };
      var zoom = Math.min(3, Math.max(1, crop.zoom || 1));
      var base = Math.max(cw / img.naturalWidth, ch / img.naturalHeight);
      var scale = base * zoom;
      var w = img.naturalWidth * scale;
      var h = img.naturalHeight * scale;
      ctx.drawImage(img, (cw / 2) + (crop.panX || 0) - w / 2, (ch / 2) + (crop.panY || 0) - h / 2, w, h);
    }
    ctx.restore();
    return { canvas: canvas, ox: geom.circleLeft, oy: geom.circleTop };
  }

  function sampleBg(sample, x, y) {
    if (!sample) return { r: 255, g: 255, b: 255 };
    var lx = Math.round(x - sample.ox);
    var ly = Math.round(y - sample.oy);
    var ctx = sample.canvas.getContext('2d');
    if (lx < 0 || ly < 0 || lx >= sample.canvas.width || ly >= sample.canvas.height) {
      return { r: 255, g: 255, b: 255 };
    }
    var d = ctx.getImageData(lx, ly, 1, 1).data;
    return { r: d[0], g: d[1], b: d[2] };
  }

  function ensureCanvas(wrapEl) {
    var canvas = wrapEl.querySelector('.rh-label-canvas');
    if (!canvas) {
      canvas = document.createElement('canvas');
      canvas.className = 'rh-label-canvas';
      canvas.setAttribute('aria-hidden', 'true');
      wrapEl.appendChild(canvas);
    }
    return canvas;
  }

  function charWidths(ctx, text, fontPx) {
    ctx.font = 'italic 400 ' + fontPx + 'px ' + FONT_FAMILY;
    return String(text || '').split('').map(function(ch) {
      return Math.max(ctx.measureText(ch === ' ' ? ' ' : ch).width, fontPx * 0.38);
    });
  }

  function pointOnArc(geom, angleDeg) {
    var rad = deg2rad(angleDeg);
    return {
      x: geom.cx + geom.labelR * Math.cos(rad),
      y: geom.cy - geom.labelR * Math.sin(rad),
      rot: (angleDeg + 90) * Math.PI / 180
    };
  }

  function drawGlyph(ctx, ch, pt, fontPx, fill) {
    ctx.save();
    ctx.translate(pt.x, pt.y);
    ctx.rotate(pt.rot);
    ctx.font = 'italic 400 ' + fontPx + 'px ' + FONT_FAMILY;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    var t = ch === ' ' ? '\u00a0' : ch;
    ctx.lineWidth = 2.5;
    ctx.lineJoin = 'round';
    ctx.strokeStyle = 'rgba(255,255,255,0.9)';
    ctx.shadowColor = 'rgba(255,255,255,0.85)';
    ctx.shadowBlur = 4;
    ctx.strokeText(t, 0, 0);
    ctx.shadowBlur = 0;
    ctx.fillStyle = fill;
    ctx.fillText(t, 0, 0);
    ctx.restore();
  }

  /** Centre-anchored: brand fixed at BRAND_CENTER_DEG */
  function drawCenterAnchored(ctx, text, geom, centerDeg, fontPx, sample, themeStr) {
    var chars = String(text || '').split('');
    if (!chars.length || geom.labelR <= 0) return;
    var widths = charWidths(ctx, chars.join(''), fontPx);
    var total = 0;
    widths.forEach(function(w) { total += w; });
    var halfDeg = (total / 2 / geom.labelR) * (180 / Math.PI);
    var traveled = 0;
    chars.forEach(function(ch, i) {
      traveled += widths[i] / 2;
      var angleDeg = centerDeg + halfDeg - (traveled / geom.labelR) * (180 / Math.PI);
      var pt = pointOnArc(geom, angleDeg);
      var bg = sampleBg(sample, pt.x, pt.y);
      drawGlyph(ctx, ch, pt, fontPx, pickFillColor(bg, themeStr));
      traveled += widths[i] / 2;
    });
  }

  /** Start-anchored: username fixed at HANDLE_START_DEG, grows CCW along arc */
  function drawStartAnchored(ctx, text, geom, startDeg, fontPx, sample, themeStr) {
    var chars = String(text || '').split('');
    if (!chars.length || geom.labelR <= 0) return;
    var widths = charWidths(ctx, chars.join(''), fontPx);
    var traveled = 0;
    chars.forEach(function(ch, i) {
      traveled += widths[i] / 2;
      var angleDeg = startDeg - (traveled / geom.labelR) * (180 / Math.PI);
      var pt = pointOnArc(geom, angleDeg);
      var bg = sampleBg(sample, pt.x, pt.y);
      drawGlyph(ctx, ch, pt, fontPx, pickFillColor(bg, themeStr));
      traveled += widths[i] / 2;
    });
  }

  function paint(wrapEl, opts) {
    opts = opts || {};
    var geom = getGeometry(wrapEl);
    if (!geom || geom.labelR <= 0) return;

    var canvas = ensureCanvas(wrapEl);
    var dpr = window.devicePixelRatio || 1;
    canvas.width = Math.round(geom.w * dpr);
    canvas.height = Math.round(geom.h * dpr);
    canvas.style.width = geom.w + 'px';
    canvas.style.height = geom.h + 'px';

    var ctx = canvas.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, geom.w, geom.h);

    var fontPx = Math.max(15, Math.round(geom.w * 0.04));
    var sample = buildPhotoSample(wrapEl, geom);
    var themeStr = themeAccent();

    drawCenterAnchored(
      ctx,
      opts.brand != null ? opts.brand : BRAND_TEXT,
      geom,
      BRAND_CENTER_DEG,
      fontPx,
      sample,
      themeStr
    );
    if (opts.handle) {
      drawStartAnchored(ctx, opts.handle, geom, HANDLE_START_DEG, fontPx, sample, themeStr);
    }
  }

  function render(wrapEl, opts) {
    if (!wrapEl) return;
    wrapEl._rhOpts = opts || wrapEl._rhOpts || {};
    var run = function() { paint(wrapEl, wrapEl._rhOpts); };
    if (document.fonts && document.fonts.load) {
      document.fonts.load('italic 400 15px ' + FONT_FAMILY).then(run).catch(run);
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
    render: render
  };
})(typeof window !== 'undefined' ? window : global);
