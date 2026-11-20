# trex

A Chromium browser that lives inside Rex panes, built for frontend development beside a coding agent. Rex is the only terminal it targets.

## Language

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
The existing open-source terminal browser that trex runs as shipped and drives from outside, rather than forking it.
_Avoid_: upstream, engine, fork
