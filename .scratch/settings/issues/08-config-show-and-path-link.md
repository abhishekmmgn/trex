# 08: `trex config show` lists the settings, and setup puts `trex` on PATH

**What to build:** two gaps found when the user first ran `trex --help` (2026-11-21). The help listed commands but no settings, and `trex` wasn't a command until it was linked by hand. See `../spec.md`.

**Blocked by:** None (01–07 are merged)

**Status:** resolved

## `trex config show`

- [x] `trex config show` prints the config path, then one row per setting: key, the value in effect, its allowed values (enums) and a one-line description. Settings that differ from the default are marked `*`, with a footer saying what `*` means and pointing to `trex config edit`. Example:

  ```
  ~/.config/trex/config.json

    default_url     http://localhost:3000                  what Open Browser opens first and on an empty answer
    open_in         split   (split | window)               where a Browser Pane opens
  * devtools.side   right   (below | above | right | left) where DevTools opens; default below
    pick.stay_on    true    (true | false)                 keep picking after a pick, until Esc

    * changed from the default. Edit with `trex config edit`.
  ```

- [x] Rows, allowed values, defaults and descriptions all come from `lua/trex/config.schema.json`, with nothing listed by hand, so a new setting shows up without touching `show`. Add a short `description` per setting to the schema if the current ones are too long for a row, for example in a separate field or by using the first sentence.
- [x] Values are what the running Rex uses (the server's settings). If the file has problems, `show` says the last good settings are in effect and points to `trex config check`. If Rex isn't reachable, it shows the file's values (or the defaults) and says so.
- [x] Bare `trex config` runs `show` (exit 0) instead of printing usage.
- [x] The `trex --help` overview gains a `config show` line ("list the settings, their values and allowed values"). `trex config --help` ends with the settings list: the same rows, without current values.
- [x] Tests with a temp config: defaults unmarked, a changed value marked, a bad file reports last-good, bare `config` equals `show`, and a setting added to a copy of the schema appears without code changes, if the test hooks allow it.

## `trex` on PATH

- [x] `trex setup` links `~/.local/bin/trex` to the main checkout's `bin/trex`. It prints `ok` if the link is already right and `installed` when it creates it. It says it `would` under `--dry-run`. A different file or link already there is left alone, and setup says so (`skipped`) without failing.
- [x] If `~/.local/bin` isn't on PATH, setup prints a line saying how to add it, and doesn't edit shell files.
- [x] Tests use a temp directory for the link target (a hook such as `TREX_BIN_DIR`), never the user's `~/.local/bin`.
- [x] README "Install" says setup does this, and "Agents" no longer tells users to link it by hand.

## Comments

### 2026-11-21: built (branch `trex/settings-08-show`)

- **`trex config show`:** asks the server's new read-only `trex_config_show` action (returns `{ text, settings, blocking }`; it never reloads) and prints `text`. The rows are rendered in Lua (`config.lua`: `rows()`, `table()`, `report()`), so no jq/python3 at runtime (ticket 01's decision stands). Rows come from the schema's leaves, sorted by key (rex.json.decode loses the schema's order, so the order is alphabetical, not the ticket's example order).
- **Schema:** a new `x-summary` per setting is the one-line row text; `description` stays the long editor hover text.
- **Layout:** key, value, `(allowed | values)`, summary, all aligned. Booleans list `(true | false)`; free text has no allowed values. A changed value gets `*` and `; default X` on its row. Values over 40 characters are cut with `...` so rows stay under ~120 columns.
- **States:** bad file means the last good settings are shown with a note pointing to `trex config check`. Also added (not asked): when the file is valid but differs from what Rex holds, a note points to `trex config reload`. No server (or trex not loaded in it): `rex do lua/trex/config-show.lua config=PATH` shows the file's values (defaults for a missing or bad file) and says so.
- **Bare `trex config`** is `show` (exit 0). An unknown subcommand still prints usage, exit 2. `trex --help` has a `config show` line and a pointer line about settings; `trex config --help` ends with the settings list (defaults, no marks), from `config-show.lua help=1`.
- **Test hook:** `TREX_SHOW_DO` replaces the action name after `rex do` (like `TREX_RELOAD_DO`). A schema with an added setting is tested by loading `config.lua` with a modified schema copy, so the CLI itself is not exercised for that case.
- **`trex` on PATH:** `trex setup` links `$TREX_BIN_DIR` (default `~/.local/bin`) `/trex` to `<repo>/bin/trex` (`--repo`, else the main checkout; `main_checkout` moved into `bin/trex-lib.sh`). `ok` / `installed` / `would` / `skipped` (anything else already there, including a different symlink, is left alone, exit 0). If the dir isn't on PATH, setup prints the `export PATH=...` line and edits no shell file.
- **Observed:** the real `~/.config/trex/config.json` on this machine is invalid (`trex config check`: "the file ends where a value was expected", probably empty). Not touched.
