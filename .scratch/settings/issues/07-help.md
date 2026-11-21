# 07: `--help` for every command

**What to build:** `trex --help`, `-h` and `trex help` print the overview of all commands. `trex <command> --help` prints that command's usage. Bare `trex` and bare `trex config` print usage. See `../spec.md`.

**Blocked by:** 02

**Status:** ready-for-agent

- [ ] Overview lists `install`, `uninstall`, `block`, `setup`, `config edit|check|reload`, `browser`, `ctl`, `mcp`, one line each
- [ ] `--help` and `-h` work on each command and exit 0. Bare `trex` exits 2 with the overview, as today. `--help` reaches `bin/trex-setup` and `bin/trex-agent` before they parse their options (for `ctl`, only when it comes before the kb command, so `trex ctl eval --help` still goes to kb)
- [ ] README "Install"/"Use" mention `trex --help`
- [ ] Tests: each command's help exits 0 and names its options

## Comments
