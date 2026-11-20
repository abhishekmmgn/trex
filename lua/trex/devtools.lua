-- The DevTools Pane: Chrome DevTools for a Browser Pane's page, shown by a
-- second kb split beside the Browser Pane.
--
-- Browser Pane block → its kb (`kb list`) → that kb's DevTools port → the page
-- target (/json/list) → the inspector URL, which devtools-pane.sh opens in a kb
-- of its own. That kb gets its own KB_SOCKET and Chrome profile, so `kb list`,
-- `kb ctl` and `kb mcp` never see it (agents keep driving the Browser Pane).

local M = {}

M.LABEL = "trex devtools"
local SHELL = "com.superlogical.terminal.shell"

local function inspector_url(port, target)
  return ("http://127.0.0.1:%s/devtools/inspector.html?ws=127.0.0.1:%s/devtools/page/%s"):format(port, port, target)
end

-- The id of the page target the kb shows: the page whose url is the kb's,
-- else the first page (`/json/list` also lists Chrome's own UI targets, and the
-- url can differ while a page loads or redirects).
local function page_target(port, url)
  local r = rex.exec({ "/usr/bin/curl", "-s", "-m", "1", "http://127.0.0.1:" .. port .. "/json/list" }, { timeout = 2 })
  local ok, targets = pcall(rex.json.decode, (r and r.stdout) or "")
  if not ok or type(targets) ~= "table" then return nil end
  local first
  for _, t in ipairs(targets) do
    if t.type == "page" then
      if t.url == url then return t.id end
      first = first or t.id
    end
  end
  return first
end

-- The session's blocks, as rex.session.list_blocks lists them.
local function blocks()
  local listed = rex.session.list_blocks{}
  return (listed and listed.blocks) or {}
end

-- The block labelled `label` among `list`, if any.
local function find_block(list, label)
  for _, b in ipairs(list) do
    if b.label == label then return b.block_id end
  end
  return nil
end

local function label_of(list, block_id)
  for _, b in ipairs(list) do
    if b.block_id == block_id then return b.label end
  end
  return nil
end

-- The kb id in a DevTools Pane's label, "trex devtools <kb id>"; nil for any other label.
local function devtools_of(label)
  if label == nil or label:sub(1, #M.LABEL + 1) ~= M.LABEL .. " " then return nil end
  return label:sub(#M.LABEL + 2)
end

-- Where a DevTools Pane can sit next to its Browser Pane, as new_split arguments.
local SIDES = {
  below = { direction = "vertical", side = "after" },
  above = { direction = "vertical", side = "before" },
  right = { direction = "horizontal", side = "after" },
  left = { direction = "horizontal", side = "before" },
}
M.DEFAULT_SIDE = "below"

-- The layout rects ({x, y, w, h}) of `a` and `b` if both are in the same layer
-- of a window, from rex.session.view.
local function rects(a, b)
  local view = rex.session.view{}
  for _, w in ipairs((view and view.windows) or {}) do
    for _, layer in ipairs(w.layers or {}) do
      local found = {}
      local function walk(node)
        if type(node) ~= "table" then return end
        if node.block_id ~= nil then found[node.block_id] = node.rect end
        if node.split ~= nil then walk(node.split.before); walk(node.split.after) end
      end
      walk(layer.layout)
      if found[a] and found[b] then return found[a], found[b] end
    end
  end
  return nil
end

-- Which side of the Browser Pane `browser` the DevTools Pane `devtools` is on:
-- "below", "above", "right" or "left"; nil if they aren't side by side in one layer.
local function side_of(browser, devtools)
  local b, d = rects(browser, devtools)
  if b == nil then return nil end
  local eps = 1e-6
  if d[2] >= b[2] + b[4] - eps then return "below" end
  if d[2] + d[4] <= b[2] + eps then return "above" end
  if d[1] >= b[1] + b[3] - eps then return "right" end
  if d[1] + d[3] <= b[1] + eps then return "left" end
  return nil
end

local function close_block(session_id, block_id)
  local r, err = rex.call("block.close", { session_id = session_id, block_id = block_id })
  if r == nil then error("trex: couldn't close the DevTools Pane: " .. tostring(err), 0) end
end

-- opts: kb (from kb.lua), script (path of devtools-pane.sh), rex (path of the
-- rex CLI, which the DevTools Pane uses to close itself with its Browser Pane),
-- state (state.lua, where the side the user last had DevTools on is kept).
function M.new(opts)
  local kb = opts.kb
  local devtools = {}

  -- Closes the DevTools Pane `block` of the Browser Pane `browser` (if known),
  -- first remembering which side of it the user had it on.
  local function close(ctx, block, browser)
    local side = browser and side_of(browser, block)
    if side ~= nil then opts.state.set("devtools_side", side) end
    close_block(ctx.session_id, block)
    return { closed = true, block_id = block, browser = browser, side = side }
  end

  -- F12: opens a DevTools Pane for the Browser Pane `ctx.block_id`, or closes
  -- the one it has. In a DevTools Pane, closes that pane. It opens on the side
  -- of the Browser Pane the last one was on when trex closed it (below at first).
  --
  -- Returns { closed = true, block_id = the DevTools Pane closed, browser, side }
  -- when it closed one; else { block_id, browser, kb, port, target, inspector,
  -- socket, side } for the pane it opened. Returns nil when `ctx.block_id` is neither a Browser
  -- Pane (no kb in `kb list` has it) nor a DevTools Pane. Raises a message for
  -- the user when it is a Browser Pane but DevTools can't open.
  function devtools.toggle(ctx)
    local here = ctx.block_id
    local list = blocks()

    local of_kb = devtools_of(label_of(list, here))
    if of_kb ~= nil then
      local browser = kb.by_id(of_kb)
      return close(ctx, here, browser and browser.block)
    end

    local browser = kb.in_block(here)
    if browser == nil then return nil end
    local label = M.LABEL .. " " .. browser.id

    local open = find_block(list, label)
    if open ~= nil then return close(ctx, open, here) end

    local port = kb.devtools_port(browser.n)
    if port == nil then
      error("trex: the KittyBrowser in this pane (" .. browser.id .. ") was started without DevTools."
        .. " Open it with Trex: Open Browser…, which runs kb --devtools.", 0)
    end
    local target = page_target(port, browser.url)
    if target == nil then
      error("trex: KittyBrowser " .. browser.id .. " lists no page on its DevTools port " .. port .. ".", 0)
    end

    -- One socket and profile per Browser kb run, so DevTools Panes for several
    -- Browser Panes can be open at once. The socket path must stay under 104 bytes.
    local dir = kb.data_dir() .. "/trex-devtools"
    local socket = dir .. "/" .. browser.id .. ".sock"
    local profile = dir .. "/" .. browser.id
    local inspector = inspector_url(port, target)

    local side = opts.state.get("devtools_side")
    if SIDES[side] == nil then side = M.DEFAULT_SIDE end
    local r, err = rex.session.new_split{
      anchor_id = here,
      direction = SIDES[side].direction,
      side = SIDES[side].side,
      focus = false,
      layout = { block = { flavor = SHELL, label = label,
        options = { command = { "/bin/sh", opts.script, kb.bin, port, inspector, socket, profile,
          opts.rex, ctx.session_id, here } } } },
    }
    if err ~= nil or r == nil then error("trex: couldn't open the DevTools Pane: " .. tostring(err), 0) end
    return { block_id = r.block_ids and r.block_ids[1], browser = here, kb = browser.id, port = port,
      target = target, inspector = inspector, socket = socket, side = side }
  end

  return devtools
end

return M
