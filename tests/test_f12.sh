# F12's key binding (lua/trex/f12.lua): consumed in a pane running kb, passed on
# unchanged everywhere else. Sourced by tests/run.sh.
#
# Keys are pressed through tests/f12.lua, which loads the binding as a client
# script. Neither test sends F12 to a real kb: the "kb" here is a copy of cat, so
# a key that got through would only be echoed (as ^[[24~), never reach kb's own
# F12 (which opens DevTools in whatever Chrome macOS picks).

# Splits a pane below $ANCHOR running ARGV, waits until its foreground program is
# NAME, and prints the block id.
pane_running() { # NAME ARGV...
  local name=$1 block i fg; shift
  block=$("$REX" split -s "$SESSION" -b "$ANCHOR" --split=below --focus=false --shell=none --json -- "$@" |
    jq -r '.block_ids[0] // empty')
  [ -n "$block" ] || return 1
  BLOCKS_SEEN+=("$block")
  for i in $(seq 1 40); do
    fg=$("$REX" block call -s "$SESSION" -b "$block" process 2>/dev/null | jq -r '.foreground.name // empty')
    if [ "$fg" = "$name" ]; then printf '%s\n' "$block"; return 0; fi
    sleep 0.25
  done
  return 1
}

# Presses F12 in BLOCK. Given FAIL, trex's stub handler raises that message.
press_f12() { # BLOCK [FAIL]  → sets $HANDLED
  local out args='{}'
  [ -n "${2:-}" ] && args=$(jq -nc --arg m "$2" '{fail: $m}')
  out=$("$REX" do "$TREX_ROOT/tests/f12.lua" -s "$SESSION" -b "$1" --timeout 20s --json --args "$args" 2>&1) ||
    { fail "f12.lua: $out"; return 1; }
  HANDLED=$(printf '%s' "$out" | jq -r '.handled')
}

label_of() { # BLOCK
  "$REX" block ls -s "$SESSION" --json | jq -r --arg b "$1" '.blocks[] | select(.block_id == $b) | .label'
}

screen() { # BLOCK
  "$REX" capture -s "$SESSION" -b "$1"
}

test_f12_passes_through_in_a_pane_not_running_kb() {
  local block
  block=$(pane_running cat /bin/cat -v) || { fail "no pane running cat"; return; }
  press_f12 "$block" || return
  assert_eq "false" "$HANDLED" "F12 handled by trex"
  sleep 0.5
  assert_contains "$(screen "$block")" "^[[24~" "cat received F12"
  [ "$(label_of "$block")" != "trex f12" ] || fail "trex's handler ran in a pane not running kb"
}

test_f12_is_consumed_in_a_pane_running_kb() {
  local dir block
  dir=$(mktemp -d)
  cp /bin/cat "$dir/kb"
  # macOS kills a copied system binary unless it is signed again.
  /usr/bin/codesign --force -s - "$dir/kb" 2>/dev/null || { fail "couldn't sign the fake kb"; rm -f "$dir/kb"; rmdir "$dir"; return; }
  block=$(pane_running kb "$dir/kb" -v) || { fail "no pane running the fake kb"; rm -f "$dir/kb"; rmdir "$dir"; return; }
  press_f12 "$block"
  assert_eq "true" "$HANDLED" "F12 handled by trex"
  assert_eq "trex f12" "$(label_of "$block")" "trex's handler ran"
  sleep 0.5
  case "$(screen "$block")" in *"[24~"*) fail "F12 reached the program in the kb pane" ;; esac
  rm -f "$dir/kb"; rmdir "$dir"
}

# A key function can't show a prompt or fail an action, so when F12's work fails
# trex shows what went wrong in a notice floating in the window, without taking
# focus. Presses F12 in a fake kb pane with a failing handler, checks the notice,
# and sets $NOTICE. Cleans up its fake kb in $FAKE_KB_DIR (rm -rf it after).
f12_shows_a_notice() {
  local block msg="trex: the KittyBrowser in this pane (2-test) was started without DevTools."
  FAKE_KB_DIR=$(mktemp -d)
  cp /bin/cat "$FAKE_KB_DIR/kb"
  /usr/bin/codesign --force -s - "$FAKE_KB_DIR/kb" 2>/dev/null || { fail "couldn't sign the fake kb"; return 1; }
  block=$(pane_running kb "$FAKE_KB_DIR/kb" -v) || { fail "no pane running the fake kb"; return 1; }
  local focused; focused=$(focused_block)
  press_f12 "$block" "$msg"
  assert_eq "true" "$HANDLED" "F12 handled by trex"
  NOTICE=$("$REX" block ls -s "$SESSION" --json | jq -r '.blocks[] | select(.label == "trex notice") | .block_id' | head -n 1)
  [ -n "$NOTICE" ] || { fail "no trex notice pane"; return 1; }
  BLOCKS_SEEN+=("$NOTICE")
  sleep 0.5
  assert_contains "$(screen "$NOTICE" | tr -d '\n')" "started without DevTools" "the notice shows the message"
  assert_eq "$focused" "$(focused_block)" "focus stays where it was"
}

# Waits up to SECONDS for the notice to close; fails with MESSAGE if it doesn't.
notice_closes_within() { # SECONDS MESSAGE
  local i
  for i in $(seq 1 $(($1 * 4))); do block_ids | grep -qx "$NOTICE" || return 0; sleep 0.25; done
  fail "$2"
}

test_f12_shows_what_went_wrong_and_a_key_closes_it() {
  f12_shows_a_notice || { rm -rf "$FAKE_KB_DIR"; return; }
  # (The notice runs bash, never kb, so a key is safe here.)
  "$REX" send -s "$SESSION" -b "$NOTICE" x >/dev/null 2>&1
  notice_closes_within 5 "the notice stayed open after a key"
  rm -rf "$FAKE_KB_DIR"
}

test_f12_notice_closes_by_itself() {
  f12_shows_a_notice || { rm -rf "$FAKE_KB_DIR"; return; }
  notice_closes_within 12 "the notice stayed open"
  rm -rf "$FAKE_KB_DIR"
}
