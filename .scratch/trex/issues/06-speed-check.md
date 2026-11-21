# 06: Speed check against the Phase 1 targets

**What to build:** Confirm the Browser Pane with its DevTools Pane is fast enough for daily frontend work, judged by the user. Measure it on a Retina half-width Rex pane with DevTools open.

**Blocked by:** 02

**Status:** resolved

- [x] Inspector hover highlight follows the cursor in ≤100 ms
- [x] Switching DevTools tabs (Elements → Console → Network) takes ≤300 ms
- [x] Page scrolling runs at ≥30 fps, with `kb bench` numbers recorded
- [x] Typing in the page appears in <50 ms
- [x] Any miss is measured to its cause before anything changes; moving DevTools to a native window is a last resort and needs the user's agreement

## Comments

- 2026-11-21: the user tried it in the Rex app (real `cmd+shift+b`, `fn+F12`): inspector hover highlight works, and hover, tab switching, scrolling and typing all feel fast enough for daily work.
- `kb bench` on https://en.wikipedia.org/wiki/Terminal_emulator, Retina half-width pane (62x41 cells, 1178x1640 px). Scrolling: 20–33 fps depending on frame mode; only "png, pixels by file" (33) and "jpeg 90, pixels by file" (31) reach 30 fps. Typing: 19–36 ms median in every mode, all under 50 ms. Scroll fps box left open until kb's default frame mode is known.

Scroll:

```
pane 62x41 cells, frames 1178x1640 pixels, 30 scroll steps each, times in ms (median)

frames sent as                      chrome  prepare  terminal   total    fps  frame KB  wire KB
png through the pty                   25.6      0.0      23.5    49.3     20       456      609
png, moved layers through the pty     25.3      7.0       1.1    35.2     28       456      123
png, pixels by file                   22.0      3.6       5.2    30.5     33       456        0
png, changed tiles by file            27.3      4.0       5.5    37.0     27       456        0
jpeg 100, pixels by file              23.4      7.9       6.0    37.3     27       658        0
jpeg 90, pixels by file               19.8      6.4       6.1    32.4     31       366        0

```

Type:

```
pane 62x41 cells, frames 1178x1640 pixels, 30 typing steps each, times in ms (median)

frames sent as                      chrome  prepare  terminal   total    fps  frame KB  wire KB
png through the pty                   16.2      0.0      19.9    36.2     28       322      430
png, moved layers through the pty     16.2      2.6       0.1    18.9     53       332        1
png, pixels by file                   16.3      2.6       4.9    24.1     41       341        0
png, changed tiles by file            21.7      2.9       0.5    25.0     40       343        0
jpeg 100, pixels by file              15.5      5.8       5.8    28.6     35       502        0
jpeg 90, pixels by file               16.7      5.3       6.4    28.7     35       285        0

```
- 2026-11-21 shadcn test (Haiku agent, throwaway session; full results in the orchestrator scratchpad `notes/shadcn-test.md`): clicks on Dialog, Dropdown, Tabs, Accordion take 300–370 ms through `kb ctl`; Ctrl+K, `/`, typing, arrows, Enter, Escape, Tab, Space all reach the page through `rex send-key`; `cmd+k` did not (Rex binds it). Key-to-page typing about 57–59 ms including about 20 ms of `kb ctl eval` overhead.
- kb's default frame mode is "png, changed tiles by file". At Retina half-width on Wikipedia it measured **27 fps** scrolling (37 ms per frame), just under the 30 fps target; it reached 78 fps only in a small 80x24 pane. The user finds scrolling fine in practice. Per this ticket, measure the miss to its cause before changing anything.
- 2026-11-21: the user accepted the 27 fps default-mode scroll as fine for now and closed this ticket. Nothing was changed; DevTools stays in Rex.
