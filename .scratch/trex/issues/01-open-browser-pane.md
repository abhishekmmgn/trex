# 01: Open a Browser Pane from Rex

**What to build:** From any Rex pane, the user runs "Trex: Open Browser…" from the command palette or presses `cmd+shift+b`. They enter a URL (default `http://localhost:3000`), and a Browser Pane running the pinned KittyBrowser with DevTools enabled opens in a split to the right of the focused pane. This ticket also sets up the trex plugin: it is loaded from this repo through a marked block in the Rex config, the way leaf is. It also adds the test harness every later ticket uses: a throwaway Rex session, a local test page, and trex actions driven with `rex do`, with the URL passed as an argument so no prompt appears.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [x] "Trex: Open Browser…" appears in the Rex command palette, and `cmd+shift+b` runs it
- [x] Without an argument it prompts for a URL defaulting to `http://localhost:3000`; with a `url` argument it opens without prompting
- [x] The Browser Pane opens as a split to the right of the focused pane and takes focus; `localhost:3000` and a bare port both work
- [x] Input that starts with `-` is rejected rather than passed to KittyBrowser as a flag
- [x] The installed KittyBrowser is checked against the pinned commit (see ADR-0001), and a mismatch is reported clearly
- [x] `rex config check` is clean with the trex block installed
- [x] A `rex do` test in a throwaway session opens the local test page and confirms the new pane through `rex block ls --json` and `kb list`

## Comments

**2026-11-21, implementer (branch `trex/01-open-browser-pane`):**

Built: `lua/trex/` (`init.lua` with `setup()`, `kb.lua` with the pin check, `url.lua`), `bin/trex install|uninstall|block`, and the `rex do` harness
(`tests/run.sh`, `tests/lib.sh`, `tests/load.lua`, `tests/site/`). README.md says how to run it. `tests/run.sh` passes 13/13.

Left for a human (the two unticked boxes):
- **Palette and `cmd+shift+b`:** `rex config check --json` on a config with the block lists `trex_open` titled "Trex: Open Browser…" and one more
  binding. Nobody has seen it in the app's palette or pressed `cmd+shift+b` on the keyboard yet. That needs the block in the live config
  (`bin/trex install`, after merging to the main checkout) and a look. An app-level shortcut on `cmd+shift+b` in Rex's own settings would win over init.lua.
- **The prompt:** the `url=` path is tested (no prompt appears). The no-argument path (`rex.ui.input` with default `http://localhost:3000`) is untested,
  because a prompt from `rex do` pops up in the user's own Rex app. Check by hand: palette → "Trex: Open Browser…" → Enter.

Verified by hand: `bin/trex install --config <temp copy of ~/.config/rex/init.lua> --repo <this checkout>` → `rex config check` clean (11 actions,
2 bindings, no diagnostics). `test_install_into_a_copy_of_the_live_config` repeats this on every run. Until this branch is merged into the main checkout, a
default `bin/trex install` would fail the check (the main checkout has no `lua/trex/` yet) and put the file back.

Notes for later tickets:
- An empty URL is refused ("no URL given") rather than replaced with the default.
- `kb list` can report the address kb was given (`http://localhost:N`, no trailing slash) until the page loads. Use `kb_url BLOCK EXPECTED`, which polls.
- Tests pass test-only settings to `tests/load.lua` through the environment (e.g. `TREX_CRATES2`), because `rex do --action` rejects unknown `key=value` args.
- 2026-11-21: the user confirmed in the Rex app that the palette entry, `cmd+shift+b` and the default-URL prompt work.
