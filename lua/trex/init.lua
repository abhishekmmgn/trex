-- trex for Rex: a Chromium browser (stock KittyBrowser, `kb`) in Rex panes.
--
-- `bin/trex install` loads this from Rex's config (~/.config/rex/init.lua):
--
--   dofile("/path/to/trex/lua/trex/init.lua").setup({})
--
-- setup(opts) options, all optional:
--   kb       path of the kb binary (default ~/.cargo/bin/kb)
--   crates2  cargo's install record, for the pin check (default ~/.cargo/.crates2.json)
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

function M.setup(opts)
  opts = opts or {}
  local home = os.getenv("HOME") or ""
  local kb = load("kb").new{
    bin = opts.kb or (home .. "/.cargo/bin/kb"),
    crates2 = opts.crates2 or (home .. "/.cargo/.crates2.json"),
  }
  local url = load("url")

  -- Opens a Browser Pane: kb --devtools URL in a split right of the focused pane.
  local function open_browser(ctx, address)
    local target, why = url.normalise(address)
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
end

return M
