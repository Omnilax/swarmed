-- Artifacts (content/artifacts): run rules bought once with amber in the Burrow, then switched on
-- or off before a run (mode select > Artifacts). Which are on is kept in prefs ("artifacts").
-- Game.new hands the active list to World.new (opts.artifacts), which applies them; a saved run
-- keeps its own list. The daily run, practice and the tutorial run without them.
local Content = require("src.content")

local Artifacts = {}

local function Prefs() return require("src.game.prefs") end

function Artifacts.unlockId(id) return "artifact_" .. id end

-- Bought (or opened by Unlock Everything)?
function Artifacts.owned(id) return require("src.game.amber").owns(Artifacts.unlockId(id)) end

local function onSet()
    local d = Prefs().get()
    if type(d.artifacts) ~= "table" then d.artifacts = {} end
    return d.artifacts
end

function Artifacts.isOn(id) return onSet()[id] == true and Artifacts.owned(id) end

function Artifacts.set(id, on)
    if on and not Artifacts.owned(id) then return false end
    onSet()[id] = on or nil
    Prefs().save()
    return true
end

-- The ids switched on now, in content order.
function Artifacts.active()
    local out = {}
    for _, a in ipairs(Content.artifacts:all()) do
        if Artifacts.isOn(a.id) then out[#out + 1] = a.id end
    end
    return out
end

-- Do these Game params take artifacts? (not the daily run, practice, the tutorial or the sandbox)
function Artifacts.allowed(params)
    if (params.mode or "run") ~= "run" or params.daily or params.practice then return false end
    local m = Content.modes:get(params.gameMode or "colony")
    return not (m and m.tutorial)
end

-- Game.new: fill params.artifacts (a new run takes what is switched on; a resumed run keeps its
-- own) and let artifacts change the params (Metamorphosis picks the bug).
function Artifacts.prepare(params)
    if not Artifacts.allowed(params) then params.artifacts = nil return params end
    if params.artifacts == nil then params.artifacts = Artifacts.active() end
    if not params.resume then
        for _, id in ipairs(params.artifacts) do
            local a = Content.artifacts:get(id)
            if a and a.params then a.params(params) end
        end
    end
    return params
end

-- World.new: apply each artifact once the world is made.
function Artifacts.apply(world, list)
    world.artifacts = {}
    for _, id in ipairs(list or {}) do
        local a = Content.artifacts:get(id)
        if a then
            world.artifacts[#world.artifacts + 1] = id
            if a.apply then a.apply(world) end
        end
    end
    -- say which are on as the first wave starts
    if #world.artifacts > 0 and world.mode == "run" then
        local said = false
        world.events:on("wave_started", function()
            if said or not world.director then return end
            said = true
            world.director:announce("Artifacts", Artifacts.names(world.artifacts), require("src.core.util").hex("#e7a3ff"))
        end)
    end
end

-- "Glass Carapace, Teeming" (or nil).
function Artifacts.names(list)
    local out = {}
    for _, id in ipairs(list or {}) do
        local a = Content.artifacts:get(id)
        if a then out[#out + 1] = a.name end
    end
    return #out > 0 and table.concat(out, ", ") or nil
end

return Artifacts
