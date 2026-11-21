-- The KittyBrowser commit trex is built against, and the check that it is the
-- one installed (ADR-0001). This file is the one place the pin lives:
-- bin/trex-setup and the tests read M.REPO and M.PIN from it.
--
-- trex depends on kb's outside surface (flags, `kb list`, `kb ctl`, its profile
-- layout), so it runs only this commit. kb's binary has no commit in it
-- (`kb --version` is just 0.1.0); cargo's install record
-- (~/.cargo/.crates2.json) is the only place that says which commit
-- `cargo install` built.

local util = ... -- util.lua, passed in by whoever loads this file

local M = {}

M.REPO = "https://github.com/graiz/kittybrowser"
M.PIN = "d252d5fe771f4d8f18fbf184d8239524b3ecda39"

local INSTALL = "cargo install --git " .. M.REPO .. " --rev " .. M.PIN .. " --force"

-- The install-record key for kittybrowser, such as
-- "kittybrowser 0.1.0 (git+https://github.com/graiz/kittybrowser#<sha>)"; nil if none.
local function installed(crates2)
  local text = util.read(crates2)
  if text == nil then return nil end
  local ok, record = pcall(rex.json.decode, text)
  if not ok or type(record) ~= "table" or type(record.installs) ~= "table" then return nil end
  for key in pairs(record.installs) do
    if key:match("^kittybrowser ") then return key end
  end
  return nil
end

-- Raises a message for the user unless the kb at `bin` is the pinned commit,
-- going by cargo's install record `crates2`.
function M.check(crates2, bin)
  local key = installed(crates2)
  if key == nil then
    error("trex: KittyBrowser isn't installed (cargo has no record of it in " .. crates2
      .. "). Install the pinned build: " .. INSTALL, 0)
  end
  if not key:find("#" .. M.PIN .. ")", 1, true) then
    local source = key:match("%((.*)%)$") or key
    error("trex: the installed KittyBrowser isn't the pinned commit " .. M.PIN
      .. ". Installed: " .. source .. ". Reinstall the pinned build: " .. INSTALL, 0)
  end
  if not util.exists(bin) then
    error("trex: KittyBrowser isn't installed at " .. bin .. ". Install the pinned build: " .. INSTALL, 0)
  end
end

return M
