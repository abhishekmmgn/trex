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
--   TREX_PROMPT   a file: when set, rex.ui.input never reaches a Rex app. It
--                 answers with the text TREX_PROMPT_ANSWER, and writes what it
--                 was asked (the rex.ui.input table, as JSON) to this file.

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
local clipboard = os.getenv("TREX_CLIPBOARD")
if clipboard ~= nil and clipboard ~= "" then opts.clipboard = clipboard end

local prompt_log = os.getenv("TREX_PROMPT")
if prompt_log ~= nil and prompt_log ~= "" then
  local function fake_input(spec)
    local f = assert(io.open(prompt_log, "w"))
    f:write(rex.json.encode(spec))
    f:close()
    return os.getenv("TREX_PROMPT_ANSWER") or ""
  end
  rex.ui.input = fake_input
  -- If Rex didn't take the stand-in, stop here rather than prompt the user's app.
  if rex.ui.input ~= fake_input then error("tests/load.lua: couldn't replace rex.ui.input", 0) end
end

dofile(root .. "/lua/trex/init.lua").setup(opts)
