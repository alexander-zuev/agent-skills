# Frontend performance targets

Apply these targets when developing or reviewing application performance.

| Measure | Target |
| --- | --- |
| Core interaction response | Under 200 ms |
| First Contentful Paint | Under 1.2 seconds |
| Largest Contentful Paint | Under 2.5 seconds |
| Cumulative Layout Shift | Under 0.1 |
| Initial compressed bundle | Under 250 KB |

Target Lighthouse scores of at least 90 for performance and accessibility.
The existing Time to Interactive target is under 3.5 seconds where that measure remains available.
Do not substitute an unavailable metric with an invented value.

Verify affected flows on mobile devices and throttled slow 3G.
Monitor Core Web Vitals in production. Backend endpoint targets belong to the backend skill.

## Web fonts

- Self-host WOFF2 variable fonts. One file per font holds every weight.
- Preload only the subsets that the locale uses, with `as="font"`, `type="font/woff2"`, and `crossorigin`. A preload ignores `unicode-range`.
- Keep the preload links in a pure module keyed by locale. The route `head()` only calls it.
- Add a metric-matched fallback `@font-face` (`size-adjust`, `ascent-override`, `descent-override`) of the same category: sans for sans. Compute the values from the shipped files with Capsize.
- On Cloudflare Workers, set TanStack Start `responseLinkHeader` with a fonts-only filter. Cloudflare sends the `103 Early Hints`; a Worker cannot.
