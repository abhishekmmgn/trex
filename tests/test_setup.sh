# bin/trex setup, against stub commands on a fake PATH and a scratch HOME. Sourced
# by tests/run.sh. Nothing is installed for real: brew, cargo, rustup-init, curl and
# hdiutil are stubs that log their arguments to $LOG and fake just the files
# setup looks for. Chrome and kb are never launched.

SETUP_PIN=$(pinned_kb PIN)
SETUP_REPO=$(pinned_kb REPO)
# What `cargo install --git REPO --rev PIN` writes into cargo's install record.
SETUP_SOURCE="git+$SETUP_REPO?rev=$SETUP_PIN#$SETUP_PIN"
SETUP_INSTALL="cargo install --git $SETUP_REPO --rev $SETUP_PIN --locked --force"

stub() { # NAME BODY: a command on the fake PATH that logs "NAME args" first
  printf '#!/bin/bash\necho "%s $*" >>"$LOG"\n%s\n' "$1" "$2" >"$T/bin/$1"
  chmod +x "$T/bin/$1"
}

crates2() { # SUFFIX: a cargo install record for kittybrowser at SUFFIX, and kb itself
  mkdir -p "$T/home/.cargo/bin"
  printf '{"installs":{"kittybrowser 0.1.0 (%s)":{"bins":["kb"]}}}\n' "$1" >"$T/home/.cargo/.crates2.json"
  : >"$T/home/.cargo/bin/kb"; chmod +x "$T/home/.cargo/bin/kb"
}

fake_chrome() { mkdir -p "$T/apps/Google Chrome.app"; }

# A cargo that records `install` and leaves the pinned kb record behind.
CARGO_BODY='case "$1" in install) mkdir -p "$HOME/.cargo/bin"
printf "{\"installs\":{\"kittybrowser 0.1.0 (%s)\":{}}}" "'"$SETUP_SOURCE"'" >"$HOME/.cargo/.crates2.json"
: >"$HOME/.cargo/bin/kb";; esac'

fake_cargo() { stub cargo "$CARGO_BODY"; }


# Fresh scratch world. Stubs: rex (config check passes), and brew/curl/hdiutil/
# rustup-init that pretend to install; PATH is the stubs plus system tools only, so
# the real brew/cargo are invisible. `T/bin/brew` exists only when asked.
new_world() {
  T=$(mktemp -d); LOG=$T/log; : >"$LOG"
  mkdir -p "$T/bin" "$T/home" "$T/apps"
  printf '#!/bin/bash\nexit 0\n' >"$T/bin/rex"; chmod +x "$T/bin/rex"
  stub hdiutil 'if [ "$1" = attach ]; then mnt=; while [ $# -gt 0 ]; do [ "$1" = -mountpoint ] && mnt=$2; shift; done; mkdir -p "$mnt/Google Chrome.app"; fi'
  # curl: `-o FILE` makes a file; otherwise the rustup script, which makes a cargo.
  stub curl 'out=; while [ $# -gt 0 ]; do [ "$1" = -o ] && out=$2; shift; done
if [ -n "$out" ]; then : >"$out"; else printf "mkdir -p \"\$HOME/.cargo/bin\"; cp \"%s/cargo-template\" \"\$HOME/.cargo/bin/cargo\"\n" "'"$T"'"; fi'
  CONFIG=$T/init.lua; : >"$CONFIG"
  printf '#!/bin/bash\necho "cargo $*" >>"$LOG"\n%s\n' "$CARGO_BODY" >"$T/cargo-template"; chmod +x "$T/cargo-template"
}

# Homebrew's rustup is keg-only: `brew install rustup` puts rustup-init under
# `brew --prefix rustup`, not on PATH. This brew does the same.
with_brew() {
  stub brew 'case "$*" in
  "install --cask google-chrome") mkdir -p "'"$T"'/apps/Google Chrome.app";;
  "install rustup") mkdir -p "'"$T"'/keg/rustup/bin"; cp "'"$T"'/rustup-init-template" "'"$T"'/keg/rustup/bin/rustup-init";;
  "--prefix rustup") echo "'"$T"'/keg/rustup";;
esac'
  printf '#!/bin/bash\necho "rustup-init $*" >>"$LOG"\nmkdir -p "$HOME/.cargo/bin"; cp "%s/cargo-template" "$HOME/.cargo/bin/cargo"\n' "$T" \
    >"$T/rustup-init-template"
  chmod +x "$T/rustup-init-template"
}

# Runs setup with the fake world; sets $OUT and $STATUS. Input comes from $ANSWER.
run_setup() {
  OUT=$(printf '%s' "${ANSWER:-}" | env -i LOG="$LOG" HOME="$T/home" PATH="$T/bin:/usr/bin:/bin" REX="$T/bin/rex" \
    TREX_APPLICATIONS="$T/apps" TREX_BIN_DIR="${LINK_DIR:-$T/linkbin}" "$TREX_ROOT/bin/trex" setup --config "$CONFIG" --repo "$TREX_ROOT" "$@" 2>&1)
  STATUS=$?
}

done_world() { rm -rf "$T"; ANSWER=; }

test_setup_with_everything_present_changes_nothing() {
  new_world; fake_chrome; fake_cargo; crates2 "$SETUP_SOURCE"
  run_setup; assert_status_code 0 "first run"
  assert_contains "$OUT" "cargo: ok" "cargo reported present"
  assert_contains "$OUT" "chrome: ok" "chrome reported present"
  assert_contains "$OUT" "kb: ok" "kb reported present"
  assert_contains "$OUT" "trex block: installed" "block written the first time"
  local first; first=$(cat "$CONFIG")
  run_setup; assert_status_code 0 "second run"
  assert_contains "$OUT" "trex block: ok" "block already up to date"
  assert_eq "$first" "$(cat "$CONFIG")" "config unchanged by the second run"
  assert_eq "" "$(cat "$LOG")" "nothing was installed (no brew, cargo or curl calls)"
  done_world
}

test_setup_without_brew_uses_rustup_installer_and_the_dmg() {
  new_world
  run_setup; assert_status_code 0 "run without brew"
  assert_contains "$OUT" "cargo: installed" "cargo installed"
  assert_contains "$OUT" "chrome: installed" "chrome installed"
  assert_contains "$OUT" "kb: installed" "kb installed"
  local log; log=$(cat "$LOG")
  assert_contains "$log" "curl --proto =https --tlsv1.2 -sSf https://sh.rustup.rs" "official rustup installer"
  assert_contains "$log" "dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg" "Google's dmg"
  assert_contains "$log" "hdiutil attach" "dmg mounted"
  [ -d "$T/apps/Google Chrome.app" ] || fail "Chrome.app was copied into the applications dir"
  assert_contains "$log" "$SETUP_INSTALL" "pinned kb install"
  done_world
}

test_setup_with_brew_uses_rustup_and_the_cask() {
  new_world; with_brew
  run_setup; assert_status_code 0 "run with brew"
  local log; log=$(cat "$LOG")
  assert_contains "$log" "brew install rustup" "homebrew rustup"
  assert_contains "$log" "rustup-init -y --no-modify-path" "rustup-init from the keg"
  assert_contains "$OUT" "cargo: installed" "cargo installed"
  assert_contains "$OUT" "$T/home/.cargo/bin/cargo" "the cargo rustup-init made"
  assert_contains "$log" "brew install --cask google-chrome" "homebrew cask"
  case "$log" in *curl*) fail "curl was not needed with brew: $log" ;; esac
  assert_contains "$OUT" "kb: installed" "kb installed"
  assert_contains "$log" "cargo install --git" "kb built with that cargo"
  done_world
}

test_setup_finds_cargo_outside_path() {
  new_world; fake_chrome; mkdir -p "$T/home/.cargo/bin"
  printf '#!/bin/bash\necho "cargo $*" >>"%s"\n' "$LOG" >"$T/home/.cargo/bin/cargo"; chmod +x "$T/home/.cargo/bin/cargo"
  run_setup; assert_status_code 0 "run"
  assert_contains "$OUT" "cargo: ok" "found ~/.cargo/bin/cargo off PATH"
  assert_contains "$(cat "$LOG")" "cargo install --git" "uses it to install kb"
  case "$(cat "$LOG")" in *rustup*) fail "rust was not reinstalled" ;; esac
  done_world
}

test_setup_kb_at_wrong_commit_is_kept_unless_confirmed() {
  new_world; fake_chrome; fake_cargo; with_brew
  crates2 "git+https://github.com/graiz/kittybrowser#0000000000000000000000000000000000000000"
  ANSWER=n; run_setup; assert_status_code 1 "declined"
  assert_contains "$OUT" "kb: FAILED" "reported and left alone"
  assert_contains "$OUT" "trex won't work until" "says trex needs the pin"
  case "$(cat "$LOG")" in *"cargo install"*) fail "installed despite no confirmation" ;; esac
  ANSWER=y; run_setup; assert_status_code 0 "confirmed"
  assert_contains "$OUT" "kb: installed" "replaced after y"
  assert_contains "$(cat "$LOG")" "cargo install --git" "cargo ran"
  done_world
}

# ADR-0002: the pin is a commit on the fork. An upstream install (the earlier pin,
# or even the same commit built from upstream) is another kb, replaced only when
# confirmed, by the fork's build.
test_setup_replaces_an_upstream_kb_with_the_forks_pin() {
  local upstream
  for upstream in "git+https://github.com/graiz/kittybrowser#d252d5fe771f4d8f18fbf184d8239524b3ecda39" \
    "git+https://github.com/graiz/kittybrowser?rev=$SETUP_PIN#$SETUP_PIN"; do
    new_world; fake_chrome; fake_cargo; crates2 "$upstream"
    ANSWER=n; run_setup; assert_status_code 1 "declined for $upstream"
    assert_contains "$OUT" "kb: FAILED" "$upstream left alone"
    assert_contains "$OUT" "$upstream" "names what is installed"
    assert_contains "$OUT" "$SETUP_REPO" "names the pinned repo"
    case "$(cat "$LOG")" in *"cargo install"*) fail "installed over $upstream without confirmation" ;; esac
    ANSWER=y; run_setup; assert_status_code 0 "confirmed for $upstream"
    assert_contains "$OUT" "kb: installed" "$upstream replaced after y"
    assert_contains "$(cat "$LOG")" "$SETUP_INSTALL" "the fork's pin installed over $upstream"
    run_setup; assert_status_code 0 "run after replacing $upstream"
    assert_contains "$OUT" "kb: ok" "the fork's pin is then ok"
    done_world
  done
}

# The record says the pin is installed but ~/.cargo/bin/kb is gone: put it back
# without asking, since nothing else would be replaced.
test_setup_reinstalls_a_missing_pinned_kb() {
  new_world; fake_chrome; fake_cargo; crates2 "$SETUP_SOURCE"
  rm "$T/home/.cargo/bin/kb"
  run_setup; assert_status_code 0 "run"
  assert_contains "$OUT" "kb: installed" "reinstalled"
  case "$OUT" in *eplace*) fail "talks of replacing another commit: $OUT" ;; esac
  assert_contains "$(cat "$LOG")" "$SETUP_INSTALL" "the pin"
  done_world
}

test_setup_yes_replaces_a_local_kb_build() {
  new_world; fake_chrome; fake_cargo; crates2 "path+file:///Users/someone/kittybrowser"
  run_setup --yes; assert_status_code 0 "--yes"
  assert_contains "$OUT" "kb: installed" "replaced without asking"
  done_world
}

test_setup_dry_run_changes_nothing() {
  new_world; with_brew
  run_setup --dry-run; assert_status_code 0 "dry run"
  assert_contains "$OUT" "cargo: would" "cargo planned"
  assert_contains "$OUT" '$(brew --prefix rustup)/bin/rustup-init' "keg-only rustup-init"
  assert_contains "$OUT" "chrome: would" "chrome planned"
  assert_contains "$OUT" "kb: would" "kb planned"
  assert_contains "$OUT" "trex block: would" "block planned"
  assert_eq "" "$(cat "$LOG")" "no command ran"
  assert_eq "" "$(cat "$CONFIG")" "config untouched"
  [ -d "$T/apps/Google Chrome.app" ] && fail "nothing was installed"
  done_world
}

test_setup_reports_missing_rex_without_installing_it() {
  new_world; fake_chrome; fake_cargo; crates2 "$SETUP_SOURCE"
  rm "$T/bin/rex"
  run_setup; assert_status_code 1 "fails when rex is missing"
  assert_contains "$OUT" "rex: FAILED" "rex reported"
  assert_contains "$OUT" "trex block: skipped" "block skipped"
  assert_eq "" "$(cat "$LOG")" "nothing was installed"
  done_world
}

test_setup_reports_a_failed_install() {
  new_world; fake_chrome; stub cargo 'exit 1'
  run_setup; assert_status_code 1 "fails"
  assert_contains "$OUT" "kb: FAILED" "failure reported"
  done_world
}

# trex's config (ADR-0003): created filled with every default, never overwritten, and
# its schema refreshed. Under the scratch HOME, so never ~/.config/trex.
test_setup_creates_the_config_and_schema_without_overwriting() {
  new_world; fake_chrome; fake_cargo; crates2 "$SETUP_SOURCE"
  local dir=$T/home/.config/trex
  run_setup; assert_status_code 0 "first run"
  assert_contains "$OUT" "config: installed" "config created"
  assert_eq "$(cat "$TREX_ROOT/lua/trex/config.default.json")" "$(cat "$dir/config.json")" "written out with every default"
  assert_eq '"$schema"' "$(jq -c 'keys_unsorted[0]' "$dir/config.json")" "\$schema comes first"
  assert_eq "./config.schema.json" "$(jq -r '.["$schema"]' "$dir/config.json")" "\$schema is a relative path"
  assert_eq "$(cat "$TREX_ROOT/lua/trex/config.schema.json")" "$(cat "$dir/config.schema.json")" "schema copied next to it"
  run_setup; assert_contains "$OUT" "config: ok" "nothing to do the second time"
  printf '{ "open_in": "window" }\n' >"$dir/config.json"
  printf 'old schema\n' >"$dir/config.schema.json"
  run_setup; assert_status_code 0 "run with an edited config"
  assert_eq '{ "open_in": "window" }' "$(cat "$dir/config.json")" "the user's config is left alone"
  assert_eq "$(cat "$TREX_ROOT/lua/trex/config.schema.json")" "$(cat "$dir/config.schema.json")" "a stale schema is refreshed"
  rm -rf "$dir"
  run_setup --dry-run; assert_contains "$OUT" "config: would" "dry run plans it"
  [ -e "$dir" ] && fail "dry run created $dir"
  done_world
}

# trex on PATH: ~/.local/bin/trex (here $T/linkbin, via TREX_BIN_DIR) links to bin/trex.
test_setup_links_trex_into_the_bin_dir_and_is_idempotent() {
  new_world; fake_chrome; fake_cargo; crates2 "$SETUP_SOURCE"
  run_setup; assert_status_code 0 "first run"
  assert_contains "$OUT" "trex link: installed" "link created"
  assert_eq "$TREX_ROOT/bin/trex" "$(readlink "$T/linkbin/trex")" "points at the checkout's bin/trex"
  assert_contains "$OUT" "is not on your PATH" "the bin dir isn't on PATH, so setup says how to add it"
  assert_contains "$OUT" 'export PATH="'"$T"'/linkbin:$PATH"' "with the line to add"
  run_setup; assert_status_code 0 "second run"
  assert_contains "$OUT" "trex link: ok" "already right"
  assert_eq "$TREX_ROOT/bin/trex" "$(readlink "$T/linkbin/trex")" "still the same link"
  [ ! -e "$T/home/.local" ] || fail "setup touched the scratch HOME's .local"
  done_world
}

test_setup_says_nothing_about_path_when_the_bin_dir_is_on_it() {
  new_world; fake_chrome; fake_cargo; crates2 "$SETUP_SOURCE"
  mkdir "$T/linkbin"
  OUT=$(env -i LOG="$LOG" HOME="$T/home" PATH="$T/linkbin:$T/bin:/usr/bin:/bin" REX="$T/bin/rex" TREX_APPLICATIONS="$T/apps" \
    TREX_BIN_DIR="$T/linkbin" "$TREX_ROOT/bin/trex" setup --config "$CONFIG" --repo "$TREX_ROOT" 2>&1)
  STATUS=$?
  assert_status_code 0 "run"
  assert_contains "$OUT" "trex link: installed" "link created"
  case "$OUT" in *"not on your PATH"*) fail "warned although the bin dir is on PATH: $OUT" ;; esac
  done_world
}

test_setup_leaves_another_trex_in_the_bin_dir_alone() {
  new_world; fake_chrome; fake_cargo; crates2 "$SETUP_SOURCE"
  mkdir "$T/linkbin"
  printf 'mine\n' >"$T/linkbin/trex"
  run_setup; assert_status_code 0 "a file there is not a failure"
  assert_contains "$OUT" "trex link: skipped" "says it skipped"
  assert_eq "mine" "$(cat "$T/linkbin/trex")" "the file is untouched"
  rm "$T/linkbin/trex"; ln -s /nonexistent/trex "$T/linkbin/trex"
  run_setup; assert_status_code 0 "another link is not a failure"
  assert_contains "$OUT" "trex link: skipped" "skipped again"
  assert_eq "/nonexistent/trex" "$(readlink "$T/linkbin/trex")" "the other link is untouched"
  done_world
}

test_setup_dry_run_does_not_link() {
  new_world; fake_chrome; fake_cargo; crates2 "$SETUP_SOURCE"
  run_setup --dry-run; assert_status_code 0 "dry run"
  assert_contains "$OUT" "trex link: would" "link planned"
  [ ! -e "$T/linkbin" ] || fail "dry run created the bin dir"
  done_world
}

assert_status_code() { # EXPECTED MESSAGE  (checks $STATUS from run_setup)
  [ "$STATUS" = "$1" ] || fail "$2: exit status $STATUS, expected $1 (output: $OUT)"
}
