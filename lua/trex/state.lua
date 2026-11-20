-- trex's small saved state: a JSON object in one file, such as
-- ~/.local/state/trex/state.json. Rex has no store of its own for plugins.
--
-- Returns new(path) → { get(key), set(key, value) }. A missing or unreadable
-- file reads as empty; a failed write is ignored (the state is only a convenience).

return function(path)
  local state = {}

  local function read()
    local f = io.open(path, "r")
    if f == nil then return {} end
    local text = f:read("*a")
    f:close()
    local ok, t = pcall(rex.json.decode, text)
    if ok and type(t) == "table" then return t end
    return {}
  end

  function state.get(key)
    return read()[key]
  end

  function state.set(key, value)
    local t = read()
    if t[key] == value then return end
    t[key] = value
    local dir = path:match("^(.*)/[^/]*$")
    if dir ~= nil then rex.exec({ "/bin/mkdir", "-p", dir }, { timeout = 2 }) end
    local f = io.open(path, "w")
    if f == nil then return end
    f:write(rex.json.encode(t))
    f:close()
  end

  return state
end
