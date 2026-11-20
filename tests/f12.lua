-- Presses F12 in a block with trex's real F12 binding (lua/trex/f12.lua) loaded,
-- without touching the user's config:
--
--   rex do tests/f12.lua -s SESSION -b BLOCK --json [--args '{"fail":"MESSAGE"}']
--
-- `rex do` scripts can't bind keys, so this loads the binding as a client script
-- on this script's own connection (client.set_script) and presses F12 there
-- (client.key). Client scripts have no io, dofile or rex.exec, so instead of
-- opening a DevTools Pane, the handler here only labels the block "trex f12",
-- or, given `fail`, raises that message the way a failed DevTools open does.
--
-- Prints { handled = true } when trex took the key, false when Rex passed it on
-- to the block. Never point this at a kb pane: if the binding let F12 through,
-- kb's own F12 would open DevTools in some other kb's Chrome. Tests use a copy
-- of cat named kb instead.

local here = debug.getinfo(1, "S").source:gsub("^@", "")
local root = here:match("^(.*)/tests/[^/]*$")

local f = assert(io.open(root .. "/lua/trex/f12.lua", "r"))
local binding = f:read("*a")
f:close()

local fail = rex.args and rex.args.fail
local source = "local FAIL = " .. (fail and ("%q"):format(fail) or "nil") .. "\n"
  .. "local bind = (function()\n" .. binding .. "\nend)()\n" .. [[
bind(function(ctx)
  if FAIL ~= nil then error(FAIL, 0) end
  rex.session.set_block_label{ block_id = ctx.block_id, label = "trex f12" }
end)
]]

local set, err = rex.call("client.set_script", { scripts = { { name = "trex-f12-test.lua", source = source } } })
if set == nil then error("client.set_script: " .. tostring(err), 0) end

local res, kerr = rex.call("client.key", { session_id = rex.session_id, block_id = rex.block_id,
  key = { key = "f12", mods = "", consumed_mods = "", text = "", unshifted_codepoint = 0, composing = false, action = "press" } })
if res == nil then error("client.key: " .. tostring(kerr), 0) end
return { handled = res.handled == true }
