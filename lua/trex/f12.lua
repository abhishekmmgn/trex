-- The DevTools keys' binding: F12 and cmd+shift+i (KEYS).
--
-- Either key in a pane whose foreground program is kb (a Browser Pane, or a
-- DevTools Pane) always ends in trex: kb's own F12 runs `open -a "Google
-- Chrome.app" <inspector>`, which can land in another kb's headless Chrome.
-- Anywhere else the key function returns false, so Rex sends the key on to the
-- program in the pane unchanged. (kb's own DevTools keys are F12, ctrl+shift+i
-- and alt+cmd+i; Rex's config binds nothing else to cmd+shift+i.)
--
-- A key function can't prompt or fail the way an action does, and Rex gives
-- plugins no way to post one of its own floating notifications (ticket 03,
-- Comments). So when the work fails, F12 shows the message in a notice: a small
-- pane floating at the top of the window, which leaves focus where it was and
-- closes after 8 seconds (or on any key, once clicked).
--
-- This file uses only rex.bind, rex.session, rex.block.call and pcall, so the
-- tests can load it as a client script, where io, rex.exec and dofile don't exist.
--
-- Loaded as loadfile("f12.lua")(util) → bind(on_kb_pane): binds KEYS to call
-- on_kb_pane(ctx) in kb panes.

local util = ...

local TERMINAL = "com.superlogical.terminal"

local NOTICE = [[
printf '\n  %s' "$1"
read -rsn1 -t 8
]]

local function foreground(block_id)
  local p = rex.block.call(TERMINAL, "process", { block_id = block_id })
  return p and p.foreground and p.foreground.name
end

-- Shows `message` in a notice at the top of the window that holds `block_id`.
local function notice(block_id, message)
  local b = util.find_block("block_id", block_id)
  rex.session.new_layer{
    window_id = b and b.window_id,
    bounds = { 0.15, 0.04, 0.7, 0.16 },
    focus = false,
    layout = { block = { flavor = util.SHELL, label = "trex notice",
      options = { shell = "none", command = { "/bin/bash", "-c", NOTICE, "trex", message } } } },
  }
end

local KEYS = { "f12", "cmd+shift+i" }

return function(on_kb_pane)
  local function on_key(ctx)
    if ctx.block_id == nil or foreground(ctx.block_id) ~= "kb" then return false end
    -- A key function that raises, or runs over 5 s, swallows the key anyway, so
    -- catch errors, log them and show them; the key is consumed either way.
    local ok, err = pcall(on_kb_pane, ctx)
    if not ok then
      if rex.log then rex.log("warn", tostring(err)) end
      pcall(notice, ctx.block_id, tostring(err))
    end
    return true
  end
  for _, key in ipairs(KEYS) do rex.bind(key, on_key) end
end
