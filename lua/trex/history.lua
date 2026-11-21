-- The rows of Trex: Open Browser…'s palette list: the default URL, then the URLs
-- kb remembers (`~/.kittybrowser/history`), best first.
--
-- kb's history file has one line per URL: `count<TAB>last-visit-epoch<TAB>url`.

local M = {}

local HOUR = 3600
local DAY = 24 * HOUR

-- How much a URL's visit count is worth, by how long ago it was last visited.
local function weight(age)
  if age <= 4 * HOUR then return 4 end
  if age <= DAY then return 2 end
  if age <= 7 * DAY then return 1 end
  return 0.5
end

-- The URL as it is shown: no scheme, no trailing slash.
function M.title(address)
  return (address:gsub("^%a[%w+.-]*://", ""):gsub("/+$", ""))
end

-- The URLs in the history file text `text`, best first, as { url, score, visited }.
-- Lines that aren't `count<TAB>epoch<TAB>url` are skipped, and so are URLs starting
-- with "-" (kb would read them as flags). A URL listed twice counts once, at its best score.
function M.ranked(text, now)
  local best = {}
  for line in (text or ""):gmatch("[^\n]+") do
    local count, visited, address = line:match("^(%d+)\t(%d+)\t([^\t\r]+)\r?$")
    count = tonumber(count)
    if count ~= nil and count > 0 and address:sub(1, 1) ~= "-" then
      visited = tonumber(visited)
      local score = count * weight(now - visited)
      local key = M.title(address)
      if best[key] == nil or score > best[key].score then
        best[key] = { url = address, score = score, visited = visited }
      end
    end
  end
  local list = {}
  for _, entry in pairs(best) do list[#list + 1] = entry end
  table.sort(list, function(a, b)
    if a.score ~= b.score then return a.score > b.score end
    if a.visited ~= b.visited then return a.visited > b.visited end
    return a.url < b.url
  end)
  return list
end

-- The rows for rex.ui.pick: `default_url` first (subtitle "default"), then up to
-- `limit` URLs from the history file at `path`. A missing or unreadable file gives
-- only the default. A row's id is its URL.
function M.rows(util, path, default_url, limit, now)
  local rows = { { id = default_url, title = M.title(default_url), subtitle = "default", icon = "globe" } }
  local skip = M.title(default_url)
  local added = 0
  for _, entry in ipairs(M.ranked(util.read(path), now)) do
    if added >= limit then break end
    if M.title(entry.url) ~= skip then
      rows[#rows + 1] = { id = entry.url, title = M.title(entry.url), subtitle = entry.url, icon = "globe" }
      added = added + 1
    end
  end
  return rows
end

return M
