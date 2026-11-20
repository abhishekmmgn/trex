# trex

A Chromium browser in Rex panes, for frontend work beside a coding agent. It runs stock KittyBrowser (`kb`) and adds Rex actions and keys around it.
See `.scratch/trex/spec.md`, `GLOSSARY.md` and `docs/adr/`.

## Layout

- `lua/trex/init.lua`: the plugin. `setup(opts)` defines the Rex actions and key bindings. Its sibling modules load from the same directory.
  - `kb.lua`: KittyBrowser: binary path and the pinned-commit check.
  - `url.lua`: turns what the user typed into the address kb gets.
  - `devtools.lua`: opens or closes a Browser Pane's DevTools Pane (block → kb → DevTools port → page target → inspector URL), on the remembered side.
  - `devtools-pane.sh`: the DevTools Pane's command. Runs the hidden DevTools kb, turns DevTools' screencast off before the inspector loads, and
    closes the pane when its Browser Pane closes.
  - `f12.lua`: the F12 binding, and the notice it shows when something fails. Uses only `rex.bind`/`rex.session`/`rex.block.call`, so tests can load
    it as a client script.
  - `state.lua`: trex's saved state (`~/.local/state/trex/state.json`): the side DevTools was last on.
- `bin/trex`: adds or removes the marked block in Rex's config. `bin/trex browser|ctl|mcp` (`bin/trex-agent`) are for agents, see Agents.
- `tests/`: the `rex do` harness and the tests.

## Install

One command does everything (Rex must already be installed; trex only reports it if missing):

```sh
bin/trex setup              # cargo, Google Chrome, the pinned KittyBrowser, then the trex block
bin/trex setup --dry-run    # print what it would do, change nothing
bin/trex setup --yes        # also replace a kb at another commit (or a local build) without asking
```

Each requirement prints `ok` (already there), `installed`, `skipped` or `FAILED` with the reason. What is present is left alone, so rerunning changes nothing.
cargo comes from an existing `cargo` (also `~/.cargo/bin/cargo`), else Homebrew's `rustup` if `brew` exists, else the official rustup installer.
Chrome is detected in `/Applications` or `~/Applications`, else installed with `brew install --cask google-chrome`, else from Google's official dmg (no Homebrew needed).
A kb at another commit is only replaced after you confirm. The pin lives in `lua/trex/kb.lua`; the logic is in `bin/trex-setup`.

Or by hand. The pinned KittyBrowser comes first:

```sh
cargo install --git https://github.com/graiz/kittybrowser --rev d252d5fe771f4d8f18fbf184d8239524b3ecda39 --force
```

Then add trex to Rex's config:

```sh
bin/trex install          # writes the trex block into ~/.config/rex/init.lua, runs `rex config check`, reloads
bin/trex uninstall        # removes it
bin/trex block            # prints the block without writing anything
bin/trex install --config /tmp/init.lua --repo .   # another config file, loading this checkout's Lua
```

The block `dofile()`s `lua/trex/init.lua` from the main checkout of this repo, not a linked worktree. If `rex config check` fails, the old file is put back.
The block holds a hash of `lua/trex/*.lua`. The Rex app refetches palette actions only when `init.lua` itself changes, so run `bin/trex install` again after
changing trex's Lua.

## Use

- **Trex: Open Browser…** (`cmd+shift+b`): asks for a URL (default `http://localhost:3000`) and opens a Browser Pane, `kb --devtools URL`, to the right
  of the focused pane. An empty answer opens the default. A bare port such as `3000` or `:3000` opens `http://localhost:3000`. Input starting with `-`
  is refused, because kb would read it as a flag. If the installed kb isn't the pinned commit, it says so and doesn't open.
- **F12** in a Browser Pane, or **Trex: Toggle DevTools** from the palette: opens a DevTools Pane beside it, with Chrome DevTools for that pane's
  page, and leaves focus in the Browser Pane. F12 again, in the Browser Pane or the DevTools Pane, closes it. The pane is labelled
  `trex devtools <kb id>`.
  - It opens below the Browser Pane at first. Move it (above, below, left or right of the Browser Pane) and close it with F12, and the next one opens
    on that side. trex keeps the side in `~/.local/state/trex/state.json`.
  - Closing the Browser Pane (or quitting its kb) closes its DevTools Pane: the DevTools Pane runs `rex wait` on the Browser Pane.
  - F12 in any pane running kb is always taken by trex, because kb's own F12 opens DevTools in a desktop Chrome window (and can land in another kb's
    Chrome). F12 in any other pane reaches the program there unchanged.
  - When F12 can't do its work (say the kb was started without `--devtools`), it says why in a notice floating in front of the window; any key
    closes it. The palette action reports the same message the usual way.
  - The DevTools Pane is a second kb, started with its own `KB_SOCKET` (`~/.kittybrowser/trex-devtools/<kb id>.sock`) and Chrome profile
    (`~/.kittybrowser/trex-devtools/<kb id>/`, removed when the pane closes). So `kb list`, plain `kb ctl` and `kb mcp` don't see it, and agents keep
    driving the Browser Pane. To reach it: `KB_SOCKET=~/.kittybrowser/trex-devtools/<kb id>.sock kb ctl status`.
  - It first loads `http://127.0.0.1:PORT/json/version`, sets `screencast-enabled=false` in that origin's localStorage (where DevTools keeps its
    settings), then opens the inspector, so DevTools never shows its page preview.

## Agents

A coding agent in an Agent Pane drives the Browser Pane beside it through `bin/trex` (logic in `bin/trex-agent`). Don't let it run plain `kb ctl`
or a plain `kb mcp serve`: without `-i` they reach the lowest-numbered kb, which is often your own kb in some other session.

```sh
bin/trex browser            # prints the kb id of the Browser Pane beside this pane
bin/trex ctl status         # kb ctl -i <that id> status; any kb ctl command works (check, eval, screenshot --out F, …)
bin/trex ctl -i 3-a7f2 check   # name one yourself (ids from `kb list`)
```

"Beside this pane" is worked out on every call from the pane's `REX_SESSION` and `REX_BLOCK` (Rex sets them in every pane, and an agent's
commands inherit them): the kb in `kb list` whose pane is in the same Rex window, else the only one in the same session. DevTools Panes' kbs are
never picked (they aren't in `kb list`). With no Browser Pane, or two in the window, it prints why (and the ids to choose from) and exits 1, and
never falls back to another kb. So a Browser Pane opened or reopened after the agent started is found without restarting anything.

Setup, once:
- Put `trex` on the agent's PATH, e.g. `ln -s "$PWD/bin/trex" ~/.local/bin/trex`, or give the agent the full path.
- MCP (optional): `kb mcp on` (kb's own switch), then `claude mcp add kb -- "$PWD/bin/trex" mcp` instead of the `kb mcp serve` that
  `kb mcp on` suggests. `trex mcp` is kb's MCP server with each tool call sent to the Browser Pane beside the agent at the time of the call.
- Skill (optional): `kb skill install` teaches the agent kb's commands. Its own recipe opens a separate kb pane; tell the agent to use the
  Browser Pane instead, for example in the project's `CLAUDE.md`/`AGENTS.md`:

  > The browser is the trex Browser Pane beside you. Drive it with `trex ctl COMMAND` (same commands as `kb ctl`), never plain `kb ctl`.
  > Don't open your own kb pane. If `trex ctl` says there are two Browser Panes, pick one with `trex ctl -i ID COMMAND`.

## Tests

```sh
tests/run.sh                                  # everything
tests/run.sh tests/test_open_browser.sh       # one file
TREX_TEST_FILTER=bare_port tests/run.sh       # test functions whose name contains this
```

Needs `rex`, `kb` (`~/.cargo/bin/kb`, or set `KB`), `jq`, `/usr/bin/python3` and `/usr/bin/curl`. No network.

What the runner does:
- It serves `tests/site/` on a free local port (`$PAGE_URL`, `$PAGE_PORT`).
- It runs each `test_*` function of each `tests/test_*.sh` in its own throwaway Rex session (`rex new trex-test`). That gives `$SESSION`, and its shell
  block `$ANCHOR`. It kills the session afterwards, which also quits every kb and Chrome in it.
- It drives trex with `rex do tests/load.lua --action NAME -s $SESSION -b BLOCK url=…`. `tests/load.lua` loads `lua/trex/init.lua` from this checkout
  the way the config block does. So tests never read or change `~/.config/rex/init.lua`, except that `test_install.sh` copies it to a temp file.
- At the end it checks that `kb list` shows no kb in any block the run created, that no DevTools Pane kb still answers on its socket or left its
  profile behind (`DEVTOOLS_SOCKETS`), and it stops the page server.
- F12 is pressed through `rex do tests/f12.lua -b BLOCK`, which loads `lua/trex/f12.lua` as a client script on its own connection with a stub
  handler, so the real config isn't involved. The kb pane in those tests is a re-signed copy of `cat` named `kb`, never a real kb.

Writing a test: add `test_something() { … }` to a `tests/test_*.sh` file (or a new one). Use the helpers in `tests/lib.sh`: `trex_do`
(sets `$DO_OUT`, `$DO_ERR`, `$DO_STATUS`), `block_ids`, `block_rect`, `focused_block`, `kb_row`, `kb_url`, and `assert_eq` / `assert_contains` /
`assert_status` / `fail`. Add any block you create outside `trex_do` to `BLOCKS_SEEN`, so the leftover check covers it.

Rules for tests, because the user's own Rex and kb run on the same machine:
- Always pass the action's arguments (for example `url=`). A missing one makes Rex show a prompt in the user's app.
- Never send keys (F12 above all) to a real kb pane, and never run `kb ctl` / `kb mcp` without `-i ID` or a DevTools Pane's `KB_SOCKET`.
- Never run kb or Chrome with a fake `HOME` (it pops a macOS keychain dialog).
- Don't edit, reload or `rex config reload` the live config. Use `bin/trex install --config <temp file>`.
