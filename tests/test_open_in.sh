# Settings ticket 04: `open_in` ("split" or "window") decides where Trex: Open Browser…
# puts the Browser Pane, and the rest of trex still finds a Browser Pane in another
# window. Sourced by tests/run.sh. Each test writes its config ($TREX_CONFIG, which
# tests/lib.sh gives it) before the first trex_do, because trex reads it at load.

oi_config() { # open_in value
  mkdir -p "$(dirname "$TREX_CONFIG")"
  printf '{ "open_in": "%s" }\n' "$1" >"$TREX_CONFIG"
}

# The id of the Rex window that holds BLOCK.
oi_window_of() { # BLOCK
  "$REX" block ls -s "$SESSION" --json | jq -r --arg b "$1" '.blocks[] | select(.block_id == $b) | .window_id'
}

oi_window_count() { "$REX" window ls -s "$SESSION" -q | grep -c .; }

# The window the user is looking at, and the focused block of WINDOW.
oi_active_window() { "$REX" session inspect "$SESSION" --json | jq -r '.active_window_id'; }
oi_focused_in() { # WINDOW
  "$REX" session inspect "$SESSION" --json | jq -r --arg w "$1" '.windows[] | select(.window_id == $w) | .focused_block_id'
}

# Opens PAGE_URL from BLOCK; sets $BROWSER and $BROWSER_ID, and waits for its kb.
oi_open() { # BLOCK
  trex_do trex_open -b "$1" url="$PAGE_URL"
  assert_status 0 "trex_open in $1"
  BROWSER=$(printf '%s' "$DO_OUT" | jq -r '.block_id // empty')
  [ -n "$BROWSER" ] || { fail "trex_open returned no block_id: $DO_OUT"; return 1; }
  BLOCKS_SEEN+=("$BROWSER")
  BROWSER_ID=$(kb_row "$BROWSER" | kb_field id)
  [ -n "$BROWSER_ID" ] || { fail "kb list never showed a kb in $BROWSER"; return 1; }
  kb_url "$BROWSER" "$PAGE_URL" >/dev/null || { fail "the kb in $BROWSER never showed $PAGE_URL"; return 1; }
}

# Runs `bin/trex ARGS...` in a new pane split below BLOCK, as an agent there would.
# Sets $AGENT_OUT, $AGENT_ERR, $AGENT_STATUS.
oi_agent_runs() { # BLOCK ARGS...
  local block=$1; shift
  local dir json; dir=$(mktemp -d)
  json=$("$REX" run -s "$SESSION" -b "$block" --split=below --focus=false --shell=none --wait --json -- \
    /bin/sh -c 'd=$1; shift; "$@" >"$d/out" 2>"$d/err"; echo $? >"$d/status"' sh "$dir" "$TREX_ROOT/bin/trex" "$@" 2>/dev/null)
  BLOCKS_SEEN+=("$(printf '%s' "$json" | jq -r '.block_ids[0] // empty' 2>/dev/null)")
  AGENT_OUT=$(cat "$dir/out" 2>/dev/null); AGENT_ERR=$(cat "$dir/err" 2>/dev/null)
  AGENT_STATUS=$(cat "$dir/status" 2>/dev/null || echo none)
  rm -f "$dir/out" "$dir/err" "$dir/status"; rmdir "$dir"
}

test_open_in_window_opens_a_new_focused_window() {
  oi_config window
  local windows; windows=$(oi_window_count)
  oi_open "$ANCHOR" || return
  assert_eq "$((windows + 1))" "$(oi_window_count)" "one new window"
  local window; window=$(oi_window_of "$BROWSER")
  [ "$window" != "$(oi_window_of "$ANCHOR")" ] || fail "the Browser Pane is in the pane's own window"
  assert_eq "$window" "$(oi_active_window)" "the new window is the one shown"
  assert_eq "$BROWSER" "$(oi_focused_in "$window")" "the Browser Pane has focus"
}

test_open_in_split_stays_in_the_window() {
  oi_config split
  local windows; windows=$(oi_window_count)
  oi_open "$ANCHOR" || return
  assert_eq "$windows" "$(oi_window_count)" "no new window"
  assert_eq "$(oi_window_of "$ANCHOR")" "$(oi_window_of "$BROWSER")" "same window as the pane it was opened from"
}

test_open_in_window_devtools_opens_in_that_window_below() {
  oi_config window
  oi_open "$ANCHOR" || return
  trex_do trex_devtools -b "$BROWSER"
  assert_status 0 "trex_devtools"
  local devtools; devtools=$(printf '%s' "$DO_OUT" | jq -r '.block_id // empty')
  [ -n "$devtools" ] || { fail "no DevTools Pane: $DO_OUT"; return; }
  BLOCKS_SEEN+=("$devtools"); DEVTOOLS_SOCKETS+=("$(printf '%s' "$DO_OUT" | jq -r '.socket // empty')")
  assert_eq "$(oi_window_of "$BROWSER")" "$(oi_window_of "$devtools")" "DevTools Pane is in the Browser Pane's window"
  assert_eq "below" "$(printf '%s' "$DO_OUT" | jq -r '.side')" "on the default side"
  read -r bx by bw bh <<<"$(block_rect "$BROWSER")"
  read -r dx dy dw dh <<<"$(block_rect "$devtools")"
  assert_eq "$(echo "$by + $bh" | bc)" "$(echo "$dy" | bc)" "DevTools Pane starts at the Browser Pane's bottom edge"
}

# The session fallback: an agent in the first window finds the one Browser Pane in another.
test_open_in_window_agent_finds_the_browser_pane_in_another_window() {
  oi_config window
  oi_open "$ANCHOR" || return
  oi_agent_runs "$ANCHOR" browser
  assert_eq 0 "$AGENT_STATUS" "trex browser from the first window (stderr: $AGENT_ERR)"
  assert_eq "$BROWSER_ID" "$AGENT_OUT" "trex browser finds the Browser Pane in the other window"
}

# What the fallback can't resolve: two Browser Panes, each in a window of its own, and an agent in a third.
test_open_in_window_two_browser_panes_elsewhere_are_ambiguous() {
  oi_config window
  oi_open "$ANCHOR" || return
  local first=$BROWSER_ID
  oi_open "$ANCHOR" || return
  oi_agent_runs "$ANCHOR" browser
  assert_eq 1 "$AGENT_STATUS" "trex browser with two Browser Panes in other windows"
  assert_contains "$AGENT_ERR" "more than one Browser Pane" "says so"
  assert_contains "$AGENT_ERR" "$first" "names the first"
  assert_contains "$AGENT_ERR" "$BROWSER_ID" "names the second"
  oi_agent_runs "$BROWSER" browser
  assert_eq "$BROWSER_ID" "$AGENT_OUT" "an agent in a Browser Pane's own window gets that one"
}

# Pick Element from an Agent Pane in the first window reaches the Browser Pane in another,
# and hands off to that same Agent Pane (nothing is clicked, so nothing is copied).
test_open_in_window_pick_from_the_agent_pane_finds_the_browser_pane() {
  oi_config window
  export TREX_CLIPBOARD=/usr/bin/true
  oi_open "$ANCHOR" || return
  local log json agent i; log=$(mktemp)
  json=$("$REX" run -s "$SESSION" -b "$ANCHOR" --split=below --focus=false --keep-open --json -- \
    /bin/bash -c 'exec -a claude /bin/bash "$0" "$1"' "$TREX_ROOT/tests/stub_agent.sh" "$log")
  agent=$(printf '%s' "$json" | jq -r '.block_id // .block_ids[0] // empty')
  [ -n "$agent" ] || { fail "couldn't start the stand-in agent: $json"; rm -f "$log"; return; }
  BLOCKS_SEEN+=("$agent")
  for i in $(seq 1 40); do
    "$REX" capture -s "$SESSION" -b "$agent" 2>/dev/null | grep -q 'stub agent ready' && break
    sleep 0.25
  done
  trex_do trex_pick -b "$agent"
  assert_status 0 "trex_pick from the Agent Pane"
  assert_eq "$BROWSER_ID" "$(printf '%s' "$DO_OUT" | jq -r '.kb // empty')" "pick reached the Browser Pane in the other window"
  assert_eq "$agent" "$(printf '%s' "$DO_OUT" | jq -r '.agent // empty')" "and kept the Agent Pane it ran from"
  unset TREX_CLIPBOARD
  rm -f "$log"
}
