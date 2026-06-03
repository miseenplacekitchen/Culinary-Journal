# Database SQL Source

This folder is the **single source of truth** for The Culinary Journal's Supabase SQL — schema, functions (RPCs), triggers, policies, and seed data. It exists so every change is tracked in version control and old/stale SQL cannot be reintroduced by accident.

---

## ⚠️ READ FIRST — nothing here runs automatically

**These files are version-controlled source only. Committing or uploading them to GitHub does NOT execute them and does NOT change the live Supabase database.** SQL only runs when it is deliberately pasted into the Supabase SQL editor and executed by hand.

To keep it that way:

- **Do not** put SQL in a folder named `supabase/migrations/`. Supabase's GitHub integration auto-applies that exact folder. This project keeps SQL in `database/sql/` precisely so it stays inert.
- **Do not** run whole files against the live database. The live database is changed only through small, targeted statements (a single `CREATE OR REPLACE FUNCTION`, or a single signature-specific `DROP FUNCTION`), reviewed before running.
- **Never** run a broad file such as `02-functions.sql` or `00-drop-functions.sql` against the live database. They contain bulk drops and many definitions; running them can wipe and recreate functions and revert fixes.

---

## What this folder is — and isn't

**It is:** a complete, tracked snapshot of the SQL that defines the database, plus a manifest (`INDEX.md`) describing each file's status and the functions it owns.

**It is not:** an auto-deploy pipeline, a migrations system, or a guarantee that the files exactly match the live database at any instant. The live database is the running system; this folder is the record of intent and the place changes are authored and reviewed before being applied by hand.

---

## Folder layout

```
database/
├── README.md      ← this file
├── INDEX.md        ← manifest: every file, its status, the functions it defines
└── sql/
    ├── 01-schema.sql
    ├── 02-functions.sql      ← cleaned copy (stale admin_get_users / admin_count_users removed)
    ├── 04-auth-triggers.sql
    ├── user_management.sql
    ├── recipe_management.sql
    ├── ... (all current SQL files)
    └── archive/    ← (added later) superseded files, each marked "DO NOT RUN"
```

The HTML / JS / CSS web app stays at the repository root, untouched. SQL lives only under `database/`.

---

## How a future SQL change is made (the workflow)

1. **Edit the owning file** in `database/sql/` (see `INDEX.md` for which file owns which function). One function lives in exactly one file.
2. **Commit it** to GitHub with a short message describing the change. This is the tracked record.
3. **Apply it to the live database by hand:** copy the single changed statement into the Supabase SQL editor and run it. Use a targeted `CREATE OR REPLACE FUNCTION` (and, if removing a signature, a specific `DROP FUNCTION ...(exact args)`) — never the whole file.
4. **Verify** the result (a read-only catalog query and/or the affected page in the browser).
5. If anything is wrong, the previous version is in Git history and can be restored.

The GitHub file and the live database are kept in step manually. The file is what we review and trust; the database is what we apply it to.

---

## Single source of truth & preventing reintroduction of old SQL

- `INDEX.md` names the **canonical owner file** for each function. Only the owner's definition is authoritative.
- Files marked **⚠️ Band-aid / patch** or **⚠️ Admin bundle (retire)** in `INDEX.md` are scheduled to be folded into their owners and then moved to `sql/archive/` with a `-- DEPRECATED — DO NOT RUN` header.
- Because every change is a tracked commit, a stale definition can't quietly reappear: reintroducing it would show up as a diff in review.

---

## Current status

This is the **initial baseline snapshot** — a complete, honest copy of the SQL as it exists today, *including* the duplicate and band-aid files, because some "fix-" files currently hold the live, correct version of a function (for example, `fix-get-my-profile.sql` holds the live `get_my_profile`). Removing them prematurely would make the source of truth incomplete.

**Consolidation comes next, as small reviewed commits** — one function (or one small group) at a time, applied with the same care as the live database fixes: read first, smallest change, verify, then commit. The de-duplication plan is the function ownership map produced during the audit.

Known items to work through (see `INDEX.md` for specifics):

- ~69 functions are defined in more than one file (duplicates to consolidate to a single owner).
- `02-functions.sql` still uses a "drop every signature, then recreate" pattern for some functions (e.g. `get_my_profile`); the admin user functions were already cleaned, the rest are pending review.
- `admin_bulk_update_field` is a **name collision** — two different functions (one for ingredients, one for users) share a name; this needs a rename, not a delete.
- `admin_rpcs.sql` duplicates the dedicated feature files and is slated to be retired.

---

## Note on completeness

This snapshot was assembled from the current SQL file set (31 files). Before relying on `database/sql/` as the *complete* source of truth, confirm there is no other SQL kept elsewhere (other Supabase snippets, older exports, etc.). Anything found should be added here so the folder is genuinely complete.
