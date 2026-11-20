-- The DevTools Pane: Chrome DevTools for a Browser Pane's page, shown by a
-- second kb split below the Browser Pane.
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

-- The session's block labelled `label`, if any.
local function find_block(label)
  local listed = rex.session.list_blocks{}
  for _, b in ipairs((listed and listed.blocks) or {}) do
    if b.label == label then return b.block_id end
  end
  return nil
end

-- opts: kb (from kb.lua), script (path of devtools-pane.sh).
function M.new(opts)
  local kb = opts.kb
  local devtools = {}

  -- Opens the DevTools Pane below `browser_block`, leaving focus where it is. The
  -- pane is labelled "trex devtools <kb id>", which is how it is found again.
  -- Returns { block_id, browser, kb, port, target, inspector, socket,
  -- already_open (true when it was open already) }, or nil
  -- when `browser_block` isn't a Browser Pane (no kb in `kb list` has it).
  -- Raises a message for the user when it is one but DevTools can't open.
  function devtools.open(browser_block)
    local browser = kb.in_block(browser_block)
    if browser == nil then return nil end
    local port = kb.devtools_port(browser.n)
    if port == nil then
      error("trex: the KittyBrowser in this pane (" .. browser.id .. ") was started without DevTools."
        .. " Open it with trex: Open Browser…, which runs kb --devtools.", 0)
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
    local label = M.LABEL .. " " .. browser.id
    local result = { browser = browser_block, kb = browser.id, port = port, target = target,
      inspector = inspector, socket = socket }

    -- Already open: leave it be. (Two would share one socket and profile.)
    local open = find_block(label)
    if open ~= nil then
      result.block_id = open
      result.already_open = true
      return result
    end

    local r, err = rex.session.new_split{
      anchor_id = browser_block,
      direction = "vertical",
      side = "after",
      focus = false,
      layout = { block = { flavor = SHELL, label = label,
        options = { command = { "/bin/sh", opts.script, kb.bin, port, inspector, socket, profile } } } },
    }
    if err ~= nil or r == nil then error("trex: couldn't open the DevTools Pane: " .. tostring(err), 0) end
    result.block_id = r.block_ids and r.block_ids[1]
    return result
  end

  return devtools
end

return M
