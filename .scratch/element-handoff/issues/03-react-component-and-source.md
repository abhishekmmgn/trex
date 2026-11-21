# 03: The description names the React component and its source

**What to build:** When the picked element belongs to a React app, the description adds the nearest component and its `file:line:column` to the first line, and a `react:` line with up to five component names, innermost first. Everything is read from the element at pick time (`__reactFiber$…`), so the app needs no setup and the page needs no reload. See `../spec.md`, "The description" and "React source location".

**Blocked by:** 01

**Status:** resolved

- [x] Component names come from the fiber chain above the element: function, class, `memo` and `forwardRef` components, not host elements or React internals
- [x] React 18 and earlier (development): source from `_debugSource`
- [x] React 19 (development): source from `_debugStack`, resolved through the bundle's source map. Decide between vendoring bippy's source module (MIT, pinned version) and writing it ourselves, and record why
- [x] Hovering never resolves source; only a click does. Source maps are cached until the page reloads
- [x] While the lookup runs, the overlay's label says "Finding source…". After 2 s the description is handed off without the source, and the label says so
- [x] Production builds and pages without React: the `react:` line and `at …` are left out, or the names are given as they are, and nothing throws
- [x] Fixtures in `tests/site/`, built with React 18 and React 19 in development with source maps and checked in (no network, no `npm install` in tests). Tests check the names and `file:line` for each
- [x] Checked by hand on a real Vite or Next.js dev app: click to text takes ≤2 s on a first lookup and ≤500 ms after that

## Comments

- 2026-11-21, implementer (branch `trex/eh-03-react-source`):
  - All in `lua/trex/pick.js` ("React" section). The fiber is `__reactFiber$…` on the element or its nearest ancestor. Names follow owners
    (`_debugOwner`, who rendered whom; Server Component owners are `{ name, env: "Server", owner }`), else the fiber ancestry (production).
    Function, class, forwardRef and memo components count; memo(X) is named once.
  - Source: React 18 `_debugSource`; React 19 `_debugStack`, its first frame that isn't React's (`jsxDEV`, `react-stack-`, `fakeJSXCallSite`,
    `node_modules`, `.vite/deps`), through the script's source map (VLQ decode and index maps written here, not bippy: no new dependency).
    `rsc://React/Server/<file>` frames are unwrapped, and a URL the page can't fetch gets its map from Next's `/__nextjs_source-map`. A mapping
    into `node_modules` moves on to the next frame. Maps are fetched per pick, because hot reload keeps URLs.
  - Fixtures: `tests/site/react/{18,19}` built by `tests/site/react/build.sh` (esbuild 0.25.0, React 18.3.1 and 19.1.0, development, maps
    without sources content: about 1 MB each). Tests: `test_pick_react_18_names_components_and_source`,
    `test_pick_react_19_maps_the_stack_to_the_source` (#save, memo, forwardRef), `test_pick_react_source_gives_up_after_2_s` (fetch never
    answers: copied after about 2 s without the source, and the note says so). Full suite 63/63.
  - Checked by hand, real dev servers in throwaway sessions (times from the start of `kb ctl click`, which alone takes about 0.37 s):
    - Vite 6 + React 19: `<button> in <App> at src/App.jsx:21:9`, `h1` 19:7, `img` 16:11, all matching the file; 0.66–0.77 s.
    - Next.js 15.3 App Router, Turbopack and webpack: `<li> in <Home> at …/app/page.js:20:11`, `code` 18:36; a client component
      `<button id="counter"> in <Counter> at app/ui/Counter.js:7:5`, `react: Counter ← Home`; 0.69–0.9 s. After adding a line by hot reload
      the same pick gave line 21 (it gave the stale 18 before maps were fetched per pick).
  - Also found and fixed: a pick started within a second of the last one lost its click to the last one's leftover listeners (`#root` on
    Vite). A new pick now releases them; `test_pick_right_after_a_pick_gets_its_click` fails without that.
