# 04: `open_in` opens the Browser Pane in a new Rex window

**What to build:** with `open_in: "window"`, Trex: Open Browser… opens the Browser Pane in a new Rex window (tab) of the session, by itself, instead of a split. `"split"` is today's behaviour. See `../spec.md`.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] `"window"` makes a new window in the focused pane's session, running `kb --devtools URL`, and focuses it
- [ ] F12, Pick Element and `bin/trex browser` still find it: check how "beside this pane" behaves for an Agent Pane in another window of the same session (the session fallback), and say what happens in this file
- [ ] The DevTools Pane opens inside the new window, on the configured side
- [ ] Tests for both values

## Comments
