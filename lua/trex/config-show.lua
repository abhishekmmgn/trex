-- `trex config show` when the Rex server can't be asked, and the settings list of
-- `trex config --help`: a `rex do` script that runs on its own.
--
--   rex do lua/trex/config-show.lua config=PATH     the file's values (the defaults if it has none)
--   rex do lua/trex/config-show.lua help=1          every setting with its default, no current values

local this_file = debug.getinfo(1, "S").source:gsub("^@", "")
local dir = this_file:match("^(.*)/[^/]*$")
local util = assert(loadfile(dir .. "/util.lua"))()
local config = assert(loadfile(dir .. "/config.lua"))(util, dir .. "/config.schema.json")

if rex.args.help ~= nil then
  print(config.help_rows())
else
  local path = rex.args.config
  if type(path) ~= "string" or path == "" then error("trex: config-show.lua needs config=PATH or help=1", 0) end
  print(config.report(path, nil))
end
rex.stop(0)
