#!/bin/bash
# Run the verifier on the trust-suite cases, and print the scorecard.
# Usage: trust-suite/run.sh [CASE...]   (no CASE: all cases)
# It needs claude (Claude Code, logged in), git, jq and python3. Each case is
# one verifier run, so the script uses model tokens.
# The results go to $TRUST_SUITE_RESULTS (default: trust-suite/results/<UTC time>/).
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
out=${TRUST_SUITE_RESULTS:-$here/results/$(date -u +%Y%m%dT%H%M%SZ)}
# A neutral name: the verifier must not see that it runs in a test suite.
tmp=$(mktemp -d "${TMPDIR:-/tmp}/review.XXXXXX") || exit 1
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$out" || exit 1
[ $# -gt 0 ] || set -- $(cd "$here/cases" && ls)

model=$(python3 "$here/../scripts/agent.py" "$here/../agents/verifier.md" | jq -r .model) || exit 1

for name in "$@"; do
  case_dir=$here/cases/$name
  mkdir -p "$out/cases/$name" && cp "$case_dir/expected.json" "$out/cases/$name/" || continue
  work=$(mktemp -d "$tmp/pr.XXXXXX")
  repo=$work/pocketlib
  cp -R "$here/fixture" "$repo"
  g() { git -C "$repo" -c user.name=builder -c user.email=builder@localhost "$@"; }
  g init -q -b main && g add -A && g commit -qm "Base" && g checkout -q -b agent/change \
    && g apply "$case_dir/pr.diff" && g add -A && g commit -qm "Change" \
    || { echo "$name: the PR does not apply" >&2; continue; }
  (cd "$repo" && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v) > "$work/verify.log" 2>&1
  # The same verifier step as in production (scripts/verify.sh).
  (cd "$repo" && "$here/../scripts/verify.sh" "$work/out" main "$work/verify.log" "$case_dir/issue.md" \
    "$case_dir/pr.md" "python3 -m unittest")
  cp "$work/out/verdict.json" "$out/$name.json" && cp "$work/out/verifier.raw.json" "$out/$name.raw.json"
  echo "$name: $(jq -r '.result // "invalid"' "$out/$name.json" 2> /dev/null || echo invalid)"
done

{
  python3 "$here/../scripts/report.py" scorecard "$out/cases" "$out"
  echo "- Cost: \$$(jq -s 'map(.total_cost_usd // 0) | add' "$out"/*.raw.json) for $# verifier runs ($model)."
} | tee "$out/scorecard.md"
