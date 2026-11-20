-- Loads trex from this checkout for `rex do tests/load.lua --action NAME`,
-- the way the trex block in init.lua does, so tests never touch the real
-- config. Test-only settings come from the environment, because `rex do`
-- types KEY=VALUE pairs against the action's own arguments:
--
--   TREX_CRATES2  the cargo install record to check the pinned kb against
--   TREX_STATE    trex's state file (tests/lib.sh gives each test its own)

local here = debug.getinfo(1, "S").source:gsub("^@", "")
local root = here:match("^(.*)/tests/[^/]*$")

local opts = {}
local crates2 = os.getenv("TREX_CRATES2")
if crates2 ~= nil and crates2 ~= "" then opts.crates2 = crates2 end
local state = os.getenv("TREX_STATE")
if state ~= nil and state ~= "" then opts.state = state end

dofile(root .. "/lua/trex/init.lua").setup(opts)
