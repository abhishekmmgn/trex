# trex: a Chromium browser with DevTools inside Rex

Status: ready-for-agent

## Goal

A Cursor/cmux-style browser built into Rex for frontend work, sitting beside a coding agent. The main reason it exists is fast Chrome DevTools: an inspector that hovers smoothly, Console, Network, Sources and cache, all inside Rex panes. Rex is the only terminal we target.

See `GLOSSARY.md` for the terms (Browser Pane, DevTools Pane, Agent Pane, Element Handoff, Base Browser) and `docs/adr/0001-build-on-stock-kittybrowser.md` for why we build on stock KittyBrowser and don't fork.

## Shape

- **Base Browser:** stock KittyBrowser (`kb`), from `graiz/kittybrowser`, pinned at `d252d5fe771f4d8f18fbf184d8239524b3ecda39` and installed with `cargo install --git … --rev`. It runs the installed Google Chrome with kb's own profile.
- **trex:** a Rex plugin in this repo. Like leaf, a marked block in `~/.config/rex/init.lua` `dofile()`s trex's Lua from this repo. It adds Rex actions and key bindings, plus helper scripts if Lua alone isn't enough.
- **Upstream changes:** anything that needs kb's code goes to `graiz/kittybrowser` as a pull request from `abhishekmmgn/trex-browser`. We fork only if blocked (see ADR-0001).
- **Removed (2026-11-21):** `terminal-browser` is gone entirely: its Rex actions, its `com.superlogical.rex.browser-action` and `dev.zenbu.terminal-browser` preferences, its launcher, the app, and its profile. The app and profile went to the macOS Trash.
- **Tickets:** `.scratch/trex/issues/01`–`06`. 01 (Open Browser Pane) and 05 (upstream scroll PR) have no blockers.

## Phase 1: Browser Pane + DevTools Pane

1. **Open Browser.** "trex: Open Browser…" appears in the Rex command palette and is bound to `cmd+shift+b`. It asks for a URL (default `http://localhost:3000`) and runs `kb --devtools <url>` in a Rex split to the right of the focused pane.
2. **DevTools Pane.** F12, bound in Rex:
   - **In a Browser Pane:** finds that pane's kb (`kb list` maps each kb to its Rex block) and reads its DevTools port (`profile-N/DevToolsActivePort`). It then opens `http://127.0.0.1:PORT/devtools/inspector.html?ws=127.0.0.1:PORT/devtools/page/<target>` in a second kb, split below, with DevTools' screencast turned off. Pressing F12 again closes it. trex remembers the last split side the user chose.
   - **In any other pane:** F12 passes through to the program unchanged.
3. **Trackpad scroll.** kb moves a fixed 60 CSS px per wheel event (`WHEEL_STEP`, `src/app.rs`), so a trackpad scrolls much too fast. Fix it upstream so the scroll follows the actual delta.
4. **Agent access.** `kb ctl`, `kb mcp` and `kb skill install` already exist. Confirm that an agent in the Agent Pane drives the Browser Pane beside it, not the DevTools Pane's kb.
5. **Speed check** with DevTools open on a Retina half-width pane:
   - inspector hover highlight follows the cursor in ≤100 ms
   - DevTools tab switch takes ≤300 ms
   - scrolling runs at ≥30 fps
   - typing echoes in <50 ms

## Testing

- **One seam: trex's Rex actions, driven from outside with `rex do`, in a throwaway Rex session.**
  - `rex do <script>.lua --action NAME` loads trex's Lua straight from this repo, so tests never touch the user's real `init.lua`.
  - Arguments such as `url=` skip the `rex.ui` prompts.
- **Assertions use existing tools only:**
  - `rex block ls --json` for the panes: created, on the right side, closed
  - `kb list` for which kb belongs to which block
  - the DevTools port's `/json/list` and `kb ctl` for which page each pane shows, and which pane an agent reaches
- **Test page:** a local HTML server, so tests don't need the network.
- **No lower seams.** The internal lookups (block → kb → port → page target → inspector URL) are tested only through the action's result.
- **Not covered by this seam:**
  - The upstream scroll fix is tested in KittyBrowser's own repo, by its conventions.
  - The speed targets are judged by the user, with `kb bench` numbers.

## Phase 2: Element Handoff (only once Phase 1 feels right)

A pick mode, separate from the DevTools inspector. It sends a Cursor-style description of the picked element to the Agent Pane as unsent text, and also copies it to the clipboard. The description has the DOM path, position and opening HTML, plus the React component and source `file:line` when available (react-grab style). It is injected into the page over CDP, not built into a fork. It gets its own spec when we get there.

## Out of scope

- Terminals other than Rex.
- DevTools in a native desktop Chrome window. That stays a last resort, and only if the speed check can't be met inside Rex; ask the user first.
- Forking KittyBrowser.
- A pinned Chrome for Testing. Revisit only if a Chrome update breaks something.

## Verified so far

- On 2026-11-21, stock kb `--devtools` plus a second kb on `inspector.html` gave a working DevTools Pane in Rex.
  - The `screencastEnabled=false` setting in DevTools' localStorage removes the page preview.
  - The user found the hover and tab switching fast.
