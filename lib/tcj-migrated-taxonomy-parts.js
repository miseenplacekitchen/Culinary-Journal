/**
 * Override book-generator PART groupings for A–K migrated categories (2026 v2).
 * Load after taxonomy-parts.js + tcj-*-taxonomy.js — fixes wrong Meat & Fire / technique PARTS.
 */
(function () {
  'use strict';

  function subsFrom(arr) {
    if (!arr || !arr.length) return [];
    return arr.map(function (s) { return s.name; });
  }

  var migrated = {};

  if (typeof TCJ_GARDEN_TAXONOMY !== 'undefined') {
    migrated['Garden & Earth'] = {
      A: { title: 'FROM THE GARDEN', emoji: '🥬', subs: subsFrom(TCJ_GARDEN_TAXONOMY) }
    };
  }
  if (typeof TCJ_FEATHER_TAXONOMY !== 'undefined') {
    migrated['Feather & Flock'] = {
      A: { title: 'FROM THE COOP', emoji: '🐓', subs: subsFrom(TCJ_FEATHER_TAXONOMY) }
    };
  }
  if (typeof TCJ_PASTURE_TAXONOMY !== 'undefined') {
    migrated['Pasture & Hoof'] = {
      A: { title: 'FROM THE PASTURE', emoji: '🍖', subs: subsFrom(TCJ_PASTURE_TAXONOMY) }
    };
  }
  if (typeof TCJ_OCEAN_TAXONOMY !== 'undefined') {
    migrated['Ocean & River'] = {
      A: { title: 'FROM THE WATER', emoji: '🌊', subs: subsFrom(TCJ_OCEAN_TAXONOMY) }
    };
  }
  if (typeof TCJ_GRAIN_FIELD_TAXONOMY !== 'undefined') {
    migrated['The Grain Field'] = {
      A: { title: 'FROM THE GRAIN FIELD', emoji: '🌾', subs: subsFrom(TCJ_GRAIN_FIELD_TAXONOMY) }
    };
  }
  if (typeof TCJ_SIPS_STORIES_TAXONOMY !== 'undefined') {
    migrated['Sips & Stories'] = {
      A: { title: 'FROM THE GLASS', emoji: '🥂', subs: subsFrom(TCJ_SIPS_STORIES_TAXONOMY) }
    };
  }

  window.TAXONOMY_PARTS = window.TAXONOMY_PARTS || {};
  Object.keys(migrated).forEach(function (cat) {
    window.TAXONOMY_PARTS[cat] = migrated[cat];
  });
})();
