ARCHIVED SQL — do not run on production unless you know why.

These files are superseded by RUN-IN-SUPABASE-copy-paste-this.sql,
RUN-LIVE-CLEANUP.sql, or feature-owner modules in database/sql/.

Files:
  RUN-IN-SUPABASE-phases-39-40-ONLY.sql — partial snapshot; missing phases 41-43
  admin_rpcs.sql — duplicate admin bundle; functions live in feature modules
  setup-notifications.sql — duplicate of notification_rpcs.sql
  setup-user-features.sql — folded into 01-schema.sql + 03-seed.sql

Regenerate archived 39-40 bundle (dev only):
  python database/sql/_bundle_phases_only.py
