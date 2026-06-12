/* Submit recipe validation and method-step junk filter */
(function (global) {
  function countWords(s) {
    return (s || '').trim().split(/\s+/).filter(Boolean).length;
  }

  function isJunkMethodStep(step) {
    var t = String(step || '').trim();
    if (!t || t.length < 3) return true;
    var junkRes = [
      /^\(?\s*\d+\s*reviews?\s*\)?\.?$/i, /^check here for more/i, /^sharing is caring/i,
      /^bon appetit/i, /^related posts?/i, /^print\s*\(/i, /^leave a reply/i, /^one response to/i,
      /^facebook$/i, /^instagram$/i, /^youtube$/i, /^food advertisements by/i,
      /^continue reading/i, /^discover more from/i, /^subscribe to our newsletter/i,
      /^written by$/i, /^author$/i, /^\d+\s+comments?$/i, /^recent posts$/i, /^categories$/i,
      /^\d+\/\d+\s*\(\d+\s*reviews?\)/i, /^until next time/i, /^related posts?\s*:/i,
      /^puttu\s+kappa\s+puttu/i, /^erachi\s+puttu/i,
      /^note\s*:/i, /^love$/i, /^veena$/i, /^vinu$/i, /^notes?$/i, /^loading$/i
    ];
    if (junkRes.some(function (re) { return re.test(t); })) return true;
    if (t.length <= 18 && /^[A-Za-z][a-z]{2,14}$/.test(t) && !/\b(rice|chicken|onion|salt|water|heat|add|mix)\b/i.test(t)) return true;
    if (t.length < 28 && /^serve\s+(hot|with|warm)/i.test(t) && !/\b(heat|add|mix|stir|place|cover|knead|roll)\b/i.test(t)) return true;
    if (t.length < 18 && /^(?:serves?|yield)\s*:?\s*[\d\u00BC]/i.test(t)) return true;
    return false;
  }

  function filterMethSecsJunk(methSecs) {
    (methSecs || []).forEach(function (sec) {
      sec.steps = (sec.steps || []).filter(function (st) {
        var s = typeof st === 'string' ? st : (st.text || st.title || '');
        return s && !isJunkMethodStep(s);
      });
    });
    return (methSecs || []).filter(function (sec) { return (sec.steps || []).length > 0; });
  }

  function validate(data) {
    if (!data.recipe_name) return 'Please enter a recipe name.';
    if (data.introduction && countWords(data.introduction) > 100) {
      return 'Introduction is over the 100-word limit. Please shorten it.';
    }
    if (!data.category) return 'Please select a category.';
    if (!data.spice_level) return 'Please pick a spice level (or N/A if not spicy).';
    if (!data.sweet_level) return 'Please pick a sweet level (or N/A if not sweet).';
    if (!data.difficulty) return 'Please pick a difficulty level.';
    if (!data.servings || data.servings < 1) return 'Please enter the number of servings.';
    if (!data.prep_time_minutes && !data.cook_time_minutes) {
      return 'Please enter prep time or cook time.';
    }
    if (!data.origin_continent) return 'Please select the recipe origin (at least a continent).';
    var ingRows = 0;
    (data.ingredients || []).forEach(function (s) {
      (s.items || []).forEach(function (i) {
        var name = (i.ingredient || i.name || '').trim();
        if (name.length > 1) ingRows++;
      });
    });
    if (ingRows < 2) {
      return 'Please add at least two ingredients with names. The import may have missed some — check the paste box.';
    }
    var goodSteps = 0;
    (data.method || []).forEach(function (s) {
      (s.steps || []).forEach(function (st) {
        var t = (typeof st === 'string' ? st : (st.text || st.title || '')).trim();
        if (t && !isJunkMethodStep(t)) goodSteps++;
      });
    });
    if (goodSteps < 2) {
      return 'Please add at least two real method steps. Remove review links, related posts, or other junk lines.';
    }
    var ingBlob = (data.ingredients || []).map(function (s) {
      return (s.items || []).map(function (i) {
        return ((i.ingredient || i.name || '') + ' ' + (i.note || '')).toLowerCase();
      }).join(' ');
    }).join(' ');
    var diet = data.dietary_tags || [];
    if (diet.indexOf('Gluten Free') >= 0 && /\b(wheat|atta|all[- ]?purpose flour|maida|bread flour|semolina)\b/.test(ingBlob)) {
      return 'Gluten Free is checked but the recipe contains wheat or flour. Uncheck incorrect dietary tags.';
    }
    if (diet.indexOf('Vegan') >= 0 && /\b(chicken|mutton|lamb|beef|pork|fish|prawn|shrimp|egg|milk|butter|ghee|cheese|paneer|yoghurt|yogurt|curd|honey)\b/.test(ingBlob)) {
      return 'Vegan is checked but animal or dairy ingredients are listed. Uncheck incorrect dietary tags.';
    }
    if (data.source_type !== 'Original') {
      if (!data.credit_name) return "Please enter the original creator's name.";
      if (!data.credit_url) return 'Please add the source URL.';
    }
    if (typeof global.RecipeImportValidate !== 'undefined' && global.RecipeImportValidate.categoryContradictsTitle) {
      var catIssue = global.RecipeImportValidate.categoryContradictsTitle(data.category, data.recipe_name);
      if (catIssue) return catIssue + ' Choose a matching category.';
    }
    return null;
  }

  global.TcjSubmitValidate = {
    validate: validate,
    countWords: countWords,
    isJunkMethodStep: isJunkMethodStep,
    filterMethSecsJunk: filterMethSecsJunk
  };
  global.validate = validate;
  global.countWords = countWords;
  global.isJunkMethodStep = isJunkMethodStep;
  global.filterMethSecsJunk = filterMethSecsJunk;
})(typeof window !== 'undefined' ? window : globalThis);
