# 03: The description names the React component and its source

**What to build:** When the picked element belongs to a React app, the description adds the nearest component and its `file:line:column` to the first line, and a `react:` line with up to five component names, innermost first. Everything is read from the element at pick time (`__reactFiber$…`), so the app needs no setup and the page needs no reload. See `../spec.md`, "The description" and "React source location".

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] Component names come from the fiber chain above the element: function, class, `memo` and `forwardRef` components, not host elements or React internals
- [ ] React 18 and earlier (development): source from `_debugSource`
- [ ] React 19 (development): source from `_debugStack`, resolved through the bundle's source map. Decide between vendoring bippy's source module (MIT, pinned version) and writing it ourselves, and record why
- [ ] Hovering never resolves source; only a click does. Source maps are cached until the page reloads
- [ ] While the lookup runs, the overlay's label says "Finding source…". After 2 s the description is handed off without the source, and the label says so
- [ ] Production builds and pages without React: the `react:` line and `at …` are left out, or the names are given as they are, and nothing throws
- [ ] Fixtures in `tests/site/`, built with React 18 and React 19 in development with source maps and checked in (no network, no `npm install` in tests). Tests check the names and `file:line` for each
- [ ] Checked by hand on a real Vite or Next.js dev app: click to text takes ≤2 s on a first lookup and ≤500 ms after that

## Comments
