-- F12's key binding.
--
-- F12 in a pane whose foreground program is kb (a Browser Pane, or a DevTools
-- Pane) always ends in trex: kb's own F12 runs `open -a "Google Chrome.app"
-- <inspector>`, which can land in another kb's headless Chrome. F12 anywhere else
-- returns false, so Rex sends it on to the program in the pane unchanged.
--
-- A key function can't prompt or fail the way an action does, so when the work
-- fails, F12 shows the message in a notice: a small pane floating in front of
-- the window that closes on any key (or after a minute).
--
-- This file uses only rex.bind, rex.session, rex.block.call and pcall, so the
-- tests can load it as a client script, where io, rex.exec and dofile don't exist.
--
-- Loaded as loadfile("f12.lua")(util) → bind(on_kb_pane): binds F12 to call
-- on_kb_pane(ctx) in kb panes.

local util = ...

local TERMINAL = "com.superlogical.terminal"

local NOTICE = [[
printf '\n  %s\n\n  (any key closes this)' "$1"
read -rsn1 -t 60
]]

local function foreground(block_id)
  local p = rex.block.call(TERMINAL, "process", { block_id = block_id })
  return p and p.foreground and p.foreground.name
end

-- Shows `message` in a notice in front of the window that holds `block_id`.
local function notice(block_id, message)
  local b = util.find_block("block_id", block_id)
  rex.session.new_layer{
    window_id = b and b.window_id,
    bounds = { 0.1, 0.35, 0.8, 0.3 },
    focus = true,
    layout = { block = { flavor = util.SHELL, label = "trex notice",
      options = { shell = "none", command = { "/bin/bash", "-c", NOTICE, "trex", message } } } },
  }
end

return function(on_kb_pane)
  rex.bind("f12", function(ctx)
    if ctx.block_id == nil or foreground(ctx.block_id) ~= "kb" then return false end
    -- A key function that raises, or runs over 5 s, swallows the key anyway, so
    -- catch errors, log them and show them; the key is consumed either way.
    local ok, err = pcall(on_kb_pane, ctx)
    if not ok then
      if rex.log then rex.log("warn", tostring(err)) end
      pcall(notice, ctx.block_id, tostring(err))
    end
    return true
  end)
end
