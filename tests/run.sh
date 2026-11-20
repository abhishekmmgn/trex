#!/bin/bash
# Runs trex's tests: every `test_*` function in tests/test_*.sh, each in its own
# throwaway Rex session, against a local test page. See README.md.
#
#   tests/run.sh                    all test files
#   tests/run.sh tests/test_x.sh    only these files
#   TREX_TEST_FILTER=open tests/run.sh   only test functions whose name contains "open"

TREX_ROOT=$(cd "$(dirname "$0")/.." && pwd)
export TREX_ROOT
. "$TREX_ROOT/tests/lib.sh"

trap cleanup EXIT
trap 'exit 130' INT TERM

for tool in jq /usr/bin/python3 /usr/bin/curl; do
  command -v "$tool" >/dev/null || { log "missing $tool"; exit 2; }
done
[ -x "$REX" ] || { log "rex not found (set REX)"; exit 2; }
[ -x "$KB" ] || { log "kb not found at $KB (set KB)"; exit 2; }

start_page_server || exit 2

if [ $# -gt 0 ]; then files=("$@"); else files=("$TREX_ROOT"/tests/test_*.sh); fi

for file in "${files[@]}"; do
  log "$(basename "$file")"
  # shellcheck disable=SC1090
  . "$file"
  for fn in $(grep -oE '^test_[A-Za-z0-9_]+' "$file"); do
    case "$fn" in *"${TREX_TEST_FILTER:-}"*) run_test "$fn" ;; esac
  done
done

cleanup
check_no_leftover_kbs
leftover=$?

log ""
log "$((TESTS_RUN - TESTS_FAILED))/$TESTS_RUN passed"
[ "$TESTS_FAILED" = 0 ] && [ "$leftover" = 0 ]
