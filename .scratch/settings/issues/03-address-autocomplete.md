# 03: Open Browser suggests from kb's history, and `default_url`

**What to build:** Trex: Open Browser… asks with `rex.ui.pick` instead of `rex.ui.input`: the default URL first, then kb's history, filtered as the user types, with free text allowed. See `../spec.md`. The `default_url` setting replaces `DEFAULT_URL` in `lua/trex/init.lua`.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] The rows are `default_url`, then up to 50 URLs from `~/.kittybrowser/history` (`count<TAB>last-visit-epoch<TAB>url` lines), ranked by count weighted by recency. The default isn't repeated. Unreadable lines and a missing file are skipped
- [ ] Row title is the URL without scheme or trailing slash. Subtitle is the full URL
- [ ] A picked row opens its URL. Free text goes through `url.normalise` as today (bare port → localhost, a leading `-` refused). An empty answer opens `default_url`
- [ ] `rex.ui.pick` is called only from the server action. Its `unsupported`/`failed` reasons fall back to `rex.ui.input`, and `busy` says Rex is already asking something
- [ ] The test prompt stub (`TREX_PROMPT`) covers `rex.ui.pick`, and the history path is settable in tests
- [ ] Tests: ranking order from a fixture history, the default row first, free text and port, `default_url` from config
Ranking in the prototype the user tried on 2026-11-21: score = count × 4 when visited in the last 4 h, × 2 in the last 24 h, × 1 in the last 7 days, × 0.5 when older.

## Comments
