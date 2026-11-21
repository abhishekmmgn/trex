-- Watches over one DevTools Pane while it is open. devtools-pane.sh runs it as
--
--   rex do devtools-watch.lua -s SESSION
--
-- with REX_BLOCK (the DevTools Pane, set by Rex) and TREX_WATCH (JSON from
-- devtools.lua: browser, the Browser Pane's block; kb, kb_id, port, target, the
-- Browser Pane's kb and the page DevTools shows; socket, the DevTools Pane's
-- kb; state, trex's state file) in its environment. It
--
-- - closes the DevTools Pane when the Browser Pane closes or its kb exits
--   (Rex's config Lua can't react to a block closing; a `rex do` script can),
-- - remembers which side of the Browser Pane the DevTools Pane is on every time
--   the layout changes, so the side is kept however the pane is later closed
--   (F12, Rex's own close, or with its Browser Pane),
-- - follows the Browser Pane's kb to the window it shows: when a page opens a
--   new window and kb switches its pane to it (or back), DevTools is pointed at
--   that page. Same-tab navigation needs nothing: the page target stays the same.
--
-- It stops when the DevTools Pane closes, or the session goes.

local DIR = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*)/[^/]*$")
local function load(name, ...) return assert(loadfile(DIR .. "/" .. name .. ".lua"))(...) end

local util = load("util")
local kb_module = load("kb", util)
local devtools_module = load("devtools", util, kb_module)

local watch = rex.json.decode(os.getenv("TREX_WATCH") or "")
local devtools = os.getenv("REX_BLOCK")
local state = load("state", util, watch.state)
local kb = kb_module.new{ bin = watch.kb }

local function close_devtools()
  rex.call("block.close", { session_id = rex.session_id, block_id = devtools })
end

-- The Browser Pane may have gone before this script started listening.
if util.find_block("block_id", watch.browser) == nil then
  close_devtools()
  return
end

rex.on("block_closed", function(_, ev)
  if ev.block_id == watch.browser then close_devtools(); rex.stop(0) end
  if ev.block_id == devtools then rex.stop(0) end
end)

rex.on("terminal.child_exited", function(ctx)
  if ctx.block_id == watch.browser then close_devtools(); rex.stop(0) end
end)

rex.on("session_view_changed", function()
  devtools_module.remember_side(state, watch.browser, devtools)
end)

-- kb has no event for switching windows, so ask it what it shows every second,
-- and look for the page target again only when that changes.
local shown, last_seen = watch.target, nil
rex.every(1, function()
  local status = kb.status(watch.kb_id)
  if status == nil then return end
  local seen = tostring(status.url) .. "\n" .. tostring(status.windows)
  if seen == last_seen then return end
  last_seen = seen
  local target = kb.shown_target(watch.kb_id, watch.port)
  if target ~= nil and target ~= shown then
    rex.exec({ watch.kb, "ctl", "open", kb_module.inspector_url(watch.port, target) },
      { env = { KB_SOCKET = watch.socket }, timeout = 5 })
    shown = target
  end
end)
