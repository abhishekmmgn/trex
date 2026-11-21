-- Element Handoff's pick mode (.scratch/element-handoff/spec.md): the user
-- hovers the page in a Browser Pane and clicks an element, and its description
-- goes to the clipboard.
--
-- The action only turns pick mode on (or off) and returns at once: pick.js runs
-- in the page through `kb ctl -i ID eval`, and pick-wait.sh, started in the
-- background, waits for the pick and copies it.
--
-- Loaded as loadfile("pick.lua")(util). Returns M; M.new(opts) → pick.

local util = ...

local M = {}

-- opts: kb (kb.lua's kb), js (path of pick.js), waiter (path of pick-wait.sh),
-- clipboard (a command that copies its stdin, /usr/bin/pbcopy).
function M.new(opts)
  local kb = opts.kb
  local pick = {}

  -- The Browser Pane's kb for a command run in `block_id`: that pane's own kb,
  -- else the only one in its Rex window, else the only one in its session (as
  -- `bin/trex browser` decides). Returns the kb row, or nil and a message.
  function pick.browser_for(block_id)
    local own = kb.in_block(block_id)
    if own ~= nil then return own end

    local listed = rex.session.list_blocks{}
    local window_of, here = {}, nil
    for _, b in ipairs((listed and listed.blocks) or {}) do
      window_of[b.block_id] = b.window_id
      if b.block_id == block_id then here = b.window_id end
    end
    local in_window, in_session = {}, {}
    for _, k in ipairs(kb.list()) do
      local w = window_of[k.block]
      if w ~= nil then
        in_session[#in_session + 1] = k
        if w == here then in_window[#in_window + 1] = k end
      end
    end
    local found = #in_window > 0 and in_window or in_session
    if #found == 1 then return found[1] end
    if #found == 0 then
      return nil, "trex: there's no Browser Pane here. Open one with Trex: Open Browser… (cmd+shift+b)."
    end
    local ids = {}
    for _, k in ipairs(found) do ids[#ids + 1] = k.id end
    return nil, "trex: there's more than one Browser Pane here (" .. table.concat(ids, ", ")
      .. "), so run Trex: Pick Element in the one you want."
  end

  -- Turns pick mode on in the Browser Pane for `ctx.block_id`, or off if it is
  -- on. Returns { started = true, kb, browser } or { cancelled = true, kb,
  -- browser }. Raises a message for the user when there's no Browser Pane or
  -- its page doesn't answer.
  function pick.toggle(ctx)
    local browser, why = pick.browser_for(ctx.block_id)
    if browser == nil then error(why, 0) end

    local js = util.read(opts.js)
    if js == nil then error("trex: couldn't read " .. opts.js, 0) end
    local r = rex.exec({ kb.bin, "ctl", "-i", browser.id, "eval", js },
      { timeout = 5, env = { KB_SOCKET = false, KB_INSTANCE = false } })
    local answer = r and r.ok and (r.stdout or ""):gsub("%s+$", "")
    if answer == "cancelled" then return { cancelled = true, kb = browser.id, browser = browser.block } end
    if answer ~= "started" then
      local detail = r and ((r.stderr ~= "" and r.stderr) or r.stdout) or "no answer"
      error("trex: couldn't start picking in KittyBrowser " .. browser.id .. ": "
        .. tostring(detail):gsub("%s+$", ""), 0)
    end

    -- In the background, so the action returns while the user picks. Its
    -- output goes nowhere, or rex.exec would wait for it.
    rex.exec({ "/bin/sh", "-c", '"$0" "$@" </dev/null >/dev/null 2>&1 &',
      "/bin/sh", opts.waiter, kb.bin, browser.id, opts.clipboard }, { timeout = 3 })
    return { started = true, kb = browser.id, browser = browser.block }
  end

  return pick
end

return M
