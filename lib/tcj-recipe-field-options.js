// Shared recipe field options — aligned with submit-recipe.html
(function() {
  var SPICE = ['Not Applicable', 'Mild', 'Medium', 'Hot', 'Very Hot', 'Extremely Hot'];
  var SWEET = ['Not Applicable', 'Subtly Sweet', 'Lightly Sweet', 'Sweet', 'Very Sweet', 'Extremely Sweet'];
  var DIFFICULTY = ['', 'Easy', 'Intermediate', 'Advanced'];

  var SPICE_OPTIONS = [
    ['Not Applicable', '➖'],
    ['Mild', '🌶️'],
    ['Medium', '🌶️🌶️'],
    ['Hot', '🌶️🌶️🌶️'],
    ['Very Hot', '🌶️🌶️🌶️🌶️'],
    ['Extremely Hot', '🌶️🌶️🌶️🌶️🌶️']
  ];

  var SWEET_OPTIONS = [
    ['Not Applicable', '➖'],
    ['Subtly Sweet', '🧊'],
    ['Lightly Sweet', '🧊🧊'],
    ['Sweet', '🧊🧊🧊'],
    ['Very Sweet', '🧊🧊🧊🧊'],
    ['Extremely Sweet', '🧊🧊🧊🧊🧊']
  ];

  var DIFFICULTY_OPTIONS = [
    ['', '—'],
    ['Easy', '🟢'],
    ['Intermediate', '🟡'],
    ['Advanced', '🔴']
  ];

  var COOKING_STYLES = [
    { value: '', label: 'General cooking' },
    { value: 'stir-fry', label: 'Stir-fry & Sauté' },
    { value: 'deep-fry', label: 'Deep Frying' },
    { value: 'steam-poach', label: 'Steaming & Poaching' },
    { value: 'roasting', label: 'Roasting' },
    { value: 'air-fry', label: 'Air Frying' },
    { value: 'raw', label: 'Raw & No-Cook' },
    { value: 'bbq', label: 'Grilling & BBQ' },
    { value: 'smoking-hot', label: 'Smoking (Hot)' },
    { value: 'slow-cook', label: 'Slow Cooking & Braising' },
    { value: 'pressure', label: 'Pressure Cooking' },
    { value: 'sous-vide', label: 'Sous Vide' },
    { value: 'baking', label: 'Baking & Pastry' },
    { value: 'bread', label: 'Bread & Dough' },
    { value: 'griddle', label: 'Griddle & Flatbread' },
    { value: 'candy', label: 'Candy & Confectionery' },
    { value: 'marinating', label: 'Marinating' },
    { value: 'brining', label: 'Brining' },
    { value: 'pickling-q', label: 'Pickling (Quick)' },
    { value: 'pickling-t', label: 'Pickling (Traditional)' },
    { value: 'fermentation', label: 'Fermentation' },
    { value: 'canning', label: 'Canning & Bottling' },
    { value: 'dehydrating', label: 'Dehydrating & Drying' },
    { value: 'curing', label: 'Curing & Cold Smoking' },
    { value: 'jam', label: 'Jam, Chutney & Conserves' }
  ];

  var TAG_GROUPS = {
    meal_type_tags: [
      ['Breakfast', '🍳'], ['Brunch', '🥐'], ['Lunch', '🍲'], ['Dinner', '🍽️'], ['Snack', '🍪'], ['Drink', '🥤'],
      ['Soup', '🍜'], ['Salad', '🥗'], ['Main Course', '🍛'], ['Side Dish', '🥔'], ['Appetizer', '🫒'], ['Bread', '🍞'],
      ['Rice Dish', '🍚'], ['Dessert', '🍰'], ['Frozen Treat', '🍦'], ['Preserve / Pickle', '🫙']
    ],
    occasion_tags: [
      ['Everyday', '🍽️'], ['Under 5 Mins', '⚡'], ['Under 30 Mins', '⚡'], ['Quick', '⚡'], ['BBQ', '🔥'], ['Party', '🎉'],
      ['Wedding', '💒'], ['Christmas', '🎄'], ['Good Friday', '✝️'], ['Lent', '🕊'], ['Easter', '🐣'], ['Thanksgiving', '🦃'],
      ['Ramadan', '☪️'], ['Eid', '🌙'], ['Diwali', '🪔'], ['Onam', '🌸']
    ],
    style_tags: [
      ['Traditional', '⭐'], ['Modern', '✨'], ['Fusion', '🌍'], ['Street Food', '🌮'], ['Fine Dining', '🍷'], ['Comfort Food', '🫶']
    ],
    flavor_profile_tags: [
      ['Spicy', '🔥'], ['Tangy', '🍋'], ['Savoury', '🍗'], ['Sweet', '🍰'], ['Rich', '🧀'], ['Creamy', '🥛'],
      ['Fresh', '🌿'], ['Smoky', '🪵'], ['Nutty', '🌰'], ['Fruity', '🍇'], ['Salty', '🧂'], ['Umami', '🍄'],
      ['Bitter', '☕'], ['Earthy', '🍂'], ['Floral', '🌸'], ['Mild', '🌼']
    ],
    dietary_tags: [
      ['Vegan', '🌱'], ['Vegetarian', '🥗'], ['Gluten Free', '🌾'], ['Dairy Free', '🥛'], ['Nut Free', '🥜'],
      ['Shellfish Free', '🦐'], ['Egg Free', '🥚'], ['Halal', '☪'], ['Kosher', '✡']
    ],
    health_tags: [
      ['High Protein', '💪'], ['Low Carb', '🥦'], ['Low Fat', '🫀'], ['Low Sodium', '🧂'], ['Diabetic Friendly', '🩺'],
      ['Baby Friendly', '👶'], ['Kid Friendly', '🧒'], ['Recovery Food', '💚']
    ]
  };

  function tagOptions(key) {
    return (TAG_GROUPS[key] || []).map(function(pair) {
      return { value: pair[0], label: pair[1] + ' ' + pair[0] };
    });
  }

  function levelOptions(key) {
    var rows = key === 'SPICE' ? SPICE_OPTIONS : (key === 'SWEET' ? SWEET_OPTIONS : DIFFICULTY_OPTIONS);
    return rows.map(function(pair) {
      var value = pair[0];
      var emoji = pair[1];
      var name = value || 'Not set';
      return { value: value, label: emoji + ' ' + name };
    });
  }

  window.tcjRecipeFields = {
    SPICE: SPICE,
    SWEET: SWEET,
    DIFFICULTY: DIFFICULTY,
    COOKING_STYLES: COOKING_STYLES,
    TAG_GROUPS: TAG_GROUPS,
    tagOptions: tagOptions,
    levelOptions: levelOptions
  };
})();
