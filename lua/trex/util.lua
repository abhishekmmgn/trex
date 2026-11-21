-- Small helpers the other trex modules share.
--
-- Loads without io or rex.exec, so f12.lua can use it in a client script too;
-- only the functions that read files or run curl need them.

local M = {}

-- The flavor of a Rex terminal block, for layouts.
M.SHELL = "com.superlogical.terminal.shell"

-- Whether a file can be opened for reading.
function M.exists(path)
  local f = io.open(path, "r")
  if f == nil then return false end
  f:close()
  return true
end

-- The text of a file; nil if it can't be read.
function M.read(path)
  local f = io.open(path, "r")
  if f == nil then return nil end
  local text = f:read("*a")
  f:close()
  return text
end

-- GETs `url` from a local DevTools endpoint and decodes its JSON; nil if it
-- doesn't answer within a second or isn't JSON.
function M.get_json(url)
  local r = rex.exec({ "/usr/bin/curl", "-s", "-m", "1", url }, { timeout = 2 })
  local ok, value = pcall(rex.json.decode, (r and r.stdout) or "")
  if ok and type(value) == "table" then return value end
  return nil
end

-- A Rex window or block label: no control characters, at most 128 characters.
-- Empty after trimming is nil.
function M.clip_label(text)
  text = tostring(text or ""):gsub("%c", " "):gsub("^%s+", ""):gsub("%s+$", ""):gsub(" +", " ")
  if text == "" then return nil end
  if #text > 128 then text = text:sub(1, 128) end
  return text
end

-- The first entry of the session's blocks (rex.session.list_blocks) whose
-- `field` is `value`; nil if none.
function M.find_block(field, value)
  local listed = rex.session.list_blocks{}
  for _, b in ipairs((listed and listed.blocks) or {}) do
    if b[field] == value then return b end
  end
  return nil
end

return M
