-- The DevTools Pane: Chrome DevTools for a Browser Pane's page, shown by a
-- second kb split beside the Browser Pane.
--
-- Browser Pane block → its kb (`kb list`) → that kb's DevTools port → the page
-- target it shows (/json/list) → the inspector URL, which devtools-pane.sh opens
-- in a kb of its own. That kb gets its own KB_SOCKET and Chrome profile, so
-- `kb list`, `kb ctl` and `kb mcp` never see it (agents keep driving the
-- Browser Pane). While it is open, devtools-watch.lua keeps it on the page the
-- Browser Pane shows, remembers its side, and closes it with the Browser Pane.
--
-- Loaded as loadfile("devtools.lua")(util, kb_module). Returns M; M.new(opts) → devtools.

local util, kb_module = ...

local M = {}

local LABEL = "trex devtools"

-- The kb id of the Browser Pane a DevTools Pane belongs to, from its label
-- "trex devtools <kb id>"; nil for any other label.
local function browser_kb_id(label)
  if label == nil or label:sub(1, #LABEL + 1) ~= LABEL .. " " then return nil end
  return label:sub(#LABEL + 2)
end

-- Where a DevTools Pane can sit next to its Browser Pane, as new_split arguments.
local SIDES = {
  below = { direction = "vertical", side = "after" },
  above = { direction = "vertical", side = "before" },
  right = { direction = "horizontal", side = "after" },
  left = { direction = "horizontal", side = "before" },
}

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
function M.side_of(browser, devtools)
  local b, d = rects(browser, devtools)
  if b == nil then return nil end
  local eps = 1e-6
  if d[2] >= b[2] + b[4] - eps then return "below" end
  if d[2] + d[4] <= b[2] + eps then return "above" end
  if d[1] >= b[1] + b[3] - eps then return "right" end
  if d[1] + d[3] <= b[1] + eps then return "left" end
  return nil
end

-- Saves which side of `browser` the DevTools Pane `devtools` is on in `state`,
-- if they are side by side; returns that side.
function M.remember_side(state, browser, devtools)
  local side = browser and M.side_of(browser, devtools)
  if side ~= nil then state.set("devtools_side", side) end
  return side
end

local function close_block(session_id, block_id)
  local r, err = rex.call("block.close", { session_id = session_id, block_id = block_id })
  if r == nil then error("trex: couldn't close the DevTools Pane: " .. tostring(err), 0) end
end

-- opts: kb (kb.lua's kb), script (path of devtools-pane.sh), rex (path of the
-- rex CLI, which the DevTools Pane runs its watcher with), state (state.lua,
-- where the side the user last had DevTools on is kept), state_path (its file).
function M.new(opts)
  local kb = opts.kb
  local devtools = {}

  -- Closes the DevTools Pane `block` of the Browser Pane `browser` (if known),
  -- first remembering which side of it the user had it on.
  local function close(ctx, block, browser)
    local side = M.remember_side(opts.state, browser, block)
    close_block(ctx.session_id, block)
    return { closed = true, block_id = block, browser = browser, side = side }
  end

  -- F12: opens a DevTools Pane for the Browser Pane `ctx.block_id`, or closes
  -- the one it has. In a DevTools Pane, closes that pane. It opens on the side
  -- of the Browser Pane the last one was on (below at first).
  --
  -- Returns { closed = true, block_id = the DevTools Pane closed, browser, side }
  -- when it closed one; else { block_id, browser, kb, port, target, inspector,
  -- socket, side } for the pane it opened. Returns nil when `ctx.block_id` is
  -- neither a Browser Pane (no kb in `kb list` has it) nor a DevTools Pane.
  -- Raises a message for the user when it is a Browser Pane but DevTools can't open.
  function devtools.toggle(ctx)
    local pane = ctx.block_id

    local in_devtools = util.find_block("block_id", pane)
    local owner_id = browser_kb_id(in_devtools and in_devtools.label)
    if owner_id ~= nil then
      local owner = kb.by_id(owner_id)
      return close(ctx, pane, owner and owner.block)
    end

    local browser = kb.in_block(pane)
    if browser == nil then return nil end
    local label = LABEL .. " " .. browser.id

    local open = util.find_block("label", label)
    if open ~= nil then return close(ctx, open.block_id, pane) end

    local port = kb.devtools_port(browser.n)
    if port == nil then
      error("trex: the KittyBrowser in this pane (" .. browser.id .. ") was started without DevTools."
        .. " Open it with Trex: Open Browser…, which runs kb --devtools.", 0)
    end
    local target, why = kb.shown_target(browser.id, port)
    if target == nil then error(why, 0) end

    -- One socket and profile per run of the Browser Pane's kb, so DevTools Panes for
    -- several Browser Panes can be open at once. The socket path must stay under 104 bytes.
    local dir = kb.data_dir() .. "/trex-devtools"
    local socket = dir .. "/" .. browser.id .. ".sock"
    local profile = dir .. "/" .. browser.id
    local inspector = kb_module.inspector_url(port, target)

    local side = opts.state.get("devtools_side")
    if SIDES[side] == nil then side = "below" end
    local watch = rex.json.encode{ browser = pane, kb = kb.bin, kb_id = browser.id, port = port,
      target = target, socket = socket, state = opts.state_path }
    local r, err = rex.session.new_split{
      anchor_id = pane,
      direction = SIDES[side].direction,
      side = SIDES[side].side,
      focus = false,
      layout = { block = { flavor = util.SHELL, label = label,
        options = { command = { "/usr/bin/env",
          "TREX_KB=" .. kb.bin, "TREX_PORT=" .. port, "TREX_INSPECTOR=" .. inspector,
          "TREX_SOCKET=" .. socket, "TREX_PROFILE=" .. profile,
          "TREX_REX=" .. opts.rex, "TREX_SESSION=" .. ctx.session_id, "TREX_WATCH=" .. watch,
          "/bin/sh", opts.script } } } },
    }
    if err ~= nil or r == nil then error("trex: couldn't open the DevTools Pane: " .. tostring(err), 0) end
    return { block_id = r.block_ids and r.block_ids[1], browser = pane, kb = browser.id, port = port,
      target = target, inspector = inspector, socket = socket, side = side }
  end

  return devtools
end

return M
