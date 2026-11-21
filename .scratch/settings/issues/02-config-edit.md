# 02: `trex config edit` refuses a broken file

**What to build:** `trex config edit` and **Trex: Edit Config**, as in `../spec.md`. It opens the config in the user's editor and checks it when the editor exits, like `visudo`.

**Blocked by:** 01

**Status:** resolved

- [x] Creates the config and schema if missing, then opens `$VISUAL`, else `$EDITOR`, else `vi`
- [x] On exit with a valid file: reloads it (as `trex config reload`) and says so
- [x] On exit with problems: lists them and asks `(e)dit again / (k)eep anyway / (r)evert`. Revert restores the last good file. Keep leaves the file, and the last good settings stay in effect
- [x] **Trex: Edit Config** opens `trex config edit` in a split beside the focused pane
- [x] Tests with a stub `EDITOR` script that writes a valid or an invalid file, and answers to the prompt fed on stdin

## Comments

### 2026-11-21: built (branch `trex/settings-02-edit`)

- **Where:** `bin/trex-config edit`, reusing the same `check_file` (`rex do config-check.lua`) and `reload_server` (`trex_reload_config`, hook `TREX_RELOAD_DO`) as `check` and `reload`, so there is no second validation. **Trex: Edit Config** (`trex_edit_config`) is a small action in `init.lua` beside Reload Config.
- **Creating files:** `edit` writes the default config and copies the schema if missing, like `trex setup` (an existing config is never touched).
- **Editor:** `$VISUAL`, else `$EDITOR`, else `vi`, run through `sh -c` so a value with arguments (`code -w`) works. A non-zero editor exit is noted, and the file is checked anyway.
- **Prompt:** read from stdin with `read`; the question goes to stderr. Unknown answers ask again. End of input (stdin closed) keeps the file and exits 1, so a script can never loop forever or lose an edit. Exit codes: 0 valid and reloaded, or reverted; 1 for keep, no answer.
- **Valid file, but the server isn't reachable:** the file stays saved, and trex says `trex config reload` will try again (exit 0).
- **Keep:** also asks the server to reload. A blocking problem is refused with the server's own "Keeping the last good settings", while a file with only an unknown key still applies.
- **Revert:** copies `last-good-config.json` (beside state.json: `$TREX_STATE`'s directory in tests, else `$XDG_STATE_HOME/trex/`) over the file. Decision: with no last good file yet, it restores the default file rather than failing. It doesn't reload (the server still holds the last good settings).
- **What Rex gives a pane (checked in a throwaway session):** a `command` pane has a tty, the user's PATH, `SHELL` and `HOME`, but not `EDITOR`/`VISUAL` (not in the server's environment, and shell startup files are not read). So the action runs `$SHELL -lic "exec '<repo>/bin/trex' config edit"`, a login interactive shell, which picks up an `EDITOR` exported in `.zshrc`/`.zprofile`. Cost: shell startup time before the editor opens. Not tested against a real `.zshrc` (tests must not touch user files); the quoting was checked by running the same command line with a stub editor.
- **Tests:** 9 in `tests/test_config.sh` (valid reload, new file, VISUAL/EDITOR, edit again, keep, revert, revert without last good, unknown answer and EOF, the action opens a split) with a stub editor and answers on stdin; `test_install.sh` checks the palette title.
