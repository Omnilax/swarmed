-- Keepsakes (src/config/keepsakes.lua): one small trade your bug carries into a run. Bought with
-- amber in the Burrow ("keepsake_<id>"), picked in mode select (prefs.keepsake), handed to the
-- world as opts.keepsake by Game.new. A saved run keeps its own. Not in the daily run, practice
-- or the tutorial (the same runs that ignore artifacts).
local Cfg = require("src.config.keepsakes")

local Keepsakes = { list = Cfg }

local byId = {}
for i, k in ipairs(Cfg) do k.order = i byId[k.id] = k end

local function Prefs() return require("src.game.prefs") end

function Keepsakes.get(id) return id and byId[id] or nil end
function Keepsakes.unlockId(id) return "keepsake_" .. id end
function Keepsakes.owned(id) return require("src.game.amber").owns(Keepsakes.unlockId(id)) end

-- The keepsake picked for the next run (nil = none, or not owned any more).
function Keepsakes.chosen()
    local id = Prefs().get().keepsake
    if type(id) == "string" and byId[id] and Keepsakes.owned(id) then return id end
    return nil
end

function Keepsakes.choose(id)
    if id and not (byId[id] and Keepsakes.owned(id)) then return false end
    Prefs().get().keepsake = id or false
    Prefs().save()
    return true
end

-- Game.new: a new run takes the chosen one, a resumed run its own.
function Keepsakes.prepare(params)
    if not require("src.game.artifacts").allowed(params) then params.keepsake = nil return params end
    if params.keepsake == nil and not params.resume then params.keepsake = Keepsakes.chosen() end
    return params
end

-- World.new
function Keepsakes.apply(world, id)
    local k = Keepsakes.get(id)
    if not k or not world.player then return end
    world.keepsake = k.id
    local s = world.player.stats
    for _, m in ipairs(k.mods or {}) do s:addModifier("keepsake:" .. k.id, m[1], m[2], m[3]) end
    world.player.hp = s:get("maxHp")
    world.nectarMul = k.nectarMul
    world.xpMul = k.xpMul
    if k.nectar and k.nectar > 0 then
        world.nectar = (world.nectar or 0) + k.nectar
        world.nectarEarned = (world.nectarEarned or 0) + k.nectar
    end
end

return Keepsakes
