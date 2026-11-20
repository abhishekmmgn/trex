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

press_f12() { # BLOCK  → sets $HANDLED
  local out
  out=$("$REX" do "$TREX_ROOT/tests/f12.lua" -s "$SESSION" -b "$1" --timeout 20s --json 2>&1) || { fail "f12.lua: $out"; return 1; }
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
