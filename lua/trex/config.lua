-- trex's settings: the JSON config file (ADR-0003), checked against
-- config.schema.json, with the schema's defaults for what the file leaves out.
--
-- Loaded as loadfile("config.lua")(util, schema_path) → M with
--   M.inspect(text)         checks a config file's text → { settings, problems, blocking }
--   M.format(path, result)  the problems as text, one per line, each with its key and line
--   M.new{ path, last_good }  → a config: get(key), all(), reload()
--
-- A problem is { line, key, message, warning }. An unknown key is a warning: `trex
-- config check` reports it, but the rest of the file still applies. Any other problem
-- is blocking: the file isn't applied, and the last good settings stay.
--
-- The schema is the one place that says which settings there are, their allowed
-- values and their defaults. The JSON parser here is strict and knows lines, because
-- rex.json.decode accepts bad JSON and says nothing of where it went wrong.
-- Works in the Rex server and in a `rex do` script (config-check.lua), so
-- `trex config check` and the server agree.

local util, schema_path = ...
local M = {}

-- Lua 5.1 only (that is what Rex runs): no utf8 library, no goto.

local NULL = setmetatable({}, { __tostring = function() return "null" end })
local ARRAY = {}

-- --- strict JSON, with the line of every key -------------------------------------

local ESCAPES = { ['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t" }

-- A code point as UTF-8.
local function utf8_char(cp)
  if cp < 0x80 then return string.char(cp) end
  if cp < 0x800 then return string.char(0xC0 + math.floor(cp / 0x40), 0x80 + cp % 0x40) end
  if cp < 0x10000 then
    return string.char(0xE0 + math.floor(cp / 0x1000), 0x80 + math.floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
  end
  return string.char(0xF0 + math.floor(cp / 0x40000), 0x80 + math.floor(cp / 0x1000) % 0x40,
    0x80 + math.floor(cp / 0x40) % 0x40, 0x80 + cp % 0x40)
end

-- Parses `text` → value, lines (key path such as "devtools.side" → the line of that
-- key). On bad JSON: nil, { line, message }.
local function parse(text)
  local pos, line = 1, 1
  local lines = {}
  local comma_line -- the line of the comma last read, for a trailing-comma error

  local function fail(message, at) error({ line = at or line, message = message }, 0) end

  local function skip()
    while true do
      local c = text:sub(pos, pos)
      if c == "\n" then line = line + 1; pos = pos + 1
      elseif c == " " or c == "\t" or c == "\r" then pos = pos + 1
      elseif c == "/" and (text:sub(pos + 1, pos + 1) == "/" or text:sub(pos + 1, pos + 1) == "*") then
        fail("comments aren't allowed in JSON")
      else return end
    end
  end

  local value

  local function str()
    local start_line = line
    pos = pos + 1
    local out = {}
    while true do
      local s = text:find('["\\\0-\31]', pos)
      if s == nil then fail("a string isn't closed", start_line) end
      out[#out + 1] = text:sub(pos, s - 1)
      local c = text:sub(s, s)
      if c == '"' then pos = s + 1; return table.concat(out) end
      if c ~= "\\" then fail("a string can't hold a raw newline or control character", start_line) end
      local e = text:sub(s + 1, s + 1)
      if ESCAPES[e] then out[#out + 1] = ESCAPES[e]; pos = s + 2
      elseif e == "u" then
        local hex = text:match("^%x%x%x%x", s + 2)
        if hex == nil then fail("a \\u escape needs four hex digits") end
        out[#out + 1] = utf8_char(tonumber(hex, 16))
        pos = s + 6
      else fail("a string has a bad escape \\" .. e) end
    end
  end

  local function object(path)
    local obj = {}
    pos = pos + 1
    skip()
    if text:sub(pos, pos) == "}" then pos = pos + 1; return obj end
    while true do
      skip()
      local c = text:sub(pos, pos)
      if c == "}" then fail("a trailing comma isn't allowed in JSON", comma_line) end
      if c ~= '"' then
        fail(c == "'" and "keys need double quotes, not single quotes" or "expected a key in double quotes")
      end
      local key_line = line
      local key = str()
      skip()
      if text:sub(pos, pos) ~= ":" then fail("expected ':' after the key \"" .. key .. "\"") end
      pos = pos + 1
      skip()
      local child = path == "" and key or (path .. "." .. key)
      lines[child] = key_line
      obj[key] = value(child)
      skip()
      c = text:sub(pos, pos)
      if c == "}" then pos = pos + 1; return obj end
      if c ~= "," then fail("expected ',' or '}' after a value") end
      comma_line = line
      pos = pos + 1
    end
  end

  local function array(path)
    local arr = setmetatable({}, ARRAY)
    pos = pos + 1
    skip()
    if text:sub(pos, pos) == "]" then pos = pos + 1; return arr end
    while true do
      skip()
      if text:sub(pos, pos) == "]" then fail("a trailing comma isn't allowed in JSON", comma_line) end
      arr[#arr + 1] = value(path)
      skip()
      local c = text:sub(pos, pos)
      if c == "]" then pos = pos + 1; return arr end
      if c ~= "," then fail("expected ',' or ']' after a value") end
      comma_line = line
      pos = pos + 1
    end
  end

  function value(path)
    skip()
    local c = text:sub(pos, pos)
    if c == "{" then return object(path) end
    if c == "[" then return array(path) end
    if c == '"' then return str() end
    if text:sub(pos, pos + 3) == "true" then pos = pos + 4; return true end
    if text:sub(pos, pos + 4) == "false" then pos = pos + 5; return false end
    if text:sub(pos, pos + 3) == "null" then pos = pos + 4; return NULL end
    local num = text:match("^-?%d+%.?%d*[eE]?[+-]?%d*", pos)
    if num ~= nil and tonumber(num) ~= nil then pos = pos + #num; return tonumber(num) end
    if c == "" then fail("the file ends where a value was expected") end
    fail("unexpected '" .. c .. "'; expected a value")
  end

  local ok, result = pcall(function()
    local root = value("")
    skip()
    if pos <= #text then fail("unexpected text after the end of the JSON") end
    return root
  end)
  if ok then return result, lines end
  if type(result) ~= "table" then error(result, 0) end -- a bug here, not bad JSON
  return nil, result
end

M.parse = parse

-- --- the schema ------------------------------------------------------------------

local schema_cache
local function schema()
  if schema_cache == nil then schema_cache = rex.json.decode(assert(util.read(schema_path), "trex: no schema at " .. schema_path)) end
  return schema_cache
end

local function sorted_keys(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys)
  return keys
end

-- The schema's leaf settings, flat: "devtools.side" → its schema node.
local function leaves(node, prefix, out)
  for _, key in ipairs(sorted_keys(node.properties or {})) do
    local child = node.properties[key]
    local name = prefix == "" and key or (prefix .. "." .. key)
    if child.type == "object" then leaves(child, name, out)
    elseif child.default ~= nil then out[name] = child end
  end
  return out
end

local function defaults()
  local out = {}
  for name, node in pairs(leaves(schema(), "", {})) do out[name] = node.default end
  return out
end

-- --- checking --------------------------------------------------------------------

local function kind(v)
  if v == NULL then return "null" end
  if type(v) == "table" then return getmetatable(v) == ARRAY and "array" or "object" end
  return type(v)
end

local function show(v)
  if kind(v) == "array" or kind(v) == "object" then return kind(v) end
  if v == NULL then return "null" end
  return rex.json.encode(v)
end

local function contains(list, v)
  for _, item in ipairs(list) do
    if item == v then return true end
  end
  return false
end

local function quoted_list(values)
  local out = {}
  for _, v in ipairs(values) do out[#out + 1] = show(v) end
  return table.concat(out, ", ")
end

-- Checks the config file's `text` against the schema → { settings, problems, blocking }.
-- `settings` is flat ("devtools.side" → value): the defaults, with the file's valid
-- values over them. `blocking` is whether any problem should stop the file applying.
function M.inspect(text)
  local result = { settings = defaults(), problems = {}, blocking = false }
  local function problem(line, key, message, warning)
    result.problems[#result.problems + 1] = { line = line, key = key, message = message, warning = warning or false }
    if not warning then result.blocking = true end
  end

  local root, lines = parse(text)
  if root == nil then
    problem(lines.line, nil, "syntax error: " .. lines.message)
    return result
  end
  if kind(root) ~= "object" then
    problem(1, nil, "the file must hold one JSON object ({ ... }), not " .. show(root))
    return result
  end

  local function walk(node, value, path)
    for _, key in ipairs(sorted_keys(value)) do
      local name = path == "" and key or (path .. "." .. key)
      local child = (node.properties or {})[key]
      local v = value[key]
      if child == nil then
        local known = {}
        for _, k in ipairs(sorted_keys(node.properties or {})) do
          if k ~= "$schema" then known[#known + 1] = k end
        end
        problem(lines[name], name, "isn't a trex setting. Settings here: " .. table.concat(known, ", "), true)
      elseif child.type == "object" then
        if kind(v) == "object" then walk(child, v, name)
        else problem(lines[name], name, "must be an object ({ ... }), not " .. show(v)) end
      elseif kind(v) ~= child.type then
        problem(lines[name], name, "must be " .. (child.type == "object" and "an" or "a") .. " " .. child.type .. ", not " .. show(v))
      elseif child.enum ~= nil and not contains(child.enum, v) then
        problem(lines[name], name, "must be one of " .. quoted_list(child.enum) .. ", not " .. show(v))
      elseif child.default ~= nil then
        result.settings[name] = v
      end
    end
  end
  walk(schema(), root, "")

  table.sort(result.problems, function(a, b)
    if a.line ~= b.line then return a.line < b.line end
    return (a.key or "") < (b.key or "")
  end)
  return result
end

-- The problems of `result` as text: a heading, then a line for each problem.
function M.format(path, result)
  local n = #result.problems
  local out = { string.format("%s has %d problem%s:", path, n, n == 1 and "" or "s") }
  for _, p in ipairs(result.problems) do
    out[#out + 1] = string.format("  line %d: %s%s", p.line or 1, p.key and (p.key .. ": ") or "", p.message)
  end
  return table.concat(out, "\n")
end

-- --- listing the settings ----------------------------------------------------------

-- Every setting the schema has, sorted by key: { key, default, enum, summary }. Nothing
-- is listed by hand, so a new setting in the schema shows up in `trex config show`.
function M.rows()
  local out = {}
  local nodes = leaves(schema(), "", {})
  for _, key in ipairs(sorted_keys(nodes)) do
    local node = nodes[key]
    local allowed = node.enum
    if allowed == nil and node.type == "boolean" then allowed = { true, false } end
    out[#out + 1] = { key = key, default = node.default, enum = allowed, summary = node["x-summary"] or "" }
  end
  return out
end

local MAX_VALUE = 40

local function display(v)
  local text = type(v) == "string" and v or show(v)
  if #text > MAX_VALUE then text = text:sub(1, MAX_VALUE - 3) .. "..." end
  return text
end

local function pad(text, width) return text .. string.rep(" ", width - #text) end

-- The settings as aligned rows. `values` (flat, key → value) is what is in effect: a row
-- that differs from its default gets a `*`. Without `values`, the rows show the
-- defaults and no marks (for --help). Returns the text and whether any row is marked.
function M.table(values)
  local rows = M.rows()
  local keyw, valw, enumw = 0, 0, 0
  local cells = {}
  for i, row in ipairs(rows) do
    local value = values and values[row.key]
    if value == nil then value = row.default end
    local allowed = ""
    if row.enum ~= nil then
      local items = {}
      for _, item in ipairs(row.enum) do items[#items + 1] = display(item) end
      allowed = "(" .. table.concat(items, " | ") .. ")"
    end
    local changed = values ~= nil and value ~= row.default
    local summary = row.summary
    if changed then summary = summary .. "; default " .. display(row.default) end
    cells[i] = { key = row.key, value = display(value), allowed = allowed, summary = summary, changed = changed }
    keyw, valw, enumw = math.max(keyw, #row.key), math.max(valw, #cells[i].value), math.max(enumw, #allowed)
  end
  local lines, any = {}, false
  for _, c in ipairs(cells) do
    any = any or c.changed
    lines[#lines + 1] = (c.changed and "* " or "  ") .. pad(c.key, keyw) .. "  " .. pad(c.value, valw) .. "  "
      .. pad(c.allowed, enumw) .. "  " .. c.summary
  end
  return table.concat(lines, "\n"), any
end

local function tilde(path)
  local home = os.getenv("HOME")
  if home ~= nil and home ~= "" and path:sub(1, #home + 1) == home .. "/" then return "~" .. path:sub(#home + 1) end
  return path
end

-- The text of `trex config show`. `held` is the settings the Rex server holds (flat), or
-- nil when it couldn't be reached, when the file's own values are shown instead.
function M.report(path, held)
  local text = util.read(path)
  local file = text and M.inspect(text)
  local values, notes = held, {}
  if held == nil then
    values = file and not file.blocking and file.settings or nil
    if file ~= nil and file.blocking then
      notes[#notes + 1] = "The file has problems, and Rex isn't reachable, so these are the defaults. `trex config check` lists the problems."
    else
      notes[#notes + 1] = "Rex isn't reachable (or trex isn't installed in it: `trex install`), so these are "
        .. (file and "the values in the file (the defaults for what it leaves out)." or "the defaults: there is no config file yet.")
    end
  elseif file ~= nil and file.blocking then
    notes[#notes + 1] = "The file has problems, so the last good settings are in effect. `trex config check` lists them."
  elseif file ~= nil then
    for key, v in pairs(file.settings) do
      if held[key] ~= v then
        notes[#notes + 1] = "The file differs from what Rex uses. `trex config reload` applies it."
        break
      end
    end
  end
  local body, any = M.table(values)
  local out = { tilde(path), "" }
  for _, note in ipairs(notes) do out[#out + 1] = note end
  if #notes > 0 then out[#out + 1] = "" end
  out[#out + 1] = body
  out[#out + 1] = ""
  out[#out + 1] = (any and "* changed from the default. " or "") .. "Edit with `trex config edit`."
  return table.concat(out, "\n")
end

-- For `--help`: the settings with their defaults and allowed values, no current values.
function M.help_rows()
  return (M.table(nil))
end

-- --- the settings the server holds ------------------------------------------------

-- A config reading `path`, remembering the last good copy of the file in `last_good`
-- (so it survives a Rex restart). Call reload() to read the file; trex does at load.
function M.new(o)
  local self = { path = o.path, settings = nil }

  local function remember(text)
    if util.read(o.last_good) == text then return end
    local dir = o.last_good:match("^(.*)/[^/]*$")
    if dir ~= nil then rex.exec({ "/bin/mkdir", "-p", dir }, { timeout = 2 }) end
    local f = io.open(o.last_good, "w")
    if f == nil then return end -- only a convenience, like the state file
    f:write(text)
    f:close()
  end

  -- Reads the file and applies it if it has no blocking problem. Returns
  -- { applied, source, problems, blocking }: `source` is what the settings now come
  -- from, "file", "last-good" (kept after a bad file) or "defaults" (no file, or no
  -- good copy to keep).
  function self.reload()
    local text = util.read(o.path)
    if text == nil then
      self.settings = defaults()
      return { applied = true, source = "defaults", problems = {}, blocking = false }
    end
    local result = M.inspect(text)
    if not result.blocking then
      self.settings = result.settings
      remember(text)
      result.applied, result.source = true, "file"
      return result
    end
    result.applied = false
    if self.settings ~= nil then -- a reload: what is held is the last good already
      result.source = "last-good"
      return result
    end
    local last = util.read(o.last_good)
    local last_result = last and M.inspect(last)
    if last_result ~= nil and not last_result.blocking then
      self.settings, result.source = last_result.settings, "last-good"
    else
      self.settings, result.source = defaults(), "defaults"
    end
    return result
  end

  -- The setting called `key`, such as "devtools.side". A key the schema doesn't
  -- have is a bug in the caller, so it raises.
  function self.get(key)
    if self.settings == nil then self.reload() end
    local v = self.settings[key]
    if v == nil then error("trex: there is no setting " .. tostring(key), 2) end
    return v
  end

  -- A copy of every setting, flat ("devtools.side" → value).
  function self.all()
    if self.settings == nil then self.reload() end
    local copy = {}
    for k, v in pairs(self.settings) do copy[k] = v end
    return copy
  end

  return self
end

return M
