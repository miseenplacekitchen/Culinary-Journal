/* Paginated admin RPC helpers - no hard row caps */
(function (global) {
  var PAGE = 100;
  var MAX_ROWS = 50000;

  function resolveRpc() {
    if (typeof global.tcjAdminRpc === 'function') return global.tcjAdminRpc;
    if (typeof global.rpc === 'function') return global.rpc;
    return null;
  }

  function normalizeRpcRows(data) {
    if (Array.isArray(data)) return { rows: data, total: data.length };
    if (data && Array.isArray(data.items)) {
      return { rows: data.items, total: parseInt(data.total, 10) || data.items.length };
    }
    if (data && Array.isArray(data.users)) {
      return { rows: data.users, total: data.users.length };
    }
    return { rows: [], total: 0 };
  }

  async function fetchAllPages(rpcFn, fn, params, limitKey, offsetKey) {
    if (typeof rpcFn !== 'function') return [];
    params = params || {};
    limitKey = limitKey || 'p_limit';
    offsetKey = offsetKey || 'p_offset';
    var all = [];
    var offset = 0;
    var total = null;
    while (offset < MAX_ROWS) {
      var body = Object.assign({}, params);
      body[limitKey] = PAGE;
      body[offsetKey] = offset;
      var parsed = normalizeRpcRows(await rpcFn(fn, body));
      var rows = parsed.rows;
      if (total === null && parsed.total) total = parsed.total;
      if (!rows.length) break;
      all = all.concat(rows);
      if (rows.length < PAGE) break;
      if (total !== null && all.length >= total) break;
      offset += rows.length;
    }
    return all;
  }

  async function fetchAllAdminRecipes(params) {
    return fetchAllPages(resolveRpc(), 'admin_get_recipes', params);
  }

  async function fetchAllAdminUsers(params) {
    return fetchAllPages(resolveRpc(), 'admin_get_users', params);
  }

  async function fetchAllAuditLog(params) {
    return fetchAllPages(resolveRpc(), 'admin_get_audit_log', params);
  }

  async function fetchAllLibraryProfiles(params) {
    return fetchAllPages(resolveRpc(), 'admin_get_library_profiles', params);
  }

  async function fetchAllAdminReports(params) {
    return fetchAllPages(resolveRpc(), 'admin_get_reports', params);
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

  async function fetchAllActiveProfilesRest(apiFetchFn, baseUrl) {
    if (typeof apiFetchFn !== 'function') return [];
    var all = [];
    var offset = 0;
    while (offset < MAX_ROWS) {
      var res = await apiFetchFn(
        baseUrl + '/rest/v1/profiles?select=id,username,full_name,is_active&is_active=eq.true&order=username.asc&limit=' + PAGE + '&offset=' + offset
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
  global.TcjAdminReports = { fetchAll: fetchAllAdminReports, PAGE_SIZE: PAGE };
  global.TcjAdminLibrary = { fetchAll: fetchAllLibraryProfiles, PAGE_SIZE: PAGE };
  global.TcjAdminProfiles = {
    fetchAllRest: fetchAllProfilesRest,
    fetchAllActiveRest: fetchAllActiveProfilesRest,
    PAGE_SIZE: PAGE
  };
})(typeof window !== 'undefined' ? window : globalThis);
