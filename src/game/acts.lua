-- Acts: a 15-wave run is three acts of five waves, each on its own map. After the queen of
-- waves 5 and 10 (and her rewards and the shop), starting the next wave takes the run to the
-- next map on its route instead: the run is saved, and picked up again on the new map
-- (src/game/runsave.lua does the carrying), with a title card saying where you are.
--
-- The route is planned when the run starts: act 1 is the map you chose, acts 2 and 3 are other
-- maps you have open (bought in the Burrow), so every map you buy can turn up later in a run.
-- With only one map open, the run stays on it.
--
-- Off for practice, the daily run, endless, custom and scripted waves, modes with `acts = false`,
-- and with Settings > Gameplay > Travel Between Acts off. Gentle Start holds it back until the
-- second run ("acts" in src/config/onramp.lua).
local Settings = require("src.core.settings")
local Content = require("src.content")

local Acts = { LENGTH = 5, COUNT = 3 }

-- Does this world travel between acts?
function Acts.enabled(world)
    if Acts.off or not world or world.mode ~= "run" then return false end
    local f = world.flags or {}
    if f.demo or f.practice or world.daily or world.lessons then return false end
    if Settings.get("travelActs") == false then return false end
    local m = world.modeDef
    if m and (m.acts == false or m.custom or m.waves or m.endless or m.tutorial) then return false end
    local sp = world.spawner
    if not sp or sp.endless then return false end
    local final = sp:finalWave()
    return final ~= nil and final >= Acts.LENGTH * 2
end

-- Plan the run's route: { stage ids }, act 1 first. Seeded from the world's seed, so a seeded run
-- (the daily, a shared seed) always goes the same way.
function Acts.plan(world, rng)
    local first = world.stage.id
    local route = { first }
    local pool = {}
    for _, s in ipairs(require("src.game.cosmetics").locations()) do
        if s.id ~= first then pool[#pool + 1] = s.id end
    end
    local gen = love.math.newRandomGenerator((tonumber(world.seed) or os.time()) % 2147483647 + 7)
    local rand = rng or function(n) return gen:random(n) end
    for i = #pool, 2, -1 do
        local j = rand(i)
        pool[i], pool[j] = pool[j], pool[i]
    end
    for a = 2, Acts.COUNT do route[a] = pool[a - 1] or route[a - 1] end
    return route
end

-- Which act a wave belongs to (1..COUNT; waves past the final wave stay in the last act).
function Acts.actOf(wave)
    return math.max(1, math.min(Acts.COUNT, math.floor((math.max(1, wave) - 1) / Acts.LENGTH) + 1))
end

-- Starting wave n means moving to a new map first?
function Acts.travelsBefore(world, n)
    if not Acts.enabled(world) or not world.actRoute then return false end
    if n <= 1 or (n - 1) % Acts.LENGTH ~= 0 then return false end
    local act = Acts.actOf(n)
    if act <= (world.act or 1) then return false end
    local final = world.spawner:finalWave()
    if final and n > final then return false end
    if not require("src.game.onramp").allows(world, "acts", n) then return false end
    local nextStage = world.actRoute[act]
    return nextStage ~= nil and nextStage ~= world.stage.id
end

-- Set up a world for acts: a new run plans its route, a resumed one keeps its own.
function Acts.attach(world, snap)
    if snap and type(snap.route) == "table" then
        world.actRoute, world.act = snap.route, tonumber(snap.act) or 1
    elseif not snap then
        world.actRoute, world.act = Acts.plan(world), 1
    else
        world.actRoute, world.act = { world.stage.id }, 1
    end
    -- just arrived on a new map: a title card, and the NEW card the first time
    if snap and snap.travelled then
        local Fx = require("src.core.util")
        require("src.game.onramp").reveal(world, "acts")
        if world.director then
            world.director:announce(("Act %d of %d"):format(world.act, Acts.COUNT), world.stage.name, Fx.hex("#ffd27a"), true)
        end
    end
end

-- One line for the HUD during the break before a travel: "Next: Act 2 · Puddle Patio".
function Acts.nextLine(world)
    local sp = world.spawner
    if not sp or sp.phase ~= "break" then return nil end
    local n = sp.wave + 1
    if not Acts.travelsBefore(world, n) then return nil end
    local def = Content.stages:get(world.actRoute[Acts.actOf(n)])
    return def and ("the colony moves on: act %d is %s"):format(Acts.actOf(n), def.name) or nil
end

return Acts
