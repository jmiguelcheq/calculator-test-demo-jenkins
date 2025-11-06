#!/usr/bin/env bash
set -euo pipefail

# Requires jq (Jenkinsfile installs it before calling this script)

# 1) Prefer Cucumber JSON if you produce it
if ls target/*.json >/dev/null 2>&1; then
  jq -s '
    (map(.[]) | .) as $all
    |
    {
      total:   ($all | map(.elements) | add | length),
      passed:  ($all | map(.elements) | add | map(.steps) | add | map(select(.result.status=="passed"))  | length),
      failed:  ($all | map(.elements) | add | map(.steps) | add | map(select(.result.status=="failed"))  | length),
      skipped: ($all | map(.elements) | add | map(.steps) | add | map(select(.result.status=="skipped")) | length),
      duration_ms: (
        ($all | map(.elements) | add | map(.steps) | add | map(.result.duration // 0) | add) / 1000000
      )
    }
  ' target/*.json
  exit 0
fi

# 2) Allure summary: try common locations
if [ -f target/allure-report/widgets/summary.json ]; then
  jq '{
    total: (.statistic.total // 0),
    passed: (.statistic.passed // 0),
    failed: (.statistic.failed // 0),
    skipped: (.statistic.skipped // 0),
    duration_ms: (.time.duration // 0)
  }' target/allure-report/widgets/summary.json
  exit 0
fi

if [ -f allure-report/widgets/summary.json ]; then
  jq '{
    total: (.statistic.total // 0),
    passed: (.statistic.passed // 0),
    failed: (.statistic.failed // 0),
    skipped: (.statistic.skipped // 0),
    duration_ms: (.time.duration // 0)
  }' allure-report/widgets/summary.json
  exit 0
fi

# 3) Last resort: search anywhere for widgets/summary.json (first match)
FOUND="$(find . -type f -path '*/widgets/summary.json' | head -n1 || true)"
if [ -n "${FOUND:-}" ] && [ -f "$FOUND" ]; then
  jq '{
    total: (.statistic.total // 0),
    passed: (.statistic.passed // 0),
    failed: (.statistic.failed // 0),
    skipped: (.statistic.skipped // 0),
    duration_ms: (.time.duration // 0)
  }' "$FOUND"
  exit 0
fi

# 4) Fallback: nothing found
echo '{"total":0,"passed":0,"failed":0,"skipped":0,"duration_ms":0}'
