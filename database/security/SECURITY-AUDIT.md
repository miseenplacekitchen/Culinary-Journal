# TCJ Security Audit — RLS & SECURITY DEFINER RPCs

**Date:** 2026-06-17  
**Canonical deploy:** `database/full-setup.sql`  
**Live patch:** `database/sql/fix-security-rpcs.sql`  
**Re-run audit:** `python database/security/audit_rls_rpcs.py`

---

## How TCJ security works

| Layer | Role |
|--------|------|
| **Anon key in `supabase-config.js`** | Expected for static SPAs — not a secret |
| **RLS policies** | Row-level gate on tables |
| **`SECURITY DEFINER` RPCs** | Bypass RLS for scoped reads/writes — must self-guard |
| **`is_admin()`** | Server truth: `profiles.is_admin` for `auth.uid()` only |
| **Client `is_admin` in localStorage** | UI only — must come from `fetchTcjIsAdmin()` / `get_my_profile`, never email fallback |

**Service role key must never appear in client code.** ✓ Not present in repo.

---

## Inventory (`full-setup.sql`)

| Metric | Count |
|--------|------:|
| `SECURITY DEFINER` functions | **99** |
| Tables with RLS enabled | **~32** |
| Policies (static + dynamic + storage) | **~80** |

---

## CRITICAL — fix before scale

### 1. `get_login_info(text)` — anon granted, no session

- **Grants:** `anon`, `authenticated`
- **Returns:** email, username, `is_active`, **`is_admin`** for matching identifier
- **Risk:** User enumeration + admin-flag leak
- **Status:** Documented — needs product decision (CAPTCHA Edge Function, rate limit, or remove `is_admin` from response)
- **Used by:** login flow

### 2. `submit_guest_dietary(uuid, jsonb)` — anon write by UUID

- **Grants:** `anon`, `authenticated`
- **Mutates:** `event_guests.dietary` with no session
- **Risk:** Anyone with guest link UUID can overwrite dietary data
- **Status:** Intentional for guest cards — add `expires_at`, one-time submit lock, or signed tokens

---

## HIGH — patched in `fix-security-rpcs.sql`

| Item | Issue | Fix |
|------|--------|-----|
| **`admin_get_submitter`** | Any authenticated user could probe admin UUIDs and read admin emails | Caller `is_admin()` guard added |
| **`send_notification`** | No explicit `REVOKE PUBLIC` | `REVOKE ALL FROM PUBLIC` + `GRANT authenticated` |
| **`repair_orphan_recipe_ingredients`** | Bulk mutates approved recipes, no auth (live scripts) | Admin guard + revoke public |

Run in Supabase:

```sql
-- paste database/sql/fix-security-rpcs.sql
```

---

## HIGH — still open (manual review)

| Item | Notes |
|------|--------|
| **Ingredient admin RPCs** | 30+ functions in `database/sql/archive/admin_rpcs.sql` — not in `full-setup.sql` |
| **Garden RUN-GARDEN-*.sql** | 20+ SECURITY DEFINER RPCs deployed separately |
| **`get_collection_recipes`** | Anon read may expose non-approved `status` on public collections |
| **Missing `REVOKE PUBLIC`** | Many authenticated-only RPCs rely on default PUBLIC execute |

---

## Admin RPCs — `is_admin()` on caller

~55 admin functions in canonical deploy correctly use `IF NOT is_admin()`.

**Exception (fixed):** `admin_get_submitter` — previously checked target user's admin flag, not caller.

---

## Anon-readable RPCs (intentional public read)

| Function | Guard |
|----------|--------|
| `get_public_profile` | Active users only |
| `get_approved_recipes` | `status = approved` AND visibility public |
| `get_public_recipe` | Owner / admin / approved+public |
| `get_guest_card` | UUID bearer token |
| `get_page_settings` | Public site config |
| `is_username_taken` | Signup enumeration |
| `get_library_directory` / `get_library_profile` | Published only |
| `search_ingredients` | Read-only |
| `get_recipe_taxonomy` | Active taxonomy rows |

---

## Client admin auth (2026-06-17 change)

**Removed:** Email fallback `miseenplacekitchen.official@gmail.com` in `isTcjAdmin()`.

**Now:**

- `isTcjAdmin(profile)` → `profile.is_admin === true` only (cached)
- `fetchTcjIsAdmin(session)` → calls RPC `is_admin()` (server truth)
- Login / nav / dashboard call `fetchTcjIsAdmin` after `get_my_profile`
- `page-guard.js` re-checks server admin if cache says non-admin

**DB:** Your account should have `profiles.is_admin = true` (set in `full-setup.sql` seed).

---

## Recommended next steps

1. Run `fix-security-rpcs.sql` on production Supabase
2. Compare live `pg_proc` list vs this doc (especially garden + archived admin RPCs)
3. Decide on `get_login_info` response shape (drop `is_admin` from anon path)
4. Harden guest dietary submit (expiry / one-time)
5. Add `REVOKE ALL ON FUNCTION … FROM PUBLIC` sweep for all SECURITY DEFINER functions
6. Fold live-only SQL into manifest or regenerate `full-setup.sql` after changes

---

## Top 10 review queue

| # | Item | Severity |
|---|------|----------|
| 1 | `get_login_info` anon + `is_admin` in response | CRITICAL |
| 2 | `submit_guest_dietary` anon write | CRITICAL |
| 3 | `admin_get_submitter` caller check | HIGH (fixed) |
| 4 | `send_notification` PUBLIC grant | HIGH (fixed) |
| 5 | `repair_orphan_recipe_ingredients` no auth | HIGH (fixed) |
| 6 | Ingredient admin RPCs outside full-setup | HIGH |
| 7 | Garden RPCs outside full-setup | HIGH |
| 8 | `get_collection_recipes` status leak | MEDIUM |
| 9 | PUBLIC execute on authenticated RPCs | MEDIUM |
| 10 | RLS policy drift across phase SQL files | LOW |
