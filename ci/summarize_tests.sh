#!/usr/bin/env bash
set -euo pipefail

# Produces a minimal JSON with total, passed, failed, skipped, and duration_ms.
# Looks for either Cucumber JSON under target/ or Allure summary under allure-report/widgets/summary.json.

# --- Verify jq presence (fail early if missing) ---
if ! command -v jq >/dev/null 2>&1; then
  echo "❌ jq not found. Please ensure it's installed in Jenkinsfile before running this script."
  exit 1
fi

# --- Case 1: Cucumber JSON reports ---
if ls target/*.json >/dev/null 2>&1; then
  jq -s '
    (map(.[]) | .) as $all
    |
    {
      total: ($all | map(.elements) | add | length),
      passed: ($all | map(.elements) | add | map(.steps) | add | map(select(.result.status=="passed")) | length),
      failed: ($all | map(.elements) | add | map(.steps) | add | map(select(.result.status=="failed")) | length),
      skipped: ($all | map(.elements) | add | map(.steps) | add | map(select(.result.status=="skipped")) | length),
      duration_ms: (
        ($all | map(.elements) | add | map(.steps) | add | map(.result.duration // 0) | add) / 1000000
      )
    }
  ' target/*.json
  exit 0
fi

# --- Case 2: Allure summary JSON ---
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

# --- Default empty JSON (no reports found) ---
echo '{"total":0,"passed":0,"failed":0,"skipped":0,"duration_ms":0}'
