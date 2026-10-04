# Entrypoints and Application Handlers

## Layer Consistency Check

Inspect layers in any order. Before accepting the design:

1. Apply the system boundary test in SKILL.md; identify external input, its receiving operation, and delivery semantics.
2. Identify whether the application uses a message bus or direct handlers.
3. Confirm that the main application flow is immediately visible.
4. Map each external capability to an application-owned port and infrastructure adapter.
5. Confirm that domain rules, use-case sequencing, and provider details have separate owners.

The application flow often resembles: retrieve → prepare or decide → act → persist → return. This is a rule of thumb, not a target count.

If nested conditions or branches hide the main flow, move business decisions into domain models or services. Extract application steps only when the new handler or method owns a meaningful sub-flow.

## Message-Bus Entrypoints

Operational entrypoints identified by the boundary test use this pattern.

### Server function example

```typescript
export const getPostFn = createServerFn({ method: 'GET' })
  .middleware([withD1ReadOnly])
  .validator(getPostInput)
  .handler(async ({ context, data }) =>
    context.deps.services
      .messageBus()
      .handle(createQuery('GetPost', { slug: data.slug })),
  )
```

The server function owns input validation and dispatch. The query handler owns the read use case.
This example assumes a bare application value. For Result handlers, use the existing adapter conversion.
Shared error middleware owns the failure payload. Read [transport contracts](transport-contracts.md) before changing this boundary.

### Queue consumer example

```typescript
const message = parseQueueMessage(body)
await deps.services.messageBus().handle(message)
message.ack()
```

The queue boundary owns parse, acknowledgement, retry, and final logging. The application handler owns the use case.

### Workflow orchestration example

```typescript
await step.do('mark started', config, () =>
  deps.services.messageBus().handle(
    createCommand('MarkStarted', { jobId }, `${instanceId}:mark-started`),
  ),
)
```

Workflow `run` receives invocation input. This internal step owns retry configuration; its callback is not another system entrypoint.
The command handler owns the use case.

## Direct-Handler Entrypoints

Use this architecture when the application has no message bus. The language does not determine the architecture.

### HTTP route example

```python
@router.post('/extract-audio')
async def extract_audio(
    request: ExtractAudioRequest,
    handler: ExtractAudioDep,
) -> ExtractAudioResponse:
    result = await handler.execute(
        request_id=request.request.id,
        source_url=request.presigned_url,
        output_key=request.output.key,
    )
    return to_extract_audio_response(result)
```

FastAPI validates the request. The route calls one application handler. The response mapper owns the API schema.

The route must not call storage, subprocesses, repositories, or provider SDKs.

Other operational entrypoints can also call a direct application handler. Their platform semantics stay at the boundary.

## Application Handler

An application handler coordinates the use case through narrow ports.

```python
class ExtractAudio:
    def __init__(
        self,
        extractor: AudioExtractor,
        output_storage: AudioOutputStorage,
    ) -> None:
        self._extractor = extractor
        self._output_storage = output_storage

    async def execute(self, source_url: HttpUrl, output_key: str) -> ExtractAudioResult:
        plan = AudioExtractionPlan.flac_mono(source_url, sample_rate=16_000)
        async with self._extractor.open(plan) as extraction:
            size = await self._output_storage.put_audio(output_key, extraction.stream)
            await extraction.require_success()
        return ExtractAudioResult(output_key=output_key, output_size_bytes=size)
```

This handler owns the plan, sequence, cleanup scope, and result. The extractor owns only the subprocess. Storage owns only upload behavior.

Application handlers can also:

- Load domain models through repositories.
- Call domain methods that enforce invariants.
- Stage repository writes in one unit of work.
- Coordinate two or more outbound ports.
- Convert a typed error only when it changes use-case behavior.

## Ownership Test

Ask these questions for each parameter and return value:

1. Does a subprocess adapter receive a request ID? Move operation logging to the application or boundary.
2. Does an extractor receive an output storage key? Split extraction from storage.
3. Does an adapter return an HTTP response model? Return an application or domain result instead.
4. Does one infrastructure service depend on subprocess, storage, repositories, and policy? It probably owns the use case.
5. Does the handler only call that broad service and return its result? The handler is an empty forwarding wrapper.

## Valid One-Step Handlers

A one-port read can be one call. Do not manufacture orchestration.

```python
async def execute(self, source_url: HttpUrl) -> MediaMetadata:
    return await self._metadata_reader.read(source_url)
```

This is valid only when the port itself performs one external capability. It becomes invalid if the adapter also uploads data, writes repositories, or applies use-case policy.

## Error Ownership

- Entrypoint: map the final typed result or error to the transport once.
- Application: catch only to continue, compensate, clean up, or return a different typed use-case result.
- Infrastructure: convert raw provider or process failures to typed boundary errors.
- Domain: return or throw domain violations without logging.
- Owning boundary: log the final error once.
