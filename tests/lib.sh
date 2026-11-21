# trex test harness, sourced by tests/run.sh. Bash.
#
# Every test runs in its own throwaway Rex session and drives trex's actions
# from outside with `rex do`, loading trex's Lua straight from this checkout
# (tests/load.lua), so the user's ~/.config/rex/init.lua is never touched.
#
# What a test gets:
#   $TREX_ROOT        this checkout
#   $SESSION, $ANCHOR the throwaway session and its first (shell) block
#   $PAGE_PORT        port of the local test page server (tests/site)
#   $PAGE_URL         http://127.0.0.1:$PAGE_PORT/
#   trex_do ACTION [-b BLOCK] [KEY=VALUE...]   run a trex action; sets
#                     $DO_OUT (stdout, JSON), $DO_ERR (stderr), $DO_STATUS
#   kb_row BLOCK      wait for `kb list` to show a kb in BLOCK; prints its
#                     tab-separated row (number, url, pane, id)
#   block_ids         the session's block ids, one per line
#   $TREX_STATE       this test's own trex state file (where the DevTools side is remembered)
#   $TREX_CONFIG      this test's own trex config file path (the file isn't there until the test writes it)
#   $TREX_KB_HISTORY  this test's own kb history file path (not there until the test writes it)
#   block_rect BLOCK  the block's layout rect "x y w h" (fractions)
#   focused_block     the focused block of the session's first window
#   assert_eq / assert_contains / assert_status / fail
#
# Safety (see the notes the plan links to): never send keys to kb panes,
# never call `rex do` without the args that skip prompts, never run kb ctl
# without -i, and clean up every session, kb and server the run started.

set -u

# REX, pinned_kb, kb_rows_in and kb_field (see there).
. "$TREX_ROOT/bin/trex-lib.sh"
KB=${KB:-$HOME/.cargo/bin/kb}
TREX_LOAD="$TREX_ROOT/tests/load.lua"
# trex opens its Browser Panes with $KB too (tests/load.lua). The installed kb must
# be the pinned commit. A KB built from the pinned commit elsewhere (cargo build
# --release in a checkout of it) has no cargo install record, so the pin check
# gets a stand-in record saying the pin is installed. Tests that hand it their
# own TREX_CRATES2 still get theirs.
export TREX_KB=$KB
if [ "$KB" != "$HOME/.cargo/bin/kb" ] && [ -z "${TREX_CRATES2:-}" ]; then
  TREX_STAND_IN_CRATES2=$(mktemp)
  printf '{"installs":{"kittybrowser 0.1.0 (git+%s?rev=%s#%s)":{"bins":["kb"]}}}\n' \
    "$(pinned_kb REPO)" "$(pinned_kb PIN)" "$(pinned_kb PIN)" >"$TREX_STAND_IN_CRATES2"
  export TREX_CRATES2=$TREX_STAND_IN_CRATES2
fi

TESTS_RUN=0
TESTS_FAILED=0
CURRENT_FAILED=0
SESSIONS_CREATED=()
BLOCKS_SEEN=()
DEVTOOLS_SOCKETS=()   # control sockets of the DevTools Panes' kbs, which `kb list` doesn't show

log() { printf '%s\n' "$*" >&2; }

fail() {
  CURRENT_FAILED=1
  printf '    FAIL: %s\n' "$*" >&2
}

assert_eq() { # EXPECTED ACTUAL MESSAGE
  if [ "$1" != "$2" ]; then fail "$3: expected [$1], got [$2]"; fi
}

assert_contains() { # HAYSTACK NEEDLE MESSAGE
  case "$1" in
    *"$2"*) ;;
    *) fail "$3: [$2] not in [$1]" ;;
  esac
}

assert_status() { # EXPECTED MESSAGE  (checks $DO_STATUS)
  if [ "$DO_STATUS" != "$1" ]; then
    fail "$2: exit status $DO_STATUS, expected $1 (stderr: $DO_ERR)"
  fi
}

# --- test page ---------------------------------------------------------------

start_page_server() {
  PAGE_PORT=$(/usr/bin/python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')
  /usr/bin/python3 -m http.server "$PAGE_PORT" --bind 127.0.0.1 --directory "$TREX_ROOT/tests/site" \
    >/dev/null 2>&1 &
  PAGE_PID=$!
  PAGE_URL="http://127.0.0.1:$PAGE_PORT/"
  local i
  for i in $(seq 1 50); do
    if /usr/bin/curl -s -m 1 -o /dev/null "$PAGE_URL"; then return 0; fi
    sleep 0.1
  done
  log "test page server didn't start on $PAGE_PORT"
  return 1
}

stop_page_server() {
  if [ -n "${PAGE_PID:-}" ]; then kill "$PAGE_PID" 2>/dev/null; wait "$PAGE_PID" 2>/dev/null; PAGE_PID=; fi
}

# --- sessions ------------------------------------------------------------------

new_session() {
  local json
  json=$("$REX" new "trex-test" --window Main --json) || return 1
  SESSION=$(printf '%s' "$json" | jq -r '.session_id')
  ANCHOR=$(printf '%s' "$json" | jq -r '.initial_windows[0].block_ids[0]')
  SESSIONS_CREATED+=("$SESSION")
  BLOCKS_SEEN+=("$ANCHOR")
}

kill_session() {
  if [ -n "${SESSION:-}" ]; then
    # Remember every block, so the final check can confirm their kbs are gone.
    local b
    for b in $(block_ids 2>/dev/null); do BLOCKS_SEEN+=("$b"); done
    "$REX" kill "$SESSION" >/dev/null 2>&1
    SESSION=
  fi
}

block_ids() {
  "$REX" block ls -s "$SESSION" --json | jq -r '.blocks[].block_id'
}

# The layout rect of BLOCK as "x y w h".
block_rect() {
  "$REX" session inspect "$SESSION" --json | jq -r --arg b "$1" '
    [.. | objects | select(.block_id? == $b) | .rect] | first | map(tostring) | join(" ")'
}

focused_block() {
  "$REX" do -s "$SESSION" -e 'local v = rex.session.view{}; return v.windows[1].focused_block_id' --json | jq -r .
}

# --- driving trex ----------------------------------------------------------------

# trex_do ACTION [-b BLOCK] [KEY=VALUE...]. Without -b the action runs in $ANCHOR.
# Always pass the args that skip prompts: a prompt would pop up in the user's Rex app.
trex_do() {
  local action=$1; shift
  local block=$ANCHOR
  if [ "${1:-}" = "-b" ]; then block=$2; shift 2; fi
  local errfile; errfile=$(mktemp)
  DO_OUT=$("$REX" do "$TREX_LOAD" --action "$action" -s "$SESSION" -b "$block" --timeout 60s --json "$@" 2>"$errfile")
  DO_STATUS=$?
  DO_ERR=$(cat "$errfile"); rm -f "$errfile"
}

# Waits up to 20 s for `kb list` to show a kb in BLOCK, and prints its row.
kb_row() {
  local i row
  for i in $(seq 1 80); do
    row=$(kb_rows_in "$("$KB" list 2>/dev/null)" "$1")
    if [ -n "$row" ]; then printf '%s\n' "$row"; return 0; fi
    sleep 0.25
  done
  return 1
}

# Waits up to 20 s for the kb in BLOCK to report URL in `kb list` (a page that is
# still loading reports what it was given). Prints the last url seen; status 1 if
# it never matched.
kb_url() { # BLOCK URL
  local i url=
  for i in $(seq 1 80); do
    url=$(kb_rows_in "$("$KB" list 2>/dev/null)" "$1" | kb_field url)
    if [ "$url" = "$2" ]; then printf '%s\n' "$url"; return 0; fi
    sleep 0.25
  done
  printf '%s\n' "$url"
  return 1
}

# --- runner ------------------------------------------------------------------------

run_test() { # FUNCTION
  CURRENT_FAILED=0
  TESTS_RUN=$((TESTS_RUN + 1))
  printf '  %s ... ' "$1" >&2
  # Each test gets its own trex state file (tests/load.lua), never the user's.
  TREX_STATE_DIR=$(mktemp -d)
  export TREX_STATE="$TREX_STATE_DIR/state.json"
  # And its own config file path (not created), so none ever reads the user's ~/.config/trex.
  export TREX_CONFIG="$TREX_STATE_DIR/xdg/trex/config.json"
  export TREX_CLIENT_LOG="$TREX_STATE_DIR/client-actions.jsonl"
  # And its own kb history file path (not created), so none ever suggests from ~/.kittybrowser/history.
  export TREX_KB_HISTORY="$TREX_STATE_DIR/kb-history"
  if ! new_session; then fail "couldn't create a throwaway Rex session"; else "$1"; fi
  kill_session
  rm -rf "$TREX_STATE_DIR"
  if [ "$CURRENT_FAILED" = 0 ]; then printf 'ok\n' >&2; else
    TESTS_FAILED=$((TESTS_FAILED + 1)); printf '  %s FAILED\n' "$1" >&2
  fi
}

# Confirms that no kb the run started is still alive (they die with their session),
# including the DevTools Panes' kbs, which only answer on their own sockets.
check_no_leftover_kbs() {
  local i list b leftover
  for i in $(seq 1 40); do
    list=$("$KB" list 2>/dev/null)
    leftover=
    for b in ${BLOCKS_SEEN[@]+"${BLOCKS_SEEN[@]}"}; do
      if [ -n "$(kb_rows_in "$list" "$b")" ]; then leftover="$leftover $b"; fi
    done
    for b in ${DEVTOOLS_SOCKETS[@]+"${DEVTOOLS_SOCKETS[@]}"}; do
      if [ -n "$b" ] && [ -S "$b" ] && KB_SOCKET=$b "$KB" ctl status >/dev/null 2>&1; then leftover="$leftover $b"; fi
      # The pane removes its Chrome profile (next to the socket) when it closes.
      if [ -n "$b" ] && [ -e "${b%.sock}" ]; then leftover="$leftover ${b%.sock}"; fi
    done
    [ -z "$leftover" ] && return 0
    sleep 0.25
  done
  log "WARNING: kbs still running in test blocks or on DevTools sockets:$leftover"
  return 1
}

cleanup() {
  kill_session
  local s
  for s in ${SESSIONS_CREATED[@]+"${SESSIONS_CREATED[@]}"}; do "$REX" kill "$s" >/dev/null 2>&1; done
  stop_page_server
  [ -n "${TREX_STAND_IN_CRATES2:-}" ] && rm -f "$TREX_STAND_IN_CRATES2"
}
