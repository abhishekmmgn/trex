# Element Handoff

Status: needs-triage

## Goal

The user points at something in a Browser Pane and tells the coding agent "change this". They run one command, hover the page, and click an element. A description of that element appears in the Agent Pane as unsent text and is also on the clipboard, so they can type their request after it and send. This is Phase 2 of `.scratch/trex/spec.md`. See `GLOSSARY.md` for Browser Pane, Agent Pane and Element Handoff.

## Decisions (2026-11-21, with the user)

- **Started by a command.** "Trex: Pick Element" in the Rex palette, bound to a new key. kb's own Inspect key (`Ctrl+Shift+C` / `Cmd+Shift+C`) stays as it is. The proposed key is `cmd+shift+e`, to be checked against Rex's app shortcuts (ticket 01; an app shortcut wins over `init.lua`).
- **A menu in kb's top bar comes later.** A dropdown next to kb's ✕ needs kb's code, so it is a separate upstream ticket (04), like tickets 05 and 08 in `trex`.
- **One pick, then exit.** A click hands off one element and pick mode ends. Run the command again for another.
- **The Agent Pane is the pane running Claude Code, Codex or Cursor's CLI** (changed 2026-11-21: the user uses only these three, and Rex gives config Lua no focus events, so "the pane the user was in last" can't be tracked). It is the pane the command ran from, if an agent runs there; else the one agent pane in the Browser Pane's Rex window, else in its session (another tab); of several, the one last focused in its window. With none, or several that can't be told apart, the description is only copied, and the note says why.

## How it works

1. **Start.** The command works from a Browser Pane, or from any other pane with a Browser Pane beside it (resolved the way `bin/trex browser` does it). In the second case the pane the command ran from is the Agent Pane. Running it again while picking cancels.
2. **Pick mode.** trex adds an overlay to the Browser Pane's page through kb's control socket (`kb ctl -i ID eval`, which waits on a promise). The overlay is drawn the way kb's own Inspect is (`src/app.rs`, `HOVER`): margin, border, padding and content boxes plus a label, in a layer that ignores the mouse. Capture-phase listeners on the page take pointer moves, presses and clicks, so the page never sees the click that picks. The wheel still scrolls. Esc cancels. Navigating away ends pick mode.
3. **Describe.** On click, the page builds the description below from the element and returns it. The React part is found from the element at that moment (`__reactFiber$…` on the DOM node), so it works on any open page. The app doesn't have to include react-grab, and no reload is needed.
4. **Hand off.** trex pastes the description into the Agent Pane with a paste event (`block.event`). Claude Code, Codex and Cursor's CLI all turn on bracketed paste, so they get it as pasted text and the newlines don't send it (Claude Code shows it as `[Pasted text #1 +7 lines]`). Just before pasting, trex checks an agent still runs there, so it never types into a shell. It also copies the description to the clipboard and moves focus to the Agent Pane (switching tabs if needed). If there is no Agent Pane, the description only goes to the clipboard, and the note on the page says why.

## The description

Plain text, short enough to read at a glance and specific enough for an agent to find the code:

```
<button class="btn primary"> in <SaveBar> at src/components/SaveBar.tsx:42:7
page: http://localhost:3000/settings
path: #root > main > form > div > button:nth-of-type(2)
box: 96×32 at 120,948 (page px)
text: Save changes
html: <button class="btn primary" type="submit">Save changes</button>
react: SaveBar ← SettingsForm ← SettingsPage
```

- **First line:** the tag with its id and up to three classes, plus the nearest React component and its source, when known.
- **in:** up to three web components (custom elements, named with a `-`) around the element, nearest first, across shadow roots: on a site built from them, such as YouTube, they are its components. Left out when there are none.
- **path:** a selector built like kb's `DESCRIBE`, stopping at the nearest unique id. Kept whole even when long, so it still works as a selector.
- **box:** size and position in page coordinates, as `DESCRIBE` gives them.
- **text:** the element's visible text, cut at 80 characters with `…`. Left out when there is none.
- **html:** the opening tag and text content, cut at 300 characters with `…`. In the tag, only the first three classes are kept (then ` …`) and every other attribute value is cut at 60 characters, so long Tailwind class lists, `src` and `href` don't push out the text (seen on YouTube and vercel.com).
- **react:** up to five component names, innermost first. Leave out the line when the page has no React. When source isn't known, leave out `at …`. A production build gives no source and may give minified names. Hand those names off as they are.

## React source location

React 18 and earlier keep `_debugSource` (file, line, column) on each fiber in development, so that one is read directly. React 19 dropped it and keeps `_debugStack` instead: an Error stack pointing into the bundled JS. To turn that into `file:line`, we fetch the bundle, follow its `sourceMappingURL` and decode the source map. That's what react-grab does through bippy (`bippy/dist/get-source.js`).
- Built ourselves rather than vendoring bippy (ticket 03): about 100 lines (stack frame, fetch, `sourceMappingURL`, VLQ decode, index maps), with no new dependency to pin.
- Hovering never does this lookup. Only a click does.
- Maps are fetched again for each pick: hot reload changes code under the same URL (Next.js keeps `webpack-internal:///…/page.js`), so a map kept longer gives stale lines. On a local dev server the fetch costs little.
- While it runs, the overlay's label says "Finding source…". If it takes more than 2 s, the description is handed off without the source and the note on the page says so. This is because pasted text can't be changed once sent.
- **Next.js App Router:** pages are Server Components, so the DOM comes from the server and the client fibers above it are Next's routers. React 19 keeps the server side in development: the element's `_debugOwner` is `{ name, env: "Server", owner }`, and its `_debugStack` has a frame `rsc://React/Server/<file>?<n>:line:col`. Names follow owners (who rendered whom), and a frame the page can't fetch (`webpack-internal:`, a server chunk's `file:` URL) gets its map from Next's dev endpoint `/__nextjs_source-map?filename=…`, the one React's own dev tools use.

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

- Should focus move to the Agent Pane after the handoff? The spec says yes, so the user can type their request at once. Confirm once it's in use.
