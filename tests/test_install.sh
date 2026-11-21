# bin/trex install / uninstall, on scratch copies of a Rex config. Sourced by
# tests/run.sh. Never touches ~/.config/rex/init.lua (it is only read, to copy it).

TREX_BIN="$TREX_ROOT/bin/trex"

# A small config with another plugin's marked block, like the user's.
fixture_config() {
  local file; file=$(mktemp -d)/init.lua
  printf '%s\n' \
    '-- Rex configuration.' \
    '' \
    '-- >>> other >>>' \
    'rex.action{ name = "other_hello", title = "Other: Hello", run = function() return "hi" end }' \
    'rex.bind("cmd+shift+h", "other_hello")' \
    '-- <<< other <<<' >"$file"
  printf '%s\n' "$file"
}

check_json() { "$REX" config check --json "$1"; }

# Installs into CONFIG and checks Rex loads it cleanly with trex's action and key.
installs_cleanly() { # CONFIG
  local before after
  local -x XDG_CONFIG_HOME XDG_STATE_HOME; XDG_CONFIG_HOME=$(mktemp -d); XDG_STATE_HOME=$(mktemp -d)
  # The live config may hold a trex block already; count without it.
  "$TREX_BIN" uninstall --config "$1" >/dev/null 2>&1 || { fail "uninstall from $1 failed"; return; }
  before=$(check_json "$1" | jq '.bindings')
  "$TREX_BIN" install --config "$1" --repo "$TREX_ROOT" >/dev/null 2>&1 || { fail "install into $1 failed"; return; }
  after=$(check_json "$1")
  assert_eq "[]" "$(printf '%s' "$after" | jq -c '.diagnostics')" "no complaints at all"
  assert_eq "Trex: Open Browser…" "$(printf '%s' "$after" | jq -r '.actions[] | select(.name == "trex_open") | .title')" "palette title"
  assert_eq "Trex: Toggle DevTools" "$(printf '%s' "$after" | jq -r '.actions[] | select(.name == "trex_devtools") | .title')" "DevTools palette title"
  assert_eq "Trex: Pick Element" "$(printf '%s' "$after" | jq -r '.actions[] | select(.name == "trex_pick") | .title')" "Pick Element palette title"
  assert_eq "Trex: Reload Config" "$(printf '%s' "$after" | jq -r '.actions[] | select(.name == "trex_reload_config") | .title')" "Reload Config palette title"
  assert_eq "Trex: Edit Config" "$(printf '%s' "$after" | jq -r '.actions[] | select(.name == "trex_edit_config") | .title')" "Edit Config palette title"
  assert_eq "$((before + 4))" "$(printf '%s' "$after" | jq '.bindings')" "four more key bindings (cmd+shift+b, f12, cmd+shift+i, cmd+shift+e)"
  assert_contains "$(cat "$1")" "dofile(\"$TREX_ROOT/lua/trex/init.lua\").setup(" "block loads trex from --repo"
}

test_install_adds_a_block_rex_loads_cleanly() {
  local config; config=$(fixture_config)
  installs_cleanly "$config"
  rm -f "$config"; rmdir "$(dirname "$config")"
}

test_install_into_a_copy_of_the_live_config() {
  local live=${REX_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/rex/init.lua}
  [ -f "$live" ] || { log "    (no live config at $live; skipped)"; return; }
  local dir config; dir=$(mktemp -d); config=$dir/init.lua
  cp "$live" "$config"
  installs_cleanly "$config"
  rm -f "$config"; rmdir "$dir"
}

test_install_is_idempotent_and_uninstall_restores_the_file() {
  local config original once twice
  local -x XDG_CONFIG_HOME XDG_STATE_HOME; XDG_CONFIG_HOME=$(mktemp -d); XDG_STATE_HOME=$(mktemp -d)
  config=$(fixture_config)
  original=$(cat "$config")
  "$TREX_BIN" install --config "$config" --repo "$TREX_ROOT" >/dev/null 2>&1 || fail "first install"
  once=$(cat "$config")
  "$TREX_BIN" install --config "$config" --repo "$TREX_ROOT" >/dev/null 2>&1 || fail "second install"
  twice=$(cat "$config")
  assert_eq "$once" "$twice" "installing again changes nothing"
  assert_eq "1" "$(grep -c '^-- >>> trex >>>$' "$config")" "exactly one trex block"
  "$TREX_BIN" uninstall --config "$config" >/dev/null 2>&1 || fail "uninstall"
  assert_eq "$original" "$(cat "$config")" "uninstall restores the original file"
  assert_contains "$(cat "$config")" "-- <<< other <<<" "other plugin's block untouched"
  rm -f "$config"; rmdir "$(dirname "$config")"
}

test_install_that_fails_the_check_leaves_the_config_unchanged() {
  local config original
  local -x XDG_CONFIG_HOME XDG_STATE_HOME; XDG_CONFIG_HOME=$(mktemp -d); XDG_STATE_HOME=$(mktemp -d)
  config=$(fixture_config)
  original=$(cat "$config")
  if "$TREX_BIN" install --config "$config" --repo /nonexistent/trex >/dev/null 2>&1; then
    fail "install with a broken --repo succeeded"
  fi
  assert_eq "$original" "$(cat "$config")" "config restored after a failed check"
  rm -f "$config"; rmdir "$(dirname "$config")"
}

test_block_defaults_to_the_main_checkout() {
  # The main checkout is the first worktree git lists, even when run from a linked one.
  local main
  main=$(git -C "$TREX_ROOT" worktree list --porcelain | awk '/^worktree /{print substr($0, 10); exit}')
  assert_contains "$("$TREX_BIN" block)" "dofile(\"$main/lua/trex/init.lua\")" "default repo"
}
