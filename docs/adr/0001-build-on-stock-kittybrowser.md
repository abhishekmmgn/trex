# Build on stock KittyBrowser through a Rex plugin; fork only if blocked

We build on KittyBrowser (`graiz/kittybrowser`, MIT) as it ships. It drives headless Chrome over CDP and draws frames with the kitty graphics protocol, handing them to the terminal as files. In a hands-on test in Rex it was fast where `zenbu-labs/terminal-browser` was not: with DevTools open there, the inspector hover took 3–4 s and DevTools tab switches took 8–10 s. This repo is a Rex-only plugin, trex. Its Rex actions in `init.lua` and its helper scripts open KittyBrowser in Rex splits and add a DevTools Pane: a second KittyBrowser view loading Chrome's own `devtools/inspector.html` for the page over the local DevTools port. Changes that need KittyBrowser's code, such as the trackpad scroll step, go upstream as pull requests. We do not fork, because KittyBrowser is days old and changing quickly, and a fork would mean constantly merging its churn. We fork only if something we need cannot be done from outside or upstream declines it.

## Considered Options

- **Hard fork of KittyBrowser, Rex-only.** Briefly chosen, then dropped: everything in Phase 1 except the scroll fix works from outside.
- **Fork `zenbu-labs/terminal-browser`** (Electron offscreen, 4.7k stars). DevTools is docked into the same offscreen surface, and every frame is zlib-compressed RGBA, base64-encoded through the pty. This is where the lag came from.
- **`Creator54/awrit`** (Electron, shared-memory dirty rects). Not benchmarked, because KittyBrowser already met the bar.
- **Carbonyl**, **browser-use terminal**, **cmux**. Carbonyl is abandoned and draws text characters with no DevTools. browser-use terminal is an agent, not a browser. cmux's browser panel uses WebKit.
- **Native Chrome DevTools window** (KittyBrowser's own F12). Rejected: the point is a Cursor/cmux-style browser built into the app, so DevTools stays in Rex.

## Consequences

- trex depends on KittyBrowser's outside surface: its flags, `kb list`, `kb ctl` and its profile layout. An upstream change there can break trex, so pin a known-good KittyBrowser commit.
- KittyBrowser runs with `--devtools`, so its DevTools port is open on 127.0.0.1 and any local program can drive the browser.
