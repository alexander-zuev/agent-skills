# Entity queries and mutations

Read this reference before implementing or reviewing entity factories, including changes with no UI.
Keep the requested scope. An entity-only task does not imply routes, components, stores, or server implementation.

## Evidence before implementation

1. Read the relevant specification and existing entity slices.
2. Trace a query or mutation through its server function, global middleware registration, and error contract.
3. Read the applicable local reference files below.
4. Check installed types and current documentation for the APIs used.
5. State factory ownership, operation inputs, success/error behavior, and material specification conflicts.

Read the backend skill for server functions, including stubs.
A stub uses the project's existing unimplemented helper. It declares the intended input and return contract.
Do not invent successful data, authentication, or business behavior.
An unanswered scope question does not authorize replacing a specified operation with different operations.

## Reference files by concern

Find a comparable file in the target app or a nearby project.
Read it and its relevant imports. Do not copy a whole repository's conventions.

| Concern | What to look for | Applicability |
| --- | --- | --- |
| Query factory structure | A `*-queries.ts` file that exports reusable query options | Check whether it unwraps an envelope contract |
| Mutation lifecycle | A hook that wraps a mutation and its cache effects | Inspect cache effects; hook placement does not define an FSD entity |
| Flat entities and pagination | An entity query file with separate list and detail keys | Bare success values and separate list keys |
| Mutation options and callback context | An entity `*-mutations.ts` file | Typed variables and awaited invalidation |
| Global error conversion | Target app: `src/start.ts` and `src/server/entrypoints/middleware/error.middleware.ts` | Registration determines whether individual server functions need middleware |

If no comparable file exists, inspect the primary sources below.
Report the gap. Do not invent its contents or silently assume compatible transport behavior.

## Factories

Use `queryOptions` for reads, `infiniteQueryOptions` for cursor lists, and `mutationOptions` for writes.
Use branded IDs and declared input types from the browser-safe contracts.
Keep domain conversion in the query function when needed. Do not duplicate a domain type already exported by core.

The following example assumes imported, typed server functions and contracts:

Put prefix keys (`all`, `lists`, `detailsOf`) in the factory beside the queries, as in [The Query Options API](https://tkdodo.eu/blog/the-query-options-api).
Invalidate only with factory keys. Never write a key array outside its factory.
Derive prefix keys from one module constant; a factory that reads itself in its own initializer fails TypeScript inference.

```typescript
const ROOT = ['product'] as const

export const productQueries = {
  all: () => ROOT,
  lists: () => [...ROOT, 'list'] as const,
  detail: ({ productId }: { productId: ProductId }) =>
    queryOptions({
      queryKey: [...ROOT, 'detail', productId] as const,
      queryFn: ({ signal }) => getProduct({ data: { productId }, signal }),
    }),
}

export const productMutations = {
  update: () =>
    mutationOptions({
      mutationKey: [...ROOT, 'update'] as const,
      mutationFn: (input: UpdateProductInput) => updateProduct({ data: input }),
      onSuccess: (_data, input, _onMutateResult, { client }) =>
        client.invalidateQueries({
          queryKey: productQueries.detail({ productId: input.productId }).queryKey,
        }),
    }),
}
```

This callback context is available in the inspected Query v5 API.
Verify the installed signature before using it. Do not cast around an incompatible version.
The returned invalidation promise keeps the mutation pending until invalidation completes.

A factory owns its entity's cache effects. A consuming feature owns invalidation that coordinates multiple entity slices.
Keep toasts, navigation, and multi-operation workflows in the consumer.

## Inputs, pagination, and cache behavior

Include every request input in the query key. Use separate keys for finite and infinite queries.
Use `skipToken` when a required input is unavailable. Do not invent an ID or use a non-null assertion.
Pass Query's `AbortSignal` through the server-function call when the installed API supports cancellation.

For infinite queries, declare the initial cursor and derive the next cursor from the server response.
Use the declared cursor type when `undefined` alone narrows inference too far.
Keep page size and filters in the key. Do not convert a cursor contract into offset pagination.

Choose freshness and polling from product behavior. Do not invent cache durations to complete the options object.
Read and mutation retry policies differ. Preserve terminal errors and require repeat safety before enabling mutation retries.
Live balance polling is active while the consuming feature needs it. It is not a finite job.

## Validation

Check changed behavior through a real QueryClient or the project's existing integration boundary.
Select checks that correspond to the change:

- Keys distinguish relevant inputs and finite/infinite reads.
- Pagination passes the returned cursor and stops when the server has no next cursor.
- A rejected server function enters Query's error state instead of becoming cached success.
- A successful mutation invalidates the intended cache and stays pending when the contract requires awaited invalidation.
- Cancellation or retry behavior matches the request and repeat-safety contract, when changed.

Do not add tests that only restate object literals.
Report which behavior was tested and which remains unverified. Existing suite counts are separate evidence.

## Current sources

Read the applicable Query documentation and TkDodo articles before new factory work.
Recheck installed types when an example depends on a version. Reuse evidence already read in the conversation.

- Queries: [Query options](https://tanstack.com/query/latest/docs/framework/react/guides/query-options), [The Query Options API](https://tkdodo.eu/blog/the-query-options-api), [Effective React Query Keys](https://tkdodo.eu/blog/effective-react-query-keys)
- Mutations: [Mutations](https://tanstack.com/query/latest/docs/framework/react/guides/mutations), [mutationOptions](https://tanstack.dev/query/latest/docs/framework/react/reference/mutationOptions), [Mastering Mutations](https://tkdodo.eu/blog/mastering-mutations-in-react-query)
- Shared factories: [Creating Query Abstractions](https://tkdodo.eu/blog/creating-query-abstractions)
- Server functions: [TanStack Start server functions](https://tanstack.com/start/latest/docs/framework/react/guide/server-functions)
- Placement: [FSD layers](https://feature-sliced.design/docs/reference/layers)
