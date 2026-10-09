#!/bin/bash
# build.sh: run the builder agent on one issue, then push its branch and open a draft PR.
# See docs/design.md, "Build script".
# Usage: build.sh ISSUE   (run it in a clone of the target repo, with the verify tools on PATH)
# It prints one JSON result. Exit 0: a result was printed. Exit 2: usage error.
set -uo pipefail

usage() { echo "usage: build.sh ISSUE (in a clone of the target repo)" >&2; exit 2; }
[ $# -eq 1 ] && git rev-parse --git-dir > /dev/null 2>&1 || usage
issue=$1 branch= head=
case $issue in '' | *[!0-9]*) usage ;; esac
here=$(cd "$(dirname "$0")" && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/build.XXXXXX") || exit 1
trap 'rm -rf "$tmp"; git worktree prune' EXIT
ref=refs/trust-factory/build-$issue wt=$tmp/worktree
echo '{}' > "$tmp/run.json"

api() { local path=$1; shift; gh api "repos/{owner}/{repo}/$path" "$@"; }
out() { jq -r "$1" "$tmp/out.json"; }

finish() { # STATUS [REASON] [PR]: print the result and exit
  jq -n --arg issue "$issue" --arg status "$1" --arg reason "${2:-}" --arg pr "${3:-}" \
    --arg branch "$branch" --arg commit "$head" --slurpfile run "$tmp/run.json" \
    'def opt: if . == "" then null else . end;
    {issue: ($issue | tonumber), status: $status, pr: ($pr | opt | if . then tonumber else . end),
      branch: ($branch | opt), commit: ($commit | opt), reason: ($reason | opt),
      cost_usd: $run[0].total_cost_usd,
      denied: [$run[0].permission_denials // [] | .[] | .tool_input.command // .tool_name],
      tokens: ($run[0].usage | if . then [.input_tokens, .output_tokens, .cache_read_input_tokens,
        .cache_creation_input_tokens] | map(. // 0) | add else null end)}'
  exit 0
}

# The issue must have acceptance criteria.
api "issues/$issue" > "$tmp/issue.json" || finish retry-later "could not read issue #$issue from GitHub"
jq -e '.body // "" | split("\n") | any(startswith("## Acceptance criteria"))' "$tmp/issue.json" > /dev/null \
  || finish needs-person "the issue has no acceptance criteria"

# The config comes from the default branch.
default=$(git ls-remote --symref origin HEAD | awk '$1 == "ref:" { sub("refs/heads/", "", $2); print $2 }')
cfg=$tmp/config.json
[ -n "$default" ] && git fetch -q origin "+refs/heads/$default:$ref/default" \
  || finish retry-later "could not fetch the default branch from origin"
git show "$ref/default:.trust-factory/config.json" > "$cfg" 2> /dev/null \
  && jq -e '.checks.verify | length > 0' "$cfg" > /dev/null 2>&1 \
  || finish needs-person "no valid .trust-factory/config.json on $default"
base=$(jq -r .branch.base "$cfg") branch=$(jq -r '.branch.prefix // "agent/"' "$cfg")$issue
git fetch -q origin "+refs/heads/$base:$ref/base" || finish retry-later "could not fetch $base from origin"
base_sha=$(git rev-parse "$ref/base")
git worktree add -q -B "$branch" "$wt" "$base_sha" || finish needs-person "could not make a worktree for $branch"

# Run the builder in the worktree. It can edit files there and run only the allowed commands.
jq -n --slurpfile i "$tmp/issue.json" --arg base "$base_sha" --slurpfile c "$cfg" -r '
  "Build issue #\($i[0].number). The base commit is \($base).\n\n" +
  "Verify commands (run them in this directory; all must pass):\n" + ($c[0].checks.verify | map("- " + .) | join("\n")) +
  "\n\nProtected paths (do not change them):\n" + ($c[0].merge.protected_paths // [] | map("- " + .) | join("\n")) +
  "\n\nYou can run these commands, one for each Bash call: git add, git commit, git diff, git status, git log " +
  "and the verify commands.\n\n<issue>\n# \($i[0].title)\n\n\($i[0].body // "")\n</issue>"' > "$tmp/prompt.txt"
allowed=(Read Grep Glob Edit Write "Bash(git add:*)" "Bash(git commit:*)" "Bash(git diff:*)" "Bash(git status:*)" "Bash(git log:*)")
while IFS= read -r cmd; do allowed+=("Bash($cmd:*)"); done < <(jq -r '.checks.verify[]' "$cfg")
python3 "$here/agent.py" "$here/../agents/builder.md" > "$tmp/agent.json" || exit 1
schema='{"type": "object", "required": ["status", "title", "summary"], "additionalProperties": false,
  "properties": {"status": {"enum": ["done", "blocked"]}, "title": {"type": "string"}, "summary": {"type": "string"}}}'
(cd "$wt" && GIT_AUTHOR_NAME="trust-factory builder" GIT_AUTHOR_EMAIL=builder@trust-factory.invalid \
  claude -p "$(cat "$tmp/prompt.txt")" --system-prompt "$(jq -r .prompt "$tmp/agent.json")" \
  --model "$(jq -r .model "$tmp/agent.json")" --tools "$(jq -r .tools "$tmp/agent.json")" \
  --permission-mode acceptEdits --permission-prompts none --allowedTools "${allowed[@]}" \
  --disallowedTools "Bash(git push:*)" "Bash(gh:*)" --setting-sources project \
  --strict-mcp-config --disable-slash-commands --no-session-persistence \
  --max-budget-usd "${BUILD_BUDGET_USD:-5}" --output-format json --json-schema "$schema" < /dev/null) > "$tmp/run.json"
jq -e .structured_output "$tmp/run.json" > "$tmp/out.json" 2> /dev/null || finish needs-person "the builder gave no result"
head=$(git -C "$wt" rev-parse HEAD)

# Check the builder's work before anything leaves this machine.
[ "$(out .status)" = done ] || finish needs-person "the builder is blocked: $(out .summary)"
[ "$(git -C "$wt" symbolic-ref -q --short HEAD)" = "$branch" ] || finish needs-person "the builder left the branch $branch"
[ -z "$(git -C "$wt" status --porcelain)" ] || finish needs-person "the builder left uncommitted changes"
git merge-base --is-ancestor "$base_sha" "$head" && [ "$head" != "$base_sha" ] \
  || finish needs-person "the builder made no commits on top of $base"

git push -q origin "+$head:refs/heads/$branch" || finish retry-later "could not push $branch"
api pulls -X POST -f title="$(out .title)" -f head="$branch" -f base="$base" -F draft=true \
  -f body="$(out .summary)

Closes #$issue" > "$tmp/pr.json" || finish retry-later "could not open the draft PR"
finish opened "" "$(jq -r .number "$tmp/pr.json")"
