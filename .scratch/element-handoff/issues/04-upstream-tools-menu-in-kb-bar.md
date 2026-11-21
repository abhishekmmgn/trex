# 04: Upstream: a tools menu in kb's bar that runs Element Handoff

**What to build:** A menu button in kb's top bar, next to the ✕, that opens a small dropdown. One item runs Element Handoff in that pane. kb draws the bar, so this needs kb's code and goes to `graiz/kittybrowser` as a pull request from the user's fork, like tickets 05 and 08 in `.scratch/trex/issues/`. It probably has to be a general menu (for example Inspect, DevTools, Zoom), with a way for trex to add its item, because the maintainer is unlikely to take a trex-only button. One option: an entry kb reads from `~/.kittybrowser/keys` or a config file that runs a command.

**Blocked by:** 01

**Status:** needs-triage

- [ ] Agree with the user on the menu's shape and how trex adds its item, before writing code
- [ ] Ask upstream first (issue or draft PR) whether the maintainer wants a bar menu
- [ ] Built on a KittyBrowser branch following its `AGENTS.md` and `.github/CONTRIBUTING.md`; CI passes
- [ ] Nothing is pushed or opened upstream until the user agrees

## Comments

- 2026-11-21: the user chose "command now, bar later". Element Handoff is done without this ticket.
