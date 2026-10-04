# Workers KV

Read before adding, reviewing, or tuning any KV key.

## How a read works

```
kv.get(key, { cacheTtl })
  this data center has a copy?  → yes: ~4 ms (hot)
                                → no:  central store, ~80–120 ms (cold); keep a copy for cacheTtl seconds
```

All KV speed comes from reading that copy. Every rule below makes a copy exist when you read. Measured in production: default `cacheTtl` went cold again after 75 s (88 ms); `cacheTtl: 86400` stayed hot (4 ms).

`cacheTtl` does not change the price: KV bills per key read, hot or cold.

## Rules

### 1. Read with a long `cacheTtl` when the key never changes

```ts
// ❌ default 60 s: a key read less than once a minute per data center is always cold
await env.CACHE.get(`versions/${version}/pages/germany.json`)
// ✅
await env.CACHE.get(`versions/${version}/pages/germany.json`, { cacheTtl: 86_400 })
```

Spot: a `get` with no options, or a wrapper (`KVClient.get`) that cannot pass options.

### 2. Put the version in the key; never rewrite a key you cache long

```ts
// ❌ rewritten on every change, so a long cacheTtl would serve old data
await env.CACHE.put("prices/current", table)
// ✅ a new version writes new keys; old keys never change
await env.CACHE.put(`prices/${revisionId}/by-prefix/44`, group)
```

Spot: `put` to a key that other code reads with a long `cacheTtl`.

### 3. Key by data many requests share, not by the request input

```ts
// ❌ one key per dialed number: read about once, always cold
await env.CACHE.get(`rates:destination:${e164}`)
// ✅ every UK quote reads the same key; match in memory
const group = await env.CACHE.get(`prices/by-prefix/${e164.slice(1, 3)}`, { type: "json", cacheTtl: 60 })
const price = longestPrefixMatch(group, e164)
```

Spot: a key built from a user id, phone number, search text, or other high-cardinality input, meant as a shared cache.

### 4. Make one read per request: store together what one request reads

```ts
// ❌ 3 rounds of cold reads, each waiting for the last
const page = await get(`pages/${slug}`)
const related = await Promise.all(page.nearby.map((c) => get(`summaries/${c}`)))
// ✅ the writer bundles what the reader needs
const { page, content, related } = await get(`pages/${slug}`)
```

Spot: a `get` whose result builds the next key; `Promise.all` over many keys on one request.

### 5. Write at publish time; do not fill KV on read

```ts
// ❌ first read misses, then reads another store, then fills
let v = await kv.get(key); if (v === null) { v = await r2.get(key); ctx.waitUntil(kv.put(key, v)) }
// ✅ the job that creates the data writes KV; the reader only reads
publish: await kv.put(key, body, { expirationTtl })
read:    await kv.get(key, { cacheTtl })
```

Spot: `if (value === null)` followed by another store and a `put`.

### 6. Do not read a changeable pointer before the real read

```ts
// ❌ two sequential reads; the pointer cannot use a long cacheTtl
const v = await kv.get("rates:version"); const entry = await kv.get(`rates:${v}:${id}`)
// ✅ take the version from something already in hand: a Worker var set at deploy, or the data itself
const entry = await kv.get(`content/${env.CONTENT_VERSION}/${id}`, { cacheTtl: 86_400 })
```

Spot: a `get` of a key named `version`, `current`, or `latest` on the request path.

### 7. Leave absent items out at write time

```ts
// ❌ a missing key costs a KV miss plus a fallback read, on every request
// ✅ the writer lists only existing items, so readers never ask for a missing key
related: pages.filter((p) => nearby.includes(p.countryIso2))
```

Spot: fallback reads after a KV `null` for keys that are expected to be absent.

### 8. Do not cache in KV what a response cache already serves

If Workers Cache or the CDN serves the finished response, KV only sees the first render per data center, and that read is cold. KV helps there only for keys shared across different responses (an index, a price group).

Spot: KV reads inside a handler whose response is itself cached.

## Choosing the two TTLs

- `expirationTtl` (on write) = how long the value is **correct and needed**.
  - Versioned data: the rollback window, for example 30 days.
  - A copy of changing data: until its next known change.
- `cacheTtl` (on read) = how **stale** a read may be after the key changes.
  - A key that never changes: long (1 day or more).
  - A key that changes: the staleness you accept, minimum 30 s.
  - Never above `expirationTtl`.

Share of hot reads, per key per data center (the copy lives T seconds after a cold read):

```
h = λT / (1 + λT)      λ = reads/s of that key in one data center, T = cacheTtl
avg read ≈ h × 4 ms + (1 − h) × 100 ms
```

A key read once per hour: T = 60 gives h = 1.6%; T = 86400 gives h = 96%. With no traffic yet, choose T by the staleness rule alone; it improves as traffic grows.

## Check a namespace

GraphQL `kvOperationsAdaptiveGroups`, dimensions `actionType`, `result`: compare `hot_read`, `cold_read`, `not_found`. More cold than hot reads on a read-heavy namespace means one of the rules above is broken.
