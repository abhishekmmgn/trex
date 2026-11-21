# Element Handoff ticket 01: "Trex: Pick Element" (action trex_pick) puts a
# Browser Pane's page into pick mode, and a click copies the element's
# description. Sourced by tests/run.sh.
#
# The clipboard is a stub (TREX_CLIPBOARD, see tests/load.lua) that writes to a
# file, so the user's clipboard is never touched. Clicks and keys go to the
# page through `kb ctl -i ID click/press`, which sends real CDP input, as a
# user's mouse does. Never run kb ctl here without -i.

PICK_URL=

# Opens a Browser Pane on tests/site/pick.html, right of $ANCHOR, and points
# the clipboard at a file of this test's own. Sets $BROWSER, $BROWSER_ID, $CLIP.
pick_setup() {
  PICK_URL="${PAGE_URL}pick.html"
  CLIP_DIR=$(mktemp -d)
  CLIP=$CLIP_DIR/clipboard
  printf '#!/bin/sh\nprintf %%s "$LC_CTYPE" > "%s.ctype"\ncat > "%s"\n' "$CLIP" "$CLIP" >"$CLIP_DIR/copy"
  chmod +x "$CLIP_DIR/copy"
  export TREX_CLIPBOARD=$CLIP_DIR/copy

  trex_do trex_open url="$PICK_URL"
  assert_status 0 "trex_open url=$PICK_URL"
  BROWSER=$(printf '%s' "$DO_OUT" | jq -r '.block_id // empty')
  [ -n "$BROWSER" ] || { fail "trex_open returned no block_id: $DO_OUT"; return 1; }
  BLOCKS_SEEN+=("$BROWSER")
  BROWSER_ID=$(kb_row "$BROWSER" | kb_field id)
  [ -n "$BROWSER_ID" ] || { fail "kb list never showed a kb in $BROWSER"; return 1; }
  kb_url "$BROWSER" "$PICK_URL" >/dev/null || { fail "the kb in $BROWSER never showed $PICK_URL"; return 1; }
  # The page's own listeners are in place once `heard` exists.
  wait_for_page 'typeof window.heard' object || fail "pick.html never finished loading"
}

pick_teardown() {
  rm -rf "$CLIP_DIR"
  unset TREX_CLIPBOARD
}

page_eval() { "$KB" ctl -i "$BROWSER_ID" eval "$1" 2>&1; }

# Waits up to 10 s for EXPRESSION to evaluate to VALUE in the page.
wait_for_page() { # EXPRESSION VALUE
  local i
  for i in $(seq 1 40); do
    [ "$(page_eval "$1")" = "$2" ] && return 0
    sleep 0.25
  done
  return 1
}

overlay_shown() { page_eval '!!document.getElementById("__trex_pick")'; }

# Waits up to 10 s for the stub clipboard to be written.
wait_for_clip() {
  local i
  for i in $(seq 1 40); do
    [ -s "$CLIP" ] && return 0
    sleep 0.25
  done
  return 1
}

start_pick() { # [BLOCK]
  trex_do trex_pick -b "${1:-$BROWSER}"
  assert_status 0 "trex_pick in ${1:-$BROWSER}"
  assert_eq true "$(printf '%s' "$DO_OUT" | jq -r '.started // false')" "trex_pick started pick mode ($DO_OUT)"
  assert_eq "$BROWSER_ID" "$(printf '%s' "$DO_OUT" | jq -r '.kb // empty')" "trex_pick reached the Browser Pane's kb"
  assert_eq true "$(overlay_shown)" "the pick overlay is on the page"
}

test_pick_copies_the_description_and_the_page_hears_nothing() {
  pick_setup || { pick_teardown; return; }
  start_pick

  "$KB" ctl -i "$BROWSER_ID" hover '#save' >/dev/null
  wait_for_page 'document.getElementById("__trex_pick").children[4].textContent' 'button#save.btn.primary  112 × 32' ||
    fail "hovering #save didn't label it (label: $(page_eval 'document.getElementById("__trex_pick")?.children[4].textContent'))"

  "$KB" ctl -i "$BROWSER_ID" click '#save' >/dev/null
  wait_for_clip || { fail "nothing was copied after clicking #save"; pick_teardown; return; }
  local expected
  expected=$(printf '%s\n' \
    '<button id="save" class="btn primary">' \
    "page: $PICK_URL" \
    'path: #save' \
    'box: 112×32 at 94,131 (page px)' \
    'html: <button id="save" type="submit" class="btn primary">Save changes</button>')
  assert_eq "$expected" "$(cat "$CLIP")" "the description copied"
  # pbcopy reads its input as Mac Roman without a UTF-8 locale (× became √ó).
  assert_eq UTF-8 "$(cat "$CLIP.ctype")" "the clipboard command runs with a UTF-8 locale"

  sleep 1.2 # past the second in which the rest of the click is swallowed
  assert_eq '{"pointerdown":0,"mousedown":0,"pointerup":0,"mouseup":0,"click":0,"keydown":0,"focus":0}' \
    "$(page_eval 'JSON.stringify(window.heard)')" "the page heard nothing of the pick"
  assert_eq false "$(overlay_shown)" "the overlay is gone after the pick"
  assert_eq false "$(page_eval 'globalThis.__trexPick.active()')" "pick mode is off"

  # And the page has its clicks back.
  "$KB" ctl -i "$BROWSER_ID" click '#save' >/dev/null
  assert_eq 1 "$(page_eval 'window.heard.click')" "a click after pick mode reaches the page"
  pick_teardown
}

test_pick_from_the_pane_beside_and_esc_cancels() {
  pick_setup || { pick_teardown; return; }
  start_pick "$ANCHOR"

  "$KB" ctl -i "$BROWSER_ID" press Escape >/dev/null
  wait_for_page '!!document.getElementById("__trex_pick")' false || fail "Esc didn't end pick mode"
  assert_eq 0 "$(page_eval 'window.heard.keydown')" "the page didn't hear the Esc"
  sleep 0.5
  [ -e "$CLIP" ] && fail "something was copied after Esc: $(cat "$CLIP")"
  pick_teardown
}

test_pick_again_cancels() {
  pick_setup || { pick_teardown; return; }
  start_pick
  trex_do trex_pick -b "$BROWSER"
  assert_status 0 "second trex_pick"
  assert_eq true "$(printf '%s' "$DO_OUT" | jq -r '.cancelled // false')" "the second trex_pick cancelled ($DO_OUT)"
  assert_eq false "$(overlay_shown)" "the overlay is gone"
  pick_teardown
}

test_pick_cuts_long_html() {
  pick_setup || { pick_teardown; return; }
  start_pick
  "$KB" ctl -i "$BROWSER_ID" click '#long' >/dev/null
  wait_for_clip || { fail "nothing was copied after clicking #long"; pick_teardown; return; }
  local html
  html=$(sed -n 's/^html: //p' "$CLIP")
  assert_eq 300 "$(printf '%s' "$html" | /usr/bin/python3 -c 'import sys; print(len(sys.stdin.read()))')" "html is cut to 300 characters"
  assert_contains "$html" '<p id="long">word word' "html starts with the element"
  case $html in *…) ;; *) fail "the cut html doesn't end with …: [$html]" ;; esac
  pick_teardown
}

label_is() { # TEXT: waits for the outline's label to read TEXT
  wait_for_page 'document.getElementById("__trex_pick")?.children[4].textContent' "$1" ||
    fail "the label never read [$1] (it reads: $(page_eval 'document.getElementById("__trex_pick")?.children[4].textContent'))"
}

test_pick_skips_an_empty_layer_over_its_parent() {
  pick_setup || { pick_teardown; return; }
  start_pick
  # .fill is on top, inside .ripple, both empty and covering the button.
  assert_eq '<span class="fill">' "$(page_eval '(() => { document.querySelector("#sub").scrollIntoView({ block: "center" }); const r = document.querySelector(".fill").getBoundingClientRect(); const e = document.elementFromPoint(r.x + r.width / 2, r.y + r.height / 2); return "<" + e.localName + " class=\"" + e.className + "\">"; })()')" \
    "the fill is the element under the pointer"
  "$KB" ctl -i "$BROWSER_ID" click '.fill' >/dev/null
  wait_for_clip || { fail "nothing was copied after clicking .fill"; pick_teardown; return; }
  assert_eq '<button id="sub" class="subscribe">' "$(head -n 1 "$CLIP")" "the button under the layer is picked"
  assert_eq 'path: #sub' "$(sed -n 3p "$CLIP")" "its path"
  pick_teardown
}

test_pick_arrow_keys_choose_the_parent_and_back() {
  pick_setup || { pick_teardown; return; }
  start_pick
  "$KB" ctl -i "$BROWSER_ID" hover '#save' >/dev/null
  label_is 'button#save.btn.primary  112 × 32'
  "$KB" ctl -i "$BROWSER_ID" press ArrowUp >/dev/null
  label_is "$(page_eval '(() => { const r = document.querySelector(".actions").getBoundingClientRect(); return "div.actions.toolbar.wide  " + Math.round(r.width) + " × " + Math.round(r.height); })()')"
  "$KB" ctl -i "$BROWSER_ID" press ArrowDown >/dev/null
  label_is 'button#save.btn.primary  112 × 32'
  "$KB" ctl -i "$BROWSER_ID" press ArrowUp >/dev/null
  label_is "$(page_eval '(() => { const r = document.querySelector(".actions").getBoundingClientRect(); return "div.actions.toolbar.wide  " + Math.round(r.width) + " × " + Math.round(r.height); })()')"
  # The click lands on #save, inside the div ↑ chose, so the div is picked.
  "$KB" ctl -i "$BROWSER_ID" click '#save' >/dev/null
  wait_for_clip || { fail "nothing was copied after ↑ and a click"; pick_teardown; return; }
  assert_eq '<div class="actions toolbar wide">' "$(head -n 1 "$CLIP")" "↑ then a click picks the parent"
  assert_eq 'path: #app > form > div' "$(sed -n 3p "$CLIP")" "the parent's path"
  assert_eq 0 "$(page_eval 'window.heard.keydown')" "the page didn't hear the arrows"
  pick_teardown
}

test_pick_without_a_browser_pane_says_so() {
  trex_do trex_pick
  [ "$DO_STATUS" != 0 ] || fail "trex_pick with no Browser Pane succeeded: $DO_OUT"
  assert_contains "$DO_ERR" "no Browser Pane here" "trex_pick explains"
}
