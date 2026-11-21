# 10: Cmd shortcuts reach the page in a Browser Pane

**What to build:** Shortcuts that a web app binds to Cmd (for example `Cmd+K` for search on ui.shadcn.com) reach the page in a Browser Pane, instead of being taken by Rex. Today Rex keeps `Cmd+K` for itself, so the page never sees it. Ctrl, `/`, arrows, Enter, Escape, Tab and Space already reach the page.

**Blocked by:** None

**Status:** needs-triage

- [ ] Find which Cmd keys Rex takes before the program in a pane sees them, and whether a Rex binding scoped to panes running kb can pass them through
- [ ] Decide with the user which Cmd shortcuts the Browser Pane should get, and which Rex keeps

## Comments

- 2026-11-21: the user confirmed `Cmd+K` on ui.shadcn.com is taken by Rex. Keyboard navigation is low priority for now; leave this until after scrolling (09) and Element Handoff.
