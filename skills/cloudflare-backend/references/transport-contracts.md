# Transport contracts

One error value crosses every boundary. Define one closed union of public error tags, each carrying `_tag` and `message`. Call it the error payload: it is a representation, not a kind of error. Collapse every other failure into a generic member.

Never ask a transport to carry the error *type*. Carry the type as data. Let the transport carry only the *fact* of failure.

Never wrap a success value in an envelope by default. Each transport already reports failure its own way:

| Boundary | Failure channel | Success value |
| --- | --- | --- |
| HTTP API | Status code plus RFC 9457 `application/problem+json` | Bare typed body |
| Server function | Throw. One boundary converts it to a payload once | Bare typed value |
| Worker to Durable Object | Throw a tagged error; own properties cross, the prototype does not | Bare typed value |
| WebSocket | Correlated error frame | Correlated result frame |

**Server functions.** One error boundary catches every throw and converts it once. It throws a plain object, never a class instance, because only own data survives serialization. The client reads the tag to branch. An untagged rejection is not a public domain error. Treat it as a transport or unexpected failure.

**Worker to Durable Object.** Workers RPC serializes a thrown error with its `name`, `message`, `stack`, `cause`, and enumerable own properties, nested values included, and stamps `remote: true` and `durableObjectId` on arrival. Only the prototype is lost: `_tag` survives, `instanceof` fails. Verified against workerd (wrangler dev, compat 2026-08); Cloudflare's RPC error docs still claim own properties are dropped — they are stale.

1. A Durable Object method fails by throwing its tagged error. The receiving boundary identifies it by schema — an `Error` whose `_tag` is in the domain table and whose `remote` is `true` — never by `instanceof`, never by message text.
2. Platform failure stays a throw too. workerd's own flags (`retryable`, `overloaded`) survive on the error for the retry classifier.
3. Never return a `Result` instance. Its methods do not survive structured clone.
4. Return a union only when the failure is ordinary data every caller handles inline (expected absence, stale work) — never to smuggle error types the transport already carries.
5. The caller lists the tags that one call can answer with and builds the real error for each. Collapse an unlisted tag into the generic failure. Never look tags up in a shared table: a listed tag says what this call can do, and an unexpected one is a change to notice.

**WebSocket.** Use JSON-RPC 2.0 for the envelope. It is transport-agnostic and domain-free. Frames are `call`, `result`, `error`, and `notification`.

1. Put the error payload in `error.data`. Use code `-32000` for every domain error. Never map tags onto numeric codes.
2. Stream with a notification that carries the originating request token, as LSP and MCP do. Do not invent a frame type.
3. Send the application protocol version as the `Sec-WebSocket-Protocol` subprotocol. Keep JSON-RPC's required `jsonrpc` member on each message.
4. If the connection can continue, send an error frame. If it cannot, send an RFC 6455 close code. Never both.
5. Nothing throws across a socket. A handler returns a result, and the codec writes the frame.
6. Correlation and idempotency are separate facts. The request id is per connection. An idempotency key belongs in `params`.

Frame types never appear in a method signature outside their own transport.

Define each protocol as a method table: name, params schema, result schema. Derive the envelope schemas, the typed caller, and the typed dispatcher from that table. Adding a method is one table entry. Never define an envelope with an unknown payload: that is generic only because it describes nothing.

Write schemas where input is untrusted or a crossed error must be identified. Do not re-parse trusted typed successes within one deploy.

Keep external API names and values unchanged at adapters, contracts, and queue boundaries. Interpret or rename them in the domain layer.

## Server-function implementation evidence

Preserve the project's auth-expiry redirect, including stale-session detection in its existing middleware.
Give a failure its own public tag only when callers need that distinction. Collapse other failures into the generic payload.
Keep internal error messages in diagnostics. Use safe public messages for validation, authentication, and missing resources.

Read the current [TanStack Start server-function documentation](https://tanstack.com/start/latest/docs/framework/react/guide/server-functions).
Inspect the installed framework and middleware helper where serialization or validator behavior matters.
Use the existing helper to preserve Router control flow, normalize validation failures, and convert unknown errors safely.

Inspect the app's `src/start.ts` and `src/server/entrypoints/middleware/error.middleware.ts`.
Follow their imports into the payload definitions and installed middleware implementation.
If that middleware uses an envelope contract, read [RPC compatibility](rpc-compatibility.md) before copying it.

If application code returns Result, the adapter extracts success or throws the typed error to shared middleware.
The middleware serializes the final error once. Query and mutation functions consume bare success values directly.

## HTTP status mapping

Use the project's declared status mapping for HTTP routes. Server-function clients use their own failure channel.

| Status | Condition |
| --- | --- |
| 200 / 204 | Success with or without a body |
| 401 | Missing or expired authentication |
| 402 | Billing failure |
| 404 | Missing resource |
| 422 | Validation or domain failure |
| 429 | Rate limit |
| 503 | Unavailable infrastructure |
| 500 | Unexpected defect |
