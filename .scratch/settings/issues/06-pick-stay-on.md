# 06: `pick.stay_on` chooses whether pick mode ends after a pick

**What to build:** with `pick.stay_on: false`, Element Handoff ends pick mode after one pick (the overlay and listeners go). `true` is today's behaviour, where the user keeps picking. See `../spec.md` and `.scratch/element-handoff/spec.md`.

**Blocked by:** 01

**Status:** resolved

- [x] `false`: after the hand-off the page has no overlay or listeners, and the next click reaches the page
- [x] `true`: unchanged, and several picks in a row each paste
- [x] Focus stays in the Browser Pane in both cases
- [x] Tests for both values in `tests/test_pick.sh`

## Comments

### 2026-11-21: built (branch `trex/settings-06-pick-stay-on`)

- **The spec's "today's behaviour" was wrong.** Before this ticket every pick ended pick mode (`finish` on the press; `.scratch/element-handoff/spec.md` says "One pick, then exit"), and re-running the command was how you picked again. I built `true` as the spec describes it (pick mode stays on, several picks in a row each paste) and `false` as the old behaviour. So the default (`true`) changes behaviour: the user should confirm that is what they want. Esc, or the command again, still ends pick mode.
- **Mechanism:** `pick.lua` reads `config.get("pick.stay_on")` (init.lua passes `stay_on = function…`, one line) each time pick mode starts, wraps `pick.js` as `(stayOn => …)(true|false)`, and passes it to `pick-wait.sh` as the 9th argument. With `stayOn` the page queues each pick for `wait()` and keeps the overlay; the waiter hands off each pick and loops until the page says `cancelled` or goes away. A press that already picked (pointerdown then mousedown) counts once.
- **Unchanged:** focus stays in the Browser Pane either way; with `false` the 1 s swallowing of the picking click's leftovers still applies.
- **Tests:** `pick_setup` now writes `pick.stay_on: false` so the older tests keep their one-pick meaning. Two new ones: `false` (overlay gone, the next click reaches the page) and `true` (two picks both copied and pasted, overlay on, focus in the Browser Pane, page heard nothing, Esc ends). The `true` test presses from the page, not `kb ctl click`: when the page doesn't hear a click, kb repeats it with a script, which would pick again while pick mode is on.
