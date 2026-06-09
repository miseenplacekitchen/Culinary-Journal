/**
 * Node smoke test for ring label geometry (no browser required).
 * Run: node tests/hero-label-geometry.test.js
 */
'use strict';

var BRAND_CENTER_DEG = 130;
var HANDLE_START_DEG = 310;
var RING_VB = 420;
var RING_R = 168;
var PADDING_MM = 2;

function mmPx(mm) { return mm * (96 / 25.4); }
function deg2rad(d) { return d * Math.PI / 180; }

function getGeometry(wrapW, wrapH) {
  var half = Math.min(wrapW, wrapH) / 2;
  var frameR = half * (RING_R / (RING_VB / 2));
  return {
    cx: wrapW / 2,
    cy: wrapH / 2,
    r: frameR - 1.5 - mmPx(PADDING_MM),
    w: wrapW,
    h: wrapH
  };
}

function polar(g, deg) {
  var rad = deg2rad(deg);
  return { x: g.cx + g.r * Math.cos(rad), y: g.cy - g.r * Math.sin(rad) };
}

function angleBetween(a, b) {
  var d = Math.abs(a - b) % 360;
  return d > 180 ? 360 - d : d;
}

var g = getGeometry(400, 400);
var brand = polar(g, BRAND_CENTER_DEG);
var handle = polar(g, HANDLE_START_DEG);
var sep = angleBetween(BRAND_CENTER_DEG, HANDLE_START_DEG);

var failures = [];
if (Math.abs(sep - 180) > 0.1) failures.push('Brand/handle not 180° apart: ' + sep);
if (g.r < 140 || g.r > 165) failures.push('Unexpected label radius: ' + g.r.toFixed(1));
if (brand.x >= g.cx) failures.push('Brand should be left of centre, got x=' + brand.x.toFixed(1));
if (handle.x <= g.cx) failures.push('Handle should be right of centre, got x=' + handle.x.toFixed(1));
if (brand.y >= g.cy) failures.push('Brand should be above centre, got y=' + brand.y.toFixed(1));
if (handle.y <= g.cy) failures.push('Handle should be below centre, got y=' + handle.y.toFixed(1));

// Same centre for both caption anchor points
var distBrand = Math.hypot(brand.x - g.cx, brand.y - g.cy);
var distHandle = Math.hypot(handle.x - g.cx, handle.y - g.cy);
if (Math.abs(distBrand - distHandle) > 0.01) {
  failures.push('Anchor radii differ: brand=' + distBrand + ' handle=' + distHandle);
}

if (failures.length) {
  console.error('FAIL');
  failures.forEach(function(f) { console.error(' -', f); });
  process.exit(1);
}
console.log('PASS — geometry OK');
console.log('  labelR=' + g.r.toFixed(1) + 'px, separation=' + sep + '°');
console.log('  brand@130°=(' + brand.x.toFixed(1) + ',' + brand.y.toFixed(1) + ')');
console.log('  handle@310°=(' + handle.x.toFixed(1) + ',' + handle.y.toFixed(1) + ')');
