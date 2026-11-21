# 08: Upstream: `kb ctl` and `kb mcp` reach the kb beside the caller, not the lowest-numbered one

**What to build:** A pull request to `graiz/kittybrowser` so that an agent's `kb ctl` (no `-i`) and `kb mcp serve` reach the kb in the agent's own Rex window when there is one, instead of the lowest-numbered kb running anywhere. Today the default is the lowest-numbered kb (`control::connect`), which on a machine with the user's own kb open elsewhere is that kb, and `kb mcp` has no per-call way to choose (its tools take no instance argument; only `KB_INSTANCE`/`KB_SOCKET` fixed in the server's environment).

trex works around this in ticket 04 with `bin/trex ctl` / `bin/trex mcp`, which resolve the Browser Pane from `REX_SESSION`/`REX_BLOCK` and `kb list` and pass `-i`/`KB_INSTANCE`. Doing it in kb would make plain `kb ctl`, kb's skill and its MCP server safe for every Rex user, not only trex's.

Possible shapes (for the upstream discussion, pick one):
- In `control::connect`, with no `KB_SOCKET`/`-i`/`KB_INSTANCE` and `REX_SESSION` set, prefer the running kb whose `pane` is a block of the caller's Rex window (then session); if there are several, fail with the list rather than guess.
- An optional `instance` argument on every MCP tool (`commands.rs` table), so an MCP client can choose per call.

**Blocked by:** none (upstream conventions in kb's `AGENTS.md` / `.github/CONTRIBUTING.md`)

**Status:** ready-for-agent

- [ ] An upstream PR (or issue, if the maintainer prefers to discuss first) proposes one of the shapes above
- [ ] Once merged and the pin moves, `bin/trex ctl`/`mcp` either go away or become thin aliases

## Comments

- 2026-11-21: the user chose to send this as a second upstream PR, separate from 05. Shape: the first one (`control::connect` prefers the kb in the caller's Rex window), which also covers `kb mcp serve` started from the Agent Pane.
