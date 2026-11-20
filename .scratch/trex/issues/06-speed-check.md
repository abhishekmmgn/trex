# 06: Speed check against the Phase 1 targets

**What to build:** Confirm the Browser Pane with its DevTools Pane is fast enough for daily frontend work, judged by the user. Measure it on a Retina half-width Rex pane with DevTools open.

**Blocked by:** 02

**Status:** ready-for-human

- [ ] Inspector hover highlight follows the cursor in ≤100 ms
- [ ] Switching DevTools tabs (Elements → Console → Network) takes ≤300 ms
- [ ] Page scrolling runs at ≥30 fps, with `kb bench` numbers recorded
- [ ] Typing in the page appears in <50 ms
- [ ] Any miss is measured to its cause before anything changes; moving DevTools to a native window is a last resort and needs the user's agreement
