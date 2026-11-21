# 05: Trackpad scroll fix, sent upstream

**What to build:** Scrolling in a Browser Pane follows the trackpad's real distance, instead of jumping a fixed amount for every wheel event, which makes it far too fast. The change goes to KittyBrowser itself, made on a branch of the user's fork `abhishekmmgn/trex-browser`, following KittyBrowser's own contributing and testing conventions.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] Scrolling with a Mac trackpad in Rex feels proportional; a mouse wheel still scrolls a sensible amount per notch
- [ ] KittyBrowser's own tests and CI checks pass on the branch
- [ ] The user has been asked, and agreed, before the pull request is opened on `graiz/kittybrowser`
- [ ] The pull request is open upstream

## Comments
- 2026-11-21: fix committed locally in `/Users/abhishekmmgn/Projects/trex-browser`, branch `trackpad-scroll-delta` (9671b44); CI checks pass. The user tried it: it works, though not quite as smooth as a real browser. The user said not to push or open the PR for now.
- 2026-11-21: pushed to the fork only (`origin` = `abhishekmmgn/trex-browser`), branch `trackpad-scroll-delta` (9671b44). No PR. trex now pins `trex-pin` (1cc86f1), which contains it (ADR-0002).
