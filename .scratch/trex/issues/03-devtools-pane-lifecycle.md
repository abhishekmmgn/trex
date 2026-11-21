# 03: DevTools Pane lifecycle

**What to build:** The DevTools Pane behaves like a built-in panel. F12 again, from the Browser Pane or the DevTools Pane, closes it. F12 in any pane that isn't a Browser Pane reaches the program running there, unchanged. trex remembers which side the user last put DevTools on. Closing a Browser Pane also closes its DevTools Pane. If a KittyBrowser was started without DevTools, F12 says so instead of failing silently.

**Blocked by:** 02

**Status:** ready-for-agent

- [x] F12 toggles the DevTools Pane closed from either pane
- [x] F12 in a shell, editor or other non-Browser Pane reaches that program as if trex weren't installed
- [x] The last DevTools side the user used is remembered for the next open
- [x] Closing the Browser Pane closes its DevTools Pane
- [x] A KittyBrowser started without DevTools gets a clear message on F12
- [x] Check whether the DevTools Pane follows the page when the Browser Pane navigates; if it doesn't, raise it with the user rather than deciding alone
- [x] `rex do` tests cover toggling off, pass-through, and closing the Browser Pane

## Comments

**2026-11-21, implementer (branch `trex/03-devtools-pane-lifecycle`):**

Built:
- **Toggle:** `devtools.toggle(ctx)` (palette: "Trex: Toggle DevTools", action `trex_devtools`; F12 runs the same function). In a Browser Pane it opens
  the DevTools Pane, or closes it if the pane labelled `trex devtools <kb id>` is open. In a DevTools Pane (found by that label) it closes that pane.
- **Remembered side:** when trex closes a DevTools Pane it reads where the pane sits next to its Browser Pane (`rex.session.view` rects: below,
  above, right or left) and saves it in `~/.local/state/trex/state.json` (`$XDG_STATE_HOME` honoured; `setup{ state = … }` overrides). The next
  DevTools Pane, for any Browser Pane, opens on that side. Default: below.
- **Closes with its Browser Pane:** `devtools-pane.sh` runs `rex wait -s SESSION BROWSER; rex block close -s SESSION $REX_BLOCK` in the background,
  and kills that watcher when the DevTools Pane closes, so toggling leaves nothing behind. It also fires when kb in the Browser Pane quits.
  The rex path comes from `setup{ rex = … }` or the first that exists of the Rex server's install paths (`find_rex` in `init.lua`).
- **Without DevTools:** `kb.devtools_port` now only counts a `DevToolsActivePort` whose port answers with the same browser endpoint. A killed
  test Chrome had left a stale file in `profile-2`, so a kb started without `--devtools` got "lists no page on its DevTools port" instead.
- **F12 errors reach the user:** a key function can't prompt or fail like an action, so when F12's work raises, `f12.lua` logs it and shows the
  message in a notice: a small Rex pane (`trex notice`) floating in front of the window, focused, closed by any key or after 60 s.
- Tests (`tests/run.sh`, 39/39 after merging `trex/phase-1`): toggle off from the Browser Pane and from the DevTools Pane, close the Browser Pane →
  DevTools Pane, kb and profile gone, no `rex wait` left after toggling off, side remembered (moved right then closed from the Browser Pane; moved
  above then closed from the DevTools Pane), kb without `--devtools` → message, F12 failure → notice with the message that closes on a key,
  pass-through to `cat -v` (from 02). Each test gets its own `TREX_STATE` file, so the real state file is never written.

**Question for the user: should the DevTools Pane follow the page?** Checked in a throwaway session (`kb ctl -i <id> open …` on the Browser
Pane, then DevTools' `document.title`):
- Same-tab navigation: **DevTools follows**, including to another origin (`DevTools - 127.0.0.1:P/` → `…/two.html` → `localhost:P/`). The page
  target id stays the same, so the inspector stays attached.
- A page that opens a new window (`window.open`): kb switches its pane to the new page (`kb list` shows `two.html`), but **DevTools stays on the
  old page**, which is no longer visible. Do you want trex to re-point DevTools when kb switches to another window (that would need trex to notice
  the switch, e.g. polling `kb list` or a kb change upstream), or is staying on the original page fine? Nothing was changed for this.

Left for a human:
- **Real F12 presses** with the block installed: F12 in a Browser Pane opens, F12 again (in either pane) closes. Only the action and the binding
  with a stub handler are tested; nobody has pressed F12 on the keyboard against a real kb.
- **The notice:** check it looks right in the app (bounds `0.1, 0.35, 0.8, 0.3` of the window, focused) and that focus goes back where it was
  after a key closes it. Try F12 on a kb started by hand without `--devtools` (`kb http://example.com` in a pane).
- **Remembered side by hand:** move a DevTools Pane with Rex's own move/drag, close it with F12, open again. Closing it any other way (Rex's close
  pane, or with the Browser Pane) does not record the side, because trex only sees the layout when it does the closing.
- The palette title changed from "Trex: Open DevTools" to "Trex: Toggle DevTools"; the app may need the block rewritten to refetch it.

**2026-11-21, review round (branch `trex/review-fixes`):**

- **F12 attaches to the window kb shows.** `kb.shown_target` (lua/trex/kb.lua): with one page target, that one; otherwise the page whose url
  (ignoring a trailing `/`, since kb reports the given address until the page loads) and, if needed, title match `kb ctl -i ID status`. No match
  or several (two windows on one page) is an error for the user ("can't tell which one it shows"); there is no fallback to the first page.
  Tests: `test_devtools_attaches_to_the_window_kb_shows`, `test_devtools_refuses_to_guess_between_windows_on_one_page`.
- **Follows new windows (the user's answer to the question above: yes).** The `rex wait` watcher is replaced by `lua/trex/devtools-watch.lua`,
  a `rex do` script the DevTools Pane runs beside its kb. Every second it asks the Browser Pane's kb what it shows (`kb ctl -i ID status`);
  when the url or the `windows:` line changes it finds the page target again and, if it is another one, `kb ctl open`s that inspector in the
  DevTools Pane's KittyBrowser (same origin, so the screencast setting still holds). It follows back when the popup closes. It also closes the
  DevTools Pane on `block_closed` / `terminal.child_exited` of the Browser Pane, and exits when the DevTools Pane closes.
  Test: `test_devtools_follows_kb_to_a_window_the_page_opens` (window.open, then `kb ctl back`).
- **Remembered side, however it closes.** Rex gives no hook at close time (the layout is already gone by then, and config Lua can't hear
  `block_closed`), so the watcher records the side on every `session_view_changed`: on open and whenever the pane is moved. The last side seen
  while the two panes sat side by side is what the next DevTools Pane uses, whether this one was closed by F12, by Rex's own close, or with
  its Browser Pane. F12's own close still records it too. Tests: `test_devtools_closed_by_rex_…`, `test_devtools_closed_with_its_browser_pane_…`.
  (Moving the DevTools Pane to another tab or window records nothing; the side before that stays.)
- **Rex's floating notifications: no route for plugins.** Checked the Rex docs (`reference_mac-actions.md` "Notification Position",
  `reference_mac-settings.md` In-App Notifications, `automate_lua-events.md`, `reference_lua.md`, `reference_api.md`, and the live
  `build/program-status.md`) and the app itself (`rex client inspect` on the Mac app, its binary's strings):
  - No Lua API posts a notification, and the Mac app's client actions include only `client.notice.dismiss`, nothing that shows one, so
    `rex.client.queue` / `client.perform` can't either.
  - OSC 9 / OSC 777 go to **native macOS notifications** (Settings > Notifications > System Notifications > "Terminal notifications"),
    not the in-app ones.
  - OSC 7501 (Program Status Protocol) drives tab indicators, the session picker, sounds and macOS notifications while Rex is in the
    background; it would also have to be written by the program in the Browser Pane (kb), not by trex.
  - The app's floating notices (`RexNotice`, `ActionFailureReporter`, "Pane Action Failed") are what it shows for its own failures. A key
    function that raises makes the app's `client.key` call fail, which might land there, but whether the app shows `client.key` failures is
    unverified (it needs a real key press in the app), and raising would lose the message if it doesn't. Worth one manual try: temporarily
    make f12.lua re-raise instead of showing its notice, press F12 on a kb started without `--devtools`, and see if Rex shows a notice.
  So the floating `trex notice` pane stays, as the fallback, changed so it doesn't steal focus: it sits at the top of the window
  (`0.15, 0.04, 0.7, 0.16`), opens unfocused, and closes itself after 8 s (or on a key once clicked). Tests: the notice shows the message,
  focus stays where it was, a key closes it, and it closes by itself.
- `tests/run.sh`: 47/47.

Left for a human: following a real popup in the app (a site that opens a window), the side after dragging the pane with the mouse and
closing it with Rex's close, and how the new notice looks.
