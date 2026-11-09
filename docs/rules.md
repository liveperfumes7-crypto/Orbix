# Rules enforced on the server
All rules live in Postgres (RLS + security-definer RPCs + triggers). The app only displays what `my_status()` returns.
- **Attribution:** ads vs organic is set once at first open (`record_install`) and cannot change, even for admins.
- **Audiences:** posts/channels have an audience (all / ads / organic); RLS hides what a user may not see. Hidden content is never returned.
- **Quota:** guest 0 · free mode or Play-verified 15 GB · active plan 2 TB. Uploads check `used_bytes + size ≤ quota` in RLS and again in `finalize`.
- **Media:** private buckets, short-lived signed URLs. Full premium video needs a plan (or full access in free mode); trailers/thumbnails are open.
- **Channels:** created as pending, visible only to the creator until the owner approves; consent required before the first post.
- **Profiles:** users cannot change `used_bytes`, `is_guest`, `play_verified`.
- **Tests:** `supabase/tests/*.sql` (64 + 57 checks) run in CI against a fresh database.
