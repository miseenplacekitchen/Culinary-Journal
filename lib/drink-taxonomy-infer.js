/**
 * Sips & Stories — J1–J9 sub inference via tcj-sips-stories-taxonomy.js.
 * Divisions are added in admin when ready; no legacy sub names here.
 */
(function (root) {
  'use strict';

  function infer(blob) {
    var text = String(blob || '');
    if (!text) return { sub: '', div: '' };
    if (typeof inferCategorySubFromBlob === 'function') {
      return inferCategorySubFromBlob('Sips & Stories', text);
    }
    return { sub: '', div: '' };
  }

  function inferCategory(blob) {
    var text = String(blob || '').toLowerCase();
    var drinkRe = /\b(water|coffee|tea|espresso|latte|matcha|juice|smoothie|shake|milkshake|milk|drink|beverage|cocktail|mocktail|spirit|wine|beer|cider|liqueur|vodka|gin|rum|whiskey|whisky|tequila|kombucha|kefir|lassi|tonic|soda|cordial|squash|shrub|agua fresca|horchata|yerba mate|kvass|chicha|protein shake|energy drink|lemonade|refresher|hot chocolate|cocoa|sharbat|bubble tea|boba|syrup|bitters|sake|soju|mead|spritz|negroni|mojito)\b/;
    return drinkRe.test(text) ? 'Sips & Stories' : '';
  }

  root.DrinkTaxonomyInfer = { infer: infer, inferCategory: inferCategory };
})(typeof globalThis !== 'undefined' ? globalThis : typeof self !== 'undefined' ? self : this);
