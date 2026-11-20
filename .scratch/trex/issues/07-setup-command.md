# 07: One command installs everything trex needs

**What to build:** A single command, `bin/trex setup`, takes a Mac with Rex on it to a working trex. It installs what is missing and leaves alone what is already there. That covers the Rust toolchain (cargo), Google Chrome, the pinned KittyBrowser (see ADR-0001) and the trex block in the Rex config. It works whether or not Homebrew is installed, and it can be run again safely.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] `bin/trex setup` checks each requirement in order and prints, for each, whether it was already present, has been installed, or failed and why
- [ ] Present and correct requirements are left untouched; running it twice in a row changes nothing the second time
- [ ] cargo: uses an existing `cargo` (including `~/.cargo/bin/cargo` when it isn't on PATH); otherwise installs Rust with Homebrew's `rustup` if `brew` exists, else with the official rustup installer
- [ ] Google Chrome: detected in `/Applications` or `~/Applications`; otherwise installed with `brew install --cask google-chrome` if `brew` exists, else from Google's official macOS download (dmg), with no Homebrew needed
- [ ] KittyBrowser: installed at the pinned commit with `cargo install --git … --rev`; a kb at another commit, or built from a local checkout, is reported and only replaced after the user confirms (or with `--yes`)
- [ ] The trex block is installed in the Rex config with the existing `bin/trex install`
- [ ] Rex itself is checked for and reported if missing, but not installed
- [ ] A `--dry-run` flag prints what would be done without changing anything
- [ ] Tests run against stubbed commands on a fake PATH (no brew, brew present, everything installed, kb at the wrong commit) and never install anything for real
- [ ] README documents `bin/trex setup`
