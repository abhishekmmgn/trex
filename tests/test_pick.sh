# Element Handoff ticket 01: "Trex: Pick Element" (action trex_pick) puts a
# Browser Pane's page into pick mode, and a click copies the element's
# description. Sourced by tests/run.sh.
#
# The clipboard is a stub (TREX_CLIPBOARD, see tests/load.lua) that writes to a
# file, so the user's clipboard is never touched. Clicks and keys go to the
# page through `kb ctl -i ID click/press`, which sends real CDP input, as a
# user's mouse does. Never run kb ctl here without -i.

PICK_URL=

# Opens a Browser Pane on PAGE (default pick.html) in tests/site, right of
# $ANCHOR, waits until READY (a JS expression) is true there, and points the
# clipboard at a file of this test's own. Sets $BROWSER, $BROWSER_ID, $CLIP.
pick_setup() { # [PAGE READY]
  PICK_URL="${PAGE_URL}${1:-pick.html}"
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
  # pick.html's own listeners are in place once `heard` exists.
  wait_for_page "${2:-typeof window.heard === \"object\"}" true || fail "$PICK_URL never finished loading"
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
    'text: Save changes' \
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
  local text
  text=$(sed -n 's/^text: //p' "$CLIP")
  assert_eq 80 "$(printf '%s' "$text" | /usr/bin/python3 -c 'import sys; print(len(sys.stdin.read()))')" "text is cut to 80 characters"
  case $text in 'word word '*…) ;; *) fail "the text line isn't the cut text: [$text]" ;; esac
  pick_teardown
}

test_pick_names_the_web_components_around() {
  pick_setup || { pick_teardown; return; }
  start_pick
  "$KB" ctl -i "$BROWSER_ID" click '#deep' >/dev/null
  wait_for_clip || { fail "nothing was copied after clicking #deep"; pick_teardown; return; }
  assert_eq '<span id="deep">' "$(sed -n 1p "$CLIP")" "the element"
  assert_eq 'in: <card-body> in <app-card>' "$(sed -n 2p "$CLIP")" "the web components around it, nearest first"
  assert_eq 'text: Deep inside' "$(sed -n 's/^text: /text: /p' "$CLIP")" "its text"
  pick_teardown
}

test_pick_shortens_long_attributes() {
  pick_setup || { pick_teardown; return; }
  start_pick
  "$KB" ctl -i "$BROWSER_ID" click '#far' >/dev/null
  wait_for_clip || { fail "nothing was copied after clicking #far"; pick_teardown; return; }
  assert_eq '<a id="far" class="one two three">' "$(sed -n 1p "$CLIP")" "the element"
  assert_eq 'html: <a id="far" class="one two three …" href="https://example.com/a/very/long/path/that/goes/on/and/on/an…">Far link</a>' \
    "$(sed -n 's/^html: /html: /p' "$CLIP")" "three classes, and the href cut at 60 characters"
  [ -z "$(sed -n '/^in: /p' "$CLIP")" ] || fail "an in: line on a page without web components: $(cat "$CLIP")"
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

test_pick_right_after_a_pick_gets_its_click() {
  pick_setup || { pick_teardown; return; }
  start_pick
  "$KB" ctl -i "$BROWSER_ID" click '#save' >/dev/null
  wait_for_clip || { fail "nothing was copied after the first pick"; pick_teardown; return; }
  # Within the second the first pick still swallows its click's leftovers.
  : >"$CLIP"
  start_pick
  "$KB" ctl -i "$BROWSER_ID" click '#name' >/dev/null
  wait_for_clip || { fail "the second pick, started at once, never copied"; pick_teardown; return; }
  assert_eq '<input id="name">' "$(sed -n 1p "$CLIP")" "the second pick got its own click"
  pick_teardown
}

test_pick_without_a_browser_pane_says_so() {
  trex_do trex_pick
  [ "$DO_STATUS" != 0 ] || fail "trex_pick with no Browser Pane succeeded: $DO_OUT"
  assert_contains "$DO_ERR" "no Browser Pane here" "trex_pick explains"
}

# --- React (Element Handoff ticket 03) ------------------------------------------
#
# tests/site/react: the same small app built with React 18 and React 19 in
# development, with source maps (tests/site/react/build.sh). React 18 keeps
# where each element's JSX is written (_debugSource, the path esbuild gave);
# React 19 keeps a stack into the bundle, which the source map turns into
# react/src/… (the map's ../src/ resolved against /react/19/).

# Picks SELECTOR on React fixture MAJOR and prints the description.
react_pick() { # MAJOR SELECTOR
  pick_setup "react/$1/" '!!document.getElementById("save")' || return 1
  start_pick
  "$KB" ctl -i "$BROWSER_ID" click "$2" >/dev/null
  wait_for_clip || { fail "nothing was copied after clicking $2 on React $1"; return 1; }
}

react_expect() { # MAJOR PATH
  local major=$1 path=$2
  react_pick "$major" '#save' && {
    assert_eq "<button id=\"save\" class=\"btn primary\"> in <SaveBar> at $path/SaveBar.jsx:6:7" "$(sed -n 1p "$CLIP")" "React $major: #save's first line"
    assert_eq 'react: SaveBar ← SettingsForm ← SettingsPage' "$(sed -n '/^react: /p' "$CLIP")" "React $major: #save's components"
  }
  pick_teardown
  kill_session; new_session
  react_pick "$major" '#badge' && {
    assert_eq "<span id=\"badge\"> in <Badge> at $path/SaveBar.jsx:14:10" "$(sed -n 1p "$CLIP")" "React $major: memo component"
    assert_eq 'react: Badge ← SettingsForm ← SettingsPage' "$(sed -n '/^react: /p' "$CLIP")" "React $major: memo is named once"
  }
  pick_teardown
  kill_session; new_session
  react_pick "$major" '#name' && {
    assert_eq "<input id=\"name\"> in <Field> at $path/SaveBar.jsx:19:10" "$(sed -n 1p "$CLIP")" "React $major: forwardRef component"
  }
  pick_teardown
}

test_pick_react_18_names_components_and_source() { react_expect 18 src; }

test_pick_react_19_maps_the_stack_to_the_source() { react_expect 19 react/src; }

test_pick_react_source_gives_up_after_2_s() {
  pick_setup react/19/ '!!document.getElementById("save")' || { pick_teardown; return; }
  # A source map that never arrives.
  page_eval 'window.fetch = () => new Promise(() => {}); "ok"' >/dev/null
  start_pick
  local started; started=$(/usr/bin/python3 -c 'import time; print(time.time())')
  "$KB" ctl -i "$BROWSER_ID" click '#save' >/dev/null
  wait_for_clip || { fail "nothing was copied when the source never came"; pick_teardown; return; }
  local took; took=$(/usr/bin/python3 -c "import time; print(round(time.time() - $started, 1))")
  assert_eq '<button id="save" class="btn primary"> in <SaveBar>' "$(sed -n 1p "$CLIP")" "copied without the source"
  assert_eq 'react: SaveBar ← SettingsForm ← SettingsPage' "$(sed -n '/^react: /p' "$CLIP")" "with the components"
  /usr/bin/python3 -c "import sys; sys.exit(0 if 1.8 <= $took <= 4 else 1)" || fail "copied after ${took} s, not about 2 s"
  wait_for_page '[...document.querySelectorAll("div")].some(d => d.textContent.includes("without the source"))' true ||
    fail "the note doesn't say the source was left out"
  pick_teardown
}
