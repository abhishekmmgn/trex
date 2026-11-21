# 07: One command installs everything trex needs

**What to build:** A single command, `bin/trex setup`, takes a Mac with Rex on it to a working trex. It installs what is missing and leaves alone what is already there. That covers the Rust toolchain (cargo), Google Chrome, the pinned KittyBrowser (see ADR-0001) and the trex block in the Rex config. It works whether or not Homebrew is installed, and it can be run again safely.

**Blocked by:** 01

**Status:** resolved

- [x] `bin/trex setup` checks each requirement in order and prints, for each, whether it was already present, has been installed, or failed and why
- [x] Present and correct requirements are left untouched; running it twice in a row changes nothing the second time
- [x] cargo: uses an existing `cargo` (including `~/.cargo/bin/cargo` when it isn't on PATH); otherwise installs Rust with Homebrew's `rustup` if `brew` exists, else with the official rustup installer
- [x] Google Chrome: detected in `/Applications` or `~/Applications`; otherwise installed with `brew install --cask google-chrome` if `brew` exists, else from Google's official macOS download (dmg), with no Homebrew needed
- [x] KittyBrowser: installed at the pinned commit with `cargo install --git … --rev`; a kb at another commit, or built from a local checkout, is reported and only replaced after the user confirms (or with `--yes`)
- [x] The trex block is installed in the Rex config with the existing `bin/trex install`
- [x] Rex itself is checked for and reported if missing, but not installed
- [x] A `--dry-run` flag prints what would be done without changing anything
- [x] Tests run against stubbed commands on a fake PATH (no brew, brew present, everything installed, kb at the wrong commit) and never install anything for real
- [x] README documents `bin/trex setup`

## Comments

- Unverified on a real machine: the brew and rustup-init install path, the rustup installer path, and the Chrome dmg download and copy (URL `https://dl.google.com/chrome/mac/universal/stable/GGRO/googlechrome.dmg`) were exercised only with stub commands. The Homebrew path assumes `rustup-init -y` is on PATH after `brew install rustup`.
- The trex block step uses the real `bin/trex install`, so it also runs `rex config check` and reload. In the tests that is a stub rex and a temp config.
- Orchestrator check (2026-11-21): Homebrew's `rustup` formula is **keg-only**, so after `brew install rustup` neither `rustup` nor `rustup-init` is on PATH. The brew path must call it via `$(brew --prefix rustup)/bin/` (and then make sure `~/.cargo/bin/cargo` is used). To fix in the review round.
- 2026-11-21, review round (branch `trex/review-fixes`):
  - Keg-only rustup fixed: the Homebrew path runs `brew install rustup` then `"$(brew --prefix rustup)/bin/rustup-init" -y --no-modify-path`,
    and afterwards uses `~/.cargo/bin/cargo` (or fails saying it isn't there). The dry run prints that command. The test brew now installs
    `rustup-init` under its own prefix, off PATH, and the test checks setup ran it and built kb with the cargo it made.
  - An install record that names the pin while `~/.cargo/bin/kb` is missing now reinstalls the pin without asking
    (`test_setup_reinstalls_a_missing_pinned_kb`), instead of offering to "replace" the same commit.
  - Declining to replace a kb at another commit is now `kb: FAILED … trex won't work until it is the pinned commit …` and setup exits 1.
  - The pin moved to `lua/trex/pin.lua` (still the one place it lives); setup and the tests read it there, through `pinned_kb` in `bin/trex-lib.sh`.
  - Still unverified on a real machine: all install paths run only against stubs.
