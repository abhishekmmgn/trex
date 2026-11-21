# Ticket 04: an agent in an Agent Pane drives the Browser Pane beside it, never
# the DevTools Pane's kb, a kb in another window or session (the user's own),
# or whichever kb happens to be lowest-numbered. Sourced by tests/run.sh.
#
# The agent side is `bin/trex browser` / `bin/trex ctl`, run in a real Rex pane
# (`rex run`), so it gets REX_SESSION and REX_BLOCK from Rex itself. Never run
# plain `kb ctl` here: without -i it reaches the user's kb.

# Opens a Browser Pane on URL, right of BLOCK, and waits for its kb. Sets $BROWSER
# and $BROWSER_ID (its kb id from `kb list`).
agent_open_browser() { # BLOCK URL
  trex_do trex_open -b "$1" url="$2"
  assert_status 0 "trex_open url=$2 in $1"
  BROWSER=$(printf '%s' "$DO_OUT" | jq -r '.block_id // empty')
  [ -n "$BROWSER" ] || { fail "trex_open returned no block_id: $DO_OUT"; return 1; }
  BLOCKS_SEEN+=("$BROWSER")
  BROWSER_ID=$(kb_row "$BROWSER" | kb_field id)
  [ -n "$BROWSER_ID" ] || { fail "kb list never showed a kb in $BROWSER"; return 1; }
  kb_url "$BROWSER" "$2" >/dev/null || { fail "the kb in $BROWSER never showed $2"; return 1; }
}

# Opens the DevTools Pane for BLOCK's Browser Pane and waits for its kb to answer.
agent_open_devtools() { # BLOCK
  local socket i
  trex_do trex_devtools -b "$1"
  assert_status 0 "trex_devtools in $1"
  socket=$(printf '%s' "$DO_OUT" | jq -r '.socket // empty')
  BLOCKS_SEEN+=("$(printf '%s' "$DO_OUT" | jq -r '.block_id // empty')")
  DEVTOOLS_SOCKETS+=("$socket")
  for i in $(seq 1 80); do
    [ -S "$socket" ] && KB_SOCKET=$socket "$KB" ctl status >/dev/null 2>&1 && return 0
    sleep 0.25
  done
  fail "the DevTools Pane's kb never answered on [$socket]"
}

# Runs `bin/trex ARGS...` in a new pane split below BLOCK, the way an agent in
# that pane would. Sets $AGENT_OUT, $AGENT_ERR, $AGENT_STATUS.
in_agent_pane() { # BLOCK ARGS...
  local block=$1; shift
  local dir; dir=$(mktemp -d)
  local json
  json=$("$REX" run -s "$SESSION" -b "$block" --split=below --focus=false --shell=none --wait --json -- \
    /bin/sh -c 'd=$1; shift; "$@" >"$d/out" 2>"$d/err"; echo $? >"$d/status"' sh "$dir" "$TREX_ROOT/bin/trex" "$@" 2>/dev/null)
  BLOCKS_SEEN+=("$(printf '%s' "$json" | jq -r '.block_ids[0] // empty' 2>/dev/null)")
  AGENT_OUT=$(cat "$dir/out" 2>/dev/null)
  AGENT_ERR=$(cat "$dir/err" 2>/dev/null)
  AGENT_STATUS=$(cat "$dir/status" 2>/dev/null || echo none)
  rm -f "$dir/out" "$dir/err" "$dir/status"; rmdir "$dir"
}

test_agent_pane_reaches_its_browser_pane_while_devtools_is_open() {
  agent_open_browser "$ANCHOR" "$PAGE_URL" || return
  agent_open_devtools "$BROWSER" || return

  in_agent_pane "$ANCHOR" ctl status
  assert_eq 0 "$AGENT_STATUS" "trex ctl status exit (stderr: $AGENT_ERR)"
  assert_contains "$AGENT_OUT" "url: $PAGE_URL" "kb ctl status reports the Browser Pane's page"
  assert_contains "$AGENT_OUT" "pane: $BROWSER" "kb ctl status reports the Browser Pane"
  assert_contains "$AGENT_OUT" "id: $BROWSER_ID" "kb ctl status reports the Browser Pane's kb"

  in_agent_pane "$ANCHOR" ctl check
  assert_eq 0 "$AGENT_STATUS" "trex ctl check exit (out: $AGENT_OUT, stderr: $AGENT_ERR)"
  assert_contains "$AGENT_OUT" "$PAGE_URL" "kb ctl check reports on the Browser Pane's page"

  in_agent_pane "$ANCHOR" browser
  assert_eq 0 "$AGENT_STATUS" "trex browser exit (stderr: $AGENT_ERR)"
  assert_eq "$BROWSER_ID" "$AGENT_OUT" "trex browser prints the Browser Pane's kb id"
}

test_two_browser_panes_in_the_agents_window_must_be_named() {
  agent_open_browser "$ANCHOR" "$PAGE_URL" || return
  local first=$BROWSER first_id=$BROWSER_ID
  agent_open_browser "$ANCHOR" "${PAGE_URL}two.html" || return

  in_agent_pane "$ANCHOR" ctl status
  assert_eq 1 "$AGENT_STATUS" "trex ctl status with two Browser Panes in the window refuses"
  assert_eq "" "$AGENT_OUT" "nothing reached a kb"
  assert_contains "$AGENT_ERR" "$first_id" "the refusal lists the first Browser Pane"
  assert_contains "$AGENT_ERR" "$BROWSER_ID" "the refusal lists the second Browser Pane"

  in_agent_pane "$ANCHOR" ctl -i "$first_id" status
  assert_eq 0 "$AGENT_STATUS" "trex ctl -i ID status exit (stderr: $AGENT_ERR)"
  assert_contains "$AGENT_OUT" "url: $PAGE_URL" "-i reaches the named Browser Pane's page"
  assert_contains "$AGENT_OUT" "pane: $first" "-i reaches the named Browser Pane"
}

test_each_window_reaches_its_own_browser_pane() {
  local first second_window
  agent_open_browser "$ANCHOR" "$PAGE_URL" || return
  first=$BROWSER
  second_window=$("$REX" window new -s "$SESSION" agent2 --focus=false --json | jq -r '.block_ids[0] // empty')
  [ -n "$second_window" ] || { fail "couldn't open a second window"; return; }
  BLOCKS_SEEN+=("$second_window")
  agent_open_browser "$second_window" "${PAGE_URL}two.html" || return

  in_agent_pane "$ANCHOR" ctl status
  assert_eq 0 "$AGENT_STATUS" "first window: trex ctl status exit (stderr: $AGENT_ERR)"
  assert_contains "$AGENT_OUT" "pane: $first" "first window reaches its own Browser Pane"

  in_agent_pane "$second_window" ctl status
  assert_eq 0 "$AGENT_STATUS" "second window: trex ctl status exit (stderr: $AGENT_ERR)"
  assert_contains "$AGENT_OUT" "pane: $BROWSER" "second window reaches its own Browser Pane"
  assert_contains "$AGENT_OUT" "url: ${PAGE_URL}two.html" "second window reaches its own page"
}

test_browser_panes_in_other_sessions_are_never_reached() {
  # A Browser Pane in another session stands in for the user's own kb.
  local other_json other other_anchor
  other_json=$("$REX" new "trex-test" --window Main --json) || { fail "couldn't create a second session"; return; }
  other=$(printf '%s' "$other_json" | jq -r '.session_id')
  other_anchor=$(printf '%s' "$other_json" | jq -r '.initial_windows[0].block_ids[0]')
  SESSIONS_CREATED+=("$other")
  BLOCKS_SEEN+=("$other_anchor")
  local mine=$SESSION
  SESSION=$other
  agent_open_browser "$other_anchor" "$PAGE_URL"
  for b in $(block_ids); do BLOCKS_SEEN+=("$b"); done
  SESSION=$mine
  [ -n "${BROWSER_ID:-}" ] || return

  in_agent_pane "$ANCHOR" ctl status
  assert_eq 1 "$AGENT_STATUS" "trex ctl status with no Browser Pane in this session refuses"
  assert_eq "" "$AGENT_OUT" "nothing reached a kb"
  assert_contains "$AGENT_ERR" "no Browser Pane in this Rex session" "the refusal says why"
  "$REX" kill "$other" >/dev/null 2>&1
}
