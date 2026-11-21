-- Running KittyBrowsers (`kb`, the Base Browser, ADR-0001): which kb is in which
-- Rex block (`kb list`), what it shows (`kb ctl status`), and its DevTools port
-- and page targets. The one place trex reads kb's text output.
--
-- Loaded as loadfile("kb.lua")(util). Returns M; M.new{ bin, home } → kb.

local util = ... -- util.lua, passed in by whoever loads this file

local M = {}

-- The URL of Chrome DevTools for page target `target` on DevTools port `port`,
-- the same form kb's own F12 builds.
function M.inspector_url(port, target)
  return ("http://127.0.0.1:%s/devtools/inspector.html?ws=127.0.0.1:%s/devtools/page/%s"):format(port, port, target)
end

-- Whether two page URLs are the same, ignoring a trailing "/": kb reports the
-- address it was given (http://localhost:3000) until the page loads, Chrome the
-- loaded one (http://localhost:3000/).
local function same_url(a, b)
  return (a or ""):gsub("/$", "") == (b or ""):gsub("/$", "")
end

-- opts: bin (path of kb), home (whose ~/.kittybrowser to look in).
function M.new(opts)
  local kb = { bin = opts.bin, home = opts.home }

  -- Runs `kb ARGS` for a Browser Pane's kb. Never with the DevTools Pane's
  -- KB_SOCKET, which beats -i.
  local function run(args, timeout)
    local argv = { kb.bin }
    for _, a in ipairs(args) do argv[#argv + 1] = a end
    return rex.exec(argv, { timeout = timeout, env = { KB_SOCKET = false, KB_INSTANCE = false } })
  end

  -- Every kb in `kb list`: { n = instance number, url = its page, block = its
  -- Rex block, id = "N-xxxx" }. A DevTools Pane's kb has its own KB_SOCKET, so
  -- `kb list` never shows it.
  function kb.list()
    -- F12 runs this in a key function, which Rex gives 5 s in all.
    local r = run({ "list" }, 3)
    local rows = {}
    for line in ((r and r.stdout) or ""):gmatch("[^\n]+") do
      local n, url, block, id = line:match("^(%d+)\t([^\t]*)\t([^\t]*)\t([^\t]*)$")
      if n ~= nil then rows[#rows + 1] = { n = tonumber(n), url = url, block = block, id = id } end
    end
    return rows
  end

  local function find(field, value)
    for _, k in ipairs(kb.list()) do
      if k[field] == value then return k end
    end
    return nil
  end

  -- The kb running in Rex block `block_id`; nil if none.
  function kb.in_block(block_id) return find("block", block_id) end

  -- The kb `kb list` calls `id` ("N-xxxx"); nil if none.
  function kb.by_id(id) return find("id", id) end

  -- What kb `id` shows: { url, title, windows = the `windows:` line }; nil if
  -- it doesn't answer.
  function kb.status(id)
    local r = run({ "ctl", "-i", id, "status" }, 2)
    if r == nil or not r.ok then return nil end
    local text = r.stdout
    return {
      url = text:match("\nurl: ([^\n]*)") or text:match("^url: ([^\n]*)"),
      title = text:match("\ntitle: ([^\n]*)") or text:match("^title: ([^\n]*)"),
      windows = text:match("\nwindows: ([^\n]*)"),
    }
  end

  -- kb's data directory: its profiles and sockets, and trex's DevTools Pane files.
  function kb.data_dir()
    return kb.home .. "/.kittybrowser"
  end

  -- The DevTools port of kb instance `n`; nil if it was started without --devtools.
  -- Instance 1's profile is `profile`, the others' `profile-N`. Chrome writes
  -- DevToolsActivePort there: the port, then its browser endpoint
  -- (/devtools/browser/<id>). A Chrome that is killed can leave the file behind,
  -- and a kb without --devtools then finds it, so the port only counts if the
  -- Chrome on it reports that same endpoint.
  function kb.devtools_port(n)
    local profile = kb.data_dir() .. "/" .. (n == 1 and "profile" or ("profile-" .. n))
    local port, endpoint = (util.read(profile .. "/DevToolsActivePort") or ""):match("^(%d+)\r?\n([^\r\n]+)")
    if port == nil then return nil end
    local version = util.get_json("http://127.0.0.1:" .. port .. "/json/version")
    local ws = version and version.webSocketDebuggerUrl
    if type(ws) ~= "string" or ws:sub(-#endpoint) ~= endpoint then return nil end
    return port
  end

  -- The id of the page target kb `id` shows, among the pages on its DevTools
  -- port `port` (`/json/list` also lists Chrome's own UI targets, and each
  -- window a page opens is a page of its own). With one page, that one; else
  -- the page whose url, and if need be title, are the ones kb shows. Returns
  -- nil and a message for the user when no page or several match: trex never
  -- guesses.
  function kb.shown_target(id, port)
    local pages = {}
    for _, t in ipairs(util.get_json("http://127.0.0.1:" .. port .. "/json/list") or {}) do
      if t.type == "page" then pages[#pages + 1] = t end
    end
    if #pages == 0 then
      return nil, "trex: KittyBrowser " .. id .. " lists no page on its DevTools port " .. port .. "."
    end
    if #pages == 1 then return pages[1].id end

    local shown = kb.status(id)
    if shown == nil then return nil, "trex: KittyBrowser " .. id .. " isn't answering." end
    local function matching(list, keep)
      local out = {}
      for _, t in ipairs(list) do if keep(t) then out[#out + 1] = t end end
      return out
    end
    local same = matching(pages, function(t) return same_url(t.url, shown.url) end)
    if #same > 1 then same = matching(same, function(t) return t.title == shown.title end) end
    if #same == 1 then return same[1].id end
    if #same == 0 then
      return nil, ("trex: none of KittyBrowser %s's %d windows is on %s, the page it shows."
        .. " Press F12 again once the page has loaded."):format(id, #pages, tostring(shown.url))
    end
    return nil, ("trex: KittyBrowser %s has %d windows on %s, so trex can't tell which one it shows."
      .. " Close the others (kb ctl -i %s back closes a popup) and press F12 again."):format(id, #same, shown.url, id)
  end

  return kb
end

return M
