# `trex --help` and `trex COMMAND --help`. Sourced by tests/run.sh. Help must be
# handled before a command parses options or does any work, so these tests run
# the commands with stubs that log whatever they are asked to do, and with every
# path pointed at a scratch dir, and check nothing happened.

TREX_BIN="$TREX_ROOT/bin/trex"

# Runs `trex ARGS...`; sets $HELP_OUT (stdout), $HELP_ERR (stderr), $HELP_STATUS.
run_help() {
  local err; err=$(mktemp)
  HELP_OUT=$("$TREX_BIN" "$@" 2>"$err" </dev/null); HELP_STATUS=$?
  HELP_ERR=$(cat "$err"); rm -f "$err"
}

# Checks `trex ARGS...` exits 0, prints only on stdout, and names each of NEEDLES (separated by |).
assert_help() { # NEEDLES ARGS...
  local needles=$1 needle; shift
  run_help "$@"
  assert_eq 0 "$HELP_STATUS" "trex $* exit"
  assert_eq "" "$HELP_ERR" "trex $* prints nothing on stderr"
  local IFS='|'
  for needle in $needles; do assert_contains "$HELP_OUT" "$needle" "trex $* names $needle"; done
}

test_help_overview_lists_every_command() {
  local flag
  for flag in --help -h help; do
    assert_help "install|uninstall|block|setup|config show|config edit|config check|config reload|browser|ctl|mcp" "$flag"
  done
  run_help
  assert_eq 2 "$HELP_STATUS" "bare trex exits 2"
  assert_contains "$HELP_ERR" "usage: trex COMMAND" "bare trex prints the overview on stderr"
  assert_eq "" "$HELP_OUT" "bare trex prints nothing on stdout"
}

test_help_overview_has_one_line_per_command() {
  run_help --help
  local c
  for c in install uninstall block setup "config show" "config edit" "config check" "config reload" browser ctl mcp; do
    assert_eq 1 "$(printf '%s\n' "$HELP_OUT" | grep -c "^  $c ")" "one line for $c"
  done
}

test_help_unknown_command_names_it_and_prints_the_overview() {
  run_help frobnicate
  assert_eq 2 "$HELP_STATUS" "unknown command exits 2"
  assert_contains "$HELP_ERR" "no command frobnicate" "says which"
  assert_contains "$HELP_ERR" "usage: trex COMMAND" "prints the overview"
  run_help frobnicate --help
  assert_eq 2 "$HELP_STATUS" "unknown command with --help exits 2"
  run_help help frobnicate
  assert_eq 2 "$HELP_STATUS" "help for an unknown command exits 2"
}

test_help_install_uninstall_block_name_their_options() {
  local flag
  for flag in --help -h; do
    assert_help "trex install|--config|--repo" install "$flag"
    assert_help "trex uninstall|--config" uninstall "$flag"
    assert_help "trex block|--repo" block "$flag"
  done
}

test_help_install_changes_nothing() {
  local dir; dir=$(mktemp -d)
  local -x XDG_CONFIG_HOME=$dir XDG_STATE_HOME=$dir
  assert_help "trex install" install --config "$dir/init.lua" --help
  assert_eq "" "$(ls -A "$dir")" "install --help wrote nothing"
  printf 'keep\n' >"$dir/init.lua"
  assert_help "trex uninstall" uninstall --config "$dir/init.lua" -h
  assert_eq "keep" "$(cat "$dir/init.lua")" "uninstall --help left the config alone"
  rm -rf "$dir"
}

test_help_setup_names_its_options_and_installs_nothing() {
  local dir tool flag; dir=$(mktemp -d)
  mkdir "$dir/bin"
  for tool in cargo brew curl hdiutil rustup-init; do
    printf '#!/bin/bash\necho "%s $*" >>"%s/log"\n' "$tool" "$dir" >"$dir/bin/$tool"
    chmod +x "$dir/bin/$tool"
  done
  local -x PATH="$dir/bin:$PATH" XDG_CONFIG_HOME="$dir/xdg"
  for flag in --help -h; do
    assert_help "trex setup|--dry-run|--yes|--config|--repo" setup "$flag"
    assert_help "trex setup|--dry-run" setup --dry-run --yes "$flag"
  done
  run_help setup --config "$dir/init.lua" --help
  assert_eq "" "$(cat "$dir/log" 2>/dev/null)" "no cargo, brew, curl, hdiutil or rustup was run"
  [ ! -e "$dir/xdg" ] && [ ! -e "$dir/init.lua" ] || fail "setup --help wrote a config, schema or Rex config"
  # A step line is "NAME  ok|installed|would|skipped|FAILED ...".
  printf '%s\n' "$HELP_OUT" | grep -qE '^(Rex|cargo|Chrome|kb|config|trex)[A-Za-z ]* +(ok|installed|would|skipped|FAILED)' &&
    fail "setup --help printed a step: $HELP_OUT"
  rm -rf "$dir"
}

test_help_config_names_its_commands_and_opens_no_editor() {
  local dir flag sub; dir=$(mktemp -d)
  printf '#!/bin/sh\ntouch "%s/editor-ran"\n' "$dir" >"$dir/editor"; chmod +x "$dir/editor"
  local -x VISUAL="$dir/editor" EDITOR="$dir/editor" XDG_CONFIG_HOME="$dir/xdg" TREX_RELOAD_DO=no_such_action
  for flag in --help -h; do
    for sub in "" edit check reload; do
      # $sub is left unquoted on purpose: empty means no argument.
      assert_help "trex config show|trex config edit|trex config check|trex config reload|devtools.side" config $sub "$flag"
    done
  done
  [ ! -e "$dir/editor-ran" ] || fail "an editor was opened"
  [ ! -e "$dir/xdg" ] || fail "config --help created $dir/xdg"
  # An unknown subcommand prints the usage and exits 2.
  run_help config frobnicate
  assert_eq 2 "$HELP_STATUS" "trex config frobnicate exits 2"
  assert_contains "$HELP_ERR" "trex config edit" "trex config frobnicate prints the usage on stderr"
  assert_eq "" "$HELP_OUT" "trex config frobnicate prints nothing on stdout"
  rm -rf "$dir"
}

test_help_agent_commands_never_contact_kb() {
  local dir flag; dir=$(mktemp -d)
  printf '#!/bin/sh\necho "kb $*" >>"%s/log"\n' "$dir" >"$dir/kb"; chmod +x "$dir/kb"
  local -x KB="$dir/kb"
  for flag in --help -h; do
    assert_help "trex browser" browser "$flag"
    assert_help "trex ctl COMMAND|-i" ctl "$flag"
    assert_help "trex mcp" mcp "$flag"
  done
  assert_eq "" "$(cat "$dir/log" 2>/dev/null)" "kb was never run"
  rm -rf "$dir"
}

test_help_ctl_passes_a_later_help_on_to_kb() {
  local dir; dir=$(mktemp -d)
  printf '#!/bin/sh\necho "kb $*" >>"%s/log"\n' "$dir" >"$dir/kb"; chmod +x "$dir/kb"
  local -x KB="$dir/kb"
  run_help ctl -i 1-abcd eval --help
  assert_eq 0 "$HELP_STATUS" "ctl -i ID eval --help exit"
  assert_eq "kb ctl -i 1-abcd eval --help" "$(cat "$dir/log")" "kb got eval --help"
  # Outside a Rex pane `trex ctl eval --help` can't pick a kb. It must say so, not print trex's help.
  REX_SESSION= REX_BLOCK= run_help ctl eval --help
  assert_eq 1 "$HELP_STATUS" "ctl eval --help outside a pane fails like any ctl"
  assert_contains "$HELP_ERR" "not a Rex pane" "it went to the kb path, not to help"
  case "$HELP_OUT" in *"usage: trex ctl"*) fail "trex ctl eval --help printed trex's help" ;; esac
  rm -rf "$dir"
}

test_help_for_a_command_by_name() {
  assert_help "trex install|--repo" help install
  assert_help "trex setup|--dry-run" help setup
  assert_help "trex config edit" help config
  assert_help "trex ctl" help ctl
}
