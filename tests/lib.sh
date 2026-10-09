# Shared helpers for the shell tests. A test file sources this file, defines
# setup NAME and the test_* functions, and then calls run_tests.
# Each test runs in a subshell with its own directory $T.

TESTS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CHECK=$TESTS_DIR/../scripts/check.sh
root=$(mktemp -d "${TMPDIR:-/tmp}/tf-test.XXXXXX")
trap 'rm -rf "$root"' EXIT

init_test_dir() { # DIR: make $T, and isolate git and the stubs in tests/bin
  T=$1
  mkdir -p "$T/gh"
  export HOME=$T GIT_CONFIG_NOSYSTEM=1 GH_STUB_DIR=$T/gh PATH="$TESTS_DIR/bin:$PATH" \
    GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com \
    GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
}

# --- Repos: origin.git, a work clone for the PR author, a clone for check.sh ---

make_repos() { # FILES_DIR (optional): make the repos; with FILES_DIR, push its files as main
  git init -q --bare -b main "$T/origin.git"
  git clone -q "$T/origin.git" "$T/work" 2> /dev/null
  if [ -n "${1:-}" ]; then cp -R "$1/." "$T/work/" && commit "Base" && git -C "$T/work" push -q origin main; fi
}

put() { mkdir -p "$(dirname "$T/work/$1")" && printf '%s\n' "$2" > "$T/work/$1"; }
commit() { git -C "$T/work" add -A && git -C "$T/work" commit -qm "$1"; }
branch() { git -C "$T/work" checkout -q -B "$1" main; }
head_sha() { git -C "$T/work" rev-parse HEAD; }

open_pr() { # [BASE]: push the work HEAD as PR 57 for issue 42, and write the gh stub replies
  git -C "$T/work" push -q origin +HEAD +HEAD:refs/pull/57/head
  jq -n --arg sha "$(head_sha)" --arg base "${1:-main}" \
    '{number: 57, head: {sha: $sha, ref: "agent/42"}, base: {ref: $base, repo: {default_branch: "main"}}}' \
    > "$T/gh/pulls-57.json"
  echo '{"number": 42, "labels": []}' > "$T/gh/issues-42.json"
}

run_check() {
  [ -d "$T/clone" ] || git clone -q "$T/origin.git" "$T/clone"
  (cd "$T/clone" && "$CHECK" 42 57 "$T/out") > "$T/stdout" 2> "$T/stderr"
  rc=$?
}

# --- Assertions ---------------------------------------------------------------

result() { jq -r "$1" "$T/out/result.json"; }
check_of() { result ".checks[] | select(.name == \"$1\") | .result"; }
posted() { grep "statuses/$1 " "$T/gh/calls.log" 2> /dev/null | sed -n 's/.*state=\([a-z]*\).*/\1/p'; }
fail() { echo "$1"; [ ! -s "$T/stderr" ] || { echo "--- stderr:"; cat "$T/stderr"; }; exit 1; }
expect() { [ "$2" = "$3" ] || fail "$1: expected '$3', got '$2'"; }
contains() { case $2 in *"$3"*) ;; *) fail "$1: '$2' does not contain '$3'" ;; esac; }

run_tests() {
  local t msg failures=0
  for t in $(declare -F | awk '$3 ~ /^test_/ { print $3 }'); do
    if msg=$(setup "$t" 2>&1 && "$t" 2>&1); then
      echo "ok   $t"
    else
      echo "FAIL $t"; echo "$msg" | sed 's/^/     /'
      failures=$((failures + 1))
    fi
  done
  echo "$(basename "$0"): $failures failed"
  [ "$failures" -eq 0 ]
}
