# 01: The config file, its schema, check and reload

**What to build:** `~/.config/trex/config.json` and `config.schema.json`, as in `../spec.md` "Decisions" and ADR-0003. The server reads the file when Rex loads its config and keeps the result. `trex config check` validates it, and `trex config reload` (plus **Trex: Reload Config**) makes it take effect. No option changes behaviour yet; tickets 03–06 wire them in.

**Blocked by:** None (can start immediately)

**Status:** resolved

- [x] `config.schema.json` lives in the repo and describes every option with a `description`, its type or `enum`, and its default. `additionalProperties: false`, so editors flag unknown keys
- [x] `trex setup` creates the config (every default written out, `$schema` first) and copies the schema next to it if missing. An existing config is left alone, and the schema is refreshed
- [x] The server reads the config at load. Missing keys get their defaults, and a missing file means all defaults
- [x] `trex config check` prints each problem with its key, the allowed values and its line. A syntax error gives its line. Exits 0 when the file is valid, 1 otherwise
- [x] `trex config reload` and **Trex: Reload Config** apply a valid file. With an invalid one, they keep the last good settings (also across a Rex restart) and report the problems
- [x] Settings are reachable from Lua in one place (for example `config.get("devtools.side")`) for tickets 03–06
- [x] Tests with a temp config dir: defaults when missing, a bad enum value reported with allowed values, a syntax error with its line, reload keeps the last good, setup creates without overwriting

## Comments

### 2026-11-21: built (branch `trex/settings-01-config`)

- **Schema and defaults:** `lua/trex/config.schema.json` is the one place that lists the settings, their allowed values and defaults. `lua/trex/config.default.json` is the file setup writes (a test checks it equals "no file").
- **Loading:** `lua/trex/config.lua`. `setup{ config = … }` overrides the path (default `$XDG_CONFIG_HOME/trex/config.json`). The server reads it at load and keeps the result; `config.get("devtools.side")` is the one accessor for tickets 03–06 (a name the schema lacks raises, so typos aren't silent `nil`s). The last good copy of the file is `last-good-config.json` beside `state.json`.
- **Decision: no new runtime dependency.** `check` is `rex do lua/trex/config-check.lua`, running the same Lua as the server (Rex is already required). Not jq or python3: `rex.json.decode` accepts bad JSON (`x` as a value) and gives no line, so config.lua has its own strict parser that tracks the line of every key. The tests still use jq.
- **Blocking vs not:** syntax errors, wrong types and bad enum values block the whole file (last good settings stay: from memory on a reload, from the saved copy at load, else defaults). An unknown key is only a warning for `reload` (the rest applies, and the reply names it) but `check` exits 1 for it, as the spec says.
- **Reload:** the `trex_reload_config` action ("Trex: Reload Config") returns `{ message, settings }`, or raises with the problems and what is kept. `bin/trex config reload` runs it with `rex do trex_reload_config` and prints the message. Hook for tests: `TREX_RELOAD_DO`.
- **Commands:** new `bin/trex-config` (`check`, `reload`; bare `trex config` prints usage and exits 2). `edit` is ticket 02, `--help` is 07.
- **Setup:** creates config and schema; an existing config is left alone, the schema refreshed. Output line `config: ok|installed|would`.
- **Tests:** `tests/test_config.sh` (13), one more in `test_setup.sh`, and `test_install.sh` checks the new palette title. `tests/lib.sh` gives each test its own `$TREX_CONFIG`. The tests that make `rex config check` load trex run with temp `XDG_CONFIG_HOME` and `XDG_STATE_HOME` (the check inherits the caller's environment), so trex never reads or saves anything of the user's. Full suite: 85/85.
- **Left for later:** nothing for this ticket. No option changes behaviour yet. Note for ticket 05 (devtools side): the remembered side must record the `devtools.side` it was saved under (spec notes).
