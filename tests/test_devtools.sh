# Ticket 02: F12 in a Browser Pane opens a DevTools Pane below it (action
# trex_devtools, which the F12 binding runs). Sourced by tests/run.sh.
#
# The DevTools Pane's kb is hidden from `kb list` and plain `kb ctl` (it has its
# own KB_SOCKET), so these tests reach it only through the socket the action
# reports. Never run `kb ctl` here without that socket or `-i`.

# Opens a Browser Pane on URL, right of $ANCHOR, and waits for its kb. Sets $BROWSER.
open_browser() { # URL
  trex_do trex_open url="$1"
  assert_status 0 "trex_open url=$1"
  BROWSER=$(printf '%s' "$DO_OUT" | jq -r '.block_id // empty')
  [ -n "$BROWSER" ] || { fail "trex_open returned no block_id: $DO_OUT"; return 1; }
  BLOCKS_SEEN+=("$BROWSER")
  kb_row "$BROWSER" >/dev/null || { fail "kb list never showed a kb in $BROWSER"; return 1; }
  kb_url "$BROWSER" "$1" >/dev/null || { fail "the kb in $BROWSER never showed $1"; return 1; }
}

# The inspector URL for the page BLOCK's kb shows, worked out from outside trex:
# `kb list` → instance number → its profile's DevToolsActivePort → /json/list.
expected_inspector() { # BLOCK PAGE_URL
  local n profile port target
  n=$(kb_row "$1" | cut -f1)
  if [ "$n" = 1 ]; then profile=$HOME/.kittybrowser/profile; else profile=$HOME/.kittybrowser/profile-$n; fi
  port=$(head -n 1 "$profile/DevToolsActivePort")
  target=$(/usr/bin/curl -s -m 2 "http://127.0.0.1:$port/json/list" |
    jq -r --arg u "$2" '[.[] | select(.type == "page" and .url == $u)][0].id // empty')
  [ -n "$target" ] || { fail "no page target for $2 on port $port"; return 1; }
  printf 'http://127.0.0.1:%s/devtools/inspector.html?ws=127.0.0.1:%s/devtools/page/%s\n' "$port" "$port" "$target"
}

# `kb ctl` against the DevTools Pane's own kb, only ever through its socket.
devtools_ctl() { # SOCKET ARGS...
  local socket=$1; shift
  [ -n "$socket" ] && [ -S "$socket" ] || { fail "no DevTools socket [$socket]"; return 1; }
  KB_SOCKET=$socket "$KB" ctl "$@"
}

# Waits up to 20 s for the DevTools Pane's kb (on SOCKET) to show URL; prints the last url seen.
devtools_url() { # SOCKET URL
  local i url=
  for i in $(seq 1 80); do
    if [ -S "$1" ]; then
      url=$(KB_SOCKET=$1 "$KB" ctl status 2>/dev/null | sed -n 's/^url: //p')
      if [ "$url" = "$2" ]; then printf '%s\n' "$url"; return 0; fi
    fi
    sleep 0.25
  done
  printf '%s\n' "$url"
  return 1
}

# Runs trex_devtools in BLOCK and checks the DevTools Pane: a new block right below
# BLOCK, focus left where it was, whose kb shows the inspector for BLOCK's page.
# Sets $DEVTOOLS and $DEVTOOLS_SOCKET.
open_devtools_and_check() { # BLOCK PAGE_URL
  local expected before focused
  expected=$(expected_inspector "$1" "$2") || return
  before=$(block_ids | wc -l | tr -d ' ')
  focused=$(focused_block)
  trex_do trex_devtools -b "$1"
  assert_status 0 "trex_devtools in $1"
  DEVTOOLS=$(printf '%s' "$DO_OUT" | jq -r '.block_id // empty')
  DEVTOOLS_SOCKET=$(printf '%s' "$DO_OUT" | jq -r '.socket // empty')
  [ -n "$DEVTOOLS" ] || { fail "trex_devtools returned no block_id: $DO_OUT"; return; }
  BLOCKS_SEEN+=("$DEVTOOLS")
  DEVTOOLS_SOCKETS+=("$DEVTOOLS_SOCKET")
  assert_eq "$((before + 1))" "$(block_ids | wc -l | tr -d ' ')" "one new block"
  assert_eq "$expected" "$(printf '%s' "$DO_OUT" | jq -r '.inspector // empty')" "reported inspector URL"

  # Below the Browser Pane: same left edge and width, starts where it ends.
  read -r bx by bw bh <<<"$(block_rect "$1")"
  read -r dx dy dw dh <<<"$(block_rect "$DEVTOOLS")"
  [ -n "${by:-}" ] && [ -n "${dy:-}" ] || { fail "no layout rect for the Browser or DevTools Pane"; return; }
  assert_eq "$bx" "$dx" "DevTools Pane left edge"
  assert_eq "$bw" "$dw" "DevTools Pane width"
  assert_eq "$(echo "$by + $bh" | bc)" "$(echo "$dy" | bc)" "DevTools Pane starts at the Browser Pane's bottom edge"
  assert_eq "$focused" "$(focused_block)" "focus stays where it was"

  assert_eq "$expected" "$(devtools_url "$DEVTOOLS_SOCKET" "$expected")" "DevTools Pane's kb shows the inspector"
  # Written before the inspector loaded, on the origin DevTools keeps its settings in.
  assert_eq "false" "$(devtools_ctl "$DEVTOOLS_SOCKET" eval "localStorage.getItem('screencast-enabled')")" \
    "DevTools' screencast setting"
  # Hidden from `kb list`, so plain `kb ctl` and agents never pick it.
  assert_eq "" "$("$KB" list 2>/dev/null | awk -F '\t' -v b="$DEVTOOLS" '$3 == b')" "kb list shows no kb in the DevTools Pane"
}

test_devtools_opens_below_for_the_browser_panes_page() {
  open_browser "$PAGE_URL" || return
  open_devtools_and_check "$BROWSER" "$PAGE_URL"
}

# Waits up to 20 s for the DevTools Pane BLOCK to be gone: no such block, no kb
# answering on SOCKET, and its Chrome profile removed.
devtools_gone() { # BLOCK SOCKET
  local i
  for i in $(seq 1 80); do
    if ! block_ids | grep -qx "$1" && ! { [ -S "$2" ] && KB_SOCKET=$2 "$KB" ctl status >/dev/null 2>&1; } &&
      [ ! -e "${2%.sock}" ]; then
      return 0
    fi
    sleep 0.25
  done
  return 1
}

test_devtools_again_in_the_browser_pane_closes_it() {
  open_browser "$PAGE_URL" || return
  open_devtools_and_check "$BROWSER" "$PAGE_URL"
  trex_do trex_devtools -b "$BROWSER"
  assert_status 0 "second trex_devtools"
  assert_eq "true" "$(printf '%s' "$DO_OUT" | jq -r '.closed // empty')" "reports it closed the DevTools Pane"
  devtools_gone "$DEVTOOLS" "$DEVTOOLS_SOCKET" || fail "the DevTools Pane is still there"
  assert_contains "$(block_ids)" "$BROWSER" "the Browser Pane stays open"

  # And F12 a third time opens it again.
  open_devtools_and_check "$BROWSER" "$PAGE_URL"
}

test_devtools_in_the_devtools_pane_closes_it() {
  open_browser "$PAGE_URL" || return
  open_devtools_and_check "$BROWSER" "$PAGE_URL"
  trex_do trex_devtools -b "$DEVTOOLS"
  assert_status 0 "trex_devtools in the DevTools Pane"
  assert_eq "true" "$(printf '%s' "$DO_OUT" | jq -r '.closed // empty')" "reports it closed the DevTools Pane"
  assert_eq "$BROWSER" "$(printf '%s' "$DO_OUT" | jq -r '.browser // empty')" "names its Browser Pane"
  devtools_gone "$DEVTOOLS" "$DEVTOOLS_SOCKET" || fail "the DevTools Pane is still there"
  assert_contains "$(block_ids)" "$BROWSER" "the Browser Pane stays open"
}

test_closing_the_browser_pane_closes_its_devtools_pane() {
  open_browser "$PAGE_URL" || return
  open_devtools_and_check "$BROWSER" "$PAGE_URL"
  "$REX" block close -s "$SESSION" "$BROWSER" >/dev/null || { fail "couldn't close the Browser Pane"; return; }
  devtools_gone "$DEVTOOLS" "$DEVTOOLS_SOCKET" || fail "the DevTools Pane outlived its Browser Pane"
  assert_contains "$(block_ids)" "$ANCHOR" "the other pane stays open"
}

# The pane watching for its Browser Pane to close goes when the DevTools Pane does,
# so toggling DevTools again and again leaves nothing running.
test_closing_the_devtools_pane_leaves_no_watcher() {
  open_browser "$PAGE_URL" || return
  open_devtools_and_check "$BROWSER" "$PAGE_URL"
  [ -n "$(/usr/bin/pgrep -f -- "wait -s $SESSION $BROWSER")" ] || fail "no watcher while the DevTools Pane is open"
  trex_do trex_devtools -b "$DEVTOOLS"
  devtools_gone "$DEVTOOLS" "$DEVTOOLS_SOCKET" || fail "the DevTools Pane is still there"
  sleep 1
  assert_eq "" "$(/usr/bin/pgrep -f -- "wait -s $SESSION" || true)" "rex wait processes for this session"
}

# Moves BLOCK into a new split on SIDE of ANCHOR, as the user would in Rex.
move_block() { # BLOCK ANCHOR DIRECTION SIDE
  "$REX" do -s "$SESSION" -e "local r, err = rex.session.move_block{ block_id = '$1', anchor_block_id = '$2',
    direction = '$3', side = '$4' }; if r == nil then error(err, 0) end" >/dev/null ||
    fail "couldn't move $1 to $3/$4 of $2"
}

# Where block B sits next to block A: right, left, below or above (or "?").
side_of() { # A B
  local ax ay aw ah bx by bw bh
  read -r ax ay aw ah <<<"$(block_rect "$1")"
  read -r bx by bw bh <<<"$(block_rect "$2")"
  [ -n "${ah:-}" ] && [ -n "${bh:-}" ] || { echo "?"; return; }
  if [ "$(echo "$bx == $ax + $aw && $by == $ay && $bh == $ah" | bc)" = 1 ]; then echo right
  elif [ "$(echo "$ax == $bx + $bw && $by == $ay && $bh == $ah" | bc)" = 1 ]; then echo left
  elif [ "$(echo "$by == $ay + $ah && $bx == $ax && $bw == $aw" | bc)" = 1 ]; then echo below
  elif [ "$(echo "$ay == $by + $bh && $bx == $ax && $bw == $aw" | bc)" = 1 ]; then echo above
  else echo "?"; fi
}

# The side the user moved the DevTools Pane to is where the next one opens, for
# any Browser Pane, and closing it from either pane remembers it.
remembers_side() { # DIRECTION SIDE EXPECTED CLOSE_FROM(browser|devtools)
  open_browser "$PAGE_URL" || return
  open_devtools_and_check "$BROWSER" "$PAGE_URL"
  move_block "$DEVTOOLS" "$BROWSER" "$1" "$2"
  assert_eq "$3" "$(side_of "$BROWSER" "$DEVTOOLS")" "DevTools Pane moved"
  if [ "$4" = devtools ]; then trex_do trex_devtools -b "$DEVTOOLS"; else trex_do trex_devtools -b "$BROWSER"; fi
  assert_eq "true" "$(printf '%s' "$DO_OUT" | jq -r '.closed // empty')" "closed it"
  devtools_gone "$DEVTOOLS" "$DEVTOOLS_SOCKET" || { fail "the DevTools Pane is still there"; return; }

  trex_do trex_devtools -b "$BROWSER"
  assert_status 0 "reopen"
  DEVTOOLS=$(printf '%s' "$DO_OUT" | jq -r '.block_id // empty')
  DEVTOOLS_SOCKETS+=("$(printf '%s' "$DO_OUT" | jq -r '.socket // empty')")
  BLOCKS_SEEN+=("$DEVTOOLS")
  assert_eq "$3" "$(side_of "$BROWSER" "$DEVTOOLS")" "reopened DevTools Pane"
}

test_devtools_reopens_on_the_side_it_was_moved_to_right() {
  remembers_side horizontal after right browser
}

test_devtools_reopens_on_the_side_it_was_moved_to_above() {
  remembers_side vertical before above devtools
}

test_devtools_refuses_a_pane_that_is_not_a_browser_pane() {
  local before
  before=$(block_ids | wc -l | tr -d ' ')
  trex_do trex_devtools
  [ "$DO_STATUS" != 0 ] || fail "trex_devtools in a shell pane succeeded: $DO_OUT"
  assert_contains "$DO_ERR" "isn't a Browser Pane" "error"
  assert_eq "$before" "$(block_ids | wc -l | tr -d ' ')" "no new pane"
}

test_each_browser_panes_devtools_attach_to_its_own_page() {
  local first first_devtools first_socket
  open_browser "$PAGE_URL" || return
  first=$BROWSER
  open_browser "${PAGE_URL}two.html" || return
  [ "$first" != "$BROWSER" ] || { fail "both Browser Panes are $BROWSER"; return; }

  open_devtools_and_check "$first" "$PAGE_URL"
  first_devtools=$DEVTOOLS first_socket=$DEVTOOLS_SOCKET
  open_devtools_and_check "$BROWSER" "${PAGE_URL}two.html"
  [ "$first_socket" != "$DEVTOOLS_SOCKET" ] || fail "both DevTools Panes use $DEVTOOLS_SOCKET"
  [ "$first_devtools" != "$DEVTOOLS" ] || fail "both DevTools Panes are $DEVTOOLS"
}
