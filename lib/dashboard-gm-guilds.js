// dashboard-gm-guilds.js — GM guild list + member editor
(function (global) {
  function esc(s) {
    return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  async function renderGuildsTab(core) {
    var guilds = await global.gmFetchSafe('/rest/v1/guilds?select=id,slug,name,description,is_published&order=name') || [];
    var members = await global.gmFetchSafe('/rest/v1/guild_members?select=guild_id,plant_id,role') || [];
    var plantMap = {};
    (core.plants || []).forEach(function (p) { plantMap[p.id] = p; });

    var memberRows = (members || []).map(function (m) {
      var g = guilds.find(function (x) { return x.id === m.guild_id; });
      var p = plantMap[m.plant_id] || {};
      return '<tr><td>' + esc(g ? g.name : '—') + '</td>' +
        '<td><strong>' + esc(p.common_name || '—') + '</strong></td>' +
        '<td style="font-family:monospace;font-size:11px">' + esc(p.slug || '') + '</td>' +
        '<td>' + esc(m.role || '—') + '</td>' +
        '<td><button type="button" class="ing-del-btn" style="font-size:10px;padding:3px 8px" onclick="GmGuilds.removeMember(' +
        JSON.stringify(g ? g.slug : '') + ',' + JSON.stringify(p.slug || '') + ',this)">Remove</button></td></tr>';
    }).join('') || '<tr><td colspan="5" class="ap-empty-row">No guild members yet — run fix-phase57-garden-guilds-media.sql or add below.</td></tr>';

    var guildOpts = guilds.map(function (g) {
      return '<option value="' + esc(g.slug) + '">' + esc(g.name) + (g.is_published ? '' : ' (draft)') + '</option>';
    }).join('');
    var plantOpts = (core.plants || []).map(function (p) {
      return '<option value="' + esc(p.slug) + '">' + esc(p.common_name) + '</option>';
    }).join('');

    var guildList = guilds.map(function (g) {
      return '<tr><td style="font-family:monospace;font-size:11px">' + esc(g.slug) + '</td>' +
        '<td><strong>' + esc(g.name) + '</strong></td>' +
        '<td>' + (g.is_published ? 'Published' : 'Draft') + '</td>' +
        '<td style="font-size:12px;color:var(--text-mid)">' + esc((g.description || '').slice(0, 80)) + '</td>' +
        '<td style="white-space:nowrap">' +
        '<button type="button" class="ing-add-btn" style="font-size:10px;padding:3px 8px;margin-right:4px" onclick="GmGuilds.togglePublish(' +
        JSON.stringify(g.slug) + ',' + (g.is_published ? 'false' : 'true') + ',this)">' +
        (g.is_published ? 'Unpublish' : 'Publish') + '</button></td></tr>';
    }).join('') || '<tr><td colspan="5" class="ap-empty-row">No guilds.</td></tr>';

    return '<p style="font-family:DM Sans,sans-serif;font-size:13px;color:var(--text-mid);margin:0 0 12px">' +
      'Named polycultures for food-forest planning. Public site shows published guilds only.</p>' +
      global.gmAccordion('Guilds (' + guilds.length + ')', global.gmTableWrap(
        '<tr><th>Slug</th><th>Name</th><th>Status</th><th>Description</th><th></th></tr>', guildList), true) +
      global.gmAccordion('Members (' + (members || []).length + ')', global.gmTableWrap(
        '<tr><th>Guild</th><th>Plant</th><th>Slug</th><th>Role</th><th></th></tr>', memberRows), true) +
      '<div style="margin-top:16px;padding:14px;border:1px solid var(--border);border-radius:10px">' +
      '<div style="font-weight:700;margin-bottom:10px;font-family:Cormorant Garamond,serif;font-size:1.05rem">Add guild or member</div>' +
      '<div style="display:flex;flex-wrap:wrap;gap:8px;align-items:flex-end;margin-bottom:12px">' +
      '<label style="font-size:12px">New guild name<br><input id="gm-guild-name" class="ap-search" placeholder="Mediterranean kitchen"></label>' +
      '<label style="font-size:12px">Description<br><input id="gm-guild-desc" class="ap-search" style="min-width:220px" placeholder="Optional"></label>' +
      '<button type="button" class="ing-add-btn" style="font-size:11px;padding:6px 12px" onclick="GmGuilds.createGuild(this)">Create guild</button>' +
      '</div>' +
      '<div style="display:flex;flex-wrap:wrap;gap:8px;align-items:flex-end">' +
      '<label style="font-size:12px">Guild<br><select id="gm-guild-pick" class="ap-search"><option value="">—</option>' + guildOpts + '</select></label>' +
      '<label style="font-size:12px">Plant<br><select id="gm-guild-plant" class="ap-search"><option value="">—</option>' + plantOpts + '</select></label>' +
      '<label style="font-size:12px">Role<br><input id="gm-guild-role" class="ap-search" placeholder="companion / canopy"></label>' +
      '<button type="button" class="ing-add-btn" style="font-size:11px;padding:6px 12px" onclick="GmGuilds.addMember(this)">Add member</button>' +
      '</div></div>';
  }

  async function createGuild(btn) {
    var name = (document.getElementById('gm-guild-name') || {}).value || '';
    if (!name.trim()) { alert('Guild name required'); return; }
    var desc = (document.getElementById('gm-guild-desc') || {}).value || '';
    if (btn) { btn.disabled = true; btn.textContent = 'Creating…'; }
    try {
      await global.rpc('admin_upsert_guild', { p_row: { name: name.trim(), description: desc.trim(), is_published: false } });
      global.reloadGmInterface();
    } catch (e) {
      alert('Create failed: ' + e.message);
      if (btn) { btn.disabled = false; btn.textContent = 'Create guild'; }
    }
  }

  async function addMember(btn) {
    var g = (document.getElementById('gm-guild-pick') || {}).value;
    var p = (document.getElementById('gm-guild-plant') || {}).value;
    var role = (document.getElementById('gm-guild-role') || {}).value || '';
    if (!g || !p) { alert('Pick guild and plant'); return; }
    if (btn) btn.disabled = true;
    try {
      await global.rpc('admin_set_guild_member', { p_guild_slug: g, p_plant_slug: p, p_role: role, p_remove: false });
      global.reloadGmInterface();
    } catch (e) {
      alert('Add failed: ' + e.message);
      if (btn) btn.disabled = false;
    }
  }

  async function removeMember(guildSlug, plantSlug, btn) {
    if (!guildSlug || !plantSlug) return;
    if (!confirm('Remove ' + plantSlug + ' from guild?')) return;
    if (btn) btn.disabled = true;
    try {
      await global.rpc('admin_set_guild_member', { p_guild_slug: guildSlug, p_plant_slug: plantSlug, p_role: null, p_remove: true });
      global.reloadGmInterface();
    } catch (e) {
      alert('Remove failed: ' + e.message);
      if (btn) btn.disabled = false;
    }
  }

  async function togglePublish(slug, publish, btn) {
    if (!slug) return;
    var g = await global.gmFetchSafe('/rest/v1/guilds?slug=eq.' + encodeURIComponent(slug) + '&select=name,description');
    var row = g && g[0] ? g[0] : { name: slug, description: '' };
    if (btn) btn.disabled = true;
    try {
      await global.rpc('admin_upsert_guild', {
        p_row: { slug: slug, name: row.name, description: row.description || '', is_published: !!publish }
      });
      global.reloadGmInterface();
    } catch (e) {
      alert('Update failed: ' + e.message);
      if (btn) btn.disabled = false;
    }
  }

  global.GmGuilds = {
    renderGuildsTab: renderGuildsTab,
    createGuild: createGuild,
    addMember: addMember,
    removeMember: removeMember,
    togglePublish: togglePublish
  };
})(window);
