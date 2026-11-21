-- Drives trex's config module on its own, for tests/test_config.sh:
--
--   rex do tests/config.lua config=FILE last_good=FILE [then_file=FILE] [get=KEY]
--
-- Reads the config once, as the server does at load. With then_file, copies that
-- file over the config and reloads, as Trex: Reload Config does. Returns the
-- outcome of each read and the settings after the last one. With get=KEY, also the
-- value of that setting, or the error asking for it raised.

local this_file = debug.getinfo(1, "S").source:gsub("^@", "")
local root = this_file:match("^(.*)/tests/[^/]*$")
local util = assert(loadfile(root .. "/lua/trex/util.lua"))()
local module = assert(loadfile(root .. "/lua/trex/config.lua"))(util, root .. "/lua/trex/config.schema.json")

local args = rex.args
local config = module.new{ path = args.config, last_good = args.last_good }

local function outcome(result)
  return { applied = result.applied, source = result.source, problems = #result.problems }
end

local out = { reads = { outcome(config.reload()) } }
if args.then_file ~= nil then
  local f = assert(io.open(args.config, "w"))
  f:write(util.read(args.then_file))
  f:close()
  out.reads[2] = outcome(config.reload())
end
out.settings = config.all()
if args.get ~= nil then
  local ok, value = pcall(config.get, args.get)
  out.get = ok and value or ("error: " .. tostring(value))
end
return out
