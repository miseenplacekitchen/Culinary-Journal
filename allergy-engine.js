/**
 * Allergy Engine v1 — tag/keyword match (MP-13)
 * Warning only — never blocks assignment.
 */
window.AllergyEngine = (function () {
  var KEYWORDS = {
    'Peanut': ['peanut', 'groundnut', 'peanut butter'],
    'Tree Nuts': ['almond', 'walnut', 'pecan', 'cashew', 'pistachio', 'hazelnut', 'macadamia', 'pine nut', 'brazil nut', 'chestnut'],
    'Dairy': ['milk', 'butter', 'cream', 'cheese', 'yogurt', 'yoghurt', 'whey', 'lactose', 'ghee', 'paneer', 'ricotta', 'parmesan'],
    'Egg': ['egg', 'eggs', 'albumen', 'mayonnaise', 'mayo'],
    'Gluten': ['wheat', 'flour', 'bread', 'pasta', 'noodle', 'udon', 'barley', 'rye', 'couscous', 'seitan', 'gluten', 'semolina', 'spelt'],
    'Soy': ['soy', 'soya', 'tofu', 'tempeh', 'miso', 'edamame', 'soy sauce'],
    'Fish': ['fish', 'salmon', 'tuna', 'cod', 'anchov', 'sardine', 'mackerel', 'trout', 'barramundi'],
    'Shellfish': ['prawn', 'shrimp', 'crab', 'lobster', 'mussel', 'oyster', 'scallop', 'shellfish', 'crayfish', 'squid', 'calamari'],
    'Sesame': ['sesame', 'tahini'],
    'Sulphites': ['sulphite', 'sulfite', 'wine'],
    'Mustard': ['mustard']
  };

  var SPICE_MAP = { none: 0, mild: 1, medium: 2, hot: 3, very_hot: 4 };
  var SPICE_TEXT = { 'Not Applicable': 0, Mild: 1, Medium: 2, Hot: 3, 'Very Hot': 4, Extreme: 5 };

  function canonAllergen(label) {
    var s = String(label || '').toLowerCase().trim();
    if (!s) return '';
    if (s.indexOf('peanut') >= 0) return 'Peanut';
    if (s.indexOf('tree') >= 0 && s.indexOf('nut') >= 0) return 'Tree Nuts';
    if (s === 'nuts' || s === 'nut' || s.indexOf('nut allergy') >= 0) return 'Tree Nuts';
    if (s.indexOf('dairy') >= 0 || s.indexOf('milk') >= 0) return 'Dairy';
    if (s.indexOf('egg') >= 0) return 'Egg';
    if (s.indexOf('gluten') >= 0 || s.indexOf('wheat') >= 0) return 'Gluten';
    if (s.indexOf('soy') >= 0 || s.indexOf('soya') >= 0) return 'Soy';
    if (s.indexOf('shellfish') >= 0 || s.indexOf('crustacean') >= 0 || s.indexOf('prawn') >= 0) return 'Shellfish';
    if (s.indexOf('fish') >= 0) return 'Fish';
    if (s.indexOf('sesame') >= 0) return 'Sesame';
    return label;
  }

  function ingredientBlob(recipe) {
    var parts = [];
    (recipe.ingredients || []).forEach(function (sec) {
      (sec.items || []).forEach(function (item) {
        var n = item.ingredient || item.name || '';
        if (n) parts.push(n);
      });
    });
    if (recipe.recipe_name) parts.push(recipe.recipe_name);
    if (recipe.name) parts.push(recipe.name);
    return parts.join(' ').toLowerCase();
  }

  /** Word-boundary match — avoids substring false positives (e.g. raw → crawfish). */
  function keywordInBlob(kw, blob) {
    if (!kw || kw.length < 2 || !blob) return false;
    var escaped = String(kw).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    return new RegExp('(?:^|\\b)' + escaped + '(?:\\b|$)').test(blob);
  }

  function detectInRecipe(recipe) {
    var found = new Set();
    var blob = ingredientBlob(recipe);
    if (!blob) return [];
    Object.keys(KEYWORDS).forEach(function (allergen) {
      KEYWORDS[allergen].forEach(function (kw) {
        if (keywordInBlob(kw, blob)) found.add(allergen);
      });
    });
    return Array.from(found);
  }

  function recipeSpiceLevel(recipe) {
    if (typeof recipe.spice_level === 'number') return recipe.spice_level;
    return SPICE_TEXT[recipe.spice_level] != null ? SPICE_TEXT[recipe.spice_level] : 2;
  }

  function dietaryConflicts(recipe, profile) {
    var tags = recipe.dietary_tags || [];
    var out = [];
    (profile.dietary_needs || []).forEach(function (d) {
      if (d === 'Vegan' && tags.indexOf('Vegan') < 0) out.push(profile.name + ' is Vegan');
      if (d === 'Vegetarian' && tags.indexOf('Vegetarian') < 0 && tags.indexOf('Vegan') < 0) out.push(profile.name + ' is Vegetarian');
      if (d === 'Gluten Free' && tags.indexOf('Gluten Free') < 0) out.push(profile.name + ' needs Gluten Free');
      if (d === 'Halal' && tags.indexOf('Halal') < 0) out.push(profile.name + ' eats Halal');
      if (d === 'Kosher' && tags.indexOf('Kosher') < 0) out.push(profile.name + ' eats Kosher');
    });
    return out;
  }

  function allergyWarnings(recipe, profiles) {
    var warnings = [];
    var detected = detectInRecipe(recipe);
    profiles.forEach(function (p) {
      (p.allergies || []).forEach(function (a) {
        var canon = canonAllergen(a);
        var hit = detected.indexOf(canon) >= 0;
        if (!hit && canon && KEYWORDS[canon]) {
          var blob = ingredientBlob(recipe);
          hit = KEYWORDS[canon].some(function (kw) { return keywordInBlob(kw, blob); });
        }
        if (!hit && a) {
          hit = keywordInBlob(String(a).toLowerCase(), ingredientBlob(recipe));
        }
        if (hit) warnings.push('⚠ ' + (p.name || 'Member') + ' — allergic to ' + a);
      });
      dietaryConflicts(recipe, p).forEach(function (msg) { warnings.push('⚠ ' + msg); });
      var maxSpice = SPICE_MAP[p.spice_preference || 'medium'] != null ? SPICE_MAP[p.spice_preference || 'medium'] : 2;
      if (recipeSpiceLevel(recipe) > maxSpice) warnings.push('⚠ ' + (p.name || 'Member') + ' prefers less spice');
    });
    return warnings.filter(function (w, i, arr) { return arr.indexOf(w) === i; });
  }

  function checkRecipe(recipe, profiles, mode) {
    if (!profiles || !profiles.length || mode === 'individual') return [];
    return allergyWarnings(recipe, profiles);
  }

  function formatConfirmList(warnings) {
    return warnings.slice(0, 6).join('\n') + (warnings.length > 6 ? '\n…and ' + (warnings.length - 6) + ' more' : '');
  }

  /** Browse cards — uses dietary tags + recipe name when full ingredients unavailable */
  function checkRecipeLight(recipe, profiles) {
    if (!profiles || !profiles.length) return [];
    return allergyWarnings(recipe, profiles);
  }

  function parseGuestAllergies(dietaryRequirements) {
    var out = [];
    (dietaryRequirements || []).forEach(function (v) {
      var m = String(v).match(/^(allergy-severe|allergy|intolerance):(.+)$/i);
      if (m) {
        out.push({ item: m[2].trim(), severe: m[1].toLowerCase() === 'allergy-severe', raw: v });
      }
    });
    return out;
  }

  function guestTextBlob(guest) {
    return [
      guest.name || '',
      guest.notes || '',
      (guest.dietary_requirements || []).join(' ')
    ].join(' ').toLowerCase();
  }

  function allergenHitsBlob(allergenItem, blob) {
    var canon = canonAllergen(allergenItem);
    if (KEYWORDS[canon]) {
      if (KEYWORDS[canon].some(function (kw) { return keywordInBlob(kw, blob); })) return true;
    }
    return keywordInBlob(String(allergenItem).toLowerCase(), blob);
  }

  function getAdjacentSeatNums(table, seatNum) {
    var n = parseInt(seatNum, 10);
    var max = table.seats || 0;
    if (!max || !n) return [];
    var adj = [];
    if (n > 1) adj.push(n - 1);
    if (n < max) adj.push(n + 1);
    if (max > 2) {
      if (n === 1) adj.push(max);
      if (n === max) adj.push(1);
    }
    return adj.filter(function (v, i, a) { return a.indexOf(v) === i; });
  }

  function findGuestAtSeat(guests, tableId, seatNum) {
    var key = tableId + ':' + seatNum;
    return guests.find(function (g) { return g.seat_assignment === key; }) || null;
  }

  /** Table planner — proximity warnings between seated guests (v1) */
  function seatingProximityWarnings(guests, tables) {
    var warnings = [];
    var seen = {};
    (tables || []).forEach(function (table) {
      for (var s = 1; s <= (table.seats || 0); s++) {
        var guest = findGuestAtSeat(guests, table.id, s);
        if (!guest) continue;
        var allergies = parseGuestAllergies(guest.dietary_requirements);
        if (!allergies.length) continue;
        var adjNums = getAdjacentSeatNums(table, s);
        var occupiedAdj = adjNums.filter(function (an) { return findGuestAtSeat(guests, table.id, an); });
        allergies.forEach(function (al) {
          occupiedAdj.forEach(function (an) {
            var neighbor = findGuestAtSeat(guests, table.id, an);
            if (!neighbor) return;
            var blob = guestTextBlob(neighbor);
            if (allergenHitsBlob(al.item, blob)) {
              var id = table.id + ':' + s + '|' + table.id + ':' + an + '|' + al.item;
              if (seen[id]) return;
              seen[id] = true;
              warnings.push({
                severity: al.severe ? 'high' : 'medium',
                seat: table.id + ':' + s,
                neighborSeat: table.id + ':' + an,
                message: (guest.name || 'Guest') + ' (' + al.item + (al.severe ? ' — severe' : '') + ') is next to ' +
                  (neighbor.name || 'another guest') + ', whose details mention ' + al.item + '. Consider reseating or a buffer seat.'
              });
            }
          });
          if (al.severe && occupiedAdj.length >= (adjNums.length || 2)) {
            var bufId = 'buffer|' + table.id + ':' + s;
            if (!seen[bufId]) {
              seen[bufId] = true;
              warnings.push({
                severity: 'medium',
                seat: table.id + ':' + s,
                message: (guest.name || 'Guest') + ' has a severe ' + al.item + ' allergy with guests on both sides — leave a buffer seat if possible.'
              });
            }
          }
        });
      }
    });
    return warnings;
  }

  function warningsForSeat(seatKey, allWarnings) {
    return (allWarnings || []).filter(function (w) {
      return w.seat === seatKey || w.neighborSeat === seatKey;
    });
  }

  return {
    detectInRecipe: detectInRecipe,
    allergyWarnings: allergyWarnings,
    checkRecipe: checkRecipe,
    checkRecipeLight: checkRecipeLight,
    formatConfirmList: formatConfirmList,
    parseGuestAllergies: parseGuestAllergies,
    seatingProximityWarnings: seatingProximityWarnings,
    warningsForSeat: warningsForSeat
  };
})();
