# 08: `trex config show` lists the settings, and setup puts `trex` on PATH

**What to build:** two gaps found when the user first ran `trex --help` (2026-11-21). The help listed commands but no settings, and `trex` wasn't a command until it was linked by hand. See `../spec.md`.

**Blocked by:** None (01–07 are merged)

**Status:** ready-for-agent

## `trex config show`

- [ ] `trex config show` prints the config path, then one row per setting: key, the value in effect, its allowed values (enums) and a one-line description. Settings that differ from the default are marked `*`, with a footer saying what `*` means and pointing to `trex config edit`. Example:

  ```
  ~/.config/trex/config.json

    default_url     http://localhost:3000                  what Open Browser opens first and on an empty answer
    open_in         split   (split | window)               where a Browser Pane opens
  * devtools.side   right   (below | above | right | left) where DevTools opens; default below
    pick.stay_on    true    (true | false)                 keep picking after a pick, until Esc

    * changed from the default. Edit with `trex config edit`.
  ```

- [ ] Rows, allowed values, defaults and descriptions all come from `lua/trex/config.schema.json`, with nothing listed by hand, so a new setting shows up without touching `show`. Add a short `description` per setting to the schema if the current ones are too long for a row, for example in a separate field or by using the first sentence.
- [ ] Values are what the running Rex uses (the server's settings). If the file has problems, `show` says the last good settings are in effect and points to `trex config check`. If Rex isn't reachable, it shows the file's values (or the defaults) and says so.
- [ ] Bare `trex config` runs `show` (exit 0) instead of printing usage.
- [ ] The `trex --help` overview gains a `config show` line ("list the settings, their values and allowed values"). `trex config --help` ends with the settings list: the same rows, without current values.
- [ ] Tests with a temp config: defaults unmarked, a changed value marked, a bad file reports last-good, bare `config` equals `show`, and a setting added to a copy of the schema appears without code changes, if the test hooks allow it.

## `trex` on PATH

- [ ] `trex setup` links `~/.local/bin/trex` to the main checkout's `bin/trex`. It prints `ok` if the link is already right and `installed` when it creates it. It says it `would` under `--dry-run`. A different file or link already there is left alone, and setup says so (`skipped`) without failing.
- [ ] If `~/.local/bin` isn't on PATH, setup prints a line saying how to add it, and doesn't edit shell files.
- [ ] Tests use a temp directory for the link target (a hook such as `TREX_BIN_DIR`), never the user's `~/.local/bin`.
- [ ] README "Install" says setup does this, and "Agents" no longer tells users to link it by hand.

## Comments
