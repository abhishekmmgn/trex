# 04: `open_in` opens the Browser Pane in a new Rex window

**What to build:** with `open_in: "window"`, Trex: Open Browser… opens the Browser Pane in a new Rex window (tab) of the session, by itself, instead of a split. `"split"` is today's behaviour. See `../spec.md`.

**Blocked by:** 01

**Status:** resolved

- [x] `"window"` makes a new window in the focused pane's session, running `kb --devtools URL`, and focuses it
- [x] F12, Pick Element and `bin/trex browser` still find it: check how "beside this pane" behaves for an Agent Pane in another window of the same session (the session fallback), and say what happens in this file
- [x] The DevTools Pane opens inside the new window, on the configured side
- [x] Tests for both values

## Comments

### 2026-11-21: built (branch `trex/settings-04-open-in`)

- **Where:** `place_browser(ctx, layout)` in `lua/trex/init.lua` is the one place that chooses a split or a window. It reads `config.get("open_in")` each time Trex: Open Browser… runs (so a reload takes effect at once). `"window"` calls `rex.session.new_window{ focus = true }` for the focused pane's session, running the same `kb --devtools URL`. A run with no focused pane already opened a window, and still does.
- **Box 2, checked with tests (`tests/test_open_in.sh`), with the Browser Pane alone in its own window:**
  - **F12 / DevTools:** works. trex finds the Browser Pane from its own pane (kb list), and the DevTools Pane is split from that pane, so it opens in the new window, on the remembered or default side (below), and focus stays in the Browser Pane.
  - **Pick Element from the Agent Pane in the first window:** works. `pick.lua` prefers the same window, then falls back to the session, so it reaches the Browser Pane, and the Agent Pane stays the pane it ran from.
  - **`bin/trex browser` / `ctl` / `mcp` from an Agent Pane in the first window:** work, through the same fallback (window first, then session).
  - **Where it breaks:** the fallback needs exactly one Browser Pane in the session. With `"window"`, a second Browser Pane lands in a window of its own, and an agent in a third window (say the first) then sees two candidates: `trex browser` fails with "more than one Browser Pane here" and lists both ids (a test checks this); Pick Element copies only, and says why. With `"split"` the same agent would have had one beside it. An agent in a Browser Pane's own window still gets that one. Resolution was not redesigned, as asked; the workaround is `trex ctl -i ID`. If this bites, an option is to prefer the Browser Pane in the most recently focused window.
- **Tests:** `tests/test_open_in.sh` (6): new focused window for `"window"`, the split stays in its window for `"split"`, DevTools in that window below, `trex browser` and Pick Element across windows, and the two-Browser-Panes case above. The existing open tests cover the default.
- **Docs:** README "Use" and "Config".
