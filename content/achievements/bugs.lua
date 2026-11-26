-- One per playable bug (generated from content/characters), plus playing them all.
local Content = require("src.content")
local list = {}
local function add(a) a.category = "Bugs"; list[#list + 1] = a; a.order = #list end

add({ id = "play_all", name = "Menagerie", description = "Play a run with every bug.",
    -- custom bugs (Bug Creator) don't count towards these
    goal = function()
        local n = 0
        for _, c in ipairs(Content.characters:all()) do if not c.custom or c.builtin then n = n + 1 end end
        return n
    end,
    value = function(p)
        local n = 0
        for _, c in ipairs(Content.characters:all()) do if (not c.custom or c.builtin) and p.characters[c.id] and p.characters[c.id].runs > 0 then n = n + 1 end end
        return n
    end })
add({ id = "win_5bugs", name = "Diverse Portfolio", description = "Win with 5 different bugs.", goal = 5,
    value = function(p)
        local n = 0
        for id, c in pairs(p.characters) do if c.wins > 0 and id:sub(1, 7) ~= "custom_" then n = n + 1 end end
        return n
    end })
for _, c in ipairs(Content.characters:all()) do
    local id = c.id
    add({ id = "bug_" .. id, name = c.name .. " Champion", description = "Win a run as the " .. c.name .. ".",
        value = function(p) return p.characters[id] and p.characters[id].wins or 0 end })
end
return list
