# 04: Agents drive the Browser Pane, not the DevTools Pane

**What to build:** With a Browser Pane and its DevTools Pane open, a coding agent in the Agent Pane runs KittyBrowser's agent commands (`kb ctl`, its MCP server, its skill), and they reach the Browser Pane, not the KittyBrowser that is showing DevTools. Prefer a fix inside trex, or documented setup; anything that needs KittyBrowser's code becomes its own upstream ticket.

**Blocked by:** 02

**Status:** ready-for-agent

- [ ] `kb ctl check` from the Agent Pane reports on the Browser Pane's page while a DevTools Pane is open
- [ ] The behaviour holds with more than one Browser Pane open, or how to target one is documented
- [ ] A test opens both panes and confirms which page `kb ctl status` reports
