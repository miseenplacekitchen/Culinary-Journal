-- ═══════════════════════════════════════════════════════════════
-- THE CULINARY JOURNAL — 00-drop-functions.sql
-- Drops every existing function so 02-functions.sql can recreate
-- them cleanly with the correct return types.
--
-- Run ORDER: 00 → 01 → 02 → 03
-- Safe to re-run — all use IF EXISTS.
-- ═══════════════════════════════════════════════════════════════

-- Core auth helpers
DROP FUNCTION IF EXISTS public.is_admin() CASCADE;
DROP FUNCTION IF EXISTS public.get_login_info(text);

-- Profile
DROP FUNCTION IF EXISTS public.get_my_profile();
DROP FUNCTION IF EXISTS public.update_my_profile(text, text);
DROP FUNCTION IF EXISTS public.update_my_theme(text);
DROP FUNCTION IF EXISTS public.update_my_preferences(text[], text[], text[], text);
DROP FUNCTION IF EXISTS public.update_my_preferences(text[], text[], text[], text, text);
DROP FUNCTION IF EXISTS public.deactivate_my_account();
DROP FUNCTION IF EXISTS public.get_public_profile(text);

-- Recipes
DROP FUNCTION IF EXISTS public.get_my_submissions();
DROP FUNCTION IF EXISTS public.get_approved_recipes(text, text, text, text, int, int);
DROP FUNCTION IF EXISTS public.quick_update_recipe(uuid, text, text);
DROP FUNCTION IF EXISTS public.quick_update_recipe(uuid, text, text, text);

-- Admin — recipes
DROP FUNCTION IF EXISTS public.admin_get_recipes(text);
DROP FUNCTION IF EXISTS public.admin_get_stats();
DROP FUNCTION IF EXISTS public.admin_review_recipe(uuid, text, text);
DROP FUNCTION IF EXISTS public.admin_get_submitter(uuid);
DROP FUNCTION IF EXISTS public.admin_get_analytics();
DROP FUNCTION IF EXISTS public.admin_create_notification(uuid, text, uuid, text, text);

-- Admin — ingredients
DROP FUNCTION IF EXISTS public.admin_get_ingredients(text, text, int, int);
DROP FUNCTION IF EXISTS public.admin_count_ingredients(text, text);
DROP FUNCTION IF EXISTS public.admin_get_ingredient_units();
DROP FUNCTION IF EXISTS public.admin_export_ingredients(text, text);
DROP FUNCTION IF EXISTS public.admin_upsert_ingredient(int, text, text, text, text, text, numeric, text, text, text, text, text, text, text);
DROP FUNCTION IF EXISTS public.admin_upsert_ingredient(int, text, text, text, text, text, numeric, text, text, text, text, text, text, text, jsonb);
DROP FUNCTION IF EXISTS public.admin_delete_ingredient(int);
DROP FUNCTION IF EXISTS public.admin_bulk_update_field(int[], text, text);
DROP FUNCTION IF EXISTS public.admin_bulk_upsert_ingredients(jsonb);

-- Admin — users
DROP FUNCTION IF EXISTS public.admin_get_users(text, int, int);
DROP FUNCTION IF EXISTS public.admin_set_user_active(uuid, boolean);
DROP FUNCTION IF EXISTS public.admin_count_users(text);

-- Table planner
DROP FUNCTION IF EXISTS public.get_my_events();
DROP FUNCTION IF EXISTS public.upsert_event(uuid, text, text, date, text, text, jsonb);
DROP FUNCTION IF EXISTS public.save_event_layout(uuid, jsonb);
DROP FUNCTION IF EXISTS public.delete_event(uuid);
DROP FUNCTION IF EXISTS public.get_event_guests(uuid);
DROP FUNCTION IF EXISTS public.upsert_guest(uuid, uuid, text, text[], text, text, text, boolean, text, text);
DROP FUNCTION IF EXISTS public.assign_seat(uuid, text);
DROP FUNCTION IF EXISTS public.delete_guest(uuid);
DROP FUNCTION IF EXISTS public.get_guest_card(uuid);
DROP FUNCTION IF EXISTS public.submit_guest_dietary(uuid, text[]);

-- Collections
DROP FUNCTION IF EXISTS public.get_my_collections();
DROP FUNCTION IF EXISTS public.upsert_collection(uuid, text, text, text, boolean);
DROP FUNCTION IF EXISTS public.delete_collection(uuid);
DROP FUNCTION IF EXISTS public.add_to_collection(uuid, uuid);
DROP FUNCTION IF EXISTS public.remove_from_collection(uuid, uuid);
DROP FUNCTION IF EXISTS public.get_collection_recipes(uuid);
DROP FUNCTION IF EXISTS public.get_recipe_collections(uuid);

-- Family profiles
DROP FUNCTION IF EXISTS public.get_my_family_profiles();
DROP FUNCTION IF EXISTS public.upsert_family_profile(uuid, text, text, text, text[], text, text[], text[], text);
DROP FUNCTION IF EXISTS public.delete_family_profile(uuid);

-- Notifications
DROP FUNCTION IF EXISTS public.get_notification_count();
DROP FUNCTION IF EXISTS public.get_my_notifications();
DROP FUNCTION IF EXISTS public.mark_notification_read(uuid);
DROP FUNCTION IF EXISTS public.mark_all_notifications_read();

-- Page settings
DROP FUNCTION IF EXISTS public.get_page_settings();
DROP FUNCTION IF EXISTS public.set_page_visibility(text, text, text);
