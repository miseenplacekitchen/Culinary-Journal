/* Paginated get_approved_recipes helper — works around the 100-row RPC cap */
(function (global) {
  var PAGE = 100;

  function baseUrl() {
    return (global.SUPA_URL || global.SUPABASE_URL || '') + '/rest/v1/rpc/get_approved_recipes';
  }

  function apiKey() {
    return global.SUPA_KEY || global.SUPABASE_KEY || '';
  }

  async function fetchPage(body, headers) {
    var res = await fetch(baseUrl(), {
      method: 'POST',
      headers: Object.assign({ 'Content-Type': 'application/json', apikey: apiKey() }, headers || {}),
      body: JSON.stringify(body)
    });
    if (!res.ok) return [];
    var rows = await res.json();
    return Array.isArray(rows) ? rows : [];
  }

  async function fetchAllApproved(opts) {
    opts = opts || {};
    var all = [];
    var offset = 0;
    var pageSize = opts.pageSize || PAGE;
    var maxRows = opts.maxRows || 10000;
    var body = Object.assign({}, opts.params || {});
    var headers = opts.headers || null;

    while (all.length < maxRows) {
      body.p_limit = pageSize;
      body.p_offset = offset;
      var rows = await fetchPage(body, headers);
      if (!rows.length) break;
      all = all.concat(rows);
      if (rows.length < pageSize) break;
      offset += rows.length;
    }
    return all;
  }

  global.TcjRecipeBrowse = {
    fetchPage: fetchPage,
    fetchAllApproved: fetchAllApproved,
    PAGE_SIZE: PAGE
  };
})(typeof window !== 'undefined' ? window : globalThis);
