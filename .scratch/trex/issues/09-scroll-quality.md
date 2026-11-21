# 09: Scrolling in a Browser Pane is not smooth and the page shifts sideways

**What to build:** Find out why scrolling in a Browser Pane feels slow and not smooth, and why the page sometimes shifts sideways, then fix what can be fixed. The aim is not a real browser's smoothness. The aim is a steady scroll with no sideways jumps.

The user reported this on 2026-11-21, on https://transitions.dev, in a Browser Pane opened with trex (the pinned kb, so without ticket 05's fix):
- A normal vertical scroll feels slow and not smooth.
- Scrolling diagonally (left to down) shifts the layout sideways, horizontally or diagonally, on the right side.
- When a vertical scroll reaches the top or bottom of the page, the layout sometimes shifts.
- Page transitions and animations play properly, and keyboard shortcuts work.

Things already known (see ticket 05 and ticket 06's Comments):
- The terminal sends one wheel report per cell of trackpad travel: vertical per cell height, horizontal per cell width. The pinned kb scrolls a fixed 60 CSS px per report, on both axes.
- Ticket 05's branch `trackpad-scroll-delta` scrolls one pane row or column per report and merges bursts of reports. It is not in the pinned kb that trex runs.
- kb's default frame mode, "png, changed tiles by file", measured 27 fps scrolling at Retina half-width.

**Blocked by:** None

**Status:** ready-for-agent

- [ ] The cause of the sideways shift is found and shown with evidence: the wheel reports the terminal sends during a vertical or diagonal trackpad swipe, and what kb sends to Chrome for them
- [ ] The cause of the slow, unsmooth scrolling is measured: input rate, kb's merging of reports, Chrome's frame time and the frame pipeline, with the bottleneck named
- [ ] Fixes needing kb's code go on a KittyBrowser branch and follow its conventions; nothing is pushed until the user agrees
- [ ] The user confirms on transitions.dev that the sideways shift is gone and scrolling feels better
