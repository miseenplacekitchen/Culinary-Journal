-- fix-dish-index-import-excel.sql — Step 11: Visibility on CSV/Excel import + division placeholder support
-- Run in Supabase after fix-dish-index-col-filters.sql. Safe to re-run.

CREATE OR REPLACE FUNCTION public.rnl_csv_row_to_jsonb(r jsonb)
RETURNS jsonb
LANGUAGE sql IMMUTABLE SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'id', COALESCE(r->>'id', r->>'ID'),
    'dish_code', COALESCE(r->>'dish_code', r->>'Dish Code', r->>'DI#'),
    'recipe_name', COALESCE(r->>'recipe_name', r->>'Recipe Name', r->>'Name'),
    'native_name', COALESCE(r->>'native_name', r->>'Native Name'),
    'alternate_names', COALESCE(r->'alternate_names', to_jsonb(COALESCE(r->>'Alternate Names', ''))),
    'category', COALESCE(r->>'category', r->>'Category'),
    'sub_category', COALESCE(r->>'sub_category', r->>'Sub-category', r->>'Sub Category'),
    'division', NULLIF(
      COALESCE(r->>'division', r->>'Division'),
      '(none)'
    ),
    'origin_continent', COALESCE(r->>'origin_continent', r->>'Continent'),
    'origin_country', COALESCE(r->>'origin_country', r->>'Country'),
    'origin_state', COALESCE(r->>'origin_state', r->>'State'),
    'origin_locality', COALESCE(r->>'origin_locality', r->>'Locality'),
    'primary_ingredients', COALESCE(r->'primary_ingredients', to_jsonb(COALESCE(r->>'Hero Ingredient', r->>'Primary Ingredients', ''))),
    'dietary_tags', COALESCE(r->'dietary_tags', to_jsonb(COALESCE(r->>'Dietary Tags', ''))),
    'meal_type_tags', COALESCE(r->'meal_type_tags', to_jsonb(COALESCE(r->>'Meal Type Tags', ''))),
    'occasion_tags', COALESCE(r->'occasion_tags', to_jsonb(COALESCE(r->>'Occasion Tags', ''))),
    'style_tags', COALESCE(r->'style_tags', to_jsonb(COALESCE(r->>'Style Tags', ''))),
    'health_tags', COALESCE(r->'health_tags', to_jsonb(COALESCE(r->>'Health Tags', ''))),
    'flavor_profile_tags', COALESCE(r->'flavor_profile_tags', to_jsonb(COALESCE(r->>'Flavor Profile Tags', r->>'Flavor Tags', ''))),
    'equipment', COALESCE(r->'equipment', to_jsonb(COALESCE(r->>'Equipment', ''))),
    'introduction', COALESCE(r->>'introduction', r->>'Introduction'),
    'description', COALESCE(r->>'description', r->>'Description'),
    'image_url', COALESCE(r->>'image_url', r->>'Image URL'),
    'image_source_url', COALESCE(r->>'image_source_url', r->>'Image Source URL'),
    'prep_time_minutes', COALESCE(r->>'prep_time_minutes', r->>'Prep Time Minutes', r->>'Prep Time'),
    'cook_time_minutes', COALESCE(r->>'cook_time_minutes', r->>'Cook Time Minutes', r->>'Cook Time'),
    'additional_time_minutes', COALESCE(r->>'additional_time_minutes', r->>'Additional Time Minutes', r->>'Additional Time'),
    'servings', COALESCE(r->>'servings', r->>'Servings'),
    'servings_unit', COALESCE(r->>'servings_unit', r->>'Servings Unit'),
    'difficulty', NULLIF(COALESCE(r->>'difficulty', r->>'Difficulty'), 'Not set'),
    'spice_level', COALESCE(r->>'spice_level', r->>'Spice Level'),
    'sweet_level', COALESCE(r->>'sweet_level', r->>'Sweet Level'),
    'cooking_style', COALESCE(r->>'cooking_style', r->>'Cooking Style'),
    'cooking_notes', COALESCE(r->>'cooking_notes', r->>'Cooking Notes'),
    'shelf_life_value', COALESCE(r->>'shelf_life_value', r->>'Shelf Life Value'),
    'shelf_life_unit', COALESCE(r->>'shelf_life_unit', r->>'Shelf Life Unit'),
    'shelf_life_storage', COALESCE(r->>'shelf_life_storage', r->>'Shelf Life Storage'),
    'after_open_value', COALESCE(r->>'after_open_value', r->>'After Open Value'),
    'after_open_unit', COALESCE(r->>'after_open_unit', r->>'After Open Unit'),
    'source_type', COALESCE(r->>'source_type', r->>'Source Type'),
    'credit_name', COALESCE(r->>'credit_name', r->>'Credit Name'),
    'credit_handle', COALESCE(r->>'credit_handle', r->>'Credit Handle'),
    'credit_url', COALESCE(r->>'credit_url', r->>'Credit URL'),
    'source_url', COALESCE(r->>'source_url', r->>'Source URL'),
    'source_notes', COALESCE(r->>'source_notes', r->>'Source Notes'),
    'research_status', COALESCE(r->>'research_status', r->>'Research Status'),
    'content_status', COALESCE(r->>'content_status', r->>'Content Status'),
    'linked_recipe_id', COALESCE(r->>'linked_recipe_id', r->>'Linked Recipe ID')
  ) || jsonb_build_object(
    'visibility', COALESCE(NULLIF(btrim(COALESCE(r->>'visibility', r->>'Visibility')), ''), 'Private'),
    'notes', COALESCE(r->>'notes', r->>'Notes'),
    'is_active', COALESCE(r->>'is_active', r->>'Active', 'true')
  );
$$;

SELECT 'fix-dish-index-import-excel complete' AS status;
