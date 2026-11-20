# trex

A Chromium browser in Rex panes, for frontend work beside a coding agent. It runs stock KittyBrowser (`kb`) and adds Rex actions and keys around it.
See `.scratch/trex/spec.md`, `GLOSSARY.md` and `docs/adr/`.

## Layout

- `lua/trex/init.lua`: the plugin. `setup(opts)` defines the Rex actions and key bindings. Its sibling modules load from the same directory.
  - `kb.lua`: KittyBrowser: binary path and the pinned-commit check.
  - `url.lua`: turns what the user typed into the address kb gets.
- `bin/trex`: adds or removes the marked block in Rex's config.
- `tests/`: the `rex do` harness and the tests.

## Install

The pinned KittyBrowser comes first:

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

- **trex: Open Browser…** (`cmd+shift+b`): asks for a URL (default `http://localhost:3000`) and opens a Browser Pane, `kb --devtools URL`, to the right
  of the focused pane. A bare port such as `3000` or `:3000` opens `http://localhost:3000`. Input starting with `-` is refused, because kb would read it
  as a flag. If the installed kb isn't the pinned commit, it says so and doesn't open.

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
- At the end it checks that `kb list` shows no kb in any block the run created, and it stops the page server.

Writing a test: add `test_something() { … }` to a `tests/test_*.sh` file (or a new one). Use the helpers in `tests/lib.sh`: `trex_do`
(sets `$DO_OUT`, `$DO_ERR`, `$DO_STATUS`), `block_ids`, `block_rect`, `focused_block`, `kb_row`, `kb_url`, and `assert_eq` / `assert_contains` /
`assert_status` / `fail`. Add any block you create outside `trex_do` to `BLOCKS_SEEN`, so the leftover check covers it.

Rules for tests, because the user's own Rex and kb run on the same machine:
- Always pass the action's arguments (for example `url=`). A missing one makes Rex show a prompt in the user's app.
- Never send keys (F12 above all) to a kb pane in a session the test didn't create, and never run `kb ctl` / `kb mcp` without `-i ID`.
- Never run kb or Chrome with a fake `HOME` (it pops a macOS keychain dialog).
- Don't edit, reload or `rex config reload` the live config. Use `bin/trex install --config <temp file>`.
