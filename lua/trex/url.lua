-- What the user typed → the address trex hands to kb.
--
-- kb normalises most input itself (`localhost:3000` → http, `example.com` →
-- https), but it searches Google for a bare port, so trex turns `3000` and
-- `:3000` into http://localhost:3000 first.

local M = {}

-- The address for `input`; or nil and a message saying why it can't be opened.
function M.normalise(input)
  local text = tostring(input or ""):match("^%s*(.-)%s*$")
  if text == "" then return nil, "trex: no URL given. Enter a URL or a localhost port." end
  -- kb reads any word starting with "-" as a flag, and has no "--" to stop that.
  if text:sub(1, 1) == "-" then
    return nil, ("trex: %q starts with \"-\", so KittyBrowser would read it as a flag."
      .. " Enter a URL or a localhost port."):format(text)
  end
  local port = text:match("^:?(%d+)$")
  if port ~= nil then return "http://localhost:" .. port end
  return text
end

return M
