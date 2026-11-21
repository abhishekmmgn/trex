# 05: `devtools.side` sets where DevTools opens

**What to build:** the DevTools Pane opens on `devtools.side` (default `"below"`). Moving it is still remembered, but a changed `devtools.side` wins over the remembered side. See `../spec.md`.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] With nothing remembered, DevTools opens on `devtools.side`
- [ ] After the user moves it, the next one opens on the moved-to side (as today)
- [ ] The remembered side is stored with the `devtools.side` it was remembered under. When the configured value differs from that, the configured value is used and the memory is dropped
- [ ] Tests: each side, moved side remembered, config change resets it

## Comments
