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

test_config_command_without_a_subcommand_prints_usage() {
  local out status
  out=$("$TREX_ROOT/bin/trex" config 2>&1); status=$?
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
