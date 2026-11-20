-- KittyBrowser (`kb`), the Base Browser trex runs as shipped (ADR-0001).
--
-- trex depends on kb's outside surface (flags, `kb list`, `kb ctl`, its profile
-- layout), so it runs only the commit it was built against. kb's binary has no
-- commit in it (`kb --version` is just 0.1.0); cargo's install record
-- (~/.cargo/.crates2.json) is the only place that says which commit
-- `cargo install` built.

local M = {}

M.REPO = "https://github.com/graiz/kittybrowser"
M.PIN = "d252d5fe771f4d8f18fbf184d8239524b3ecda39"

local INSTALL = "cargo install --git " .. M.REPO .. " --rev " .. M.PIN .. " --force"

local function read(path)
  local f = io.open(path, "r")
  if f == nil then return nil end
  local text = f:read("*a")
  f:close()
  return text
end

local function exists(path)
  local f = io.open(path, "r")
  if f == nil then return false end
  f:close()
  return true
end

-- The install-record key for kittybrowser, such as
-- "kittybrowser 0.1.0 (git+https://github.com/graiz/kittybrowser#<sha>)"; nil if none.
local function installed(crates2)
  local text = read(crates2)
  if text == nil then return nil end
  local ok, record = pcall(rex.json.decode, text)
  if not ok or type(record) ~= "table" or type(record.installs) ~= "table" then return nil end
  for key in pairs(record.installs) do
    if key:match("^kittybrowser ") then return key end
  end
  return nil
end

function M.new(opts)
  local kb = { bin = opts.bin, crates2 = opts.crates2 }

  -- Raises a message for the user unless the installed kb is the pinned commit.
  function kb.check_pin()
    local key = installed(kb.crates2)
    if key == nil then
      error("trex: KittyBrowser isn't installed (cargo has no record of it in " .. kb.crates2
        .. "). Install the pinned build: " .. INSTALL, 0)
    end
    if not key:find("#" .. M.PIN .. ")", 1, true) then
      local source = key:match("%((.*)%)$") or key
      error("trex: the installed KittyBrowser isn't the pinned commit " .. M.PIN
        .. ". Installed: " .. source .. ". Reinstall the pinned build: " .. INSTALL, 0)
    end
    if not exists(kb.bin) then
      error("trex: KittyBrowser isn't installed at " .. kb.bin .. ". Install the pinned build: " .. INSTALL, 0)
    end
  end

  return kb
end

return M
