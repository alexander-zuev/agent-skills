# Measure a Worker

Use this reference to measure the speed and failures of a deployed Worker from Workers Observability.
Every fact below was verified against a production Worker. Where a path is not verified, the text says so.

## Tool

Run queries with the `cf` CLI: `pnpm dlx --allow-build=workerd cf observability telemetry query --body '<json>'`.
The body is the JSON of the Workers Observability telemetry query API.
`cf` needs the `workerd` build script, so pass `--allow-build=workerd`.

Authentication:

- Local: create a profile with `cf auth create <name>`, then bind it to the repository with `cf auth activate <name> <dir>`. The OAuth login includes the Workers Observability scopes.
- Cloud agents: an API token with Workers Observability read access, in `CLOUDFLARE_API_TOKEN`. `cf` reads that variable before the OAuth profile.
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

Measure one row with `scripts/measure-row.sh <worker> <days> '<filters JSON array>' [duration key]`.
It prints `count`, `exact`, `p50`, `p95`, and `p99` of `$workers.wallTimeMs`, or of the key you pass. Refer to "Sampling" for how it counts.

Examples of row filters:

- Pages: `eventType` = `fetch`, method = `GET`, URL does not include `/api/`, `/_serverFn/`, or `/relay/`.
- Server functions: `eventType` = `fetch`, URL includes `/_serverFn/`.
- One queue: `eventType` = `queue`, `$workers.event.queue` = the queue name.
- One cron: `eventType` = `scheduled`, `$workers.event.cron` = the expression.
- One Durable Object: `entrypoint` = the class, `eventType` = `jsrpc`.
- One Workflow: `entrypoint` = the class.

## Query one span

A span is an operation inside an invocation, such as one server function call. Spans do not have `$workers.wallTimeMs`.
Filter on the span attribute, for example `code.function.name` = the function name. Pass `$metadata.duration` as the fourth argument of `scripts/measure-row.sh`.
Not verified yet: that `$metadata.duration` is in milliseconds, and that `$metadata.error` `exists` matches failed spans.

Spans are in the `otel` dataset. Invocations and logs are in `cloudflare-workers`. A query without `datasets` reads both.

## Sampling

Cloudflare samples a query that scans many rows. Each response time bucket has `sampleInterval`: 10 means one row in 10 was read and counted 10 times.
The aggregate shows `sampleInterval` 1 even when the buckets are sampled. Check the buckets.
A sample keeps busy rows accurate but makes rare rows random: a 7-day query returned 10 or 20 for 10 real calls, and 4 or 0 for 6 real CPU kills.

`scripts/measure-row.sh` handles this:

- `count` is the sum of one-day queries. One-day queries of rare rows are not sampled. `exact` is false when a day was sampled; then the count is large and the estimate is close.
- `p50`, `p95`, and `p99` come from one query over all days. They are null below 100 calls, because a few calls or a sample cannot give a useful p95.

## Count failures

A failure is an invocation with an outcome that is neither `ok` nor `canceled`, or a `fetch` with outcome `ok` and status 5xx.
`canceled` means the client disconnected. It is not a failure.

Count each failure outcome with an `eq` filter, and add the counts.
Never use `neq "ok"`: it also matches log events, which have no outcome field.

## Known traps

1. `$metadata.origin` and `$metadata.duration` filters returned 0 rows for invocations. Use `$workers.eventType` and `$workers.wallTimeMs`.
2. If no matching row has the key of a calculation, every calculation returns 0, `count` included. A 0 from a query with a wrong duration key is not a real 0.
3. With `groupBys`, the response has no overall aggregate. It returns per-bucket values in `series` only, and percentiles from buckets cannot be combined.
4. A 7-day query with `groupBys` timed out. Run one ungrouped query per row instead.
5. `chartType: "aggregate"` returned empty aggregates. Leave `chartType` out.
6. The `events` view returned 0 rows for filters that the `calculations` view matched. Not resolved yet: use `calculations` for numbers.
7. The `count` result includes log events. Percentiles of `$workers.wallTimeMs` use invocation events only.

## Other sources

- GraphQL Analytics `workersInvocationsAdaptive`: whole-Worker totals per `status`, with times in microseconds. It has no route or trigger dimension.
- GraphQL Analytics `durableObjectsInvocationsAdaptiveGroups`: requests and errors per Durable Object namespace ID.
- GraphQL Analytics `queueMessageOperationsAdaptiveGroups`: `avg { lagTime retryCount }` in milliseconds, by `queueId`, `actionType`, and `outcome`. It has no percentiles, so measure queue lag as an average. Queue lag is not in Workers Observability.
