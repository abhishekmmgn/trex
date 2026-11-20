# Ticket 01: "Trex: Open Browser…" (action trex_open). Sourced by tests/run.sh.

# Opens URL with trex_open and checks the Browser Pane: a new block to the right of
# $ANCHOR, focused, running a kb that shows EXPECTED_URL. Sets $BROWSER.
open_and_check() { # URL EXPECTED_URL
  local before after rect_a rect_b
  before=$(block_ids | wc -l | tr -d ' ')
  trex_do trex_open url="$1"
  assert_status 0 "trex_open url=$1"
  BROWSER=$(printf '%s' "$DO_OUT" | jq -r '.block_id // empty')
  [ -n "$BROWSER" ] || { fail "trex_open returned no block_id: $DO_OUT"; return; }
  BLOCKS_SEEN+=("$BROWSER")

  after=$(block_ids | wc -l | tr -d ' ')
  assert_eq "$((before + 1))" "$after" "one new block"
  assert_contains "$(block_ids)" "$BROWSER" "rex block ls lists the Browser Pane"

  # Right of the pane it was opened from: same top, starts where the anchor ends.
  read -r ax ay aw ah <<<"$(block_rect "$ANCHOR")"
  read -r bx by bw bh <<<"$(block_rect "$BROWSER")"
  [ -n "${ay:-}" ] && [ -n "${by:-}" ] || { fail "no layout rect for the anchor or the Browser Pane"; return; }
  assert_eq "$ay" "$by" "Browser Pane top"
  assert_eq "$(echo "$ax + $aw" | bc)" "$(echo "$bx" | bc)" "Browser Pane starts at the anchor's right edge"
  assert_eq "$BROWSER" "$(focused_block)" "Browser Pane has focus"

  kb_row "$BROWSER" >/dev/null || { fail "kb list never showed a kb in $BROWSER"; return; }
  assert_eq "$2" "$(kb_url "$BROWSER" "$2")" "kb list url"
}

test_opens_local_page_to_the_right() {
  open_and_check "$PAGE_URL" "$PAGE_URL"
}

test_bare_port_opens_localhost() {
  open_and_check "$PAGE_PORT" "http://localhost:$PAGE_PORT/"
}

test_localhost_port_opens_over_http() {
  open_and_check "localhost:$PAGE_PORT" "http://localhost:$PAGE_PORT/"
}

# Opening ADDRESS must fail with a message containing MESSAGE, and open no pane.
refuses() { # ADDRESS MESSAGE
  local before
  before=$(block_ids | wc -l | tr -d ' ')
  trex_do trex_open url="$1"
  [ "$DO_STATUS" != 0 ] || fail "trex_open url=$1 succeeded: $DO_OUT"
  assert_contains "$DO_ERR" "$2" "error for url=$1"
  assert_eq "$before" "$(block_ids | wc -l | tr -d ' ')" "no new pane for url=$1"
}

test_rejects_input_that_looks_like_a_flag() {
  # Not a real kb flag such as --headless: if this ever got through, kb would only
  # print its usage, rather than start a browser that outlives the test.
  refuses "--not-a-kb-flag" "flag"
  refuses "  -x example.com" "flag"
}

# An empty answer at the prompt opens the default, http://localhost:3000. Only the
# action's result and the new pane are checked: whatever is (or isn't) on port 3000
# is the user's.
opens_the_default() { # ADDRESS
  local before
  before=$(block_ids | wc -l | tr -d ' ')
  trex_do trex_open url="$1"
  assert_status 0 "trex_open url=[$1]"
  assert_eq "http://localhost:3000" "$(printf '%s' "$DO_OUT" | jq -r '.url // empty')" "url for [$1]"
  local block; block=$(printf '%s' "$DO_OUT" | jq -r '.block_id // empty')
  [ -n "$block" ] && BLOCKS_SEEN+=("$block")
  assert_eq "$((before + 1))" "$(block_ids | wc -l | tr -d ' ')" "one new block for [$1]"
}

test_empty_input_opens_the_default_url() {
  opens_the_default ""
  opens_the_default "   "
}

# The pin check reads cargo's install record; these hand trex a made-up one.
PIN=d252d5fe771f4d8f18fbf184d8239524b3ecda39

fake_crates2() { # INSTALL_KEY...  → path of a crates2.json listing those installs
  local file; file=$(mktemp)
  printf '%s\n' "$@" | jq -R . | jq -s 'map({(.): {bins: ["kb"]}}) | add // {} | {installs: .}' >"$file"
  printf '%s\n' "$file"
}

test_reports_a_kb_that_is_not_the_pinned_commit() {
  local other=0123456789abcdef0123456789abcdef01234567 crates2
  crates2=$(fake_crates2 "kittybrowser 0.1.0 (git+https://github.com/graiz/kittybrowser#$other)")
  TREX_CRATES2=$crates2 refuses "$PAGE_URL" "isn't the pinned"
  assert_contains "$DO_ERR" "$PIN" "names the pinned commit"
  assert_contains "$DO_ERR" "$other" "names what is installed"
  assert_contains "$DO_ERR" "cargo install --git https://github.com/graiz/kittybrowser --rev $PIN" "says how to fix it"
  rm -f "$crates2"
}

test_reports_a_kb_installed_from_a_local_checkout() {
  local crates2
  crates2=$(fake_crates2 "kittybrowser 0.1.0 (path+file:///Users/me/src/kittybrowser)")
  TREX_CRATES2=$crates2 refuses "$PAGE_URL" "isn't the pinned"
  assert_contains "$DO_ERR" "path+file:///Users/me/src/kittybrowser" "names what is installed"
  rm -f "$crates2"
}

test_reports_a_missing_kb() {
  local crates2
  crates2=$(fake_crates2 "ripgrep 14.1.0 (registry+https://github.com/rust-lang/crates.io-index)")
  TREX_CRATES2=$crates2 refuses "$PAGE_URL" "isn't installed"
  assert_contains "$DO_ERR" "--rev $PIN" "says how to install it"
  rm -f "$crates2"
}
