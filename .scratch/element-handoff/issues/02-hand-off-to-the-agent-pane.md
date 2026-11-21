# 02: The description is pasted into the Agent Pane as unsent text

**What to build:** After a pick, trex pastes the description into the Agent Pane and moves focus there, so the user can type their request after it and send. The Agent Pane is the last focused pane in the Browser Pane's Rex window that isn't a Browser Pane or a DevTools Pane. When the command runs from another pane, that pane is the Agent Pane. See `../spec.md`, "Hand off" and "Open questions".

**Blocked by:** 01

**Status:** resolved

- [x] Find out whether a Rex Lua plugin can hear focus changes (`rex.on` or server events). If it can, trex remembers the last focused pane per window. If not, use the fallback (the only other pane in the window, else clipboard only) and record what was found. **Changed with the user: the Agent Pane is found by what runs in it (Claude Code, Codex, Cursor), see Comments**
- [x] The description reaches the Agent Pane as a paste (`block.event`), so a program with bracketed paste on gets the paste markers and nothing is submitted
- [x] Checked by hand in Claude Code: the multi-line description shows up in the prompt unsent
- [x] ~~Focus moves to the Agent Pane after the paste~~ Focus stays in the Browser Pane (the user's decision, see Comments)
- [x] With no Agent Pane, the description goes to the clipboard only, and trex says so without taking focus (like F12's error notice)
- [x] The clipboard copy from ticket 01 still happens in every case
- [x] `rex do` tests: a stub program in the Agent Pane turns on bracketed paste and logs its input (paste markers present, no Enter after them); focus ends on it; with only a Browser Pane in the window, clipboard only

## Comments

- 2026-11-21, implementer (branch `trex/eh-02-hand-off`):
  - The user asked for this to reach Claude Code, Codex or Cursor in the last pane they used, and only those three. Rex gives config Lua no
    focus events (`init.lua`: no `rex.on`), and `rex events` only says the view changed. So the Agent Pane is found by what runs in it:
    the last part of the foreground process's `argv0` is `claude`, `codex`, `cursor-agent`, or `agent` started from a `cursor-agent` path.
    Seen on this machine: Claude Code's process name is its version (`2.1.330`) and Cursor's is `node`, so argv0 is what tells them apart.
    Order: the pane the command ran from; else the one in the Browser Pane's window; else in the session; of several, the one that is its
    window's focused pane (`rex.session.view`); else none, and the note on the page names them.
  - `pick.lua` resolves it when pick mode starts and hands it to `pick-wait.sh`. After the pick, the waiter checks an agent still runs
    there, pastes with `rex api call block.event` (the page returns the description as a JSON string too, so the shell needs no jq or
    python), then `rex focus`. The note says "Sent to Claude Code and copied", or "Copied to the clipboard (why not)".
  - Checked by hand with the real agents in a throwaway session: Claude Code 2.1.330, Codex 0.170.0 and Cursor's CLI 2026.11.19 all turn
    on bracketed paste. A paste of a 7-line description sat unsent in each input (Claude Code shows `[Pasted text #1 +7 lines]`).
  - Tests use a stand-in agent, `tests/stub_agent.sh` (`exec -a claude`, bash builtins only so Rex sees it as `claude`; python3 re-execs and
    loses the name), which turns on bracketed paste and logs its input: one exact paste with no Enter after it, focus moved; run from one of
    two agents goes there; two agents from the Browser Pane only copies; an agent in another window is reached; a shell is never typed
    into; an agent that quit before the click isn't pasted into. Full suite 69/69.
- 2026-11-21: the user decided focus stays in the Browser Pane after a pick, because they may want to pick more elements. The waiter no
  longer runs `rex focus`; each pick's paste adds to what waits unsent in the agent's input. The test now checks focus stays on the Browser Pane.
