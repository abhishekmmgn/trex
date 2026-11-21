# trex

A Chromium browser that lives inside Rex panes, built for frontend development beside a coding agent. Rex is the only terminal it targets.

## Language

### Rex

**Session**:
A named group of Tabs in Rex, listed as a heading in the sidebar.
_Avoid_: workspace, project

**Tab**:
One entry under a Session in Rex's sidebar, holding one or more Panes. A Tab can be moved out into its own app window and is still a Tab.
_Avoid_: window (what the `rex` CLI and API call it), browser tab

**Pane**:
One rectangle inside a Tab, with its own header and name, running one program.
_Avoid_: block (what the `rex` CLI and API call it), split

### trex

**Browser Pane**:
A Rex pane showing a live web page that the user can scroll, click and type into.
_Avoid_: browser window, browser tab, webview

**DevTools Pane**:
A Rex pane showing Chrome DevTools for the page in a Browser Pane, sitting beside it rather than drawn inside it.
_Avoid_: docked DevTools, inspector window

**Agent Pane**:
The Rex pane where a coding agent (Claude Code, Codex) runs next to a Browser Pane.
_Avoid_: chat pane, terminal

**Element Handoff**:
Picking an element in a Browser Pane and sending a description of it (DOM path, position, HTML, and React component with source location when available) to the Agent Pane as unsent text.
_Avoid_: grab, select tool, inspect (inspect means the DevTools inspector)

**Base Browser**:
The existing open-source terminal browser that trex runs as shipped and drives from outside, rather than forking it. For now trex pins a commit on the user's fork that adds fixes not yet upstream (ADR-0002).
_Avoid_: upstream, engine, fork
