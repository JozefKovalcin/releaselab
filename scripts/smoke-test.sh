#!/usr/bin/env bash
set -euo pipefail
base=${1:-http://127.0.0.1:3000}
sha=${2:?Usage: smoke-test.sh URL EXPECTED_SHA}
curl -fsS --max-time 10 "$base/health" | jq -e '.status == "ok"' >/dev/null
curl -fsS --max-time 10 "$base/version" | jq -e --arg sha "$sha" '.commitSha == $sha' >/dev/null
curl -fsS --max-time 10 "$base/releases" | jq -e 'type == "array"' >/dev/null
code=$(curl -sS --max-time 10 -o /dev/null -w '%{http_code}' -X POST "$base/releases" \
  -H 'Content-Type: application/json' -H 'X-API-Key: incorrect-api-key' -d '{"version":"9.0.0"}')
[[ "$code" == 401 ]]
echo "Smoke passed: healthy API, expected commit $sha, unauthorized write denied."
