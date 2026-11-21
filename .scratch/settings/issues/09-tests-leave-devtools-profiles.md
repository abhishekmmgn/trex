# 09: Test runs leave DevTools Pane profiles in the user's `~/.kittybrowser/trex-devtools/`

**What to build:** find which test (or which teardown path) leaves a DevTools Pane's KittyBrowser profile folder behind, and fix it so a run leaves nothing.

**Blocked by:** None

**Status:** needs-triage

Found 2026-11-21: after several suites ran at the same time (tickets 02, 04, 05), `~/.kittybrowser/trex-devtools/` in the user's home held four profile folders (`2-ca4c`, `3-4a43`, `4-12a0`, `4-802a`, from 14:46–14:48). No kb was running on them, and their sockets were gone. Runs reported "kbs still running … on DevTools sockets" for some of these ids. They were deleted by hand.

- [ ] Reproduce: run `tests/test_devtools.sh` (and the full suite) alone and while another suite runs, and list `~/.kittybrowser/trex-devtools/` before and after
- [ ] Find the cause. `devtools-pane.sh` removes the profile when the pane closes; check what happens when the session is killed (test teardown) before that cleanup runs
- [ ] Fix so a killed session still removes its profiles, or have the runner's end-of-run check remove (and report) profiles of DevTools Panes from blocks the run created
- [ ] The runner's leftover check fails the run when a profile folder is left, not only a socket
- [ ] Consider having tests use their own `trex-devtools` directory so a leak never reaches the user's

## Comments
