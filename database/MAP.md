# Database Map — The Culinary Journal

Single reference for schema, features, and where each RPC lives.  
**Machine-readable source:** `manifest.json`  
**One-shot deploy:** `full-setup.sql` (regenerate with `python build-setup.py`)

---

## How to deploy (no more manual script hunting)

1. Open **Supabase Dashboard → SQL Editor**
2. Paste the entire contents of `database/full-setup.sql`
3. Run once on a **fresh** project (or after review on staging)
4. For future schema changes: edit the **owning file** in `sql/`, run `python build-setup.py`, commit, and apply only the changed section to live DB

---

## Layers (run order)

| # | File | Domain | What it owns |
|---|------|--------|--------------|
| 1 | `01-schema.sql` | Core schema | `profiles`, `submitted_recipes`, `ingredients`, `events`, `collections`, RLS, storage |
| 2 | `sync-submitted-recipes-columns.sql` | Patch | Column guards for `submitted_recipes` |
| 3 | `02-functions.sql` | Core RPCs | Auth, profile, collections read, notifications read, page settings, `is_admin` |
| 4 | `03-seed.sql` | Seed | Substitutions, page settings, admin bootstrap |
| 5 | `04-auth-triggers.sql` | Auth | `handle_new_user` trigger |
| 6 | `05-diary.sql` | Diary | `diary_entries` + diary RPCs |
| 7 | `06-culinary-life.sql` | Culinary Life | `cooking_events`, milestones, timeline RPCs |
| 8 | `table_planner.sql` | Table Planner | `events`, `event_guests`, seating RPCs |
| 9 | `setup-collections.sql` | Collections | Collection CRUD RPCs |
| 10 | `setup-family-profiles.sql` | Family / Guest | Family profiles + dietary card RPCs |
| 11 | `notification_rpcs.sql` | Notifications | `send_notification` + delivery RPCs |
| 12 | `recipe_management.sql` | Recipe Admin | Review, feature, draft, collection admin RPCs |
| 13 | `user_management.sql` | User Admin | Users, badges, reports, invites, feedback RPCs |
| 14 | `recipe_notes.sql` | Recipe Notes | Personal/public note RPCs |
| 15 | `grocery_list.sql` | Grocery | `grocery_lists` RPCs |
| 16 | `pantry.sql` | Pantry | `pantry` RPCs |
| 17 | `meal_planner.sql` | Meal Planner | `meal_plans` RPCs |
| 18 | `library-profiles.sql` | Library | Ingredient/spice/tool/cut/preservation profiles |
| 19 | `library_rls.sql` | Library RLS | Library access policies |
| 20 | `email_templates.sql` | Email | `email_templates`, `email_queue`, `queue_email` |
| 21 | `finance_tables.sql` | Finance | `member_subscriptions`, tier RPCs |
| 22 | `sm_rpc_functions.sql` | Site Mgmt | Pages, features, announcements, settings RPCs |
| 23 | `sm_compat_rpcs.sql` | Site Mgmt | Compatibility RPCs (`search_ingredients`, etc.) |
| 24 | `fix_rls_recursion.sql` | Patch | RLS recursion fix |
| 25 | `fix_anon_grants.sql` | Patch | Anon role grants |

---

## Archived (do not run)

Moved to `sql/archive/` — see `manifest.json` → `archived`:

- `00-drop-functions.sql` — bulk DROP maintenance only
- `admin_rpcs.sql` — retired duplicate admin bundle
- `setup-notifications.sql` — superseded by `notification_rpcs.sql`
- `setup-user-features.sql` — superseded by schema + seed
- `deactivate_account.sql` — superseded by `02-functions.sql` + `user_management.sql`

---

## Function ownership (canonical)

Each RPC should be edited in **one file only**. Key owners:

| Function | Owner file |
|----------|------------|
| `get_my_profile`, `update_my_profile`, `is_admin` | `02-functions.sql` |
| `admin_get_users`, `admin_count_users` | `user_management.sql` |
| `admin_get_recipes`, `admin_review_recipe` | `recipe_management.sql` |
| `get_my_collections`, `upsert_collection` | `setup-collections.sql` |
| `get_my_family_profiles`, `get_guest_card` | `setup-family-profiles.sql` |
| `get_my_events`, `upsert_event` | `table_planner.sql` |
| `get_library_directory` | `library-profiles.sql` |
| `queue_email` | `email_templates.sql` |

Full map: `manifest.json` → `function_owners`

---

## Folder layout

```
database/
├── MAP.md              ← this file (human map)
├── manifest.json       ← machine map + run order
├── full-setup.sql      ← generated one-shot setup (commit this)
├── build-setup.py      ← regenerate full-setup.sql
├── README.md
├── INDEX.md
└── sql/
    ├── 01-schema.sql … (canonical modules)
    └── archive/        ← deprecated files (DO NOT RUN)
```
