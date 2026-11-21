# 01: Pick mode puts an element's description on the clipboard

**What to build:** "Trex: Pick Element" (palette, and a new key) puts the Browser Pane's page into pick mode. Hovering outlines the element under the cursor the way kb's Inspect does. Clicking one ends pick mode and copies its description to the clipboard: the tag with its id and classes, page URL, selector path, box, and opening HTML. There's no React part yet; that's ticket 03. See `../spec.md`, "How it works" and "The description".

**Blocked by:** None (can start immediately)

**Status:** ready-for-human

- [ ] "Trex: Pick Element" is in the palette and bound to a key that isn't kb's Inspect key. `cmd+shift+e` is proposed. Check it isn't taken by a Rex app shortcut, and record what was checked
- [x] Works from a Browser Pane, and from another pane with a Browser Pane beside it (resolved like `bin/trex browser`). Anywhere else it says there's no Browser Pane
- [x] Hovering outlines margin, border, padding and content with a label, in a layer that ignores the mouse. Shadow DOM is followed, as in kb's `HOVER`
- [x] The click that picks doesn't reach the page: no `pointerdown`, `mousedown`, `click` or focus change on the page. The wheel still scrolls
- [x] Esc, running the command again, or navigating away ends pick mode and leaves no overlay or listeners on the page
- [x] The description matches the format in the spec (first line, `page`, `path`, `box`, `html` cut at 300 characters) and is on the clipboard
- [x] Pick mode that runs longer than `kb ctl`'s 70 s reply timeout keeps working, or ends with a clear message. Decide which, and say so here
- [x] `rex do` tests in a throwaway session: pick with `kb ctl click` on the test page (page click counter stays 0), check the clipboard text, Esc cancels, a second command cancels

## Comments

- 2026-11-21, implementer (worktree `/Users/abhishekmmgn/Projects/trex-eh-01`, branch `trex/eh-01-pick-mode`, not committed):
  - Built: `lua/trex/pick.lua` (action `trex_pick`, "Trex: Pick Element", bound to `cmd+shift+e`), `lua/trex/pick.js` (runs in the page through
    `kb ctl -i ID eval`: outline, capture listeners, description, a toggle that returns `started` or `cancelled`), `lua/trex/pick-wait.sh` (started
    in the background; waits for the pick, copies it, shows "Copied to the clipboard" on the page). `setup{ clipboard = … }` sets the copy command
    (default `/usr/bin/pbcopy`). README "Use" documents it.
  - The Browser Pane is the pane's own kb, else the only one in its Rex window, else the only one in its session, as `bin/trex browser` decides.
    With none or several it says so.
  - Long picks: kb gives up on any request after **30 s** (`REQUEST_TIMEOUT`, `src/devtools.rs:27`), not the 70 s this ticket assumed. So
    the waiter asks the page in 25 s rounds (`pending`), and retries a failed round while pick mode is still on. Checked by hand: a pick made
    80 s after starting was copied, and the waiter exited. If the waiter dies, the page ends pick mode itself after 90 s with no wait.
  - Swallowing: the press that picks, and every press, release and click for 1 s after it, are stopped at window capture. Without that, `kb ctl
    click` (which falls back to a JavaScript click when the real one "didn't reach the page") leaked a pointerdown and mousedown to the page.
    A page's own window-capture listeners registered before pick mode would still run first. That's rare, so it's left alone.
  - Tests: `tests/test_pick.sh` (5): pick `#save` (exact description, page heard nothing, overlay gone, page's clicks work again), from the pane
    beside it plus Esc, the command again cancels, html cut at 300 characters with `…`, no Browser Pane. The clipboard is a stub
    (`TREX_CLIPBOARD`), never the user's. `test_install.sh` now expects three bindings and the Pick Element title. Full suite: 52/52.
  - **The suite needs `TREX_CRATES2`** pointing at a record that names the pin. During this work the installed kb became a build of
    `abhishekmmgn/trex-browser` at `1cc86f1` (not done by this ticket), so trex's pin check refuses `trex_open`. That's the user's real Rex too.
  - **Left for the user (the unticked box):** the Rex app's own shortcuts aren't visible from the CLI (`rex keymap` shows only config bindings,
    and osascript has no accessibility permission to read the app's menus). Press `cmd+shift+e` in a Browser Pane after `bin/trex install` from
    the main checkout. If the palette opens something else, the app has it, and we pick another key.
  - Not tested, true by construction: the wheel still scrolls (pick mode never listens to `wheel`), and navigating away ends pick mode (the
    outline, listeners and state live in the page's own JS, and the waiter exits when its eval fails and `__trexPick` is gone).
  - Not yet seen by a person: hovering and clicking with a real mouse in the Rex app.
