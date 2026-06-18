# TCJ Security Audit — RLS & SECURITY DEFINER RPCs

**Date:** 2026-06-17  
**Canonical deploy:** `database/full-setup.sql`  
**Live patches:** `database/sql/fix-security-rpcs.sql`, `database/sql/fix-login-info-leak.sql`  
**Re-run audit:** `python database/security/audit_rls_rpcs.py`

---

## External audit crosswalk (2026-06-17)

| # | Finding | Status | Action |
|---|---------|--------|--------|
| 1 | SSRF in `/api/fetch-recipe-url.js` | **Fixed (deploy)** | `lib/ssrf-guard.js`: DNS resolve, block private/metadata/loopback, manual redirect re-check; session required via `verifySupabaseSession`; client sends Bearer in `submit-recipe-url-import.js` |
| 2 | `get_login_info` leaks `is_admin` to anon | **Fixed (run SQL)** | `is_admin` removed from return; `REVOKE PUBLIC`; canonical + `fix-login-info-leak.sql`; login uses generic “invalid credentials” message |
| 3 | XSS — sparse `escapeHtml` vs innerHTML sinks | **Partial** | Hotspots fixed in `recipe-page.html` (collections, related recipes, error text); ~800+ sinks remain — DOMPurify sweep still recommended |
| 4 | Client email admin fallback | **Fixed** | Removed in commit `33460cf`; `isTcjAdmin()` = DB flag only |
| 5 | RLS + SECURITY DEFINER boundary | **Documented** | 78 admin RPCs checked; anon key by design; no service-role in repo |
| 6 | Stripe webhook swallows RPC errors | **Fixed (deploy edge fn)** | `stripe-webhook/index.ts` returns 500 on RPC failure so Stripe retries; **`apply_stripe_subscription` idempotency** — run `fix-category-cleanup-v3.sql` on production |
| 7 | Function ownership drift (duplicate SQL defs) | **Open** | Ledger rule exists; dedupe `admin_edit_recipe`, garden RPCs across files |
| 8 | Dropped “Admin can read all profiles” policy | **Clarified** | Comment in `01-schema.sql`: intentional; admin reads via SECURITY DEFINER RPCs |
| 9 | Archive SQL footgun | **Open** | Move `database/sql/archive/` out of working tree or add CI guard |
| 10 | Very large single files | **Open** | Review fatigue risk at approval gate |
| 11 | Thin automated testing | **Open** | Only import-tests CI; add RLS/RPC regression harness |
| 12 | Core journeys unverified on live | **Operational** | `Lane2_Verification_Log.txt` spot-checks still unchecked |
| 13 | Monetisation half-built | **Operational** | Stripe code present; tier model / Print Studio checkout decision open |
| 14 | Legal pages unreviewed | **Operational** | Drafts awaiting lawyer |

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
- **Returns:** email, username, `is_active`, `account_status` ( **`is_admin` removed** )
- **Risk:** User enumeration remains (email/username lookup) — mitigated with generic login error copy
- **Status:** **Fixed in repo** — run `database/sql/fix-login-info-leak.sql` on production
- **Used by:** login flow (email resolution before password sign-in)

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

1. ~~Run `fix-security-rpcs.sql` on production Supabase~~ ✓ (Betty confirmed applied)
2. **Run `fix-login-info-leak.sql` on production Supabase**
3. **Deploy** `api/fetch-recipe-url.js` + `lib/ssrf-guard.js` (Vercel) and redeploy `stripe-webhook` edge function
4. Compare live `pg_proc` list vs this doc (especially garden + archived admin RPCs)
5. Harden guest dietary submit (expiry / one-time)
6. Add `REVOKE ALL ON FUNCTION … FROM PUBLIC` sweep for all SECURITY DEFINER functions
7. Make `apply_stripe_subscription` idempotent (skip if `stripe_session_id` already completed)
8. XSS sweep — DOMPurify or systematic `escapeHtml` on remaining innerHTML sinks
9. Fold live-only SQL into manifest or regenerate `full-setup.sql` after changes

---

## Top 10 review queue

| # | Item | Severity |
|---|------|----------|
| 1 | `get_login_info` anon + `is_admin` in response | CRITICAL (**fixed — run SQL**) |
| 2 | `submit_guest_dietary` anon write | CRITICAL |
| 3 | SSRF `/api/fetch-recipe-url` | CRITICAL (**fixed — deploy**) |
| 4 | XSS innerHTML sinks | HIGH (**partial**) |
| 5 | Stripe webhook silent RPC failure | HIGH (**fixed — deploy edge fn**) |
| 6 | `admin_get_submitter` caller check | HIGH (fixed) |
| 7 | `send_notification` PUBLIC grant | HIGH (fixed) |
| 8 | `repair_orphan_recipe_ingredients` no auth | HIGH (fixed) |
| 9 | Ingredient admin RPCs outside full-setup | HIGH |
| 10 | Garden RPCs outside full-setup | HIGH |
