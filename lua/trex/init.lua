-- trex for Rex: a Chromium browser (stock KittyBrowser, `kb`) in Rex panes.
--
-- `bin/trex install` loads this from Rex's config (~/.config/rex/init.lua):
--
--   dofile("/path/to/trex/lua/trex/init.lua").setup({})
--
-- setup(opts) options, all optional:
--   kb       path of the kb binary (default ~/.cargo/bin/kb)
--   crates2  cargo's install record, for the pin check (default ~/.cargo/.crates2.json)
--   rex      path of the rex CLI (default: the one Rex's server runs from)
--   state    trex's state file (default ~/.local/state/trex/state.json)
--
-- Config Lua runs in the Rex server: its PATH is only /usr/bin:/bin, and it has
-- no rex.sleep or rex.on. Use absolute paths and keep actions short.

local M = {}

local SHELL = "com.superlogical.terminal.shell"
local DEFAULT_URL = "http://localhost:3000"

-- The directory this file is in, so its sibling modules load from the same checkout.
local DIR = debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*)/[^/]*$")

local function load(name)
  return dofile(DIR .. "/" .. name .. ".lua")
end

local function exists(path)
  local f = io.open(path, "r")
  if f == nil then return false end
  f:close()
  return true
end

-- The rex CLI. The server's PATH has no rex, so look where Rex installs it.
local function find_rex(home)
  local candidates = {
    home .. "/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex",
    "/Applications/Rex Beta.app/Contents/Helpers/Rex Server.rex/Contents/MacOS/rex",
    "/Applications/Rex.app/Contents/Helpers/Rex Server.rex/Contents/MacOS/rex",
    "/opt/homebrew/bin/rex",
    "/usr/local/bin/rex",
  }
  for _, path in ipairs(candidates) do
    if exists(path) then return path end
  end
  return candidates[1]
end

function M.setup(opts)
  opts = opts or {}
  local home = os.getenv("HOME") or ""
  local kb = load("kb").new{
    bin = opts.kb or (home .. "/.cargo/bin/kb"),
    crates2 = opts.crates2 or (home .. "/.cargo/.crates2.json"),
    home = home,
  }
  local url = load("url")
  local devtools = load("devtools").new{
    kb = kb,
    script = DIR .. "/devtools-pane.sh",
    rex = opts.rex or find_rex(home),
    state = load("state")(opts.state or ((os.getenv("XDG_STATE_HOME") or (home .. "/.local/state")) .. "/trex/state.json")),
  }

  -- Opens a Browser Pane: kb --devtools URL in a split right of the focused pane.
  local function open_browser(ctx, address)
    local target, why = url.normalise(address, DEFAULT_URL)
    if target == nil then error(why, 0) end
    kb.check_pin()

    local layout = { block = { flavor = SHELL, label = "trex browser",
      options = { command = { kb.bin, "--devtools", target } } } }
    local r, err
    if ctx.block_id == nil then
      r, err = rex.session.new_window{ label = "trex browser", layout = layout, focus = true }
    else
      r, err = rex.session.new_split{
        anchor_id = ctx.block_id,
        direction = "horizontal",
        side = "after",
        focus = true,
        layout = layout,
      }
    end
    if err ~= nil or r == nil then error("trex: couldn't open a pane: " .. tostring(err), 0) end
    local block_id = r.block_ids and r.block_ids[1]
    return { block_id = block_id, url = target }
  end

  rex.action{
    name = "trex_open",
    title = "trex: Open Browser…",
    description = "Open a URL or a localhost port in a Browser Pane (KittyBrowser with DevTools)"
      .. " to the right of this pane.",
    category = "trex",
    keywords = "trex browser chrome chromium kb kittybrowser web localhost devtools url open",
    args = { url = "string?" },
    run = function(ctx, args)
      local address = args.url
      if address == nil then
        local answer = rex.ui.input{
          title = "Open in a Browser Pane",
          placeholder = "URL or localhost port",
          value = DEFAULT_URL,
          confirm = "Open",
        }
        if answer == nil then return nil end -- cancelled, timed out, or no app to ask
        address = answer
      end
      return open_browser(ctx, address)
    end,
  }
  rex.bind("cmd+shift+b", "trex_open")

  -- Opens a DevTools Pane for the focused Browser Pane, or closes it if it is
  -- open; in a DevTools Pane, closes that.
  local function toggle_devtools(ctx)
    local result = devtools.toggle(ctx)
    if result == nil then error("trex: this pane isn't a Browser Pane. Open one with trex: Open Browser….", 0) end
    return result
  end

  rex.action{
    name = "trex_devtools",
    title = "trex: Toggle DevTools",
    description = "Open Chrome DevTools for this Browser Pane's page in a DevTools Pane, or close it if it is open.",
    category = "trex",
    keywords = "trex devtools inspector inspect elements console network sources chrome kb f12 toggle close",
    run = toggle_devtools,
  }

  -- In config, rex.invoke reaches only actions of the file that defined them, so
  -- the key calls the function rather than the action.
  load("f12")(toggle_devtools)
end

return M
