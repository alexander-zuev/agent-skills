# Testing

This reference is the default for every project. A project testing document records only its exceptions, each with a reason.
For query and component tests, also read [tanstack-frontend](../../tanstack-frontend/SKILL.md).
For workerd, bindings, and Hyperdrive, also read the backend [Workers testing](../../cloudflare-backend/references/testing.md) reference.

## What to test

Keep each test within 10–15 lines. Prefer critical behavior coverage over test count.
Never add a test only to raise coverage.

Report new tests separately from existing suite results. State which changed behavior the new tests prove.
A passing suite does not prove behavior it never exercises.

Add an end-to-end test whenever the behavior can be exercised through its real public entrypoint in the normal test environment without unreliable third parties or unreasonable setup, runtime, or cost. Add lower-level tests when they provide extra coverage for important cases.

Prefer confidence-oriented tests:

1. end-to-end tests through real public entrypoints whenever possible
2. integration tests through real seams
3. focused/property tests for pure Domain Modules
4. unit tests when they test meaningful behavior, not implementation details

Prefer tests that assert observable input/output behavior:

- returned value/error
- persisted state
- emitted event/message
- rendered response
- sent email record in a fake/local adapter

Avoid spy-driven tests like `expect(sendEmail).toHaveBeenCalledWith(...)` unless the interaction itself is the only observable behavior.

## Layout

Each test folder maps to one runtime:

| Folder               | Runtime                       | Tests                                                 |
| -------------------- | ----------------------------- | ----------------------------------------------------- |
| `tests/unit/`        | Node, no I/O                  | Domain Modules, parsers, adapters with a scripted SDK |
| `tests/browser/`     | Real browser                  | Components and hooks                                  |
| `tests/integration/` | Production runtime + database | Entrypoints, database, bindings                       |
| `tests/fakes/`       | —                             | One fake per external provider                        |
| `tests/data/`        | —                             | Plain test data with no I/O, shared by all projects   |

No test project runs a file in the `tests/` root. Lint rejects it.
Use Pytest fixtures for Python.

## Fixtures

Each project with I/O has one base `test`, built with `test.extend`. Its tests import that `test`, never `test` from `vitest`.
Assert with `expect` from `vitest`. Use Vitest's `assert` only where TypeScript must narrow a value. Never use `node:assert`.

Create scenario data through public code paths: the real API, parsers, or the library's official test helpers.
Tests must not bypass parsers, smart constructors, or invariants.
Keep a scenario fixture in its test file. Move it to `fixtures/` when a second file needs it.

## State and isolation

Every test passes alone, repeated, and in any order.

1. Reset shared state **before** each test, in an automatic fixture. The reset covers database rows, provider fakes, and bindings.
2. Never delete rows in teardown. A failed test then cannot affect the next one. A test may still delete data when deletion is the scenario.
3. Prepare expensive resources once per run in `globalSetup`: create the database, run the migrations, and `provide` the connection values.
4. Take a lock in `globalSetup`, so two runs on one machine cannot reset each other. Give each git worktree its own database.
5. Background work that the code under test starts finishes inside that test. A fixture waits for it before the test ends.
6. Tests share no mutable module state.

When SQL, schema, or transactions matter, test against the production database engine on a local instance. Do not replace it with an in-memory fake.

## Fakes

Never use `vi.mock`, `jest.mock`, or `vi.stubGlobal`. Use real seams:

- constructor-injected interfaces/classes
- Effect services/layers
- in-memory adapters when behavior is simple
- fake external adapters when needed

Fake an HTTP provider at the network with MSW. The real SDK and adapter run, and production code does not change for tests.
Configure MSW so that a request with no handler fails the test.
Keep one fake per provider in `tests/fakes/`. A fake fails with the error type that production receives.

Turn off SDK retries in test fixtures, so each failure returns at once.
Prove the production retry limits in one unit test with controlled timers.

## Time

In integration tests, one `clock` fixture is the only code that changes the time. It restores real time after each test.
Unit tests may use fake timers directly, because they do no I/O.

## Speed and flakiness

A flaky test has a cause: shared state, unawaited work, real time, test order, or an unhandled request.
Fix the cause. Never fix flakiness with retries, a longer timeout, `.skip`, or a sleep.
Prove a flakiness fix: the changed file passes 3 runs in a row.

A test setup change needs timing evidence. Setup includes pools, isolation, parallelism, and `globalSetup`.
Measure before and after with the same command on the same machine.
Record the decision and its numbers in the project testing document.
Profile before you change setup. Use the reporter's slowest files and Vitest import durations.

## Lint

Enforce these rules in lint for `tests/**`. Each message names the fix.

- no `.only`, `.skip`, conditional tests, or conditional `expect`
- no `vi.mock`, `vi.stubGlobal`, or `node:assert`
- no fake timers outside the `clock` fixture in integration tests
- no `test` imported from `vitest` in a project with a base `test`
- no I/O imports in `tests/unit/`

## Property tests and arbitraries

Use `fast-check` where properties are clearer than examples, especially for:

- parsers/smart constructors
- branded/refined types
- state machines
- serialization roundtrips
- normalization/idempotence
- lawful combinators

Use arbitraries for mock/test data generation. Prefer exporting arbitraries near the domain module they support:

```txt
src/billing/
  invoice-number.ts
  invoice-number.arbitrary.ts
tests/unit/billing/
  invoice-number.test.ts
```
