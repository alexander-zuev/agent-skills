# Measure a Worker

Use this reference to measure the speed and failures of a deployed Worker from Workers Observability.
Every fact below was verified against a production Worker. Where a path is not verified, the text says so.

## Tool

Run queries with the `cf` CLI: `pnpm dlx --allow-build=workerd cf observability telemetry query --body '<json>'`.
The body is the JSON of the Workers Observability telemetry query API.
`cf` needs the `workerd` build script, so pass `--allow-build=workerd`.

Authentication:

- Local: create a profile with `cf auth create <name>`, then bind it to the repository with `cf auth activate <name> <dir>`. The OAuth login includes the Workers Observability scopes.
- Cloud agents: an API token with Workers Observability read access, in `CLOUDFLARE_API_TOKEN`. Not verified yet: whether `cf` reads that variable.
- A wrangler OAuth login does not include Workers Observability read access. The API returns "Authentication error".

Workers Observability keeps 7 days of data.

## Invocation fields

Each invocation writes one event with these fields. Use them, not the `$metadata.*` fields.

| Field | Meaning |
| --- | --- |
| `$metadata.service` | Worker name; always filter on it |
| `$workers.eventType` | `fetch`, `queue`, `scheduled`, `jsrpc`, `alarm`, or `workflow` |
| `$workers.wallTimeMs` | wall time in milliseconds |
| `$workers.cpuTimeMs` | CPU time in milliseconds |
| `$workers.outcome` | `ok`, `canceled`, `exception`, `exceededCpu`, `exceededMemory`, and others |
| `$workers.entrypoint` | Durable Object or Workflow class name |
| `$workers.event.request.method`, `$workers.event.request.url` | `fetch` request |
| `$workers.event.response.status` | `fetch` response status |
| `$workers.event.queue` | queue name for `queue` invocations |
| `$workers.event.cron` | cron expression for `scheduled` invocations |

## Query one row

Measure one row with one ungrouped query: filters for the row, then `count`, `median`, `p95`, and `p99` of `$workers.wallTimeMs`.
`scripts/measure-row.sh <worker> <days> '<filters JSON array>'` runs that query and prints the four numbers.

Examples of row filters:

- Pages: `eventType` = `fetch`, method = `GET`, URL does not include `/api/`, `/_serverFn/`, or `/relay/`.
- Server functions: `eventType` = `fetch`, URL includes `/_serverFn/`.
- One queue: `eventType` = `queue`, `$workers.event.queue` = the queue name.
- One cron: `eventType` = `scheduled`, `$workers.event.cron` = the expression.
- One Durable Object: `entrypoint` = the class, `eventType` = `jsrpc`.
- One Workflow: `entrypoint` = the class.

## Count failures

A failure is an invocation with an outcome that is neither `ok` nor `canceled`, or a `fetch` with outcome `ok` and status 5xx.
`canceled` means the client disconnected. It is not a failure.

Count each failure outcome with an `eq` filter, and add the counts.
Never use `neq "ok"`: it also matches log events, which have no outcome field.

## Known traps

1. `$metadata.origin` and `$metadata.duration` filters returned 0 rows for invocations. Use `$workers.eventType` and `$workers.wallTimeMs`.
2. With `groupBys`, the response has no overall aggregate. It returns per-bucket values in `series` only, and percentiles from buckets cannot be combined.
3. A 7-day query with `groupBys` timed out. Run one ungrouped query per row instead.
4. `chartType: "aggregate"` returned empty aggregates. Leave `chartType` out.
5. The `events` view returned 0 rows for filters that the `calculations` view matched. Not resolved yet: use `calculations` for numbers.
6. The `count` result includes log events. Percentiles of `$workers.wallTimeMs` use invocation events only.

## Other sources

- GraphQL Analytics `workersInvocationsAdaptive`: whole-Worker totals per `status`, with times in microseconds. It has no route or trigger dimension.
- GraphQL Analytics `durableObjectsInvocationsAdaptiveGroups`: requests and errors per Durable Object namespace ID.
- Queue lag is not in Workers Observability. Not verified yet: the GraphQL queue dataset that has it.
