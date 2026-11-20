-- F12's key binding.
--
-- F12 in a pane whose foreground program is kb (a Browser Pane, or a DevTools
-- Pane) always ends in trex: kb's own F12 runs `open -a "Google Chrome.app"
-- <inspector>`, which can land in another kb's headless Chrome. F12 anywhere else
-- returns false, so Rex sends it on to the program in the pane unchanged.
--
-- This file uses only rex.bind, rex.block.call and pcall, so the tests can load
-- it as a client script, where io, rex.exec and dofile don't exist.
--
-- Returns bind(on_kb_pane): binds F12 to call on_kb_pane(ctx) in kb panes.

local TERMINAL = "com.superlogical.terminal"

local function foreground(block_id)
  local p = rex.block.call(TERMINAL, "process", { block_id = block_id })
  return p and p.foreground and p.foreground.name
end

return function(on_kb_pane)
  rex.bind("f12", function(ctx)
    if ctx.block_id == nil or foreground(ctx.block_id) ~= "kb" then return false end
    -- A key function that raises, or runs over 5 s, swallows the key anyway, so
    -- catch errors and log them; the key is consumed either way.
    local ok, err = pcall(on_kb_pane, ctx)
    if not ok and rex.log then rex.log("warn", tostring(err)) end
    return true
  end)
end
