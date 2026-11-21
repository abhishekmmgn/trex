-- Loads trex from this checkout for `rex do tests/load.lua --action NAME`,
-- the way the trex block in init.lua does, so tests never touch the real
-- config. Test-only settings come from the environment, because `rex do`
-- types KEY=VALUE pairs against the action's own arguments:
--
--   TREX_KB       the kb binary trex runs (tests/lib.sh sets it to $KB)
--   TREX_CRATES2  the cargo install record to check the pinned kb against
--   TREX_STATE    trex's state file (tests/lib.sh gives each test its own)
--   TREX_CONFIG   trex's config file (tests/lib.sh gives each test its own, in a temp dir)
--   TREX_CLIPBOARD the command Element Handoff copies with, so tests never
--                 touch the user's clipboard
--   TREX_KB_HISTORY kb's history file (tests that need one write their own fixture)
--   TREX_PROMPT   a file: when set, rex.ui.input and rex.ui.pick never reach a Rex
--                 app. They answer with TREX_PROMPT_ANSWER, and write what they were
--                 asked (the table, as JSON, items included) to this file (rex.ui.pick:
--                 to this file with ".pick" added). rex.ui.pick answers as
--                 TREX_PROMPT_PICK says: "id" (the default: the answer is a row id),
--                 "text" (typed text, as { text = … }), or the reason it returns
--                 with no answer: "unsupported", "failed", "busy", "cancelled".
--   TREX_CLIENT_LOG a file each rex.client.queue call is appended to, as a JSON line.
--                 rex.client.queue never reaches a Rex app from here, set or not, so
--                 tests never switch the user's app to a test session.

local this_file = debug.getinfo(1, "S").source:gsub("^@", "")
local root = this_file:match("^(.*)/tests/[^/]*$")

local opts = {}
local kb = os.getenv("TREX_KB")
if kb ~= nil and kb ~= "" then opts.kb = kb end
local crates2 = os.getenv("TREX_CRATES2")
if crates2 ~= nil and crates2 ~= "" then opts.crates2 = crates2 end
local state = os.getenv("TREX_STATE")
if state ~= nil and state ~= "" then opts.state = state end
local config = os.getenv("TREX_CONFIG")
if config ~= nil and config ~= "" then opts.config = config end
local kb_history = os.getenv("TREX_KB_HISTORY")
if kb_history ~= nil and kb_history ~= "" then opts.kb_history = kb_history end
local clipboard = os.getenv("TREX_CLIPBOARD")
if clipboard ~= nil and clipboard ~= "" then opts.clipboard = clipboard end

-- Client actions (such as session.select) would go to the user's app, so record them instead.
local client_log = os.getenv("TREX_CLIENT_LOG")
local function fake_queue(name, args)
  if client_log == nil or client_log == "" then return end
  local f = assert(io.open(client_log, "a"))
  f:write(rex.json.encode({ name = name, args = args or {} }), "\n")
  f:close()
end
rex.client = rex.client or {}
rex.client.queue = fake_queue
if rex.client.queue ~= fake_queue then
  error("tests/load.lua: couldn't replace rex.client.queue", 0)
end

local prompt_log = os.getenv("TREX_PROMPT")
if prompt_log ~= nil and prompt_log ~= "" then
  local function fake_input(spec)
    local f = assert(io.open(prompt_log, "w"))
    f:write(rex.json.encode(spec))
    f:close()
    return os.getenv("TREX_PROMPT_ANSWER") or ""
  end
  local function fake_pick(spec)
    local f = assert(io.open(prompt_log .. ".pick", "w"))
    f:write(rex.json.encode(spec))
    f:close()
    local answer = os.getenv("TREX_PROMPT_ANSWER") or ""
    local as = os.getenv("TREX_PROMPT_PICK") or "id"
    if as == "id" then return answer end
    if as == "text" then return { text = answer } end
    return nil, as
  end
  rex.ui.input = fake_input
  rex.ui.pick = fake_pick
  -- If Rex didn't take the stand-ins, stop here rather than prompt the user's app.
  if rex.ui.input ~= fake_input or rex.ui.pick ~= fake_pick then
    error("tests/load.lua: couldn't replace rex.ui.input and rex.ui.pick", 0)
  end
end

dofile(root .. "/lua/trex/init.lua").setup(opts)
