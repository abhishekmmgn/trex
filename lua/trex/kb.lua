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
  local kb = { bin = opts.bin, crates2 = opts.crates2, home = opts.home }

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

  -- The first kb in `kb list` whose `field` is `value`:
  -- { n = instance number, url = its page, block = its Rex block, id = "N-xxxx" };
  -- nil if none. A DevTools Pane's kb has its own KB_SOCKET, so `kb list` never shows it.
  local function find(field, value)
    -- F12 runs this in a key function, which Rex gives 5 s in all.
    local r = rex.exec({ kb.bin, "list" }, { timeout = 3 })
    for line in ((r and r.stdout) or ""):gmatch("[^\n]+") do
      local n, url, pane, id = line:match("^(%d+)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
      local k = { n = tonumber(n), url = url, block = pane, id = id }
      if n ~= nil and k[field] == value then return k end
    end
    return nil
  end

  -- The kb running in Rex block `block_id`; nil if none.
  function kb.in_block(block_id) return find("block", block_id) end

  -- The kb `kb list` calls `id` ("N-xxxx"); nil if none.
  function kb.by_id(id) return find("id", id) end

  -- kb's data directory: its profiles and sockets, and trex's DevTools Pane files.
  function kb.data_dir()
    return kb.home .. "/.kittybrowser"
  end

  -- The DevTools port of kb instance `n`; nil if it was started without --devtools.
  -- Instance 1's profile is `profile`, the others' `profile-N`. Chrome writes the
  -- port on the first line of DevToolsActivePort there, and deletes it on exit.
  function kb.devtools_port(n)
    local profile = kb.data_dir() .. "/" .. (n == 1 and "profile" or ("profile-" .. n))
    local text = read(profile .. "/DevToolsActivePort")
    return text and text:match("^(%d+)")
  end

  return kb
end

return M
