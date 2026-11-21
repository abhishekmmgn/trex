# Settings and address autocomplete

Status: ready-for-agent

## Goal

The user can change how trex behaves without editing Lua or guessing option names, and opening a Browser Pane suggests addresses they have visited before, the way zsh-autocomplete suggests from history. See `GLOSSARY.md` for Browser Pane, DevTools Pane and Element Handoff, and ADR-0003 for why the config is JSON.

## Decisions (2026-11-21, with the user)

- **Autocomplete comes from kb's history.** Trex: Open Browser… becomes a palette list (`rex.ui.pick` with `allow_other = true`) that filters as you type. The first row is the configured default URL. After it come up to 50 URLs from `~/.kittybrowser/history`, ranked by visits and recency, and read every time the prompt opens. Enter on a row opens it. Enter on text that matches no row opens that text, after `url.normalise` (a bare port becomes localhost, and input starting with `-` is refused). Prototyped and tried by the user 2026-11-21. `rex.ui.pick` works only in actions defined in the server's `init.lua`. From a `rex do` script it returns `unsupported`.
- **The config is `$XDG_CONFIG_HOME/trex/config.json`** (default `~/.config/trex/config.json`), with `config.schema.json` next to it (ADR-0003). It is created already filled with every default:

  ```json
  {
    "$schema": "./config.schema.json",
    "default_url": "http://localhost:3000",
    "open_in": "split",
    "devtools": { "side": "below" },
    "pick": { "stay_on": true }
  }
  ```

  - `default_url`: what an empty answer, or the first row, opens. Default `http://localhost:3000`.
  - `open_in`: `"split"` opens the Browser Pane to the right of the focused pane (today's behaviour). `"window"` opens it in a new Rex window (a tab in the app).
  - `devtools.side`: `"below" | "above" | "right" | "left"`, default `"below"`. It is where a DevTools Pane opens. Moving a DevTools Pane is still remembered, and the next one opens there. When the user changes `devtools.side` in the config, the configured value wins and the remembered side is forgotten. There is no `"remember"` value.
  - `pick.stay_on`: `true` (default, today's behaviour) keeps pick mode on after a pick, so the user can hand off several elements in a row. `false` ends pick mode after one pick.
- **Commands are modeled on Rex's `rex config check` and `rex config reload`:**
  - `trex config edit`: creates the file and schema if missing, then opens the file in `$VISUAL`, else `$EDITOR`, else `vi`. When the editor exits, the file is checked. If it's valid, trex reloads it. If not, trex lists the problems and asks `(e)dit again / (k)eep anyway / (r)evert`. Revert puts back the last good file, as `visudo` and `crontab -e` do.
  - `trex config check`: validates the file and prints each problem with its key, the allowed values, and the line where it can be found. Exits 1 if there are problems.
  - `trex config reload`: makes the server use the file's settings now. If the file has problems, trex keeps the last good settings and reports what's wrong.
  - trex also reads the config whenever Rex loads its config (startup, `rex config reload`). Settings don't change between reloads.
  - Palette actions **Trex: Edit Config** (opens `trex config edit` in a split) and **Trex: Reload Config**.
  - `trex setup` creates the config and schema if they're missing, and leaves an existing file alone.
- **`--help` everywhere.** `trex --help`, `-h` and `help` print the overview. `trex <command> --help` prints that command's usage (`install`, `uninstall`, `block`, `setup`, `config edit|check|reload`, `browser`, `ctl`, `mcp`). Bare `trex` and bare `trex config` print usage.

## Notes for implementers

- Missing keys get their defaults. An unknown key is a problem `check` reports, though it doesn't stop a reload. trex never rewrites the user's file, except to create it or to revert it on the user's request.
- "Last good settings" has to survive a Rex restart. One way is a copy of the last valid file under trex's state directory, beside `state.json`.
- The remembered DevTools side is stored with the `devtools.side` it was remembered under, so a changed config value can be detected.
- Config Lua runs in the Rex server with PATH `/usr/bin:/bin` and no `rex.sleep`. `trex config reload` from a shell can reach the server through `rex do trex_reload_config`.

## Testing

As in `README.md`, "Tests": every test uses a temp `XDG_CONFIG_HOME` (or a `setup{ config = … }` path) and never the user's `~/.config/trex/` or live Rex config. The history file's path is configurable for tests (`setup{ kb_history = … }`).
