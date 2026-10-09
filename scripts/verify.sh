#!/bin/bash
# verify.sh: run the verifier agent on one PR. See docs/design.md, "Criteria map".
# Usage: verify.sh OUT_DIR BASE_REF TEST_LOG ISSUE_FILE SUMMARY_FILE [COMMAND...]
# Run it in a checkout of the PR head. COMMAND is a test command that the verifier may run.
# It writes OUT_DIR/verdict.json (the criteria map, or null) and OUT_DIR/verifier.raw.json.
# factory.sh and trust-suite/run.sh both use this script.
set -uo pipefail
[ $# -ge 5 ] || { echo "usage: verify.sh OUT_DIR BASE_REF TEST_LOG ISSUE_FILE SUMMARY_FILE [COMMAND...]" >&2; exit 2; }
here=$(cd "$(dirname "$0")" && pwd)
out=$1 base=$2 log=$3 issue=$4 summary=$5
shift 5
mkdir -p "$out" && python3 "$here/agent.py" "$here/../agents/verifier.md" > "$out/verifier.json" || exit 2

allowed=(Read Grep Glob "Bash(git diff:*)" "Bash(git log:*)" "Bash(git show:*)")
list="git diff, git log, git show"
for cmd in "$@"; do allowed+=("Bash($cmd:*)"); list="$list, $cmd"; done
prompt="Check this PR. The base ref is $base. The test output is in $log.
Use the Read tool for files. You can run these commands, one for each Bash call: $list.

<issue>
$(cat "$issue")
</issue>

<pr-summary>
$(cat "$summary")
</pr-summary>"

claude -p "$prompt" --system-prompt "$(jq -r .prompt "$out/verifier.json")" \
  --model "$(jq -r .model "$out/verifier.json")" --tools "$(jq -r .tools "$out/verifier.json")" \
  --permission-mode dontAsk --add-dir "$(dirname "$log")" --allowedTools "${allowed[@]}" \
  --strict-mcp-config --setting-sources project --disable-slash-commands --no-session-persistence \
  --max-budget-usd "${VERIFY_BUDGET_USD:-3}" --output-format json \
  --json-schema "$(cat "$here/../agents/verifier.schema.json")" < /dev/null > "$out/verifier.raw.json"
jq .structured_output "$out/verifier.raw.json" > "$out/verdict.json" 2> /dev/null || echo null > "$out/verdict.json"
