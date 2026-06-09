/**
 * Recipe hero ring captions — circular-caption-reference-v7.html (signed off)
 * Angles: 0° = right, 90° = top, CCW. Brand 140°, username 320° (180° opposite).
 * Both centre-anchored; separate arcs with mirrored sweep. Cinzel 400, cap-height gaps.
 */
(function (global) {
  'use strict';

  var BRAND_TEXT = 'THE CULINARY JOURNAL';
  var BRAND_ANGLE = 140;
  var USER_ANGLE = 320;
  var ARC_HALF = 42;
  var VB = 420;
  var CX = 210;
  var CY = 210;
  var RING_R = 168;
  var STROKE = 3;
  var FONT_SIZE = 15;
  var GAP_BRAND_MM = 4;
  var GAP_USER_MM = 2;
  var MM_TO_PX = 96 / 25.4;
  var VB_SCALE = VB / 400;

  var probe = document.createElement('canvas').getContext('2d');

  function mmGap(mm) { return mm * MM_TO_PX * VB_SCALE; }

  function innerRadius() { return RING_R - STROKE; }

  function toClock(their) {
    return (((90 - their) % 360) + 360) % 360;
  }

  function polarClock(clockDeg, r) {
    var a = (clockDeg * Math.PI) / 180;
    return { x: CX + r * Math.sin(a), y: CY - r * Math.cos(a) };
  }

  function arcPath(startClock, endClock, sweep, r) {
    var p1 = polarClock(startClock, r);
    var p2 = polarClock(endClock, r);
    var large = Math.abs(endClock - startClock) > 180 ? 1 : 0;
    return 'M ' + p1.x.toFixed(2) + ' ' + p1.y.toFixed(2) +
      ' A ' + r.toFixed(2) + ' ' + r.toFixed(2) + ' 0 ' + large + ' ' + sweep +
      ' ' + p2.x.toFixed(2) + ' ' + p2.y.toFixed(2);
  }

  function fontSpec() {
    return '400 ' + FONT_SIZE + 'px Cinzel, serif';
  }

  function capAscent(text) {
    probe.font = fontSpec();
    return probe.measureText(String(text || '').toUpperCase()).actualBoundingBoxAscent || FONT_SIZE * 0.72;
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

  function rgbStr(rgb) {
    return 'rgb(' + Math.round(rgb.r) + ',' + Math.round(rgb.g) + ',' + Math.round(rgb.b) + ')';
  }

  function themeCaptionColors() {
    var style = getComputedStyle(document.body);
    var ring = (style.getPropertyValue('--accent') || '#C4973B').trim();
    var onLight = style.getPropertyValue('--ring-caption-on-light').trim();
    var onDark = style.getPropertyValue('--ring-caption-on-dark').trim();
    if (!onLight || !onDark) {
      var base = parseRgb(ring);
      onLight = rgbStr({
        r: base.r * 0.38,
        g: base.g * 0.38,
        b: base.b * 0.38
      });
      onDark = rgbStr({
        r: Math.min(255, base.r + (255 - base.r) * 0.82),
        g: Math.min(255, base.g + (255 - base.g) * 0.82),
        b: Math.min(255, base.b + (255 - base.b) * 0.82)
      });
    }
    return { ring: ring, onLight: onLight, onDark: onDark };
  }

  function lum(rgb) {
    function ch(c) {
      c /= 255;
      return c <= 0.03928 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
    }
    return 0.2126 * ch(rgb.r) + 0.7152 * ch(rgb.g) + 0.0722 * ch(rgb.b);
  }

  function sampleLuminance(wrapEl, theirAngle, r) {
    var img = wrapEl.querySelector('.sr-img-hero-img, .rp-hero-img');
    var circle = wrapEl.querySelector('.sr-img-hero-circle, .rp-hero-circle');
    if (!img || !img.naturalWidth || !circle) return 0.55;
    var clock = toClock(theirAngle);
    var pt = polarClock(clock, r);
    var cw = circle.clientWidth;
    var ch = circle.clientHeight;
    var ring = wrapEl.querySelector('.sr-img-hero-ring, .rp-hero-ring');
    var ringRect = ring ? ring.getBoundingClientRect() : null;
    if (!ringRect || !ringRect.width) return 0.55;
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

  function escapeXml(s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }

  function setHandleTextPath(tp, handle) {
    var raw = String(handle || '').trim();
    if (!raw) { tp.textContent = ''; return; }
    var body = raw.replace(/^@/, '').toUpperCase();
    if (raw.indexOf('@') === 0) {
      tp.innerHTML = '<tspan class="rh-at">@</tspan>' + escapeXml(body);
    } else {
      tp.textContent = body;
    }
  }

  function applyCaptionStyle(textEl, colour, isDark, filterId) {
    textEl.setAttribute('fill', colour);
    textEl.removeAttribute('stroke');
    textEl.removeAttribute('stroke-width');
    textEl.removeAttribute('stroke-opacity');
    textEl.removeAttribute('paint-order');
    textEl.setAttribute('filter', isDark ? 'url(#' + filterId + ')' : 'none');
    textEl.style.font = fontSpec();
    textEl.style.letterSpacing = '0.5px';
  }

  function ringParts(wrapEl) {
    var ring = wrapEl.querySelector('.sr-img-hero-ring, .rp-hero-ring');
    if (!ring) return null;
    var pfx = ring.classList.contains('sr-img-hero-ring') ? 'sr-ring' : 'rp-ring';
    return {
      ring: ring,
      brandArc: ring.querySelector('#' + pfx + '-arc-brand'),
      handleArc: ring.querySelector('#' + pfx + '-arc-handle'),
      brandText: ring.querySelector('.rh-ring-brand'),
      handleText: ring.querySelector('.rh-ring-handle'),
      haloId: pfx + '-softHalo'
    };
  }

  function paint(wrapEl, opts) {
    opts = opts || {};
    var parts = ringParts(wrapEl);
    if (!parts || !parts.brandArc || !parts.brandText) return;

    var legacy = wrapEl.querySelector('.rh-label-svg, .rh-label-canvas');
    if (legacy) legacy.remove();

    var inner = innerRadius();
    var brandAsc = capAscent(BRAND_TEXT);
    var handleRaw = opts.handle || '';
    var userAsc = handleRaw ? capAscent(handleRaw.replace(/^@/, '')) : FONT_SIZE * 0.72;
    var brandR = inner - mmGap(GAP_BRAND_MM) - brandAsc;
    var userR = inner - mmGap(GAP_USER_MM) - userAsc;

    var bc = toClock(BRAND_ANGLE);
    var us = toClock(USER_ANGLE);

    parts.brandArc.setAttribute('d', arcPath(bc - ARC_HALF, bc + ARC_HALF, 1, brandR));

    var brandTp = parts.brandText.querySelector('textPath');
    if (brandTp) {
      brandTp.setAttribute('startOffset', '50%');
      brandTp.setAttribute('text-anchor', 'middle');
      brandTp.textContent = opts.brand != null ? String(opts.brand).toUpperCase() : BRAND_TEXT;
    }

    var colours = themeCaptionColors();
    var ringStroke = parts.ring.querySelector('.sr-img-hero-ring-stroke, .rp-hero-ring-stroke');
    if (ringStroke) ringStroke.setAttribute('stroke', colours.ring);

    var brandDark = sampleLuminance(wrapEl, BRAND_ANGLE, brandR) < 0.45;
    applyCaptionStyle(parts.brandText, brandDark ? colours.onDark : colours.onLight, brandDark, parts.haloId);

    if (handleRaw && parts.handleArc && parts.handleText) {
      parts.handleArc.setAttribute('d', arcPath(us + ARC_HALF, us - ARC_HALF, 0, userR));
      parts.handleText.style.display = '';
      var handleTp = parts.handleText.querySelector('textPath');
      if (handleTp) {
        handleTp.setAttribute('startOffset', '50%');
        handleTp.setAttribute('text-anchor', 'middle');
        setHandleTextPath(handleTp, handleRaw);
      }
      var userDark = sampleLuminance(wrapEl, USER_ANGLE, userR) < 0.45;
      applyCaptionStyle(parts.handleText, userDark ? colours.onDark : colours.onLight, userDark, parts.haloId);
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
    BRAND_ANGLE: BRAND_ANGLE,
    USER_ANGLE: USER_ANGLE,
    render: render
  };
})(typeof window !== 'undefined' ? window : global);
