# TanStack Router + Query

Read this reference when a route preloads Query data, uses Query during SSR, or binds URL state to query options.

## Ownership

| Layer | Ownership |
|---|---|
| Entity | Query factory, query keys, request, DTO conversion, and domain types |
| Route | URL validation and query input binding |
| Loader | Early cache work for the route match |
| Page | Query observation and feature composition |
| Feature | User actions and domain behavior |

Entities and features do not import Router APIs. The route-aware page passes domain data to features.

## Router setup

Router context and React use the same `QueryClient`. A different client creates a different cache.

Create a new client for each SSR request. A shared server client can expose cached data between requests.

Set `defaultPreloadStaleTime: 0` when Query owns freshness. This makes Router call the loader and lets Query decide whether to fetch.

```typescript
export function getRouter() {
  const queryClient = new QueryClient()
  const router = createRouter({
    routeTree,
    context: { queryClient },
    defaultPreloadStaleTime: 0,
  })

  setupRouterSsrQueryIntegration({ router, queryClient })
  return router
}
```

The integration owns Query dehydration, hydration, and streaming. It supplies `QueryClientProvider` unless `wrapQueryClient` is false.

## Bind query options once

An entity owns the query factory. Route context owns the bound options for the current URL.

Parse path params at the route definition when the route requires validation, refinement, or conversion. Return parsed values so child routes inherit them. The parser must be deterministic and side-effect-free.

Use `loaderDeps` only for validated search params that change the request. Path params already identify the route match.

```typescript
export const Route = createFileRoute('/_authed/products/$productId')({
  params: {
    parse: ({ productId }) => {
      const result = ProductIdSchema.safeParse(productId)

      return result.success ? { productId: result.data } : false
    },
    stringify: ({ productId }) => ({ productId }),
  },
  validateSearch: z.object({ asOf: z.iso.date().optional() }),
  loaderDeps: ({ search }) => ({ asOf: search.asOf }),
  context: ({ params, deps }) => ({
    productDetailQuery: productQueries.detail({
      productId: params.productId,
      asOf: deps.asOf,
    }),
    relatedProductsQuery: productQueries.related(params.productId),
  }),
  loader: async ({ context }) => {
    await context.queryClient.query({
      ...context.productDetailQuery,
      staleTime: 'static',
    })
    void context.queryClient.query(context.relatedProductsQuery).catch(noop)
  },
  pendingComponent: ProductSkeleton,
  errorComponent: ProductError,
})
```

`noop` is exported from `@tanstack/react-query`. `ensureQueryData` / `prefetchQuery` / `fetchQuery` still run in 5.102 and go away in Query v6.

The page observes the exact bound object. It does not reconstruct inputs from params or search.

```typescript
const routeApi = getRouteApi('/_authed/products/$productId')

function ProductPage() {
  const productDetailQuery = routeApi.useRouteContext({
    select: (context) => context.productDetailQuery,
  })
  const { data } = useSuspenseQuery(productDetailQuery)

  return <ProductDetails product={data} />
}
```

Do not call the same factory separately in the loader and page. Different inputs can cause an unused prefetch and a request waterfall.

Parent route context can pass bound query options to child routes. Use this for shared data, such as the current user.

Parsed path params are also available to child routes. Parse a domain value once at the owning route.

The route `context` option requires a Router version that supports it. Check the installed types before implementation.

## Choose loader timing

An SSR route uses exactly one of three patterns for each query:

| Pattern | Loader | Observer | Loading and error |
|---|---|---|---|
| 1. Await | Return or await `query({ ...options, staleTime: 'static' })` | `useSuspenseQuery` | The route waits for the data. A failure goes to the route `errorComponent`. |
| 2. Stream | `void query(options).catch(noop)` | `useSuspenseQuery` under local boundaries | The page renders at once. The local `Suspense` fallback shows until the streamed data arrives. A failure stays in the local error boundary. |
| 3. Client only | No loader work | `useQuery` | The server and the first client render are both `pending`. The browser fetches after hydration. |

Never read a query that a loader starts without awaiting with `useQuery` on the first render. The loader snapshot dehydrates the query as pending, and the read can finish before or after the server renders the component. The browser can hydrate either state, so `useQuery` can render different HTML than the server did. React then fails hydration (error #418) and the route error boundary replaces the page. Fast local databases hide this race.

Plain `useQuery` does not execute during SSR. Loader prefetches and `useSuspenseQuery` participate in SSR and streaming.

Always observe Query-owned data with `useQuery` or `useSuspenseQuery`. Do not return it as Router loader data or read it with `useLoaderData`.

## Boundaries

`useSuspenseQuery` moves the loading and error states out of the component. `data` is always defined, and `status` is never `pending`. On the first load, the component suspends to the nearest `Suspense` and throws to the nearest error boundary. A failed background refetch keeps the old `data` and does not throw.

Route-wide data (pattern 1) uses the route `pendingComponent`, `errorComponent`, and the router-wide `defaultErrorComponent`.

Every other `useSuspenseQuery` component sits inside its own boundaries, so one failed piece of a page never replaces the route. The piece the page renders owns its frame and wraps one slot with `QueryErrorResetBoundary`, an error boundary, and `Suspense`, in that order:

```tsx
// The piece: frame + boundaries. The page renders <CallLimit />.
function CallLimit() {
  return (
    <Card>
      <CardHeader>…title and hint…</CardHeader>
      <CardContent className="min-h-11">
        <QueryErrorResetBoundary>
          {({ reset }) => (
            <CatchBoundary
              getResetKey={() => 'call-limit'}
              errorComponent={({ reset: resetBoundary }) => (
                <CallLimitError onRetry={() => { reset(); resetBoundary() }} />
              )}
            >
              <Suspense fallback={<CallLimitLoading />}>
                <CallLimitSteps />
              </Suspense>
            </CatchBoundary>
          )}
        </QueryErrorResetBoundary>
      </CardContent>
    </Card>
  )
}

// The data state: the only component that calls useSuspenseQuery.
function CallLimitSteps() {
  const { data } = useSuspenseQuery(callingProfileQueries.current())
  return <ToggleGroup className="grid grid-cols-2 gap-2 sm:grid-cols-5">…</ToggleGroup>
}
```

`QueryErrorResetBoundary` resets the query error, so the retry fetches again. Use the repository's error boundary; use TanStack Router `CatchBoundary` when it has none.

The layout of the slot, its states, and their names are in "State layout" under "Async State Rendering" in [SKILL.md](../SKILL.md).

## Router subscriptions

Use `Route.use...` or `getRouteApi` when the component belongs to one route. These APIs preserve strict route types.

Use the global hook with `from` when importing a route API is not suitable. Use `strict: false` only for a component shared by multiple routes.

Use `select` to subscribe to the smallest required value. This reduces renders from unrelated Router state changes.

## Sources

- [TanStack Query integration](https://tanstack.com/router/latest/docs/integrations/query)
- [TanStack Query Suspense: resetting error boundaries](https://tanstack.com/query/latest/docs/framework/react/guides/suspense#resetting-error-boundaries)
- [React Suspense](https://react.dev/reference/react/Suspense)
- [TanStack Router data loading](https://tanstack.com/router/latest/docs/guide/data-loading)
- [TanStack Router path params](https://tanstack.com/router/latest/docs/guide/path-params)
- [TanStack Router render optimizations](https://tanstack.com/router/latest/docs/guide/render-optimizations)
- [TanStack Router and Query](https://tkdodo.eu/blog/tan-stack-router-and-query)
- [Reliable Query Prefetching with TanStack Router](https://tkdodo.eu/blog/reliable-query-prefetching-with-tanstack-router)
