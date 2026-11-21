-- The KittyBrowser commit trex is built against, and the check that it is the
-- one installed. This file is the one place the pin lives: bin/trex-setup and
-- the tests read M.REPO and M.PIN from it.
--
-- trex depends on kb's outside surface (flags, `kb list`, `kb ctl`, its profile
-- layout), so it runs only this commit (ADR-0001). For now the commit is on the
-- user's fork, not upstream (ADR-0002), so the check wants both: this repo and
-- this commit. kb's binary has no commit in it (`kb --version` is just 0.1.0);
-- cargo's install record (~/.cargo/.crates2.json) is the only place that says
-- which repo and commit `cargo install` built.

local util = ... -- util.lua, passed in by whoever loads this file

local M = {}

M.REPO = "https://github.com/abhishekmmgn/trex-browser"
M.PIN = "1cc86f1863de596f771d509b15ee446cc3450b27"

local INSTALL = "cargo install --git " .. M.REPO .. " --rev " .. M.PIN .. " --locked --force"

-- The install-record key for kittybrowser, such as
-- "kittybrowser 0.1.0 (git+https://github.com/abhishekmmgn/trex-browser?rev=<sha>#<sha>)"
-- (`?rev=` only when installed with --rev); nil if none.
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

-- Whether install source `source` ("git+URL[?QUERY]#SHA") is M.PIN built from M.REPO.
local function is_pin(source)
  local url, sha = source:match("^git%+([^?#]*)[^#]*#(%x+)$")
  return url ~= nil and url:gsub("%.git$", ""):gsub("/$", "") == M.REPO and sha == M.PIN
end

-- Raises a message for the user unless the kb at `bin` is the pinned commit
-- from the pinned repo, going by cargo's install record `crates2`.
function M.check(crates2, bin)
  local key = installed(crates2)
  if key == nil then
    error("trex: KittyBrowser isn't installed (cargo has no record of it in " .. crates2
      .. "). Install the pinned build: " .. INSTALL, 0)
  end
  local source = key:match("%((.*)%)$") or key
  if not is_pin(source) then
    error("trex: the installed KittyBrowser isn't the pinned commit " .. M.PIN .. " from " .. M.REPO
      .. ". Installed: " .. source .. ". Reinstall the pinned build: " .. INSTALL, 0)
  end
  if not util.exists(bin) then
    error("trex: KittyBrowser isn't installed at " .. bin .. ". Install the pinned build: " .. INSTALL, 0)
  end
end

return M
