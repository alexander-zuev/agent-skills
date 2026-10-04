# Existing RPC envelope contracts

Read this only when the inspected server function returns a result envelope.
Do not introduce this contract because an internal handler uses Result.

An envelope flow has three parts:
- A query or mutation function calls a client helper such as `unwrapResult`.
- The server function returns the boundary's success wrapper.
- The error middleware builds the failure wrapper for that contract.

Read those files and follow their imports to the actual envelope implementation.
Envelope shapes differ between projects. Do not invent another shape or copy one into a bare-value boundary.

A common older shape is:

```typescript
type RpcResult<T, E> =
  | { status: 'ok'; value: T }
  | { status: 'error'; error: E }
```

The existing server converter builds the envelope once.
The existing client helper unwraps it and throws its failure so Query enters the error state.
Keep this conversion in query or mutation functions, never in rendering code.

Do not return Result class instances across the transport.
Do not mix bare values and envelope wrappers on the same contract.
Migrate an internal contract only within the requested scope. Published clients require the backend skill's overlap and deprecation rules.
