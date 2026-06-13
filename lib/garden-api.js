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

  async function listJournalEntries(limit) {
    var res = await global.supaFetch(
      '/rest/v1/garden_journal?select=id,entry_date,body,user_plant_id,created_at&order=entry_date.desc,created_at.desc&limit=' + (limit || 50)
    );
    if (!res.ok) throw new Error('journal');
    return res.json();
  }

  async function addJournalEntry(opts) {
    var session = global.getSession && global.getSession();
    if (!session || !session.user) throw new Error('sign in required');
    var row = {
      user_id: session.user.id,
      body: opts.body,
      entry_date: opts.entry_date || new Date().toISOString().slice(0, 10)
    };
    if (opts.user_plant_id) row.user_plant_id = opts.user_plant_id;
    var res = await global.supaFetch('/rest/v1/garden_journal', {
      method: 'POST',
      headers: { Prefer: 'return=minimal' },
      body: JSON.stringify(row)
    });
    if (!res.ok) throw new Error('journal save ' + res.status);
    return true;
  }

  async function deleteJournalEntry(id) {
    var res = await global.supaFetch('/rest/v1/garden_journal?id=eq.' + encodeURIComponent(id), {
      method: 'DELETE',
      headers: { Prefer: 'return=minimal' }
    });
    if (!res.ok) throw new Error('journal delete ' + res.status);
    return true;
  }

  function saveClimatePref(slug) {
    if (slug) localStorage.setItem('tcj_garden_climate', slug);
    else localStorage.removeItem('tcj_garden_climate');
  }

  function loadClimatePref() {
    return localStorage.getItem('tcj_garden_climate') || '';
  }

  async function listPublishedGuilds() {
    var res = await global.supaFetch(
      '/rest/v1/guilds?is_published=eq.true&select=slug,name,description,guild_members(role,plants(common_name,is_published))&order=name'
    );
    if (!res.ok) throw new Error('guilds');
    var rows = await res.json();
    return (rows || []).map(function (g) {
      var members = (g.guild_members || []).filter(function (m) {
        return m.plants && m.plants.is_published;
      }).map(function (m) {
        return { name: m.plants.common_name, role: m.role || '' };
      });
      return { slug: g.slug, name: g.name, description: g.description, members: members };
    }).filter(function (g) { return g.members.length > 0; });
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
    listPublishedGuilds: listPublishedGuilds,
    listJournalEntries: listJournalEntries,
    addJournalEntry: addJournalEntry,
    deleteJournalEntry: deleteJournalEntry,
    saveClimatePref: saveClimatePref,
    loadClimatePref: loadClimatePref
  };
})(window);
