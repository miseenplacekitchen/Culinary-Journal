/* Paginated admin RPC helpers - no hard row caps */
(function (global) {
  var PAGE = 100;
  var MAX_ROWS = 50000;

  async function fetchAllPages(rpcFn, fn, params, limitKey, offsetKey) {
    if (typeof rpcFn !== 'function') return [];
    params = params || {};
    limitKey = limitKey || 'p_limit';
    offsetKey = offsetKey || 'p_offset';
    var all = [];
    var offset = 0;
    while (offset < MAX_ROWS) {
      var body = Object.assign({}, params);
      body[limitKey] = PAGE;
      body[offsetKey] = offset;
      var rows = await rpcFn(fn, body);
      if (!Array.isArray(rows) || !rows.length) break;
      all = all.concat(rows);
      if (rows.length < PAGE) break;
      offset += rows.length;
    }
    return all;
  }

  async function fetchAllAdminRecipes(params) {
    return fetchAllPages(global.rpc, 'admin_get_recipes', params);
  }

  async function fetchAllAdminUsers(params) {
    return fetchAllPages(global.rpc, 'admin_get_users', params);
  }

  async function fetchAllAuditLog(params) {
    return fetchAllPages(global.rpc, 'admin_get_audit_log', params);
  }

  async function fetchAllLibraryProfiles(params) {
    return fetchAllPages(global.rpc, 'admin_get_library_profiles', params);
  }

  async function fetchAllProfilesRest(apiFetchFn, baseUrl) {
    if (typeof apiFetchFn !== 'function') return [];
    var all = [];
    var offset = 0;
    while (offset < MAX_ROWS) {
      var res = await apiFetchFn(
        baseUrl + '/rest/v1/profiles?select=id,username,full_name,email,subscription_tier&order=full_name.asc&limit=' + PAGE + '&offset=' + offset
      );
      if (!res || !res.ok) break;
      var rows = await res.json();
      if (!Array.isArray(rows) || !rows.length) break;
      all = all.concat(rows);
      if (rows.length < PAGE) break;
      offset += rows.length;
    }
    return all;
  }

  global.TcjAdminRecipes = { fetchAll: fetchAllAdminRecipes, PAGE_SIZE: PAGE };
  global.TcjAdminUsers = { fetchAll: fetchAllAdminUsers, PAGE_SIZE: PAGE };
  global.TcjAdminAudit = { fetchAll: fetchAllAuditLog, PAGE_SIZE: PAGE };
  global.TcjAdminLibrary = { fetchAll: fetchAllLibraryProfiles, PAGE_SIZE: PAGE };
  global.TcjAdminProfiles = { fetchAllRest: fetchAllProfilesRest, PAGE_SIZE: PAGE };
})(typeof window !== 'undefined' ? window : globalThis);
