# 03: Open Browser suggests from kb's history, and `default_url`

**What to build:** Trex: Open Browser… asks with `rex.ui.pick` instead of `rex.ui.input`: the default URL first, then kb's history, filtered as the user types, with free text allowed. See `../spec.md`. The `default_url` setting replaces `DEFAULT_URL` in `lua/trex/init.lua`.

**Blocked by:** 01

**Status:** resolved

- [x] The rows are `default_url`, then up to 50 URLs from `~/.kittybrowser/history` (`count<TAB>last-visit-epoch<TAB>url` lines), ranked by count weighted by recency. The default isn't repeated. Unreadable lines and a missing file are skipped
- [x] Row title is the URL without scheme or trailing slash. Subtitle is the full URL
- [x] A picked row opens its URL. Free text goes through `url.normalise` as today (bare port → localhost, a leading `-` refused). An empty answer opens `default_url`
- [x] `rex.ui.pick` is called only from the server action. Its `unsupported`/`failed` reasons fall back to `rex.ui.input`, and `busy` says Rex is already asking something
- [x] The test prompt stub (`TREX_PROMPT`) covers `rex.ui.pick`, and the history path is settable in tests
- [x] Tests: ranking order from a fixture history, the default row first, free text and port, `default_url` from config
Ranking in the prototype the user tried on 2026-11-21: score = count × 4 when visited in the last 4 h, × 2 in the last 24 h, × 1 in the last 7 days, × 0.5 when older.

## Comments

### 2026-11-21: built (branch `trex/settings-03-autocomplete`)

- **Module:** `lua/trex/history.lua` (new) builds the rows; `init.lua` asks with `rex.ui.pick{ title, placeholder, items, allow_other = true }` through `ask_address`. `DEFAULT_URL` is gone: everything reads `config.get("default_url")`, so an empty answer and an empty `url` argument open it too. `setup{ kb_history = … }` overrides `~/.kittybrowser/history`.
- **Ranking:** score = count x 4 (last visit within 4 h), x 2 (24 h), x 1 (7 days), x 0.5 (older). Ties: later visit, then URL. A URL listed twice counts once at its best score. Lines that aren't `count<TAB>epoch<TAB>url`, a count of 0, and URLs starting with `-` are skipped (a picked row goes through `url.normalise`, so a `-` row would only error). The default is not repeated: URLs are compared without scheme and trailing slash, so a history `http://localhost:3000/` is the default's row, not a second one. (Side effect: `https://x` and `http://x` count as the same row; the better-scoring one stays.)
- **Rows:** title is the URL without scheme and trailing slash, subtitle the full URL (the default row's subtitle is "default"), icon `globe` (in Rex's documented icon list: document, folder, branch, terminal, code, server, database, package, globe, link, person, tag, clock, star, gear, plus). Row id is the URL.
- **Answers:** a row id is a string; typed text is `{ text = … }` (as in leaf), both run through `url.normalise(_, default_url)`. `unsupported` and `failed` fall back to `rex.ui.input` (same title and placeholder as before); `busy` raises "trex: Rex is already asking something else. Answer or close that, then try again."; any other reason (cancelled, timeout) returns nil. leaf's `can_ask` idea: if `rex.ui.pick` isn't a function (older Rex) it also falls back to the plain prompt.
- **Test stub:** `tests/load.lua` now also replaces `rex.ui.pick`, writing its spec (items included) to `$TREX_PROMPT.pick` (the input still writes `$TREX_PROMPT`). `TREX_PROMPT_PICK` = `id` (default), `text`, or a reason to return with no answer. `TREX_KB_HISTORY` is wired like `TREX_CONFIG`; `tests/lib.sh` gives each test its own path (not created), so no test reads the user's history.
- **Tests:** new `tests/test_open_prompt.sh` (10): palette spec and empty answer, ranking from a fixture (with a duplicate-of-default and junk lines), the 50 cap, missing file, picking a row, typed port and URL, typed flag refused, `default_url` from config (first row, empty answer, blank text, empty `url`), fallback on unsupported and failed, busy and cancelled. The old "prompt starts empty" test in `test_open_browser.sh` moved there.
- **Not testable here:** the real palette (`rex.ui.pick` only works in server init.lua actions, and tests never prompt the user's app), so the real round trip is untested.
