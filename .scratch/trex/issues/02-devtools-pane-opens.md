# 02: F12 opens a DevTools Pane

**What to build:** In a Browser Pane, F12 opens a DevTools Pane split below it, showing Chrome DevTools for that pane's page with DevTools' screencast preview off. Elements, Console, Network, Sources and Styles all work, and the inspector highlights elements in the Browser Pane. With several KittyBrowsers running, it always attaches to the one in the focused pane.

**Blocked by:** 01

**Status:** ready-for-agent

- [x] F12 in a Browser Pane opens a DevTools Pane below it, for that pane's page
- [x] DevTools' screencast preview is off from the first paint, or at most after one automatic reload
- [x] With two or more Browser Panes open, each one's F12 attaches DevTools to its own page
- [x] A `rex do` test confirms the new pane and its target: the DevTools Pane's URL names the Browser Pane's page target on that KittyBrowser's DevTools port

## Comments

**2026-11-21, implementer (branch `trex/02-devtools-pane-opens`):**

Built:
- `lua/trex/devtools.lua`: Browser Pane block → its kb (`kb list`) → `profile[-N]/DevToolsActivePort` → `/json/list` page target (the page whose url is
  the kb's, else the first page) → inspector URL → a split below (`vertical`/`after`, focus stays put), labelled `trex devtools`.
- `lua/trex/devtools-pane.sh`: the DevTools Pane's command. Starts kb on `http://127.0.0.1:PORT/json/version`; in the background it waits for kb to
  answer, writes `screencast-enabled=false` to that origin's localStorage, then `kb ctl open`s the inspector. When the pane closes it removes its
  socket and profile (after waiting for Chrome to exit).
- `lua/trex/f12.lua`: F12 is consumed (returns true) whenever the focused pane's foreground program is `kb`, and returns false everywhere else. Errors
  are caught and logged, never raised. In a DevTools Pane (its kb isn't in `kb list`) F12 is consumed and does nothing yet.
- Action `trex_devtools` ("trex: Open DevTools") runs the same thing from the palette and is the test seam. Run in a pane that isn't a Browser Pane, it
  says so. A Browser kb started without `--devtools` gets "was started without DevTools" (ticket 03 owns making that message reach the user on F12:
  today a key function can only log it).
- Tests: `tests/test_devtools.sh` (pane below, focus kept, inspector URL = port from `DevToolsActivePort` + target from `/json/list` worked out
  independently, screencast key is `"false"`, hidden from `kb list`, two Browser Panes each get their own; not-a-Browser-Pane refused) and
  `tests/test_f12.sh` (binding loaded as a client script: passes through to `cat -v` as `^[[24~`; consumed in a pane whose program is named `kb`, which
  is a re-signed copy of `cat`, never a real kb). `tests/run.sh` 19/19.

**Hiding the DevTools kb from `kb ctl` (ticket 04):** done. It runs with `KB_SOCKET=~/.kittybrowser/trex-devtools/<browser kb id>.sock` and
`KB_CHROME_ARGS=--user-data-dir=~/.kittybrowser/trex-devtools/<browser kb id>`. The tests check `kb list` doesn't show it. Side effects, from kb's
source: with `KB_SOCKET` kb counts itself instance 1, so at start it rewrites `~/.kittybrowser/profile/Default/Preferences` (the same three
password/autofill-off values kb always writes there), and the inspector URLs go into kb's shared address-bar history (`~/.kittybrowser/history`).

Left for a human (first box unticked):
- **A real F12 press** with the block installed (`bin/trex install` after merging; the app may need the block rewritten to refetch). The binding is
  tested only as a client script with a stub handler, and the opening only through the action; nobody has pressed F12 on the keyboard. Check the Mac
  fn-key setting (F12 may need `fn`). Also check the time: the key function has 5 s in all and runs `kb list` + one `curl`.
- **Screencast off from the first paint:** tested by reading the stored value, not by looking. The exploration's screenshots showed this recipe
  paints without the preview. Expect a brief flash of `/json/version` JSON before the inspector loads.
- **DevTools itself:** Elements, Console, Network, Sources and Styles working, and the inspector highlight appearing in the Browser Pane.

Notes for ticket 03:
- The DevTools Pane is labelled `trex devtools <browser kb id>`; `devtools.open` finds an open one by that label and returns it with
  `already_open = true` instead of opening a second (two would share one socket and profile; `test_devtools_again_keeps_the_open_devtools_pane`).
  That is the hook for toggle-close. `devtools-pane.sh` also refuses to start if another live pane holds the profile directory.
- An empty `url=` in "trex: Open Browser…" now opens `http://localhost:3000` (user request), replacing the old "no URL given" refusal.
- 2026-11-21: the user pressed a real `fn+F12` in a Browser Pane in the Rex app: the DevTools Pane opened below, for that page, with no screencast preview. Elements and Styles rendered. Inspector highlight and the other panels still to confirm.
