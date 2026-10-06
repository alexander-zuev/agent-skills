#!/usr/bin/env bash
# Print count, p50, p95, and p99 of duration for one Worker row from Workers Observability.
# Usage: bash measure-row.sh <worker> <days> '<filters JSON array>' [duration key]
# The duration key is $workers.wallTimeMs for invocations (default) and $metadata.duration for spans.
# Example: bash measure-row.sh my-worker 7 '[{"key":"$workers.eventType","operation":"eq","type":"string","value":"scheduled"}]'
#
# The count is the sum of one-day queries. Cloudflare samples a busy query, and a sample skews small counts,
# so "exact" is false when a day was sampled.
# The percentiles come from one query over all days, which Cloudflare may sample. They are null below 100 calls,
# because a sample or a few calls cannot give a useful p95.
set -euo pipefail

WORKER="$1"
DAYS="$2"
FILTERS="$3"
KEY="${4:-\$workers.wallTimeMs}"
DAY_MS=$((24 * 3600 * 1000))
NOW=$(($(date -u +%s) * 1000))

query() {
  pnpm dlx --allow-build=workerd cf observability telemetry query --body "$1" 2>/dev/null |
    grep -v -E "Progress|Downloading|store|postinstall|dependencies|^\+|Done in"
}

body() {
  jq -cn --arg w "$WORKER" --argjson f "$1" --argjson t "$2" --argjson extra "$FILTERS" --argjson calcs "$3" '{
    queryId: "measure-row", dry: true, view: "calculations", timeframe: {from: $f, to: $t},
    parameters: {
      filters: ([{key: "$metadata.service", operation: "eq", type: "string", value: $w}] + $extra),
      calculations: $calcs
    }
  }'
}

COUNT_CALC='[{"operator":"count","alias":"count"}]'
COUNT=0
EXACT=true
for ((d = 0; d < DAYS; d++)); do
  TO=$((NOW - d * DAY_MS))
  RESPONSE=$(query "$(body $((TO - DAY_MS)) "$TO" "$COUNT_CALC")")
  if [ "$(jq '[.calculations[0].series[].data[]?.sampleInterval] | any(. != 1)' <<<"$RESPONSE")" = "true" ]; then
    EXACT=false
  fi
  COUNT=$((COUNT + $(jq '.calculations[0].aggregates[0].value // 0 | floor' <<<"$RESPONSE")))
done

if [ "$COUNT" -lt 100 ]; then
  jq -cn --argjson count "$COUNT" --argjson exact "$EXACT" '{count: $count, exact: $exact, p50: null, p95: null, p99: null}'
  exit 0
fi

PERCENTILE_CALCS=$(jq -cn --arg k "$KEY" '[
  {operator: "count", alias: "rows"},
  {operator: "median", key: $k, keyType: "number", alias: "p50"},
  {operator: "p95", key: $k, keyType: "number", alias: "p95"},
  {operator: "p99", key: $k, keyType: "number", alias: "p99"}
]')
RESPONSE=$(query "$(body $((NOW - DAYS * DAY_MS)) "$NOW" "$PERCENTILE_CALCS")")
VALUES=$(jq -c '[.calculations[] | {(.alias): (.aggregates[0].value // 0 | floor)}] | add' <<<"$RESPONSE")

# A calculation on a key that no matching row has makes every calculation return 0.
if [ "$COUNT" -gt 0 ] && [ "$(jq .rows <<<"$VALUES")" -eq 0 ]; then
  echo "error: no matching row has the key $KEY. Spans use \$metadata.duration." >&2
  exit 1
fi

jq -c --argjson count "$COUNT" --argjson exact "$EXACT" '{count: $count, exact: $exact, p50, p95, p99}' <<<"$VALUES"
