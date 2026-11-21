-- Names a Browser Pane after the page it shows. Only the Pane: its Tab keeps
-- the name it was opened with. init.lua starts it as
--
--   rex do title-watch.lua -s SESSION
--
-- with --args JSON: browser, the Browser Pane; label, the name it was opened
-- with; kb, the kb binary; home, whose ~/.kittybrowser to look in.
-- Config Lua can't wait for the page, so this does: it asks the pane's kb
-- what it shows every second, and sets the label when the title changes. It
-- stops when the Browser Pane closes.
--
-- A name the user gives the Pane wins: once its name is not the one trex last
-- gave it, this stops and never renames it again.

local DIR = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*)/[^/]*$")
local function load(name, ...) return assert(loadfile(DIR .. "/" .. name .. ".lua"))(...) end

local util = load("util")
local kb_module = load("kb", util)

local watch = rex.args
if type(watch) ~= "table" or watch.browser == nil then
  error("trex: title-watch.lua needs --args with the Browser Pane", 0)
end

local kb = kb_module.new{ bin = watch.kb, home = watch.home }
local last = watch.label -- the name trex last gave the Pane

local function apply(title)
  title = util.clip_label(title)
  if title == nil or title == last then return end
  last = title
  rex.session.set_block_label{ block_id = watch.browser, label = title }
end

local function tick()
  local block = util.find_block("block_id", watch.browser)
  if block == nil then rex.stop(0) return end
  -- Renamed by the user (Rename Pane…, rex block rename): leave it alone from now on.
  if last ~= nil and block.label ~= last then rex.stop(0) return end
  local row = kb.in_block(watch.browser)
  if row == nil then return end
  local status = kb.status(row.id)
  if status ~= nil then apply(status.title) end
end

rex.on("block_closed", function(_, ev)
  if ev.block_id == watch.browser then rex.stop(0) end
end)

rex.every(1, tick)
tick()
