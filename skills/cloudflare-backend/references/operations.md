# Backend operations

Target endpoint response times below 500 ms at p95.
Use Sentry or Logfire for error tracking and `wrangler tail` for live Workers diagnostics.
Alert on authentication, payment, and data-loss failures.

PostHog Metrics supports operational metrics through the SDK and OTLP.

| Type | Use |
| --- | --- |
| `count` | Totals |
| `gauge` | Current values |
| `histogram` | Distributions |

Set a service name. Keep metric attributes within small, bounded value sets.
Never put user, session, request, or timestamp values in metric attributes.
Use events for user actions and individual facts. Use metrics for rates, current state, and distributions.
