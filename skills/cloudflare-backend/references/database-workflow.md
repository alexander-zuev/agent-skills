# Database Workflow

`[detect wrangler.jsonc]`: `d1_databases` → **D1 + Drizzle**; `hyperdrive` → **Postgres + Drizzle via Hyperdrive**. Wrong detection = wrong migration commands, query tooling, and test setup.

### Common

- Code-first: schema in `.ts`, Drizzle is the source of truth. Schema + migrations live in the app.
- Change the Drizzle `schema.ts` first, then run the project's `db:generate` script. Never write a normal schema migration before its schema change.
- Edit migration SQL directly only for a custom migration or to fix a verified Drizzle generation defect. Keep the corrected unapplied migration and its metadata in place.
- Migrations are plain drizzle-kit `.sql` files with auto-generated names (`0004_noisy_mephistopheles.sql`) — sequential prefixes, generated suffixes. State the migration's intent in a leading SQL comment.
- Scripts: `pnpm db:generate` (+ `db:generate:custom` for hand-written SQL), `pnpm db:migrate:<env>`.
- better-auth tables come from the `better-auth-generate` script → generated schema file; regenerate, never hand-edit.

### D1

- Apply: `wrangler d1 migrations apply <BINDING>` per env (wrapped in `db:migrate:*` scripts).
- Query: `wrangler d1 execute <db-name> --local --command "<q>"`; `--env <env> --remote` for deployed DBs.
- Before each data migration, check the current official D1 limits and migration guidance. Do not rely on stored limits.
- Cloudflare currently gives 1,000 rows as an example batch size. Select the batch size only after the current docs and production row size confirm it.
- Never rebuild a large D1 table in one statement. Prefer native `ALTER TABLE` operations or a separate bounded batch script.

### Postgres + Hyperdrive

- Local: Docker Postgres from the repo's `db/` dir (custom image may add `pg_cron`/`pg_squeeze`; init SQL creates the app role and a test DB). `pnpm db:start` / `db:stop` / `db:reset`; Drizzle Studio via `db:studio:<env>`.
- Driver: `postgres` (postgres.js). Two DB users: superuser for DDL/migrations, app role for runtime DML.
- Prod: managed Postgres (e.g. PlanetScale) — identify the provider from `hyperdrive.origin`; query via the provider's CLI/MCP.
- Drizzle env selection: `DRIZZLE_ENV` + dotenvx-encrypted env files.
- Tests hit real local Postgres via `localConnectionString` in wrangler.jsonc (Hyperdrive doesn't exist in Vitest).

### Migration rules

1. **Never modify an applied migration** — immutable once run in any environment; fix forward with a new one and document why.
2. Check what's applied before changing anything.
3. Review every generated SQL statement before applying it. Drizzle can generate incorrect SQLite and PostgreSQL migrations.
4. Fix an incorrect unapplied migration in place. Do not delete and regenerate it; preserve its journal entry and snapshot.
5. Add a `database-migration` test for each data migration or table rebuild. Run the real SQL against the prior schema and representative rows.
6. Verification `SELECT`s after data-changing migrations, in the same file.
7. **Schema additions before backfills before NOT NULL** — three separate migrations.

### Database constraint ownership

- Database constraints protect storage integrity and invariants that require atomic enforcement under concurrent writes.
- Use primary keys, foreign keys, uniqueness, required columns, and focused numeric or accounting constraints.
- Domain models own valid state combinations, state transitions, status-specific fields, reason rules, and product policy.
- Never encode a complete domain state machine or product policy list in SQL constraints.
- Repository mappers convert database rows to plain domain data. They do not parse or validate domain rules.
