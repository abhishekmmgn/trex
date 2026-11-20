# 01: Open a Browser Pane from Rex

**What to build:** From any Rex pane, the user runs "trex: Open Browser…" from the command palette or presses `cmd+shift+b`. They enter a URL (default `http://localhost:3000`), and a Browser Pane running the pinned KittyBrowser with DevTools enabled opens in a split to the right of the focused pane. This ticket also sets up the trex plugin: it is loaded from this repo through a marked block in the Rex config, the way leaf is. It also adds the test harness every later ticket uses: a throwaway Rex session, a local test page, and trex actions driven with `rex do`, with the URL passed as an argument so no prompt appears.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] "trex: Open Browser…" appears in the Rex command palette, and `cmd+shift+b` runs it
- [ ] Without an argument it prompts for a URL defaulting to `http://localhost:3000`; with a `url` argument it opens without prompting
- [ ] The Browser Pane opens as a split to the right of the focused pane and takes focus; `localhost:3000` and a bare port both work
- [ ] Input that starts with `-` is rejected rather than passed to KittyBrowser as a flag
- [ ] The installed KittyBrowser is checked against the pinned commit (see ADR-0001), and a mismatch is reported clearly
- [ ] `rex config check` is clean with the trex block installed
- [ ] A `rex do` test in a throwaway session opens the local test page and confirms the new pane through `rex block ls --json` and `kb list`
