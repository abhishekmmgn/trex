# trex's config file: loading, `trex config check`, and reload. Sourced by
# tests/run.sh. Every test reads a config under its own temp dir ($TREX_CONFIG, which
# tests/lib.sh gives each test), never ~/.config/trex, and never reloads the live
# Rex. `bin/trex config reload` is pointed at a throwaway session (TREX_RELOAD_DO).

CFG_XDG() { printf '%s\n' "${TREX_CONFIG%/trex/config.json}"; }

# Writes the test's config file from the text given.
write_config() { # TEXT
  mkdir -p "$(dirname "$TREX_CONFIG")"
  printf '%s\n' "$1" >"$TREX_CONFIG"
}

# `trex config check` on this test's config; sets $CHECK_OUT and $CHECK_STATUS.
check_config() {
  CHECK_OUT=$(XDG_CONFIG_HOME=$(CFG_XDG) "$TREX_ROOT/bin/trex" config check 2>&1)
  CHECK_STATUS=$?
}

# The config module on its own (tests/config.lua); sets $CFG_OUT (JSON).
config_flow() { # KEY=VALUE...
  CFG_OUT=$("$REX" do "$TREX_ROOT/tests/config.lua" "config=$TREX_CONFIG" "last_good=$TREX_STATE_DIR/last-good-config.json" --json "$@" 2>&1)
}

test_config_missing_file_means_all_defaults() {
  check_config
  assert_status_code_is 0 "$CHECK_STATUS" "check with no file"
  assert_contains "$CHECK_OUT" "uses its defaults" "check says what a missing file means"
  trex_do trex_reload_config
  assert_status 0 "reload with no file"
  assert_eq '{"default_url":"http://localhost:3000","devtools.side":"below","open_in":"split","pick.stay_on":true}' \
    "$(printf '%s' "$DO_OUT" | jq -cS '.settings')" "the defaults"
}

test_config_default_file_is_valid_and_is_all_defaults() {
  # The file setup writes must say exactly what a missing file means.
  mkdir -p "$(dirname "$TREX_CONFIG")"
  cp "$TREX_ROOT/lua/trex/config.default.json" "$TREX_CONFIG"
  check_config
  assert_eq "0" "$CHECK_STATUS" "the default file passes check: $CHECK_OUT"
  assert_contains "$CHECK_OUT" "is valid" "says valid"
  trex_do trex_reload_config
  local from_file; from_file=$(printf '%s' "$DO_OUT" | jq -cS '.settings')
  rm -f "$TREX_CONFIG"
  trex_do trex_reload_config
  assert_eq "$(printf '%s' "$DO_OUT" | jq -cS '.settings')" "$from_file" "default file = no file"
}

test_config_reload_applies_the_files_values() {
  write_config '{ "open_in": "window", "devtools": { "side": "left" }, "pick": { "stay_on": false }, "default_url": "http://localhost:5173" }'
  trex_do trex_reload_config
  assert_status 0 "reload"
  assert_eq '{"default_url":"http://localhost:5173","devtools.side":"left","open_in":"window","pick.stay_on":false}' \
    "$(printf '%s' "$DO_OUT" | jq -cS '.settings')" "the file's values"
  write_config '{ "open_in": "window" }'
  trex_do trex_reload_config
  assert_eq "below" "$(printf '%s' "$DO_OUT" | jq -r '.settings["devtools.side"]')" "keys the file leaves out get their defaults"
}

test_config_check_reports_a_bad_value_with_its_key_allowed_values_and_line() {
  write_config '{
  "default_url": "http://localhost:3000",
  "devtools": { "side": "under" },
  "pick": { "stay_on": "yes" }
}'
  check_config
  assert_eq "1" "$CHECK_STATUS" "exits 1"
  assert_contains "$CHECK_OUT" 'line 3: devtools.side: must be one of "below", "above", "right", "left", not "under"' "enum problem"
  assert_contains "$CHECK_OUT" 'line 4: pick.stay_on: must be a boolean, not "yes"' "type problem"
  assert_contains "$CHECK_OUT" "has 2 problems" "counts them"
}

test_config_check_reports_a_syntax_error_with_its_line() {
  write_config '{
  "open_in": "split",
  "devtools": {
    "side": "below",
  }
}'
  check_config
  assert_eq "1" "$CHECK_STATUS" "exits 1"
  assert_contains "$CHECK_OUT" "line 4: syntax error: a trailing comma" "the comma's line"
  write_config '{
  "open_in": "split"
  "pick": {}
}'
  check_config
  assert_contains "$CHECK_OUT" "line 3: syntax error" "a missing comma"
  write_config '{ "open_in": "split" } // note'
  check_config
  assert_contains "$CHECK_OUT" "comments aren't allowed" "comments are explained"
}

test_config_check_reports_an_unknown_key_but_reload_still_applies() {
  write_config '{
  "open_in": "window",
  "colour": "red"
}'
  check_config
  assert_eq "1" "$CHECK_STATUS" "check exits 1"
  assert_contains "$CHECK_OUT" "line 3: colour: isn't a trex setting" "names the key and line"
  assert_contains "$CHECK_OUT" "default_url, devtools, open_in, pick" "lists the settings"
  trex_do trex_reload_config
  assert_status 0 "reload goes on"
  assert_eq "window" "$(printf '%s' "$DO_OUT" | jq -r '.settings.open_in')" "the rest applied"
  assert_contains "$(printf '%s' "$DO_OUT" | jq -r '.message')" "line 3: colour" "and the unknown key is reported"
}

test_config_reload_refuses_a_bad_file_and_keeps_the_last_good_settings() {
  write_config '{ "open_in": "window", "devtools": { "side": "right" } }'
  trex_do trex_reload_config
  assert_status 0 "reload of a good file"
  write_config '{ "open_in": "tab" }'
  trex_do trex_reload_config
  assert_status 1 "reload of a bad file fails"
  assert_contains "$DO_ERR" 'open_in: must be one of "split", "window", not "tab"' "says what is wrong"
  assert_contains "$DO_ERR" "Keeping the last good settings" "says what is kept"
}

test_config_last_good_settings_survive_a_restart() {
  # Each run of tests/config.lua is a fresh load, as after a Rex restart.
  write_config '{ "open_in": "window", "devtools": { "side": "left" } }'
  config_flow
  assert_eq "file" "$(printf '%s' "$CFG_OUT" | jq -r '.reads[0].source')" "a good file is used"
  write_config '{ "open_in": "tab" }'
  config_flow
  assert_eq "last-good" "$(printf '%s' "$CFG_OUT" | jq -r '.reads[0].source')" "a bad file at load: the last good settings"
  assert_eq "false" "$(printf '%s' "$CFG_OUT" | jq -r '.reads[0].applied')" "not applied"
  assert_eq "window left" "$(printf '%s' "$CFG_OUT" | jq -r '.settings | "\(.open_in) \(.["devtools.side"])"')" "the earlier settings"
  write_config '{ nope'
  config_flow
  assert_eq "window" "$(printf '%s' "$CFG_OUT" | jq -r '.settings.open_in')" "also after a syntax error"
}

test_config_bad_file_with_no_last_good_uses_defaults() {
  write_config '{ "open_in": "tab" }'
  config_flow
  assert_eq "defaults" "$(printf '%s' "$CFG_OUT" | jq -r '.reads[0].source')" "defaults"
  assert_eq "split" "$(printf '%s' "$CFG_OUT" | jq -r '.settings.open_in')" "the default open_in"
}

test_config_a_reload_in_the_server_keeps_what_it_holds_after_a_bad_file() {
  write_config '{ "open_in": "window" }'
  local bad; bad=$(mktemp); printf '{ "open_in": "tab" }\n' >"$bad"
  config_flow "then_file=$bad"
  rm -f "$bad"
  assert_eq "file last-good" "$(printf '%s' "$CFG_OUT" | jq -r '[.reads[].source] | join(" ")')" "second read keeps the first"
  assert_eq "window" "$(printf '%s' "$CFG_OUT" | jq -r '.settings.open_in')" "still window"
}

test_config_get_reads_one_setting_and_refuses_an_unknown_name() {
  write_config '{ "devtools": { "side": "above" } }'
  config_flow "get=devtools.side"
  assert_eq "above" "$(printf '%s' "$CFG_OUT" | jq -r '.get')" "get(devtools.side)"
  config_flow "get=pick.stay_on"
  assert_eq "true" "$(printf '%s' "$CFG_OUT" | jq -r '.get')" "a boolean default"
  config_flow "get=devtools.sid"
  assert_contains "$(printf '%s' "$CFG_OUT" | jq -r '.get')" "there is no setting devtools.sid" "a typo is an error, not nil"
}

test_config_command_with_an_unknown_subcommand_prints_usage() {
  local out status
  out=$("$TREX_ROOT/bin/trex" config frobnicate 2>&1); status=$?
  assert_eq "2" "$status" "exits 2"
  assert_contains "$out" "trex config check" "lists check"
  assert_contains "$out" "trex config reload" "lists reload"
}

test_config_reload_command_reaches_the_server_and_reports() {
  export TREX_RELOAD_DO="$TREX_ROOT/tests/load.lua --action trex_reload_config -s $SESSION -b $ANCHOR"
  write_config '{ "open_in": "window" }'
  local out status
  out=$("$TREX_ROOT/bin/trex" config reload 2>&1); status=$?
  assert_eq "0" "$status" "reload of a good file: $out"
  assert_contains "$out" "reloaded $TREX_CONFIG" "says what it reloaded"
  write_config '{ "open_in": "tab" }'
  out=$("$TREX_ROOT/bin/trex" config reload 2>&1); status=$?
  assert_eq "1" "$status" "reload of a bad file exits 1"
  assert_contains "$out" 'line 1: open_in: must be one of "split", "window", not "tab"' "the problem, with key and line"
  unset TREX_RELOAD_DO
}

assert_status_code_is() { # EXPECTED ACTUAL MESSAGE
  assert_eq "$1" "$2" "$3: exit status"
}

# --- trex config edit ------------------------------------------------------------
# The editor is a stub script: it copies the next of the files 1, 2, ... in $STUB_DIR over
# the file it is given (and leaves it alone when there are none left). The prompt's answers
# are fed on stdin. The server is the test's throwaway session (TREX_RELOAD_DO).

# edit_flow ANSWERS [VAR=VALUE...]: runs `trex config edit`; sets $EDIT_OUT (stdout+stderr) and $EDIT_STATUS.
edit_flow() {
  local answers=$1; shift
  EDIT_OUT=$(printf '%b' "$answers" | env "$@" XDG_CONFIG_HOME="$(CFG_XDG)" TREX_STUB_DIR="$STUB_DIR" \
    TREX_RELOAD_DO="$TREX_ROOT/tests/load.lua --action trex_reload_config -s $SESSION -b $ANCHOR" \
    "$TREX_ROOT/bin/trex" config edit 2>&1)
  EDIT_STATUS=$?
}

make_stub_editor() { # sets $STUB_DIR and $STUB_EDITOR
  STUB_DIR=$(mktemp -d)
  STUB_EDITOR="$STUB_DIR/editor"
  cat >"$STUB_EDITOR" <<'STUB'
#!/bin/sh
n=$(cat "$TREX_STUB_DIR/n" 2>/dev/null || echo 0)
n=$((n + 1)); echo "$n" >"$TREX_STUB_DIR/n"
echo "$0 $*" >>"$TREX_STUB_DIR/calls"
[ -f "$TREX_STUB_DIR/$n" ] && cp "$TREX_STUB_DIR/$n" "$1"
exit 0
STUB
  chmod +x "$STUB_EDITOR"
}

test_config_edit_creates_the_files_and_reloads_a_valid_file() {
  make_stub_editor
  printf '{ "open_in": "window" }\n' >"$STUB_DIR/1"
  edit_flow "" EDITOR="$STUB_EDITOR"
  assert_eq "0" "$EDIT_STATUS" "exits 0: $EDIT_OUT"
  assert_contains "$EDIT_OUT" "is valid" "says valid"
  assert_contains "$EDIT_OUT" "reloaded $TREX_CONFIG" "and that it reloaded"
  assert_eq "ok" "$([ -f "$(dirname "$TREX_CONFIG")/config.schema.json" ] && echo ok)" "the schema is created"
  assert_eq "window" "$(jq -r .open_in "$TREX_CONFIG")" "the file is the editor's"
  trex_do trex_reload_config
  assert_eq "window" "$(printf '%s' "$DO_OUT" | jq -r '.settings.open_in')" "the server holds the new settings"
  rm -rf "$STUB_DIR"
}

test_config_edit_opens_a_new_file_filled_with_every_default() {
  make_stub_editor
  edit_flow "" EDITOR="$STUB_EDITOR"
  assert_eq "0" "$EDIT_STATUS" "exits 0: $EDIT_OUT"
  assert_eq "$(cat "$TREX_ROOT/lua/trex/config.default.json")" "$(cat "$TREX_CONFIG")" "a new file is every default"
  assert_contains "$(cat "$STUB_DIR/calls")" "$TREX_CONFIG" "the editor was given the config path"
  rm -rf "$STUB_DIR"
}

test_config_edit_prefers_visual_then_editor() {
  make_stub_editor
  local other="$STUB_DIR/other"; printf '#!/bin/sh\necho other >>"$TREX_STUB_DIR/other-calls"\n' >"$other"; chmod +x "$other"
  edit_flow "" VISUAL="$STUB_EDITOR" EDITOR="$other"
  assert_eq "1" "$(cat "$STUB_DIR/n")" "VISUAL ran"
  assert_eq "" "$(cat "$STUB_DIR/other-calls" 2>/dev/null)" "not EDITOR"
  edit_flow "" -u VISUAL EDITOR="$STUB_EDITOR --flag"
  assert_eq "2" "$(cat "$STUB_DIR/n")" "EDITOR ran when VISUAL is unset"
  assert_contains "$(tail -n1 "$STUB_DIR/calls")" "--flag $TREX_CONFIG" "an editor with arguments works"
  rm -rf "$STUB_DIR"
}

test_config_edit_invalid_file_lists_problems_and_edit_again_can_fix_it() {
  make_stub_editor
  printf '{ "open_in": "tab" }\n' >"$STUB_DIR/1"
  printf '{ "open_in": "window" }\n' >"$STUB_DIR/2"
  edit_flow "e\n" EDITOR="$STUB_EDITOR"
  assert_eq "0" "$EDIT_STATUS" "exits 0 once fixed: $EDIT_OUT"
  assert_contains "$EDIT_OUT" 'line 1: open_in: must be one of "split", "window", not "tab"' "lists the problem with key and line"
  assert_contains "$EDIT_OUT" "(e)dit again / (k)eep anyway / (r)evert?" "asks"
  assert_eq "2" "$(cat "$STUB_DIR/n")" "the editor ran twice"
  assert_contains "$EDIT_OUT" "reloaded" "reloaded after the fix"
  rm -rf "$STUB_DIR"
}

test_config_edit_keep_leaves_the_file_and_the_last_good_settings_stay() {
  make_stub_editor
  write_config '{ "open_in": "window" }'
  trex_do trex_reload_config
  assert_status 0 "a good file is loaded first"
  printf '{ "open_in": "tab" }\n' >"$STUB_DIR/1"
  edit_flow "k\n" EDITOR="$STUB_EDITOR"
  assert_eq "1" "$EDIT_STATUS" "exits 1"
  assert_eq "tab" "$(jq -r .open_in "$TREX_CONFIG")" "the file is left as written"
  assert_contains "$EDIT_OUT" "Keeping the last good settings" "the server says what it keeps"
  config_flow
  assert_eq "window" "$(printf '%s' "$CFG_OUT" | jq -r '.settings.open_in')" "after a restart the last good settings are used"
  rm -rf "$STUB_DIR"
}

test_config_edit_revert_restores_the_last_good_file() {
  make_stub_editor
  write_config '{ "open_in": "window", "devtools": { "side": "left" } }'
  trex_do trex_reload_config
  assert_status 0 "a good file is loaded first"
  local good; good=$(cat "$TREX_CONFIG")
  printf '{ "open_in": "tab" }\n' >"$STUB_DIR/1"
  edit_flow "r\n" EDITOR="$STUB_EDITOR"
  assert_eq "0" "$EDIT_STATUS" "exits 0: $EDIT_OUT"
  assert_eq "$good" "$(cat "$TREX_CONFIG")" "the last good file is back"
  assert_contains "$EDIT_OUT" "reverted" "says so"
  rm -rf "$STUB_DIR"
}

test_config_edit_revert_with_no_last_good_file_goes_back_to_the_defaults() {
  make_stub_editor
  printf '{ "open_in": "tab" }\n' >"$STUB_DIR/1"
  edit_flow "r\n" EDITOR="$STUB_EDITOR"
  assert_eq "$(cat "$TREX_ROOT/lua/trex/config.default.json")" "$(cat "$TREX_CONFIG")" "the defaults"
  rm -rf "$STUB_DIR"
}

test_config_edit_asks_again_on_an_unknown_answer_and_keeps_the_file_when_stdin_ends() {
  make_stub_editor
  printf '{ "open_in": "tab" }\n' >"$STUB_DIR/1"
  edit_flow "what\n" EDITOR="$STUB_EDITOR"
  assert_eq "1" "$EDIT_STATUS" "exits 1"
  assert_eq "2" "$(printf '%s' "$EDIT_OUT" | grep -o '(e)dit again / ' | wc -l | tr -d ' ')" "asked twice"
  assert_contains "$EDIT_OUT" "no answer; keeping the file" "end of input keeps the file"
  assert_eq "tab" "$(jq -r .open_in "$TREX_CONFIG")" "as written"
  rm -rf "$STUB_DIR"
}

test_config_edit_action_opens_a_split_beside_the_focused_pane() {
  local before after new
  before=$(block_ids | wc -l | tr -d ' ')
  trex_do trex_edit_config
  assert_status 0 "the action runs"
  new=$(printf '%s' "$DO_OUT" | jq -r '.block_id')
  case "$new" in block:*) ;; *) fail "no block id in $DO_OUT" ;; esac
  BLOCKS_SEEN+=("$new")
  after=$(block_ids | wc -l | tr -d ' ')
  assert_eq "$((before + 1))" "$after" "one more pane"
}

# --- trex config show ------------------------------------------------------------------

# `trex config ARGS` asking this test's throwaway session, with the test's config;
# sets $SHOW_OUT and $SHOW_STATUS. SHOW_DO=none means there is no server to ask.
show_flow() { # [ARGS...]
  local do_target="$TREX_ROOT/tests/load.lua --action trex_config_show -s $SESSION -b $ANCHOR"
  [ "${SHOW_DO:-}" = none ] && do_target=no_such_action
  SHOW_OUT=$(XDG_CONFIG_HOME=$(CFG_XDG) TREX_SHOW_DO="$do_target" "$TREX_ROOT/bin/trex" config "$@" 2>&1)
  SHOW_STATUS=$?
}

# The line of $SHOW_OUT that is about setting KEY.
show_row() { printf '%s\n' "$SHOW_OUT" | grep -E "^[* ] $1 "; }

test_config_show_lists_every_setting_with_values_allowed_values_and_summary() {
  show_flow show
  assert_eq "0" "$SHOW_STATUS" "exit"
  assert_eq "$TREX_CONFIG" "$(printf '%s\n' "$SHOW_OUT" | head -n1)" "the first line is the config path"
  local key
  for key in default_url devtools.side open_in pick.stay_on; do
    assert_eq "1" "$(show_row "$key" | wc -l | tr -d ' ')" "one row for $key"
  done
  assert_contains "$(show_row devtools.side)" "below" "the value"
  assert_contains "$(show_row devtools.side)" "(below | above | right | left)" "the allowed values"
  assert_contains "$(show_row pick.stay_on)" "(true | false)" "booleans allow true and false"
  assert_contains "$(show_row open_in)" "where a Browser Pane opens" "the summary, from the schema"
  assert_eq "0" "$(show_row default_url | grep -c '(')" "a free-text setting lists no allowed values"
  assert_eq "0" "$(printf '%s\n' "$SHOW_OUT" | grep -c '^\*')" "no row is marked"
  assert_contains "$SHOW_OUT" 'Edit with `trex config edit`.' "the footer"
  assert_eq "0" "$(printf '%s\n' "$SHOW_OUT" | awk 'length > 120' | wc -l | tr -d ' ')" "no line is over 120 columns"
}

test_config_show_marks_a_value_changed_from_the_default() {
  write_config '{ "devtools": { "side": "right" }, "default_url": "http://localhost:3000" }'
  show_flow show
  assert_eq "0" "$SHOW_STATUS" "exit"
  assert_contains "$(show_row devtools.side)" "right" "the value in effect"
  assert_contains "$(printf '%s\n' "$SHOW_OUT" | grep '^\* devtools.side')" "default below" "the changed row says the default"
  assert_eq "1" "$(printf '%s\n' "$SHOW_OUT" | grep -cE '^\* [a-z_.]+  ')" "only the changed row is marked"
  assert_contains "$SHOW_OUT" '* changed from the default. Edit with `trex config edit`.' "the footer says what * means"
  # Columns line up: every row's allowed-values column starts at the same place.
  local cols
  cols=$(printf '%s\n' "$SHOW_OUT" | grep -E '\((below|split|true)' | awk '{ print index($0, "(") }' | sort -u | wc -l | tr -d ' ')
  assert_eq "1" "$cols" "allowed values are aligned"
}

test_config_show_reports_the_last_good_settings_when_the_file_has_problems() {
  write_config '{ "open_in": "window" }'
  show_flow show # the server loads the good file and keeps a copy
  assert_contains "$(show_row open_in)" "window" "the good file"
  write_config '{ "open_in": "tab" }'
  show_flow show
  assert_eq "0" "$SHOW_STATUS" "exit"
  assert_contains "$SHOW_OUT" "last good settings are in effect" "says what is in effect"
  assert_contains "$SHOW_OUT" "trex config check" "points to check"
  assert_contains "$(show_row open_in)" "window" "the last good value is shown, not the bad one"
}

test_config_show_action_returns_the_settings_and_whether_the_file_blocks() {
  trex_do trex_config_show
  assert_status 0 "the action"
  assert_eq "false" "$(printf '%s' "$DO_OUT" | jq -r '.blocking')" "no problems"
  assert_eq "below" "$(printf '%s' "$DO_OUT" | jq -r '.settings["devtools.side"]')" "settings come back flat"
  write_config '{ "open_in": "tab" }'
  trex_do trex_config_show
  assert_eq "true" "$(printf '%s' "$DO_OUT" | jq -r '.blocking')" "a bad file is blocking"
}

test_config_show_reads_the_file_when_rex_cannot_be_asked() {
  write_config '{ "open_in": "window" }'
  SHOW_DO=none show_flow show
  assert_eq "0" "$SHOW_STATUS" "exit"
  assert_contains "$SHOW_OUT" "Rex isn't reachable" "says so"
  assert_contains "$(show_row open_in)" "window" "the file's value"
  rm -f "$TREX_CONFIG"
  SHOW_DO=none show_flow show
  assert_contains "$SHOW_OUT" "no config file yet" "no file: the defaults"
  assert_contains "$(show_row open_in)" "split" "the default"
  write_config '{ "open_in": "tab" }'
  SHOW_DO=none show_flow show
  assert_contains "$SHOW_OUT" "The file has problems" "a bad file is named"
  assert_contains "$(show_row open_in)" "split" "the defaults then"
}

test_config_bare_config_is_show() {
  write_config '{ "open_in": "window" }'
  local show
  show_flow show; show=$SHOW_OUT
  show_flow
  assert_eq "0" "$SHOW_STATUS" "bare config exits 0"
  assert_eq "$show" "$SHOW_OUT" "bare config prints what show prints"
}

test_config_show_lists_a_setting_added_to_the_schema_without_code_changes() {
  local dir out; dir=$(mktemp -d)
  jq '.properties.extra_flag = {type: "boolean", default: false, "x-summary": "a made-up setting"}' \
    "$TREX_ROOT/lua/trex/config.schema.json" >"$dir/schema.json"
  cat >"$dir/run.lua" <<EOF
local util = assert(loadfile("$TREX_ROOT/lua/trex/util.lua"))()
local config = assert(loadfile("$TREX_ROOT/lua/trex/config.lua"))(util, "$dir/schema.json")
print(config.report("$TREX_CONFIG", { extra_flag = true, default_url = "http://localhost:3000", open_in = "split", ["pick.stay_on"] = true, ["devtools.side"] = "below" }))
rex.stop(0)
EOF
  out=$("$REX" do "$dir/run.lua" 2>&1)
  assert_contains "$out" "* extra_flag" "the new setting is listed, and marked as changed"
  assert_contains "$out" "(true | false)" "with its allowed values"
  assert_contains "$out" "a made-up setting" "and its summary"
  rm -rf "$dir"
}

test_config_help_ends_with_the_settings_list_without_current_values() {
  write_config '{ "open_in": "window" }'
  local out; out=$(XDG_CONFIG_HOME=$(CFG_XDG) "$TREX_ROOT/bin/trex" config --help 2>&1)
  assert_contains "$out" "trex config [show]" "names show"
  assert_contains "$out" "devtools.side" "lists the settings"
  assert_contains "$out" "(below | above | right | left)" "with allowed values"
  assert_contains "$(printf '%s\n' "$out" | grep ' open_in ')" "split" "the default, not the file's value"
  assert_eq "0" "$(printf '%s\n' "$out" | grep -c '^\*')" "nothing is marked"
}
