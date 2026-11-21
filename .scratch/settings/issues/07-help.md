# 07: `--help` for every command

**What to build:** `trex --help`, `-h` and `trex help` print the overview of all commands. `trex <command> --help` prints that command's usage. Bare `trex` and bare `trex config` print usage. See `../spec.md`.

**Blocked by:** 02

**Status:** resolved

- [x] Overview lists `install`, `uninstall`, `block`, `setup`, `config edit|check|reload`, `browser`, `ctl`, `mcp`, one line each
- [x] `--help` and `-h` work on each command and exit 0. Bare `trex` exits 2 with the overview, as today. `--help` reaches `bin/trex-setup` and `bin/trex-agent` before they parse their options (for `ctl`, only when it comes before the kb command, so `trex ctl eval --help` still goes to kb)
- [x] README "Install"/"Use" mention `trex --help`
- [x] Tests: each command's help exits 0 and names its options

## Comments

- 2026-11-21: Built. `trex --help`/`-h`/`help` print the overview (stdout, exit 0); bare `trex` and an unknown command print it on stderr, exit 2 (unknown also names the command). `trex help CMD` is the same as `trex CMD --help`.
  - Each command's help text sits in the script that implements it: `overview()`, `help_install|uninstall|block` in `bin/trex`; `usage()` in `bin/trex-setup` and `bin/trex-config`; `help_browser|ctl|mcp` in `bin/trex-agent`. The old "print lines 2-9 of itself" is gone.
  - `--help`/`-h` is checked before any option parsing or work: anywhere in the args for `setup`, `config` and `install|uninstall|block`; for `browser|ctl|mcp` only as the first argument after the command, so `trex ctl eval --help` and `trex ctl -i ID eval --help` reach kb. Bare `trex config` prints its usage on stderr, exit 2 (usage errors in `trex-config` now go to stderr via `usage >&2`).
  - Decision: `--config --help` would read `--help` as help (nobody names a file that).
  - Tests: `tests/test_help.sh` (10 tests). Setup is run with logging stubs for cargo/brew/curl/hdiutil/rustup-init and a scratch XDG dir, config with a marker editor, agent commands with a logging kb: none ran or was written.
