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

| Need | Loader | Observer | Result |
|---|---|---|---|
| Critical SSR data | Await `query({ ...options, staleTime: 'static' })` | `useSuspenseQuery` | Blocks the route until data exists. Throw → route `errorComponent`. |
| Non-blocking warm cache | `void query(options).catch(noop)` | `useQuery` | Failure stays in the page. The page owns `pending`. |
| Streamed SSR data | Start `query()` without awaiting it | `useSuspenseQuery` | Streams data without blocking the route |
| Client loading state | Start without awaiting, or omit loader work | `useQuery` | Page renders its own pending state |

Plain `useQuery` does not execute during SSR. Loader prefetches and `useSuspenseQuery` participate in SSR and streaming.

Always observe Query-owned data with `useQuery` or `useSuspenseQuery`. Do not return it as Router loader data or read it with `useLoaderData`.

## Boundaries

Route-bound queries use `pendingComponent`, `errorComponent`, and the router-wide `defaultErrorComponent`.

A standalone widget can own local Suspense and error boundaries. Use the Sentry `ErrorBoundary` when the repository provides it.

Do not force every `useSuspenseQuery` component to add local boundaries. Route boundaries already own route failures.

## Router subscriptions

Use `Route.use...` or `getRouteApi` when the component belongs to one route. These APIs preserve strict route types.

Use the global hook with `from` when importing a route API is not suitable. Use `strict: false` only for a component shared by multiple routes.

Use `select` to subscribe to the smallest required value. This reduces renders from unrelated Router state changes.

## Sources

- [TanStack Query integration](https://tanstack.com/router/latest/docs/integrations/query)
- [TanStack Router data loading](https://tanstack.com/router/latest/docs/guide/data-loading)
- [TanStack Router path params](https://tanstack.com/router/latest/docs/guide/path-params)
- [TanStack Router render optimizations](https://tanstack.com/router/latest/docs/guide/render-optimizations)
- [TanStack Router and Query](https://tkdodo.eu/blog/tan-stack-router-and-query)
- [Reliable Query Prefetching with TanStack Router](https://tkdodo.eu/blog/reliable-query-prefetching-with-tanstack-router)
