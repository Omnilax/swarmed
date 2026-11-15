-- What the menus remember between sessions: the last bug and mode played (the title screen's
-- "Again" shortcut), favourite bugs, how character select is sorted and filtered, and the
-- practice screen's last choices. Saved to "prefs.lua" in the save folder.
local util = require("src.core.util")

local Prefs = { FILE = "prefs.lua", data = nil }

local function blank()
    return {
        last = nil,              -- { character = id, gameMode = id }
        favourites = {},         -- character id -> true
        sort = "default",        -- character select sort (src/config/playstyles.lua sorts)
        filter = "all",          -- character select filter
        practice = {},           -- practice screen choices
    }
end

function Prefs.load()
    local d = blank()
    if love.filesystem.getInfo(Prefs.FILE) then
        local ok, chunk = pcall(love.filesystem.load, Prefs.FILE)
        local ok2, data = false, nil
        if ok and chunk then ok2, data = pcall(chunk) end
        if ok2 and type(data) == "table" then
            for k, v in pairs(data) do
                if d[k] == nil or type(v) == type(d[k]) then d[k] = v end
            end
        end
    end
    Prefs.data = d
    return d
end

function Prefs.get() return Prefs.data or Prefs.load() end

function Prefs.save()
    if Prefs.noSave or not Prefs.data then return end
    local ok, s = pcall(util.serialize, Prefs.data)
    if ok then pcall(love.filesystem.write, Prefs.FILE, "return " .. s .. "\n") end
end

-- A real run started (Game params): remember it for the title screen shortcut.
function Prefs.played(params)
    local d = Prefs.get()
    d.last = { character = params.character, gameMode = params.gameMode or "colony" }
    Prefs.save()
end

function Prefs.isFavourite(id) return Prefs.get().favourites[id] == true end

function Prefs.toggleFavourite(id)
    local f = Prefs.get().favourites
    f[id] = not f[id] or nil
    Prefs.save()
    return f[id] == true
end

function Prefs.set(key, value)
    Prefs.get()[key] = value
    Prefs.save()
end

return Prefs
