# Settings 03: "Trex: Open Browser…" asks in the palette (rex.ui.pick) with kb's history as
# rows. Sourced by tests/run.sh.
#
# tests/load.lua answers the prompt itself (TREX_PROMPT), so no Rex app is asked: the
# pick's spec (items included) goes to "$TREX_PROMPT.pick", a plain input's to "$TREX_PROMPT".
# The history is a fixture at $TREX_KB_HISTORY, never ~/.kittybrowser/history, and the
# config is $TREX_CONFIG, never ~/.config/trex.

# Writes the history fixture from "COUNT AGE_SECONDS URL" lines, in kb's format
# (count, last visit epoch, url, tab-separated), the ages counted back from now.
write_history() { # "COUNT AGE URL"...
  local now line; now=$(date +%s)
  : >"$TREX_KB_HISTORY"
  for line in "$@"; do
    # shellcheck disable=SC2086
    set -- $line
    printf '%s\t%s\t%s\n' "$1" "$((now - $2))" "$3" >>"$TREX_KB_HISTORY"
  done
}

# Runs trex_open with the prompt answered ANSWER, the way TREX_PROMPT_PICK says (tests/load.lua).
# Sets $PROMPT_DIR and $DO_*, and remembers a block it opened.
prompted_open() { # ANSWER [id|text|unsupported|failed|busy|cancelled]
  local block
  PROMPT_DIR=$(mktemp -d)
  TREX_PROMPT=$PROMPT_DIR/prompt.json TREX_PROMPT_ANSWER=$1 TREX_PROMPT_PICK=${2:-id} trex_do trex_open
  block=$(printf '%s' "$DO_OUT" | jq -r '.block_id // empty' 2>/dev/null)
  if [ -n "$block" ]; then BLOCKS_SEEN+=("$block"); fi
  return 0
}

opened_url() { printf '%s' "$DO_OUT" | jq -r '.url // empty'; }
pick_spec() { jq -r "$1" "$PROMPT_DIR/prompt.json.pick"; }
pick_titles() { pick_spec '.items[].title'; }

test_prompt_is_a_palette_list_with_free_text() {
  prompted_open ""
  assert_status 0 "trex_open with the prompt answered empty"
  assert_eq "http://localhost:3000" "$(opened_url)" "an empty answer opens the default"
  assert_eq "true" "$(pick_spec .allow_other)" "free text allowed"
  assert_contains "$(pick_spec '.placeholder // empty')" "localhost:3000" "the hint"
  [ ! -e "$PROMPT_DIR/prompt.json" ] || fail "the plain prompt was asked too"
  rm -rf "$PROMPT_DIR"
}

test_rows_are_the_default_then_history_ranked() {
  # Scores: a 5 x 4 (visited a minute ago) = 20; b 8 x 2 (20 h) = 16; d 30 x 0.5 (a month) = 15;
  # c 10 x 1 (3 days) = 10. The history lists the default too (with a trailing slash), and has
  # lines that aren't history.
  write_history "10 259200 https://c.example/docs" "30 2592000 http://d.example/" \
    "99 60 http://localhost:3000/" "8 72000 http://b.example/x/" "5 60 https://a.example"
  printf 'garbage\nx\ty\thttp://bad.example\n3\t60\n\n' >>"$TREX_KB_HISTORY"
  prompted_open ""
  assert_eq "localhost:3000
a.example
b.example/x
d.example
c.example/docs" "$(pick_titles)" "row titles: the default first and not repeated, then by score"
  assert_eq "http://localhost:3000" "$(pick_spec '.items[0].id')" "the default row's id"
  assert_eq "default" "$(pick_spec '.items[0].subtitle')" "the default row's subtitle"
  assert_eq "http://b.example/x/" "$(pick_spec '.items[2].subtitle')" "a row's subtitle is the full URL"
  assert_eq "http://b.example/x/" "$(pick_spec '.items[2].id')" "a row's id is the full URL"
  assert_eq "globe" "$(pick_spec '.items[1].icon')" "a row's icon"
  rm -rf "$PROMPT_DIR"
}

# http and https of one host are different servers: only a trailing slash is ignored.
test_http_and_https_are_different_rows() {
  write_history "5 60 https://localhost:3000" "4 60 http://localhost:3000/" "3 60 http://h.example" \
    "2 60 https://h.example/" "1 60 https://h.example"
  prompted_open ""
  assert_eq "default
https://localhost:3000
http://h.example
https://h.example/" "$(pick_spec '.items[] | .subtitle')" "https of the default is its own row, a trailing slash is not, and the rest are not merged"
  rm -rf "$PROMPT_DIR"
}

test_rows_stop_at_fifty_history_urls() {
  local lines=() i
  for i in $(seq 1 60); do lines+=("$i 60 http://site$i.example"); done
  write_history "${lines[@]}"
  prompted_open ""
  assert_eq "51" "$(pick_spec '.items | length')" "the default and 50 history rows"
  assert_eq "site60.example" "$(pick_titles | sed -n 2p)" "best first"
  assert_eq "site11.example" "$(pick_titles | tail -1)" "the 50th best"
  rm -rf "$PROMPT_DIR"
}

test_a_missing_history_file_leaves_only_the_default() {
  prompted_open ""
  assert_eq "localhost:3000" "$(pick_titles)" "only the default"
  rm -rf "$PROMPT_DIR"
}

test_picking_a_row_opens_it() {
  write_history "5 60 $PAGE_URL"
  prompted_open "$PAGE_URL"
  assert_status 0 "picking the history row"
  assert_eq "$PAGE_URL" "$(opened_url)" "url opened"
  assert_eq "$PAGE_URL" "$(kb_url "$(printf '%s' "$DO_OUT" | jq -r '.block_id')" "$PAGE_URL")" "kb list url"
  rm -rf "$PROMPT_DIR"
}

test_typed_text_opens_after_normalising() {
  prompted_open "$PAGE_PORT" text
  assert_status 0 "typed bare port"
  assert_eq "http://localhost:$PAGE_PORT" "$(opened_url)" "a typed port opens localhost"
  rm -rf "$PROMPT_DIR"
  prompted_open "$PAGE_URL" text
  assert_status 0 "typed URL"
  assert_eq "$PAGE_URL" "$(opened_url)" "a typed URL opens as it is"
  rm -rf "$PROMPT_DIR"
}

test_typed_text_that_looks_like_a_flag_is_refused() {
  local before; before=$(block_ids | wc -l | tr -d ' ')
  prompted_open "--not-a-kb-flag" text
  [ "$DO_STATUS" != 0 ] || fail "typed flag succeeded: $DO_OUT"
  assert_contains "$DO_ERR" "flag" "error"
  assert_eq "$before" "$(block_ids | wc -l | tr -d ' ')" "no new pane"
  rm -rf "$PROMPT_DIR"
}

test_default_url_setting_is_the_first_row_and_the_empty_answer() {
  mkdir -p "$(dirname "$TREX_CONFIG")"
  printf '{ "default_url": "http://localhost:4567" }\n' >"$TREX_CONFIG"
  write_history "5 60 http://localhost:4567/" "2 60 http://other.example"
  prompted_open ""
  assert_status 0 "empty answer with default_url set"
  assert_eq "localhost:4567
other.example" "$(pick_titles)" "the configured default first, once"
  assert_eq "http://localhost:4567" "$(pick_spec '.items[0].id')" "the first row's id"
  assert_eq "http://localhost:4567" "$(opened_url)" "an empty answer opens default_url"
  rm -rf "$PROMPT_DIR"
  prompted_open "  " text
  assert_eq "http://localhost:4567" "$(opened_url)" "blank typed text opens default_url"
  rm -rf "$PROMPT_DIR"
  # And an empty url argument, which asks nothing.
  trex_do trex_open url=""
  assert_eq "http://localhost:4567" "$(opened_url)" "an empty url argument opens default_url"
  local block; block=$(printf '%s' "$DO_OUT" | jq -r '.block_id // empty')
  if [ -n "$block" ]; then BLOCKS_SEEN+=("$block"); fi
}

# Where the palette list can't be shown (as from `rex do`), the plain prompt asks instead.
test_unsupported_pick_falls_back_to_the_text_prompt() {
  local reason
  for reason in unsupported failed; do
    prompted_open "$PAGE_PORT" "$reason"
    assert_status 0 "fallback after $reason"
    assert_eq "http://localhost:$PAGE_PORT" "$(opened_url)" "url opened after $reason"
    assert_contains "$(jq -r '.title // empty' "$PROMPT_DIR/prompt.json" 2>/dev/null)" "Browser Pane" "the plain prompt was asked after $reason"
    rm -rf "$PROMPT_DIR"
  done
}

test_busy_rex_is_reported_and_cancelling_opens_nothing() {
  local before; before=$(block_ids | wc -l | tr -d ' ')
  prompted_open "" busy
  [ "$DO_STATUS" != 0 ] || fail "busy succeeded: $DO_OUT"
  assert_contains "$DO_ERR" "already asking something else" "busy message"
  [ ! -e "$PROMPT_DIR/prompt.json" ] || fail "busy fell back to the plain prompt"
  rm -rf "$PROMPT_DIR"
  prompted_open "" cancelled
  assert_status 0 "cancelled"
  [ ! -e "$PROMPT_DIR/prompt.json" ] || fail "cancel fell back to the plain prompt"
  assert_eq "" "$(opened_url)" "cancelling opens nothing"
  assert_eq "$before" "$(block_ids | wc -l | tr -d ' ')" "no new pane"
  rm -rf "$PROMPT_DIR"
}
