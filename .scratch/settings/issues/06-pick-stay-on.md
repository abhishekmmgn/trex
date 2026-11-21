# 06: `pick.stay_on` chooses whether pick mode ends after a pick

**What to build:** with `pick.stay_on: false`, Element Handoff ends pick mode after one pick (the overlay and listeners go). `true` is today's behaviour, where the user keeps picking. See `../spec.md` and `.scratch/element-handoff/spec.md`.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] `false`: after the hand-off the page has no overlay or listeners, and the next click reaches the page
- [ ] `true`: unchanged, and several picks in a row each paste
- [ ] Focus stays in the Browser Pane in both cases
- [ ] Tests for both values in `tests/test_pick.sh`

## Comments
