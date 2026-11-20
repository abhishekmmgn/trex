# 04: Agents drive the Browser Pane, not the DevTools Pane

**What to build:** With a Browser Pane and its DevTools Pane open, a coding agent in the Agent Pane runs KittyBrowser's agent commands (`kb ctl`, its MCP server, its skill), and they reach the Browser Pane, not the KittyBrowser that is showing DevTools. Prefer a fix inside trex, or documented setup; anything that needs KittyBrowser's code becomes its own upstream ticket.

**Blocked by:** 02

**Status:** ready-for-agent

- [x] `kb ctl check` from the Agent Pane reports on the Browser Pane's page while a DevTools Pane is open
- [x] The behaviour holds with more than one Browser Pane open, or how to target one is documented
- [x] A test opens both panes and confirms which page `kb ctl status` reports

## Comments

**2026-11-21, implementer (branch `trex/04-agent-drives-browser-pane`):**

Plain `kb ctl` (no `-i`) and `kb mcp serve` reach the lowest-numbered kb anywhere, which on this machine is the user's own kb in another session.
The DevTools Pane's kb was already out of reach (ticket 02: own `KB_SOCKET`, not in `kb list`); the remaining problem was every *other* kb. Fixed
in trex, documented in README "Agents":
- `bin/trex browser` prints the kb id of the Browser Pane beside the calling pane; `bin/trex ctl CMD …` runs `kb ctl -i <that id> CMD …`;
  `bin/trex ctl -i ID CMD` passes a choice through. "Beside" = the kb in `kb list` whose pane is in the caller's Rex window (`REX_BLOCK`), else the
  only one in its session (`REX_SESSION`). None, or two in the window: it says why, lists the ids, exits 1, and never falls back. Resolved on every
  call, so Browser Panes opened later or reopened are found. It unsets `KB_SOCKET`/`KB_INSTANCE`, which would otherwise override `-i`.
- `bin/trex mcp`: kb's MCP server with per-call targeting (one `kb mcp serve` per JSON-RPC line; `tools/call` lines get `KB_INSTANCE` from the same
  resolution, or an `isError` result saying why). Register with `claude mcp add kb -- <repo>/bin/trex mcp` after `kb mcp on`.
- `kb skill install`: README gives a CLAUDE.md/AGENTS.md snippet telling the agent to use `trex ctl` and not open its own kb pane.
- Tests `tests/test_agent.sh` run `bin/trex` in a real Rex pane (`rex run --split=below --wait`, so REX_* come from Rex): Browser + DevTools Pane
  open → `trex ctl status` reports the Browser Pane's url, pane and id, `trex ctl check` passes on its page, `trex browser` prints its id; two
  Browser Panes in one window → refused with both ids, `-i` reaches the named one; two windows → each reaches its own; a Browser Pane only in
  another session (standing in for the user's kb) → refused, nothing reached.

Not verified: `trex mcp` against a live kb. kb's tools answer only when the global switch `~/.kittybrowser/mcp-enabled` is on (it's off and is the
user's setting), so only the paths that don't reach a kb were run by hand (initialize passes through; `tools/call` outside Rex gives the error).
Box 1 is ticked for `trex ctl check`; plain `kb ctl check` from an Agent Pane still reaches the lowest-numbered kb. Making kb itself pick the
caller's pane is ticket 08 (upstream, needs-triage).
