#!/bin/bash
# Run all offline tests. Exit 1 if a test fails.
here=$(cd "$(dirname "$0")" && pwd)
rc=0
for f in "$here"/*_test.sh; do bash "$f" || rc=1; done
exit $rc
