# Database SQL — File Index (Manifest)

_Companion to `README.md`. Lists every SQL file in `database/sql/`, its status, purpose, and the functions it defines. Generated from the current snapshot; the `02-functions.sql` row reflects the **cleaned** copy._

## Status legend

- **Core** — numbered schema/function files, applied in order on a fresh setup.
- **Feature module** — owns the functions for one feature area.
- **⚠️ Band-aid / patch** — a fix file. Its *content* may be canonical (e.g. `fix-get-my-profile.sql`), but the file should be folded into its owner and retired.
- **⚠️ Admin bundle (retire)** — `admin_rpcs.sql`, which duplicates the feature files.
- **⚠️ Maintenance (drops)** — contains DROP statements; never run casually.

> A ⧉ next to a function means it is **also defined in another file** (a duplicate to be consolidated — see README).


## Summary table

| File | Status | # functions | # duplicated |
|---|---|---|---|
| `00-drop-functions.sql` | ⚠️ Maintenance (drops) | 0 | 0 |
| `01-schema.sql` | Core | 0 | 0 |
| `02-functions.sql` | Core | 45 | 38 |
| `03-seed.sql` | Core | 0 | 0 |
| `04-auth-triggers.sql` | Core | 2 | 1 |
| `05-diary.sql` | Core | 5 | 0 |
| `06-culinary-life.sql` | Core | 8 | 0 |
| `admin_rpcs.sql` | ⚠️ Admin bundle (retire) | 69 | 44 |
| `deactivate_account.sql` | Feature module | 3 | 3 |
| `email_templates.sql` | Feature module | 2 | 2 |
| `finance_tables.sql` | Feature module | 3 | 3 |
| `fix-get-my-profile.sql` | ⚠️ Band-aid / patch | 2 | 2 |
| `fix_anon_grants.sql` | ⚠️ Band-aid / patch | 0 | 0 |
| `fix_rls_recursion.sql` | ⚠️ Band-aid / patch | 1 | 1 |
| `grocery_list.sql` | Feature module | 2 | 0 |
| `library-profiles.sql` | Feature module | 6 | 0 |
| `library_rls.sql` | Feature module | 1 | 1 |
| `meal_planner.sql` | Feature module | 4 | 2 |
| `notification_rpcs.sql` | Feature module | 5 | 4 |
| `pantry.sql` | Feature module | 2 | 0 |
| `recipe_management.sql` | Feature module | 11 | 10 |
| `recipe_notes.sql` | Feature module | 3 | 0 |
| `setup-collections.sql` | Feature module | 9 | 9 |
| `setup-family-profiles.sql` | Feature module | 5 | 5 |
| `setup-notifications.sql` | Feature module | 7 | 7 |
| `setup-user-features.sql` | Feature module | 3 | 3 |
| `sm_compat_rpcs.sql` | Feature module | 3 | 0 |
| `sm_rpc_functions.sql` | Feature module | 11 | 0 |
| `sync-submitted-recipes-columns.sql` | ⚠️ Band-aid / patch | 0 | 0 |
| `table_planner.sql` | Feature module | 8 | 0 |
| `user_management.sql` | Feature module | 22 | 21 |

## Per-file detail

### `00-drop-functions.sql`
**Status:** ⚠️ Maintenance (drops)  
**Purpose:** Bulk DROP statements. Maintenance/reset only — review carefully before ever running.

_No `CREATE FUNCTION` statements (schema / data / policy / grants only)._

### `01-schema.sql`
**Status:** Core  
**Purpose:** Tables, types, and RLS enablement. The core schema.

_No `CREATE FUNCTION` statements (schema / data / policy / grants only)._

### `02-functions.sql`
**Status:** Core  
**Purpose:** Core auth/profile primitives + many RPCs. CLEANED copy — stale admin_get_users / admin_count_users blocks removed.

Functions defined: `is_admin` ⧉, `get_login_info`, `get_my_profile` ⧉, `update_my_profile` ⧉, `update_my_theme`, `update_my_preferences` ⧉, `deactivate_my_account` ⧉, `get_public_profile` ⧉, `get_my_submissions` ⧉, `get_approved_recipes` ⧉, `quick_update_recipe` ⧉, `admin_get_recipes` ⧉, `admin_get_stats` ⧉, `admin_review_recipe` ⧉, `admin_get_submitter`, `admin_get_analytics`, `admin_create_notification` ⧉, `admin_get_ingredients` ⧉, `admin_count_ingredients` ⧉, `admin_get_ingredient_units` ⧉, `admin_export_ingredients` ⧉, `admin_upsert_ingredient` ⧉, `admin_delete_ingredient` ⧉, `admin_bulk_update_field` ⧉, `admin_bulk_upsert_ingredients` ⧉, `admin_set_user_active`, `get_guest_card` ⧉, `submit_guest_dietary` ⧉, `get_my_collections` ⧉, `upsert_collection` ⧉, `delete_collection` ⧉, `add_to_collection` ⧉, `remove_from_collection` ⧉, `get_collection_recipes` ⧉, `get_recipe_collections` ⧉, `get_my_family_profiles` ⧉, `upsert_family_profile` ⧉, `delete_family_profile` ⧉, `get_notification_count` ⧉, `get_my_notifications` ⧉, `mark_notification_read` ⧉, `mark_all_notifications_read` ⧉, `get_page_settings`, `set_page_visibility`, `is_username_taken` ⧉

### `03-seed.sql`
**Status:** Core  
**Purpose:** Seed / reference data.

_No `CREATE FUNCTION` statements (schema / data / policy / grants only)._

### `04-auth-triggers.sql`
**Status:** Core  
**Purpose:** Auth triggers (e.g. handle_new_user) and username checks.

Functions defined: `is_username_taken` ⧉, `handle_new_user`

### `05-diary.sql`
**Status:** Core  
**Purpose:** Diary feature.

Functions defined: `get_my_diary_entries`, `search_my_diary`, `upsert_diary_entry`, `delete_diary_entry`, `get_diary_stats`

### `06-culinary-life.sql`
**Status:** Core  
**Purpose:** Culinary-life feature.

Functions defined: `log_cooking_event`, `get_culinary_life`, `get_family_favourites`, `get_culinary_timeline`, `get_year_in_review`, `get_recent_cooks`, `check_cooking_milestones`, `delete_cooking_event`

### `admin_rpcs.sql`
**Status:** ⚠️ Admin bundle (retire)  
**Purpose:** Large admin RPC bundle that duplicates the dedicated feature files. Slated to be retired during consolidation.

Functions defined: `is_admin` ⧉, `admin_get_stats` ⧉, `admin_get_recipes` ⧉, `admin_get_recipe_detail` ⧉, `admin_review_recipe` ⧉, `admin_edit_recipe` ⧉, `admin_feature_recipe` ⧉, `admin_set_recipe_of_week` ⧉, `admin_bulk_approve_recipes`, `admin_count_users` ⧉, `admin_get_users` ⧉, `admin_get_user_detail` ⧉, `admin_add_user_note` ⧉, `admin_award_badge` ⧉, `admin_remove_badge` ⧉, `admin_flag_user` ⧉, `admin_set_admin_status` ⧉, `admin_set_member_tier` ⧉, `admin_export_user_data`, `admin_get_user_analytics` ⧉, `admin_get_tier_stats` ⧉, `admin_count_pending_users` ⧉, `admin_get_inactive_users`, `admin_get_appeals`, `admin_review_appeal`, `admin_get_reports` ⧉, `admin_update_report` ⧉, `admin_get_recipe_requests` ⧉, `admin_update_recipe_request` ⧉, `admin_get_feedback` ⧉, `admin_update_feedback` ⧉, `admin_get_collections` ⧉, `admin_save_collection` ⧉, `admin_delete_collection` ⧉, `admin_log_action`, `admin_get_audit_log`, `admin_get_ingredients` ⧉, `admin_count_ingredients` ⧉, `admin_create_invite` ⧉, `admin_get_invites` ⧉, `admin_upsert_ingredient` ⧉, `admin_delete_ingredient` ⧉, `admin_export_ingredients` ⧉, `admin_get_ingredient_analytics`, `admin_get_ingredient_distinct_values`, `admin_get_ingredient_units` ⧉, `admin_get_pending_ingredients`, `admin_resolve_pending_ingredient`, `admin_clear_ingredient_category`, `admin_save_extra_fields`, `admin_delete_extra_field`, `admin_rename_extra_field`, `admin_get_deleted_extra_fields`, `admin_rename_reference_value`, `admin_get_brand_mappings`, `admin_upsert_brand_mapping`, `admin_save_brand`, `admin_delete_brand_mapping`, `admin_delete_all_brand_mappings`, `admin_bulk_upsert_brand_mappings`, `admin_sync_brands_from_ingredients`, `admin_bulk_award_badge`, `admin_bulk_update_field` ⧉, `admin_get_subscriptions` ⧉, `admin_bulk_upsert_ingredients` ⧉, `get_my_profile` ⧉, `admin_deactivate_user` ⧉, `admin_reactivate_user` ⧉, `queue_email` ⧉

### `deactivate_account.sql`
**Status:** Feature module  
**Purpose:** Account deactivation / reactivation RPCs.

Functions defined: `deactivate_my_account` ⧉, `admin_deactivate_user` ⧉, `admin_reactivate_user` ⧉

### `email_templates.sql`
**Status:** Feature module  
**Purpose:** Email template + queue_email functions.

Functions defined: `is_admin` ⧉, `queue_email` ⧉

### `finance_tables.sql`
**Status:** Feature module  
**Purpose:** Subscription / tier tables and finance admin RPCs.

Functions defined: `admin_get_tier_stats` ⧉, `admin_set_member_tier` ⧉, `admin_get_subscriptions` ⧉

### `fix-get-my-profile.sql`
**Status:** ⚠️ Band-aid / patch  
**Purpose:** PATCH file — but holds the LIVE get_my_profile (with ::text casts). Content is canonical; fold into owner then retire the file.

Functions defined: `get_my_profile` ⧉, `update_my_profile` ⧉

### `fix_anon_grants.sql`
**Status:** ⚠️ Band-aid / patch  
**Purpose:** PATCH — grants for the anon role. Review.

_No `CREATE FUNCTION` statements (schema / data / policy / grants only)._

### `fix_rls_recursion.sql`
**Status:** ⚠️ Band-aid / patch  
**Purpose:** PATCH — is_admin() + an RLS policy to break recursion. Contains an is_admin copy AND a live policy; review carefully.

Functions defined: `is_admin` ⧉

### `grocery_list.sql`
**Status:** Feature module  
**Purpose:** Grocery list feature.

Functions defined: `get_my_grocery_list`, `save_my_grocery_list`

### `library-profiles.sql`
**Status:** Feature module  
**Purpose:** Library contributor profiles.

Functions defined: `update_updated_at_column`, `get_library_directory`, `get_library_profile`, `admin_get_library_profiles`, `admin_publish_library_profile`, `admin_delete_library_profile`

### `library_rls.sql`
**Status:** Feature module  
**Purpose:** Library RLS policies (and an is_admin copy).

Functions defined: `is_admin` ⧉

### `meal_planner.sql`
**Status:** Feature module  
**Purpose:** Meal planner feature.

Functions defined: `get_approved_recipes` ⧉, `get_my_family_profiles` ⧉, `save_my_meal_plan`, `get_my_meal_plan`

### `notification_rpcs.sql`
**Status:** Feature module  
**Purpose:** Notification RPCs. Canonical owner for notifications.

Functions defined: `get_notification_count` ⧉, `get_my_notifications` ⧉, `mark_notification_read` ⧉, `mark_all_notifications_read` ⧉, `send_notification`

### `pantry.sql`
**Status:** Feature module  
**Purpose:** Pantry feature.

Functions defined: `save_my_pantry`, `get_my_pantry`

### `recipe_management.sql`
**Status:** Feature module  
**Purpose:** Recipe admin / review RPCs. Canonical owner for recipe admin.

Functions defined: `touch_updated_at`, `admin_get_recipes` ⧉, `admin_get_recipe_detail` ⧉, `admin_review_recipe` ⧉, `admin_edit_recipe` ⧉, `admin_feature_recipe` ⧉, `admin_set_recipe_of_week` ⧉, `admin_get_stats` ⧉, `admin_get_collections` ⧉, `admin_save_collection` ⧉, `admin_delete_collection` ⧉

### `recipe_notes.sql`
**Status:** Feature module  
**Purpose:** Recipe personal-notes feature.

Functions defined: `get_my_recipe_note`, `admin_get_pending_notes`, `admin_review_note`

### `setup-collections.sql`
**Status:** Feature module  
**Purpose:** Collections feature. Canonical owner for collections.

Functions defined: `get_my_collections` ⧉, `upsert_collection` ⧉, `delete_collection` ⧉, `add_to_collection` ⧉, `remove_from_collection` ⧉, `get_collection_recipes` ⧉, `get_recipe_collections` ⧉, `quick_update_recipe` ⧉, `get_public_profile` ⧉

### `setup-family-profiles.sql`
**Status:** Feature module  
**Purpose:** Family / guest profiles. Canonical owner for family/guest.

Functions defined: `get_my_family_profiles` ⧉, `upsert_family_profile` ⧉, `delete_family_profile` ⧉, `get_guest_card` ⧉, `submit_guest_dietary` ⧉

### `setup-notifications.sql`
**Status:** Feature module  
**Purpose:** Notifications setup — duplicates notification_rpcs.sql; consolidate.

Functions defined: `get_notification_count` ⧉, `get_my_notifications` ⧉, `mark_notification_read` ⧉, `mark_all_notifications_read` ⧉, `admin_create_notification` ⧉, `get_my_profile` ⧉, `update_my_preferences` ⧉

### `setup-user-features.sql`
**Status:** Feature module  
**Purpose:** User features (submissions etc.) — some duplicates with 02-functions.

Functions defined: `get_my_submissions` ⧉, `get_approved_recipes` ⧉, `deactivate_my_account` ⧉

### `sm_compat_rpcs.sql`
**Status:** Feature module  
**Purpose:** Site-management compatibility RPCs.

Functions defined: `admin_save_announcement`, `admin_update_site_page`, `search_ingredients`

### `sm_rpc_functions.sql`
**Status:** Feature module  
**Purpose:** Site-management RPCs.

Functions defined: `admin_get_site_pages`, `admin_save_site_page`, `admin_get_site_features`, `admin_toggle_site_feature`, `admin_get_announcements`, `admin_add_announcement`, `admin_delete_announcement`, `admin_get_site_settings`, `admin_save_site_setting`, `admin_get_email_templates`, `admin_save_email_template`

### `sync-submitted-recipes-columns.sql`
**Status:** ⚠️ Band-aid / patch  
**Purpose:** PATCH — column sync for submitted_recipes. Review.

_No `CREATE FUNCTION` statements (schema / data / policy / grants only)._

### `table_planner.sql`
**Status:** Feature module  
**Purpose:** Table planner / events / guests. Canonical owner for table planner.

Functions defined: `get_my_events`, `upsert_event`, `delete_event`, `get_event_guests`, `upsert_guest`, `delete_guest`, `assign_seat`, `save_event_layout`

### `user_management.sql`
**Status:** Feature module  
**Purpose:** User admin RPCs. Canonical owner for user management (includes the live admin_get_users / admin_count_users).

Functions defined: `is_admin` ⧉, `admin_get_users` ⧉, `admin_count_users` ⧉, `admin_get_user_detail` ⧉, `admin_deactivate_user` ⧉, `admin_reactivate_user` ⧉, `admin_award_badge` ⧉, `admin_remove_badge` ⧉, `admin_add_user_note` ⧉, `admin_flag_user` ⧉, `admin_set_admin_status` ⧉, `admin_get_invites` ⧉, `admin_create_invite` ⧉, `admin_count_pending_users` ⧉, `admin_get_user_analytics` ⧉, `admin_get_reports` ⧉, `admin_update_report` ⧉, `admin_get_recipe_requests` ⧉, `admin_update_recipe_request` ⧉, `admin_get_feedback` ⧉, `admin_update_feedback` ⧉, `update_avatar_url`
