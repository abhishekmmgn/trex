# 05: `devtools.side` sets where DevTools opens

**What to build:** the DevTools Pane opens on `devtools.side` (default `"below"`). Moving it is still remembered, but a changed `devtools.side` wins over the remembered side. See `../spec.md`.

**Blocked by:** 01

**Status:** resolved

- [x] With nothing remembered, DevTools opens on `devtools.side`
- [x] After the user moves it, the next one opens on the moved-to side (as today)
- [x] The remembered side is stored with the `devtools.side` it was remembered under. When the configured value differs from that, the configured value is used and the memory is dropped
- [x] Tests: each side, moved side remembered, config change resets it

## Comments

### 2026-11-21: built (branch `trex/settings-05-devtools-side`)

- **Opening:** `devtools.toggle` reads `config.get("devtools.side")` (init.lua passes `config` to devtools.new, its only change there). With nothing valid remembered it opens on that side.
- **Memory format:** `state.json` key `devtools_side` is now `{ "side": ..., "configured": ... }`. On open, `remembered_side(state, configured)` returns the side only if `configured` equals the current setting; otherwise it deletes the key and the configured side is used. An old-format value (a bare string from before) counts as a mismatch and is dropped, so an upgrade just falls back to the setting once.
- **Decision: the watcher gets the configured side from its `TREX_WATCH` JSON (`configured`), not by re-reading config.** devtools.lua already builds that JSON at open time, so the watcher needs no config path or config.lua, and the memory is tagged with the value the pane opened under. Consequence: if the config is edited and reloaded while a DevTools Pane is open, a later move is remembered under the old value and then dropped on the next open, so the new setting wins (the intended outcome).
- **Tests** (`tests/test_devtools.sh`): default below, each configured side, moved side remembered under a configured side, a changed setting wins and the memory is dropped (and a new move is remembered under the new value), old-format memory gives way. The existing remember-side tests still pass unchanged.
