/* JSON-LD helpers — inject structured data per page (Master list cultural/SEO) */
(function (global) {
  function inject(schema) {
    if (!schema || !global.document) return;
    var el = document.createElement('script');
    el.type = 'application/ld+json';
    el.textContent = JSON.stringify(schema);
    document.head.appendChild(el);
  }

  function recipeSchema(r) {
    if (!r) return;
    inject({
      '@context': 'https://schema.org',
      '@type': 'Recipe',
      name: r.name || r.recipe_name,
      description: r.intro || r.description || '',
      image: r.image_url || r.hero_image || undefined,
      recipeCategory: r.category || undefined,
      recipeCuisine: r.origin_country || undefined,
      author: r.credit_name ? { '@type': 'Person', name: r.credit_name } : undefined,
      url: 'https://www.theculinaryjournal.site/recipe-page.html?id=' + (r.id || '')
    });
  }

  function itemListSchema(name, items) {
    inject({
      '@context': 'https://schema.org',
      '@type': 'ItemList',
      name: name,
      itemListElement: (items || []).slice(0, 50).map(function (it, i) {
        return {
          '@type': 'ListItem',
          position: i + 1,
          name: it.name || it.title,
          url: it.url || undefined
        };
      })
    });
  }

  function webPageSchema(name, description, url) {
    inject({
      '@context': 'https://schema.org',
      '@type': 'WebPage',
      name: name,
      description: description || '',
      url: url || (global.location && global.location.href)
    });
  }

  global.SeoSchema = {
    inject: inject,
    recipe: recipeSchema,
    itemList: itemListSchema,
    webPage: webPageSchema
  };
})(typeof window !== 'undefined' ? window : globalThis);
