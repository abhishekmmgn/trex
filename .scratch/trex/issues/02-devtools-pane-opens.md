# 02: F12 opens a DevTools Pane

**What to build:** In a Browser Pane, F12 opens a DevTools Pane split below it, showing Chrome DevTools for that pane's page with DevTools' screencast preview off. Elements, Console, Network, Sources and Styles all work, and the inspector highlights elements in the Browser Pane. With several KittyBrowsers running, it always attaches to the one in the focused pane.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] F12 in a Browser Pane opens a DevTools Pane below it, for that pane's page
- [ ] DevTools' screencast preview is off from the first paint, or at most after one automatic reload
- [ ] With two or more Browser Panes open, each one's F12 attaches DevTools to its own page
- [ ] A `rex do` test confirms the new pane and its target: the DevTools Pane's URL names the Browser Pane's page target on that KittyBrowser's DevTools port
