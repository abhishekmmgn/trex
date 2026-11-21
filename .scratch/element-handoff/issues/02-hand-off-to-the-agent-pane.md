# 02: The description is pasted into the Agent Pane as unsent text

**What to build:** After a pick, trex pastes the description into the Agent Pane and moves focus there, so the user can type their request after it and send. The Agent Pane is the last focused pane in the Browser Pane's Rex window that isn't a Browser Pane or a DevTools Pane. When the command runs from another pane, that pane is the Agent Pane. See `../spec.md`, "Hand off" and "Open questions".

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] Find out whether a Rex Lua plugin can hear focus changes (`rex.on` or server events). If it can, trex remembers the last focused pane per window. If not, use the fallback (the only other pane in the window, else clipboard only) and record what was found
- [ ] The description reaches the Agent Pane as a paste (`block.event`), so a program with bracketed paste on gets the paste markers and nothing is submitted
- [ ] Checked by hand in Claude Code: the multi-line description shows up in the prompt unsent
- [ ] Focus moves to the Agent Pane after the paste
- [ ] With no Agent Pane, the description goes to the clipboard only, and trex says so without taking focus (like F12's error notice)
- [ ] The clipboard copy from ticket 01 still happens in every case
- [ ] `rex do` tests: a stub program in the Agent Pane turns on bracketed paste and logs its input (paste markers present, no Enter after them); focus ends on it; with only a Browser Pane in the window, clipboard only

## Comments
