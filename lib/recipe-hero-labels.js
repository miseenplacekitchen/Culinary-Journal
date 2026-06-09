/**
 * Recipe hero ring captions — circular-caption-reference-v7.html (signed off)
 * Angles: 0° = right, 90° = top, CCW. Brand 130°, username 310° (180° opposite).
 * Both centre-anchored; separate arcs with mirrored sweep. Cinzel 400, cap-height gaps.
 */
(function (global) {
  'use strict';

  var BRAND_TEXT = 'THE CULINARY JOURNAL';
  var BRAND_ANGLE = 130;
  var USER_ANGLE = 310;
  var ARC_HALF = 42;
  var VB = 420;
  var CX = 210;
  var CY = 210;
  var RING_R = 168;
  var STROKE = 3;
  var FONT_SIZE = 13;
  var GAP_BRAND_MM = 2;
  var GAP_USER_MM = 0.5;
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
    return null;
  }

  function rgbStr(rgb) {
    return 'rgb(' + Math.round(rgb.r) + ',' + Math.round(rgb.g) + ',' + Math.round(rgb.b) + ')';
  }

  var _cssColorNode = null;

  function resolveCssColor(value) {
    if (!value) return null;
    try {
      probe.fillStyle = '#000000';
      probe.fillStyle = value;
      var viaCanvas = probe.fillStyle;
      if (viaCanvas && viaCanvas.indexOf('rgb') === 0) return viaCanvas;
    } catch (_) {}
    var parsed = parseRgb(value);
    return parsed ? rgbStr(parsed) : null;
  }

  function readThemeCssColor(varName, fallback) {
    if (!_cssColorNode && document.body) {
      _cssColorNode = document.createElement('span');
      _cssColorNode.style.display = 'none';
      document.body.appendChild(_cssColorNode);
    }
    if (!_cssColorNode) return resolveCssColor(fallback);
    _cssColorNode.style.color = 'var(' + varName + ', ' + fallback + ')';
    return resolveCssColor(getComputedStyle(_cssColorNode).color);
  }

  function deriveCaptionColours(accentRgb) {
    return {
      onLight: rgbStr({
        r: accentRgb.r * 0.30,
        g: accentRgb.g * 0.30,
        b: accentRgb.b * 0.30
      }),
      onDark: rgbStr({
        r: Math.min(255, accentRgb.r + (255 - accentRgb.r) * 0.88),
        g: Math.min(255, accentRgb.g + (255 - accentRgb.g) * 0.88),
        b: Math.min(255, accentRgb.b + (255 - accentRgb.b) * 0.88)
      })
    };
  }

  function themeCaptionColors() {
    var ring = readThemeCssColor('--accent', '#C4973B') || 'rgb(196,151,59)';
    var onLight = readThemeCssColor('--ring-caption-on-light');
    var onDark = readThemeCssColor('--ring-caption-on-dark');
    if (!onLight || !onDark) {
      var accentRgb = parseRgb(ring);
      if (!accentRgb) accentRgb = { r: 196, g: 151, b: 59 };
      var derived = deriveCaptionColours(accentRgb);
      onLight = derived.onLight;
      onDark = derived.onDark;
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

  function contrastRatio(fgLum, bgLum) {
    var hi = Math.max(fgLum, bgLum) + 0.05;
    var lo = Math.min(fgLum, bgLum) + 0.05;
    return hi / lo;
  }

  var ARC_SAMPLE_STOPS = [-ARC_HALF, -ARC_HALF * 0.66, -ARC_HALF * 0.33, 0, ARC_HALF * 0.33, ARC_HALF * 0.66, ARC_HALF];

  function buildHeroSampleCanvas(wrapEl) {
    var img = wrapEl.querySelector('.sr-img-hero-img, .rp-hero-img');
    var circle = wrapEl.querySelector('.sr-img-hero-circle, .rp-hero-circle');
    if (!img || !img.naturalWidth || !circle) return null;
    var cw = circle.clientWidth;
    var ch = circle.clientHeight;
    if (!cw || !ch) return null;
    var ring = wrapEl.querySelector('.sr-img-hero-ring, .rp-hero-ring');
    var ringRect = ring ? ring.getBoundingClientRect() : null;
    if (!ringRect || !ringRect.width) return null;
    var scale = cw / (RING_R * 2 * (ringRect.width / VB));
    var canvas = document.createElement('canvas');
    canvas.width = Math.max(1, cw);
    canvas.height = Math.max(1, ch);
    var ctx = canvas.getContext('2d');
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
    return { ctx: ctx, cw: cw, ch: ch, scale: scale };
  }

  function readLuminanceAt(canvasInfo, clockDeg, r) {
    var pt = polarClock(clockDeg, r);
    var lx = Math.max(0, Math.min(canvasInfo.cw - 1, Math.round((pt.x - CX) * canvasInfo.scale + canvasInfo.cw / 2)));
    var ly = Math.max(0, Math.min(canvasInfo.ch - 1, Math.round((pt.y - CY) * canvasInfo.scale + canvasInfo.ch / 2)));
    var d = canvasInfo.ctx.getImageData(lx, ly, 1, 1).data;
    return lum({ r: d[0], g: d[1], b: d[2] });
  }

  function sampleArcLuminance(canvasInfo, theirAngle, r) {
    if (!canvasInfo) return { median: 0.55, max: 0.55 };
    var clockCenter = toClock(theirAngle);
    var samples = [];
    for (var i = 0; i < ARC_SAMPLE_STOPS.length; i++) {
      samples.push(readLuminanceAt(canvasInfo, clockCenter + ARC_SAMPLE_STOPS[i], r));
    }
    samples.sort(function (a, b) { return a - b; });
    return {
      median: samples[Math.floor(samples.length / 2)],
      max: samples[samples.length - 1]
    };
  }

  function pickCaptionColour(colours, canvasInfo, theirAngle, r) {
    var onLightRgb = parseRgb(colours.onLight);
    var onDarkRgb = parseRgb(colours.onDark);
    if (!onLightRgb || !onDarkRgb) return colours.onLight;
    if (!canvasInfo) return colours.onLight;

    var onLightLum = lum(onLightRgb);
    var onDarkLum = lum(onDarkRgb);
    var clockCenter = toClock(theirAngle);
    var minDark = Infinity;
    var minLight = Infinity;

    for (var i = 0; i < ARC_SAMPLE_STOPS.length; i++) {
      var bgLum = readLuminanceAt(canvasInfo, clockCenter + ARC_SAMPLE_STOPS[i], r);
      minDark = Math.min(minDark, contrastRatio(onLightLum, bgLum));
      minLight = Math.min(minLight, contrastRatio(onDarkLum, bgLum));
    }

    return minLight > minDark ? colours.onDark : colours.onLight;
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

  function applyCaptionStyle(textEl, colour) {
    textEl.setAttribute('fill', colour);
    textEl.removeAttribute('stroke');
    textEl.removeAttribute('stroke-width');
    textEl.removeAttribute('stroke-opacity');
    textEl.removeAttribute('paint-order');
    textEl.setAttribute('filter', 'none');
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
      handleText: ring.querySelector('.rh-ring-handle')
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

    var sampleCanvas = buildHeroSampleCanvas(wrapEl);
    applyCaptionStyle(
      parts.brandText,
      pickCaptionColour(colours, sampleCanvas, BRAND_ANGLE, brandR)
    );

    if (handleRaw && parts.handleArc && parts.handleText) {
      parts.handleArc.setAttribute('d', arcPath(us + ARC_HALF, us - ARC_HALF, 0, userR));
      parts.handleText.style.display = '';
      var handleTp = parts.handleText.querySelector('textPath');
      if (handleTp) {
        handleTp.setAttribute('startOffset', '50%');
        handleTp.setAttribute('text-anchor', 'middle');
        setHandleTextPath(handleTp, handleRaw);
      }
      applyCaptionStyle(
        parts.handleText,
        pickCaptionColour(colours, sampleCanvas, USER_ANGLE, userR)
      );
    } else if (parts.handleText) {
      parts.handleText.style.display = 'none';
    }
  }

  function bindHeroImageRepaint(wrapEl, run) {
    var img = wrapEl.querySelector('.sr-img-hero-img, .rp-hero-img');
    if (!img || img._rhLoadBound) return;
    img._rhLoadBound = true;
    img.addEventListener('load', run);
  }

  function render(wrapEl, opts) {
    if (!wrapEl) return;
    wrapEl._rhOpts = opts || wrapEl._rhOpts || {};
    var run = function() { paint(wrapEl, wrapEl._rhOpts); };
    bindHeroImageRepaint(wrapEl, run);
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
