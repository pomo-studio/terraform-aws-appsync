#!/usr/bin/env bash
set -euo pipefail

require() {
  local k="$1"
  if [[ -z "${!k:-}" ]]; then
    echo "Missing required env var: $k" >&2
    exit 1
  fi
}

require PRIMARY_APPSYNC_URL
require PRIMARY_APPSYNC_API_KEY
require DR_APPSYNC_URL
require DR_APPSYNC_API_KEY

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required" >&2
  exit 1
fi

query='{"query":"query Health { __typename }"}'

call_query() {
  local name="$1"
  local url="$2"
  local key="$3"

  local code
  code=$(curl -sS -o /tmp/appsync-smoke-${name}.json -w "%{http_code}" \
    -X POST "$url" \
    -H "Content-Type: application/json" \
    -H "x-api-key: $key" \
    --data "$query")

  if [[ "$code" != "200" ]]; then
    echo "${name}: HTTP $code" >&2
    cat "/tmp/appsync-smoke-${name}.json" >&2
    return 1
  fi

  if grep -q '"errors"' "/tmp/appsync-smoke-${name}.json"; then
    echo "${name}: GraphQL returned errors" >&2
    cat "/tmp/appsync-smoke-${name}.json" >&2
    return 1
  fi

  echo "${name}: OK"
}

echo "Running AppSync failover smoke..."
call_query "primary" "$PRIMARY_APPSYNC_URL" "$PRIMARY_APPSYNC_API_KEY"
call_query "dr" "$DR_APPSYNC_URL" "$DR_APPSYNC_API_KEY"

echo "Failover smoke passed: both primary and DR endpoints are queryable."
