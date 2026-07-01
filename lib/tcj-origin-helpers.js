// tcj-origin-helpers.js — continent / country / state lookups (requires lib/tcj-origin-data.js → window.CD)
(function() {
  function cd() { return window.CD || {}; }

  function allContinents() {
    return Object.keys(cd()).sort();
  }

  function allCountries() {
    var list = [];
    Object.keys(cd()).forEach(function(cont) {
      (cd()[cont] || []).forEach(function(c) { if (c.name) list.push(c.name); });
    });
    return list.sort(function(a, b) { return a.localeCompare(b); });
  }

  function continentForCountry(country) {
    if (!country) return '';
    var found = '';
    Object.keys(cd()).forEach(function(cont) {
      (cd()[cont] || []).forEach(function(c) {
        if (c.name === country) found = cont;
      });
    });
    return found;
  }

  function statesForCountry(country) {
    if (!country) return [];
    var states = [];
    Object.values(cd()).forEach(function(cos) {
      (cos || []).forEach(function(c) {
        if (c.name === country && c.states) states = c.states.slice();
      });
    });
    return states.sort(function(a, b) { return a.localeCompare(b); });
  }

  function resolveFromState(state) {
    var out = { continent: '', country: '' };
    if (!state) return out;
    Object.keys(cd()).forEach(function(cont) {
      (cd()[cont] || []).forEach(function(c) {
        if ((c.states || []).indexOf(state) >= 0) {
          out.continent = cont;
          out.country = c.name;
        }
      });
    });
    return out;
  }

  function applyOriginPick(row, field, value) {
    if (!row) return row;
    row[field] = value || '';
    if (field === 'origin_country') {
      row.origin_continent = continentForCountry(value) || row.origin_continent || '';
      var valid = statesForCountry(value);
      if (row.origin_state && valid.indexOf(row.origin_state) < 0) row.origin_state = '';
    }
    if (field === 'origin_state') {
      var resolved = resolveFromState(value);
      if (resolved.country) row.origin_country = resolved.country;
      if (resolved.continent) row.origin_continent = resolved.continent;
    }
    return row;
  }

  window.tcjOrigin = {
    allContinents: allContinents,
    allCountries: allCountries,
    continentForCountry: continentForCountry,
    statesForCountry: statesForCountry,
    resolveFromState: resolveFromState,
    applyOriginPick: applyOriginPick
  };
})();
