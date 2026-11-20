# 07: One command installs everything trex needs

**What to build:** A single command, `bin/trex setup`, takes a Mac with Rex on it to a working trex. It installs what is missing and leaves alone what is already there. That covers the Rust toolchain (cargo), Google Chrome, the pinned KittyBrowser (see ADR-0001) and the trex block in the Rex config. It works whether or not Homebrew is installed, and it can be run again safely.

**Blocked by:** 01

**Status:** ready-for-agent

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
