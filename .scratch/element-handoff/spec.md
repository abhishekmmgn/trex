# Element Handoff

Status: needs-triage

## Goal

The user points at something in a Browser Pane and tells the coding agent "change this". They run one command, hover the page, and click an element. A description of that element appears in the Agent Pane as unsent text and is also on the clipboard, so they can type their request after it and send. This is Phase 2 of `.scratch/trex/spec.md`. See `GLOSSARY.md` for Browser Pane, Agent Pane and Element Handoff.

## Decisions (2026-11-21, with the user)

- **Started by a command.** "Trex: Pick Element" in the Rex palette, bound to a new key. kb's own Inspect key (`Ctrl+Shift+C` / `Cmd+Shift+C`) stays as it is. The proposed key is `cmd+shift+e`, to be checked against Rex's app shortcuts (ticket 01; an app shortcut wins over `init.lua`).
- **A menu in kb's top bar comes later.** A dropdown next to kb's ✕ needs kb's code, so it is a separate upstream ticket (04), like tickets 05 and 08 in `trex`.
- **One pick, then exit.** A click hands off one element and pick mode ends. Run the command again for another.
- **The Agent Pane is the pane the user was in last.** That means the last focused pane in the Browser Pane's Rex window that isn't a Browser Pane or a DevTools Pane.

## How it works

1. **Start.** The command works from a Browser Pane, or from any other pane with a Browser Pane beside it (resolved the way `bin/trex browser` does it). In the second case the pane the command ran from is the Agent Pane. Running it again while picking cancels.
2. **Pick mode.** trex adds an overlay to the Browser Pane's page through kb's control socket (`kb ctl -i ID eval`, which waits on a promise). The overlay is drawn the way kb's own Inspect is (`src/app.rs`, `HOVER`): margin, border, padding and content boxes plus a label, in a layer that ignores the mouse. Capture-phase listeners on the page take pointer moves, presses and clicks, so the page never sees the click that picks. The wheel still scrolls. Esc cancels. Navigating away ends pick mode.
3. **Describe.** On click, the page builds the description below from the element and returns it. The React part is found from the element at that moment (`__reactFiber$…` on the DOM node), so it works on any open page. The app doesn't have to include react-grab, and no reload is needed.
4. **Hand off.** trex pastes the description into the Agent Pane with a paste event (`block.event`). A program that turned on bracketed paste, such as Claude Code or Codex, gets it as pasted text, so the newlines don't send it. trex also copies the description to the clipboard and moves focus to the Agent Pane. If there is no Agent Pane, the description only goes to the clipboard, and trex says so.

## The description

Plain text, short enough to read at a glance and specific enough for an agent to find the code:

```
<button class="btn primary"> in <SaveBar> at src/components/SaveBar.tsx:42:7
page: http://localhost:3000/settings
path: #root > main > form > div > button:nth-of-type(2)
box: 96×32 at 120,948 (page px)
html: <button class="btn primary" type="submit">Save changes</button>
react: SaveBar ← SettingsForm ← SettingsPage
```

- **First line:** the tag with its id and up to three classes, plus the nearest React component and its source, when known.
- **path:** a selector built like kb's `DESCRIBE`, stopping at the nearest unique id.
- **box:** size and position in page coordinates, as `DESCRIBE` gives them.
- **html:** the opening tag and text content, cut at 300 characters with `…`.
- **react:** up to five component names, innermost first. Leave out the line when the page has no React. When source isn't known, leave out `at …`. A production build gives no source and may give minified names. Hand those names off as they are.

## React source location

React 18 and earlier keep `_debugSource` (file, line, column) on each fiber in development, so that one is read directly. React 19 dropped it and keeps `_debugStack` instead: an Error stack pointing into the bundled JS. To turn that into `file:line`, we fetch the bundle, follow its `sourceMappingURL` and decode the source map. That's what react-grab does through bippy (`bippy/dist/get-source.js`).
- We may vendor bippy's source module (MIT, pinned version), or write the lookup ourselves. Ticket 03 decides.
- Hovering never does this lookup. Only a click does.
- The first lookup in a file downloads and parses its source map, which can take a moment on a big dev bundle. Later lookups reuse the cached map until the page reloads.
- While it runs, the overlay's label says "Finding source…". If it takes more than 2 s, the description is handed off without the source and the label says so. This is because pasted text can't be changed once sent.

## Speed targets

- The hover outline follows the cursor in ≤100 ms, the same target as the DevTools inspector (ticket 06 in `trex`). It goes through the same frame pipeline as kb's Inspect, which measured about 45–50 ms from input to screen.
- Click → text in the Agent Pane: ≤500 ms without a source lookup, and ≤2 s with a first lookup on a Vite or Next.js dev server.

## Testing

The same seam as Phase 1: trex actions driven with `rex do` in a throwaway Rex session, with assertions through existing tools.
- **Pick:** start the action, then `kb ctl -i ID click <selector>` on the test page. The click goes through CDP input like a user's, so the overlay's listeners catch it. Check the page didn't get the click (a counter on the test page stays at 0).
- **Description:** check the clipboard and the Agent Pane's screen (`rex capture`) for the expected lines.
- **Agent Pane:** a stub program in the Agent Pane that turns on bracketed paste and logs what it receives, checking the paste markers are there and nothing was submitted.
- **React:** fixtures in `tests/site/` built with React 18 and React 19 in development, with source maps, checked in so tests need no network or `npm install`. Each checks the component names and `file:line`.
- **Not covered:** the hover speed. The user judges it, as in Phase 1.

## Tickets

- `01` Pick mode, and the description without React (command, key, overlay, Esc, clipboard)
- `02` Hand off to the Agent Pane (focus tracking, paste, focus move), blocked by 01
- `03` React components and source location, blocked by 01
- `04` Upstream: a tools menu in kb's bar that runs Element Handoff, blocked by 01, needs-triage

## Out of scope for now

- Picking several elements in one go.
- Elements inside iframes: the iframe itself is picked.
- Components from frameworks other than React (Vue, Svelte, Solid).
- A screenshot of the element.

## Open questions

- Does Rex let a Lua plugin hear focus changes (`rex.on`), so trex can remember the last focused pane per window? If not, fall back to: the only other pane in the window, else clipboard only.
- Should focus move to the Agent Pane after the handoff? The spec says yes, so the user can type their request at once. Confirm once it's in use.
