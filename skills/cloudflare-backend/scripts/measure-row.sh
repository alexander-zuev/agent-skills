#!/usr/bin/env bash
# Print count, p50, p95, and p99 of wall time for one Worker row from Workers Observability.
# Usage: bash measure-row.sh <worker> <days> '<filters JSON array>'
# Example: bash measure-row.sh my-worker 7 '[{"key":"$workers.eventType","operation":"eq","type":"string","value":"scheduled"}]'
set -euo pipefail

WORKER="$1"
DAYS="$2"
FILTERS="$3"
TO=$(($(date -u +%s) * 1000))
FROM=$((TO - DAYS * 24 * 3600 * 1000))

BODY=$(jq -cn --arg w "$WORKER" --argjson f "$FROM" --argjson t "$TO" --argjson extra "$FILTERS" '{
  queryId: "measure-row", view: "calculations", timeframe: {from: $f, to: $t},
  parameters: {
    filters: ([{key: "$metadata.service", operation: "eq", type: "string", value: $w}] + $extra),
    calculations: [
      {operator: "count", alias: "count"},
      {operator: "median", key: "$workers.wallTimeMs", keyType: "number", alias: "p50"},
      {operator: "p95", key: "$workers.wallTimeMs", keyType: "number", alias: "p95"},
      {operator: "p99", key: "$workers.wallTimeMs", keyType: "number", alias: "p99"}
    ]
  }
}')

pnpm dlx --allow-build=workerd cf observability telemetry query --body "$BODY" 2>/dev/null |
  grep -v -E "Progress|Downloading|store|postinstall|dependencies|^\+|Done in" |
  jq -c '[.calculations[] | {(.alias): (.aggregates[0].value // null | if . == null then null else floor end)}] | add'
