# Error paths

Give error paths more review than happy paths. Before implementation, answer these questions:

1. What condition occurs: expected result, domain violation, application invariant, infrastructure failure, or programmer defect?
2. What must the caller do: continue, return a typed result, stop, compensate, acknowledge, or retry?
3. Which boundary logs the condition? Each error has exactly one logging point.
4. Is repetition safe? Do not retry without idempotency or another repeat-safety mechanism.
5. Which focused test proves the response, side effects, logging ownership, and retry limit?

Hard rules:

- Expected absence, no-op, completion, and stale work are data. Use a typed result or an early return.
- Remove programmer invariants with types or control flow. Otherwise, use a narrow typed non-retryable invariant error.
- The code that throws does not log. The owning entrypoint or error boundary logs the final error once.
- Unknown external errors stop local retries. Durable delivery can retry unknown errors only when repetition is safe and bounded.

Use typescript-standards for typed error construction and migration of raw throws.

## External boundary retries

An external boundary is a client for a binding, SDK, or remote API. It owns retry classification and final error conversion.

1. Check repeat safety first. A mutating timeout has an indeterminate outcome; reconcile it or repeat with the same idempotency key.
2. Pass the raw external error to the boundary classifier. Cancellation, expired deadlines, invalid input, authentication, and permission are terminal.
3. Check known terminal, boundary transient, platform, then transport errors. Keep each classifier beside its error types. Unknown errors stop.
4. Assign one retry owner at each time scale. Disable nested retries. Bound attempts and elapsed time; use backoff, full jitter, and server delays.
5. After retries stop, convert the final raw error once. Preserve it as the typed boundary error's `cause`.

High-volume retry policies need overload control, such as a retry budget, token bucket, or circuit breaker.

Use the project's retry primitive rather than implementing a new loop.
This example uses an existing throw-based adapter contract.
For an internal Result port, return its typed failure after retry classification. The transport alone chooses the wire failure channel.

```typescript
async function executeBoundary<T>(work: () => Promise<T>): Promise<T> {
  try {
    return await retry(work, decideBoundaryRetry, RETRY.transient)
  } catch (cause) {
    throw new BoundaryError({ operation, cause })
  }
}

function decideBoundaryRetry(error: unknown): RetryDecision {
  if (isTerminalBoundaryError(error)) return { retry: false }
  if (isTransientBoundaryError(error)) return { retry: true, retryAfterMs: 0 }
  if (isPlatformRetryableError(error)) return { retry: true, retryAfterMs: 0 }
  if (isTransientTransportError(error)) return { retry: true, retryAfterMs: 0 }
  return { retry: false }
}
```

## Logging

The boundary that owns the final error logs it once. Preserve existing reporting hooks.
Use a warning for expected failures when diagnostics require a log. Send unexpected failures to the configured error tracker.
Skip an outer error log when an inner service has already reported the same failure.
Log safe operation and domain context. Never expose internal messages to the user.

Match local error classes with `instanceof` when their prototypes remain intact.
Match serialized errors with their declared tags or schemas. Never classify errors from message text.
