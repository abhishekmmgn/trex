-- `trex config check`: a `rex do` script that checks the config file and prints what
-- it finds. It runs on its own, not in the server, so it checks the file as it is now.
--
--   rex do lua/trex/config-check.lua config=PATH
--
-- Exits 0 if the file is valid, or missing (trex then uses its defaults); 1 if it
-- has any problem, an unknown key included.

local this_file = debug.getinfo(1, "S").source:gsub("^@", "")
local dir = this_file:match("^(.*)/[^/]*$")
local util = assert(loadfile(dir .. "/util.lua"))()
local config = assert(loadfile(dir .. "/config.lua"))(util, dir .. "/config.schema.json")

local path = rex.args.config
if type(path) ~= "string" or path == "" then error("trex: config-check.lua needs config=PATH", 0) end

local text = util.read(path)
if text == nil then
  print("trex: no config file at " .. path .. "; trex uses its defaults. `trex setup` creates one.")
  rex.stop(0)
else
  local result = config.inspect(text)
  if #result.problems == 0 then
    print("trex: " .. path .. " is valid.")
    rex.stop(0)
  else
    print("trex: " .. config.format(path, result))
    rex.stop(1)
  end
end
