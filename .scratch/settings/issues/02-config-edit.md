# 02: `trex config edit` refuses a broken file

**What to build:** `trex config edit` and **Trex: Edit Config**, as in `../spec.md`. It opens the config in the user's editor and checks it when the editor exits, like `visudo`.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] Creates the config and schema if missing, then opens `$VISUAL`, else `$EDITOR`, else `vi`
- [ ] On exit with a valid file: reloads it (as `trex config reload`) and says so
- [ ] On exit with problems: lists them and asks `(e)dit again / (k)eep anyway / (r)evert`. Revert restores the last good file. Keep leaves the file, and the last good settings stay in effect
- [ ] **Trex: Edit Config** opens `trex config edit` in a split beside the focused pane
- [ ] Tests with a stub `EDITOR` script that writes a valid or an invalid file, and answers to the prompt fed on stdin

## Comments
