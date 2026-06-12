// garden-api.js — RPC wrappers for Garden v3 pages
(function (global) {
  function esc(s) {
    return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
  }

  async function listPlants(search, limit, offset) {
    return global.rpc('get_published_plants', {
      p_search: search || null,
      p_limit: limit || 50,
      p_offset: offset || 0
    });
  }

  async function getPlant(slug, climateSlug) {
    var params = { p_slug: slug };
    if (climateSlug) params.p_climate_slug = climateSlug;
    return global.rpc('get_plant_by_slug', params);
  }

  async function getMyGarden() {
    return global.rpc('get_my_garden_plants', {});
  }

  async function getMyRegion() {
    return global.rpc('get_my_garden_region', {});
  }

  async function whatNow(month) {
    var params = {};
    if (month) params.p_month = month;
    return global.rpc('garden_what_now', params);
  }

  async function whatNext(month) {
    var params = {};
    if (month) params.p_month = month;
    return global.rpc('garden_what_next', params);
  }

  async function addToGarden(plantId, status, bedLabel, varietyId) {
    return global.rpc('upsert_my_garden_plant', {
      p_plant_id: plantId,
      p_status: status || 'planned',
      p_bed_label: bedLabel || null,
      p_variety_id: varietyId || null
    });
  }

  async function setRegion(regionId) {
    return global.rpc('set_my_garden_region', { p_region_id: regionId });
  }

  async function setClimate(climateZoneId) {
    return global.rpc('set_my_garden_climate', { p_climate_zone_id: climateZoneId });
  }

  async function listRegions() {
    var res = await global.supaFetch(
      '/rest/v1/regions?is_active=eq.true&select=id,name,climate_zone_id,climate_zones(name)&order=name'
    );
    if (!res.ok) throw new Error('regions');
    var rows = await res.json();
    return (rows || []).map(function (r) {
      return {
        id: r.id,
        name: r.name,
        climate_zone_id: r.climate_zone_id,
        climate_name: r.climate_zones ? r.climate_zones.name : null
      };
    });
  }

  async function listClimateZones() {
    var res = await global.supaFetch('/rest/v1/climate_zones?select=id,slug,name&order=name');
    if (!res.ok) throw new Error('climates');
    return res.json();
  }

  function saveClimatePref(slug) {
    if (slug) localStorage.setItem('tcj_garden_climate', slug);
    else localStorage.removeItem('tcj_garden_climate');
  }

  function loadClimatePref() {
    return localStorage.getItem('tcj_garden_climate') || '';
  }

  global.GardenApi = {
    esc: esc,
    listPlants: listPlants,
    getPlant: getPlant,
    getMyGarden: getMyGarden,
    getMyRegion: getMyRegion,
    whatNow: whatNow,
    whatNext: whatNext,
    addToGarden: addToGarden,
    setRegion: setRegion,
    setClimate: setClimate,
    listRegions: listRegions,
    listClimateZones: listClimateZones,
    saveClimatePref: saveClimatePref,
    loadClimatePref: loadClimatePref
  };
})(window);
