# Workers testing

Read the general [testing](../../typescript-standards/references/testing.md) reference first. This reference adds the rules for workerd, bindings, and Hyperdrive.
A project testing document records only its exceptions, each with a reason.

## Runtime

Run integration tests in workerd with `cloudflareTest` from `@cloudflare/vitest-plugin`. Point it at a test `wrangler.jsonc`.
Import bindings as `env` or `exports` from `cloudflare:workers`. `env` and `SELF` from `cloudflare:test` are deprecated.
Vitest always uses local simulations of bindings, never remote resources.

## Entrypoints

- **Application:** one fixture module imports the Worker and creates execution contexts. Tests call its methods for fetch, server functions, queues, and scheduled events. Lint blocks Worker imports in other test files.
- **Library:** test each adapter against the real binding through `env`.

The entrypoint fixture waits for `waitUntil` work before it returns, also when the Worker throws.
A background rejection then fails the test that caused it, not a later test.

Miniflare cannot list queued messages. Record them with a fake producer.
Run a consumer with `createMessageBatch` and `getQueueResult` from `cloudflare:test`.

## State

The automatic `clean` fixture calls `reset()` from `cloudflare:test`. It clears KV, R2, Durable Objects, and rate limits.
Apply D1 migrations in a setup file with `readD1Migrations` and `applyD1Migrations`.

Postgres through Hyperdrive:

1. `globalSetup` creates the test database, resets the schema, runs the migrations, and provides the URLs.
2. The base `test` checks that Hyperdrive and the test point at the same database before it empties any table.
3. postgres.js clients in workerd never end. When one runner serves many invocations, add `idle_timeout` to the Hyperdrive URL, or the run uses all connections.

A `clock` fixture changes `Date` in the Worker only. Postgres `now()` keeps real time.

## Network fakes

Use `setupNetwork()` from `@msw/cloudflare` in workerd, and `msw/node` in Node unit tests.
Create one network per test file as a module constant. Set `onUnhandledFrame: "error"`.
Reset its handlers in the `clean` fixture.

## Speed

Each test file gets its own isolated runtime by default. Module loading then repeats for every file.
For a full application, `isolate: false` with `fileParallelism: false` loads modules once per run. Module state and background work then reach the next file.
Choose this mode only with timing evidence, and record the numbers in the project testing document.
Do not add workers to that mode until you measure it: one Vite process serves the modules of every worker.
