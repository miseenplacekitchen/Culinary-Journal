// garden-api.js — thin RPC wrappers for Garden v3 pages
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

  async function getPlant(slug) {
    return global.rpc('get_plant_by_slug', { p_slug: slug });
  }

  async function getMyGarden() {
    return global.rpc('get_my_garden_plants', {});
  }

  async function whatNow(month) {
    var params = {};
    if (month) params.p_month = month;
    return global.rpc('garden_what_now', params);
  }

  async function addToGarden(plantId, status, bedLabel) {
    return global.rpc('upsert_my_garden_plant', {
      p_plant_id: plantId,
      p_status: status || 'planned',
      p_bed_label: bedLabel || null
    });
  }

  async function setRegion(regionId) {
    return global.rpc('set_my_garden_region', { p_region_id: regionId });
  }

  async function listRegions() {
    var res = await global.supaFetch('/rest/v1/regions?is_active=eq.true&select=id,slug,name,climate_zone_id&order=name');
    if (!res.ok) throw new Error('regions');
    return res.json();
  }

  global.GardenApi = {
    esc: esc,
    listPlants: listPlants,
    getPlant: getPlant,
    getMyGarden: getMyGarden,
    whatNow: whatNow,
    addToGarden: addToGarden,
    setRegion: setRegion,
    listRegions: listRegions
  };
})(window);
