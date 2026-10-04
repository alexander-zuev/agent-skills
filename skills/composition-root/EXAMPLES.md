# Cloudflare Composition Root Examples

Load the example matching the implementation shape. These are structural templates, not names to copy blindly.

## Port, service, and binding adapter

Application-owned port and service:

```ts
export interface JurisdictionCache {
  get(namespace: CompositeNamespace): Promise<Jurisdiction | undefined>;
  set(namespace: CompositeNamespace, jurisdiction: Jurisdiction): Promise<void>;
}

export type ResolveJurisdictionDependencies = Readonly<{
  cache: JurisdictionCache;
  claims: JurisdictionClaims;
  tracer: Tracer;
}>;

export class ResolveJurisdictionService {
  readonly #cache: JurisdictionCache;
  readonly #claims: JurisdictionClaims;
  readonly #tracer: Tracer;

  constructor(dependencies: ResolveJurisdictionDependencies) {
    this.#cache = dependencies.cache;
    this.#claims = dependencies.claims;
    this.#tracer = dependencies.tracer;
  }

  async execute(namespace: CompositeNamespace): Promise<Jurisdiction | null> {
    return this.#tracer.span('jurisdiction.resolve', async () => {
      const cached = await this.#cache.get(namespace);
      if (cached !== undefined) {
        return cached;
      }

      const claimed = await this.#claims.lookup(namespace);
      if (claimed !== null) {
        await this.#cache.set(namespace, claimed);
      }
      return claimed;
    });
  }
}
```

Technology adapter:

```ts
export class WorkersKvJurisdictionCache implements JurisdictionCache {
  readonly #kv: KVNamespace;
  readonly #tracer: Tracer;

  constructor(kv: KVNamespace, tracer: Tracer) {
    this.#kv = kv;
    this.#tracer = tracer;
  }

  get(namespace: CompositeNamespace): Promise<Jurisdiction | undefined> {
    return this.#tracer.span('jurisdictionCache.get', async (span) => {
      const value = await this.#kv.get(`jurisdiction:v1:${namespace.toString()}`);
      if (value === null) {
        span.set({ result: 'miss' });
        return undefined;
      }
      const jurisdiction = parseJurisdiction(value);
      span.set({ result: 'hit', jurisdiction });
      return jurisdiction;
    });
  }

  set(namespace: CompositeNamespace, jurisdiction: Jurisdiction): Promise<void> {
    return this.#tracer.span('jurisdictionCache.set', async () => {
      await this.#kv.put(`jurisdiction:v1:${namespace.toString()}`, jurisdiction);
    });
  }
}
```

The adapter parses KV output. The service decides what a miss means and whether a write failure is best effort.

## TanStack Start server entry

The Worker handler builds one dependency graph per invocation. It passes the graph to the Start handler as request context.

```ts
// src/server.ts
import handler, { createServerEntry } from '@tanstack/react-start/server-entry';

declare module '@tanstack/react-start' {
  interface Register {
    server: { requestContext: { deps: AppDeps } };
  }
}

const serverEntry = createServerEntry(handler);

export default {
  fetch(request, env, ctx) {
    const deps = createAppDeps(env, ctx);
    return serverEntry.fetch(request, { context: { deps } });
  },
  queue(batch, env, ctx) {
    return queueHandler(batch, createAppDeps(env, ctx));
  },
} satisfies ExportedHandler<Env>;
```

`createAppDeps` is the only code that sees `env`. It passes each raw binding only to its adapter:

```ts
export function createAppDeps(env: Env, ctx: ExecutionContext): AppDeps {
  const tracer = createTracer();
  const store = new WorkersKvDocumentStore(env.DOCUMENTS, tracer);
  return {
    tracer,
    documents: new DocumentService({ store, tracer }),
  };
}
```

A server function reads the exact service from the request context:

```ts
export const getDocument = createServerFn({ method: 'GET' })
  .validator(parseDocumentId)
  .handler(async ({ data, context }) => {
    const result = await context.deps.documents.get(data);
    return result === null ? null : toApiDocument(result);
  });
```

Middleware and server functions receive exact typed capabilities. They never read `env` or a binding name.

## WorkerEntrypoint or JSRPC binding

```ts
export class DocumentsBinding extends WorkerEntrypoint<Env, BindingProps> {
  readonly #tracer: Tracer;
  readonly #documents: DocumentService;

  constructor(ctx: ExecutionContext, env: Env) {
    super(ctx, env);

    this.#tracer = createTracer();
    this.#documents = new DocumentService({
      store: new WorkersKvDocumentStore(env.DOCUMENTS, this.#tracer),
      tracer: this.#tracer,
    });
  }

  async get(rawId: string): Promise<ApiDocument | null> {
    const id = parseDocumentId(rawId);
    return this.#tracer.span('binding.documents.get', async () => {
      const result = await this.#documents.get(id);
      return result === null ? null : toApiDocument(result);
    });
  }
}
```

The binding validates and projects. The service owns document policy. The adapter owns KV mechanics.

## Dynamic account-bound construction

Use an application-owned factory only when information required for construction appears after authentication.

```ts
export interface AccountDocumentServiceFactory {
  forAccount(account: AccountIdentity): DocumentService;
}

export class DefaultAccountDocumentServiceFactory
  implements AccountDocumentServiceFactory
{
  constructor(
    private readonly store: DocumentStore,
    private readonly tracer: Tracer,
  ) {}

  forAccount(account: AccountIdentity): DocumentService {
    return new DocumentService({
      account,
      store: this.store,
      tracer: this.tracer,
    });
  }
}
```

The factory receives application capabilities. It does not receive or retain `Env`.

## Existing-code migration

Move the seam outward without a big-bang rewrite:

```diff
 class DocumentService {
-  constructor(private readonly env: Env) {}
+  constructor(private readonly store: DocumentStore) {}

   get(id: DocumentId) {
-    return this.env.DOCUMENTS.get(documentKey(id));
+    return this.store.find(id);
   }
 }
```

First caller:

```diff
-const service = new DocumentService(env);
+const store = new WorkersKvDocumentStore(env.DOCUMENTS, tracer);
+const service = new DocumentService(store);
```

If this caller is not a composition root, pass `DocumentStore` outward through its constructor and repeat. Delete the old `Env` path after the final caller moves.

## Verification searches

Tailor searches to the repository and changed bindings:

```bash
rg 'Env|KVNamespace|R2Bucket|D1Database|DurableObjectNamespace|ExecutionContext' src
rg 'context\.env|this\.env|env\.[A-Z][A-Z0-9_]+' src
rg 'new WorkersKv|new .*Adapter|createTracer' src
```

Every match should identify a composition root, binding adapter, framework declaration, or violation.
