# 03: DevTools Pane lifecycle

**What to build:** The DevTools Pane behaves like a built-in panel. F12 again, from the Browser Pane or the DevTools Pane, closes it. F12 in any pane that isn't a Browser Pane reaches the program running there, unchanged. trex remembers which side the user last put DevTools on. Closing a Browser Pane also closes its DevTools Pane. If a KittyBrowser was started without DevTools, F12 says so instead of failing silently.

**Blocked by:** 02

**Status:** ready-for-agent

- [ ] F12 toggles the DevTools Pane closed from either pane
- [ ] F12 in a shell, editor or other non-Browser Pane reaches that program as if trex weren't installed
- [ ] The last DevTools side the user used is remembered for the next open
- [ ] Closing the Browser Pane closes its DevTools Pane
- [ ] A KittyBrowser started without DevTools gets a clear message on F12
- [ ] Check whether the DevTools Pane follows the page when the Browser Pane navigates; if it doesn't, raise it with the user rather than deciding alone
- [ ] `rex do` tests cover toggling off, pass-through, and closing the Browser Pane
