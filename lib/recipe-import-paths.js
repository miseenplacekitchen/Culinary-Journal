/**
 * Wave 3 — documents the five submit-recipe import paths and touched subsystems.
 */
(function (root) {
  root.RecipeImportPaths = {
    version: '2.3.0-checklist-complete',
    paths: [
      {
        id: 'url-api',
        label: 'URL import (Vercel API)',
        steps: ['fetch-recipe-url', 'recipe-import-extract', 'recipe-import-core', 'parseRecipe', 'enrich gate'],
        primary: true
      },
      {
        id: 'url-fallback',
        label: 'URL import (AllOrigins fallback)',
        steps: ['allorigins', 'recipe-import-extract', 'recipe-import-core', 'parseRecipe'],
        warning: 'User-visible fallback warning'
      },
      {
        id: 'paste-parse',
        label: 'Manual paste + Parse',
        steps: ['recipe-import-core', 'parseRecipe', 'legacy parser fallback'],
        primary: true
      },
      {
        id: 'photo-scan',
        label: 'Photo / PDF scan',
        steps: ['tesseract/pdf.js', 'cleanup_recipe_ocr RPC', 'recipe-import-core', 'parseRecipe']
      },
      {
        id: 'jsonld-direct',
        label: 'JSON-LD complete schema',
        steps: ['recipe-import-extract analyzeJsonLd', 'populateFromJsonLd', 'parseRecipe']
      }
    ]
  };
})(typeof globalThis !== 'undefined' ? globalThis : typeof self !== 'undefined' ? self : this);
