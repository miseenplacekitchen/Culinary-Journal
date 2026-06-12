/* Paginated admin_get_recipes — no 500-row blind spots */
(function (global) {
  var PAGE = 100;

  async function fetchAllAdminRecipes(params) {
    if (typeof rpc !== 'function') return [];
    params = params || {};
    var all = [];
    var offset = 0;
    while (true) {
      var rows = await rpc('admin_get_recipes', Object.assign({}, params, {
        p_limit: PAGE,
        p_offset: offset
      }));
      if (!Array.isArray(rows) || !rows.length) break;
      all = all.concat(rows);
      if (rows.length < PAGE) break;
      offset += rows.length;
      if (offset > 50000) break;
    }
    return all;
  }

  global.TcjAdminRecipes = { fetchAll: fetchAllAdminRecipes, PAGE_SIZE: PAGE };
})(typeof window !== 'undefined' ? window : globalThis);
